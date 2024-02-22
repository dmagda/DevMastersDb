# PostgreSQL MVCC Backstage

PostgreSQL uses MVCC (Multi-Version Concurrency Control) to execute transactions and queries in parallel over a consistent view/snapshot of data. Each user record may exist in multiple versions simultaneously, with each version visible to a particular set of transactions.

[![@DevMastersDB](https://github.com/dmagda/DevMastersDb/assets/1537233/dc77dbea-23f6-4bee-8127-b487cf3416d8)](https://www.youtube.com/watch?v=TBmDBw1IIoY)

## Prerequisites

* Docker

## Start PostgreSQL

1. Create a directory for the Postgres container's volume:

    ```shell
    rm -r ~/postgres-volume
    mkdir ~/postgres-volume
    ```

2. Start a Postgres container:

    ```shell
    docker run --name postgres \
        -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=password \
        -p 5432:5432 \
        -v ~/postgres-volume/:/var/lib/postgresql/data \
        -d postgres:latest
    ```

3. Wait for Postgres to finish the initialization:

    ```shell
    ! while ! docker exec -it postgres pg_isready -U postgres; do sleep 1; done
    ```

## Discover Hidden Columns

Every row in Postgres has a 23-byte header that precedes the columns you define in the table schema. This header [contains 8 fields](https://www.postgresql.org/docs/current/storage-page-layout.html#STORAGE-TUPLE-LAYOUT), primarily used by the database engine internally.

First, create a sample table:

1. Connect to the database:

    ```shell
    docker exec -it postgres psql -U postgres
    ```

2. Create a sample table:

    ```sql
    create table account(id int, balance money);
    ```

3. Add a row to the table:

    ```sql
    insert into account values (1, 500);
    ```

Next, execute a very familiar request:

```sql
select * from account;
```

```output
 xmin | id | balance 
------+----+---------
  733 |  1 | $500.00
(1 row)
```

The `*` does return all the columns but hidden:

```sql
select ctid, xmin, xmax, * from account;
```

```output
 ctid  | xmin | xmax | id | balance 
-------+------+------+----+---------
 (0,1) |  733 |    0 |  1 | $500.00
(1 row)
```

* `ctid` - a row identifier within the page.
* `xmin` - an ID of the transaction created the row.
* `xmax` - an ID of the transaction deleted the row (`0` means the row is not deleted and visible to all requests).

Add two more rows and check the values of their hidden columns:

1. Add the rows:

    ```sql
    insert into account values (2, 600), (3, 700);
    ```

2. Read all the rows back:

    ```sql
    select ctid, xmin, xmax, * from account;
    ```

    ```output
     ctid  | xmin | xmax | id | balance

    -------+------+------+----+---------
    (0,1) |  733 |    0 |  1 | $500.00
    (0,2) |  734 |    0 |  2 | $600.00
    (0,3) |  734 |    0 |  3 | $700.00
    (3 rows)
    ```

## The Purpose for Hidden Columns

Why does PostgreSQL keep the hidden columns in the header of every row? It's **necessary for its MVCC engine**.
Postgres can store several versions of a single row at a time and those hidden columns help to control the visibility of the versions for running transactions/queries.

### Succesfull Transaction

Start a transaction and run a few experiments:

1. Begin the transaction:

    ```shell
    begin;
    ```

2. Get the current value of the first row:

    ```sql
    select ctid, xmin, xmax, * from account where id = 1;
    ```

    ```output
    ctid  | xmin | xmax | id | balance
    -------+------+------+----+---------
    (0,1) |  743 |    0 |  1 | $500.00
    (1 row)
    ```

3. Update the balance:

    ```sql
    update account set balance=400 where id = 1;
    ```

4. Read the row back:

    ```sql
    select ctid, xmin, xmax, * from account where id = 1;
    ```

    ```output
    ctid  | xmin | xmax | id | balance
    -------+------+------+----+---------
    (0,4) |  745 |    0 |  1 | $400.00
    (1 row)
    ```

5. Make sure that the `xmin` is equal to the ID of the current started transaction:

    ```sql
    select txid_current_if_assigned();
    ```

    ```output
    txid_current_if_assigned
    --------------------------

                        752
    (1 row)
    ```

Now, neither commit nor about this transaction. Open another session with Postgres and read the value of the record that is being modified:

1. Connect:

    ```shell
    docker exec -it postgres psql -U postgres
    ```

2. Read the row:

    ```sql
    select ctid, xmin, xmax, * from account where id = 1;
    ```

    ```output
    ctid  | xmin | xmax | id | balance
    -------+------+------+----+---------
    (0,1) |  743 |  745 |  1 | $500.00
    (1 row)
    ```

    This version has different `ctid`, `xmin` and `xmax` when compared to the version that was created by the first transaction.

    Why `xmax` is not `0` any longer. *It is possible for this column to be nonzero in a visible row version. That usually indicates that the deleting transaction hasn’t committed yet, or that an attempted deletion was rolled back.* - [read more here](https://www.cybertec-postgresql.com/en/whats-in-an-xmax/).

Now, in the first session, commit the transaction:

```sql
commit;
```

In the second session, read the row one more time:

```sql
select ctid, xmin, xmax, * from account where id = 1;
```

```output
 ctid  | xmin | xmax | id | balance 
-------+------+------+----+---------
 (0,4) |  745 |    0 |  1 | $400.00
(1 row)
```

That new version of the row was committed and is visible to all future queries/transactions.

## Dead Tuples

What happened to the old version of the row. Has it disappeared?

The database will keep storing old versions until the next garbage collection cycle. Yes, you heard me well, Postgres has a garbage collector. But before let's see how the old versions get generated by MVCC.

1. Install the `pageinspect` extension:

    ```sql
    create extension pageinspect;
    ```

2. See all the versions of all the records of the `account` table:

    ```sql
    SELECT lp, t_ctid, t_xmin, t_xmax, t_data
    FROM heap_page_items(get_raw_page('account', 0));  
    ```

    ```output
     lp | t_ctid | t_xmin | t_xmax |               t_data
    ----+--------+--------+--------+------------------------------------
    1 | (0,4)  |    733 |    737 | \x010000000000000050c3000000000000
    2 | (0,2)  |    734 |      0 | \x020000000000000060ea000000000000
    3 | (0,3)  |    734 |      0 | \x03000000000000007011010000000000
    4 | (0,4)  |    737 |      0 | \x0100000000000000409c000000000000
    (4 rows)
    ```

Also, there are special flags. Let's look at them:

1. Create a special function that makes it easy to read the flags:

    ```sql
    create function heap_page(relname text, pageno_from integer, pageno_to integer)

    returns table (ctid tid, state text, xmin text, xmin_age integer, xmax text,
    hhu text, /*heap hot update - the version is referenced from an index, traverse to the next version using ctid ref */
    hot text, /* heap only tuple - the version is created only in heap without the index update*/
    t_ctid tid
    )
    AS $$
    select (pageno,lp)::text::tid as ctid,
        case lp_flags
        when 0 then 'unused'
        when 1 then 'normal'
        when 2 then 'redirect to '||lp_off
        when 3 then 'dead'
        end as state,
        t_xmin || case
        when (t_infomask & 256+512) = 256+512 then ' f'
        when (t_infomask & 256) > 0 then ' c'
        when (t_infomask & 512) > 0 then ' a'
        else ''
        end as xmin,
        age(t_xmin) as xmin_age,
        t_xmax || case
        when (t_infomask & 1024) > 0 then ' c'
        when (t_infomask & 2048) > 0 then ' a'
        else ''
        end as xmax,
        case when (t_infomask2 & 16384) > 0 then 't' end as hhu,
        case when (t_infomask2 & 32768) > 0 then 't' end as hot,
        t_ctid
    from generate_series(pageno_from, pageno_to) p(pageno),
        heap_page_items(get_raw_page(relname,pageno))
    order by pageno, lp;
    $$ language sql;
    ```

2. Read the records of the first page:

    ```sql
    select * from heap_page('account', 0, 0);
    ```

    ```output
    ctid  | state  | xmin  | xmin_age | xmax  | hhu | hot | t_ctid
    -------+--------+-------+----------+-------+-----+-----+--------
    (0,1) | normal | 743 c |        5 | 745 c | t   |     | (0,4)
    (0,2) | normal | 744 c |        4 | 0 a   |     |     | (0,2)
    (0,3) | normal | 744 c |        4 | 0 a   |     |     | (0,3)
    (0,4) | normal | 745 c |        3 | 0 a   |     | t   | (0,4)
    (4 rows)
    ```

    The `hhu` (heap hot updated) flag set to `t` implies that the database needs to continue the search for the latest row version navigating to the row reference by the `t_ctid`.
    The `hot` (heap only tuple) set to `t` means this row version is not referenced from an index.

## Garbage Collection

Let's update each row by adding $100 to every account:

```sql
update account set balance = balance + 100::money;
```

Make sure that there only three rows in the table:

```sql
select * from account;
```

But now take a look at the Postgres heap:

```sql
select * from heap_page('account', 0, 0);
```

```output
 ctid  | state  | xmin  | xmin_age | xmax  | hhu | hot | t_ctid 
-------+--------+-------+----------+-------+-----+-----+--------
 (0,1) | normal | 733 c |       10 | 742 c | t   |     | (0,5)
 (0,2) | normal | 734 c |        9 | 742 c | t   |     | (0,6)
 (0,3) | normal | 734 c |        9 | 742 c | t   |     | (0,7)
 (0,4) | normal | 737 a |        6 | 0 a   |     | t   | (0,4)
 (0,5) | normal | 742 c |        1 | 0 a   |     | t   | (0,5)
 (0,6) | normal | 742 c |        1 | 0 a   |     | t   | (0,6)
 (0,7) | normal | 742 c |        1 | 0 a   |     | t   | (0,7)
(7 rows)
```

Repeat one more time to see even more dead versions:

```sql
update account set balance = balance + 100::money;
select * from account;
select * from heap_page('account', 0, 0);
```

The dead versions are eventually garbage collected by the vacuum process. You can run it manually for the table:

```sql
vacuum account;
```

And now you'll see that there are only three version for the rows in the Postgres heap:

```sql
select * from heap_page('account', 0, 0);
```

```output
  ctid  |     state      | xmin  | xmin_age | xmax | hhu | hot | t_ctid 
--------+----------------+-------+----------+------+-----+-----+--------
 (0,1)  | redirect to 10 |       |          |      |     |     | 
 (0,2)  | redirect to 8  |       |          |      |     |     | 
 (0,3)  | redirect to 9  |       |          |      |     |     | 
 (0,4)  | unused         |       |          |      |     |     | 
 (0,5)  | unused         |       |          |      |     |     | 
 (0,6)  | unused         |       |          |      |     |     | 
 (0,7)  | unused         |       |          |      |     |     | 
 (0,8)  | normal         | 749 c |        1 | 0 a  |     | t   | (0,8)
 (0,9)  | normal         | 749 c |        1 | 0 a  |     | t   | (0,9)
 (0,10) | normal         | 749 c |        1 | 0 a  |     | t   | (0,10)
(10 rows)
```

The old version are remove but the page was not defragmented. The good thing is that the MVCC engine will be resuing that space:

1. Update the balance for the first account:

    ```sql
    update account set balance = balance + 500::money where id = 1;
    ```

2. Confirm the new version of the row reuses a free space in the middle:

    ```sql
    select * from heap_page('account', 0,0);
    ```

    ```output
      ctid  |     state      | xmin  | xmin_age | xmax | hhu | hot | t_ctid

    --------+----------------+-------+----------+------+-----+-----+--------
    (0,1)  | redirect to 10 |       |          |      |     |     |
    (0,2)  | redirect to 8  |       |          |      |     |     |
    (0,3)  | redirect to 9  |       |          |      |     |     |
    (0,4)  | normal         | 750   |        1 | 0 a  |     | t   | (0,4)
    (0,5)  | unused         |       |          |      |     |     |
    (0,6)  | unused         |       |          |      |     |     |
    (0,7)  | unused         |       |          |      |     |     |
    (0,8)  | normal         | 749 c |        2 | 0 a  |     | t   | (0,8)
    (0,9)  | normal         | 749 c |        2 | 0 a  |     | t   | (0,9)
    (0,10) | normal         | 749 c |        2 | 750  | t   | t   | (0,4)
    (10 rows)
    ```

If you want to defragment the space and return back to the OS, then you can run `vacuum full`:

```sql
vacuum full account;

select * from heap_page('account', 0, 0);
```

```output
 ctid  | state  | xmin  | xmin_age | xmax | hhu | hot | t_ctid 
-------+--------+-------+----------+------+-----+-----+--------
 (0,1) | normal | 743 f |        2 | 0 a  |     |     | (0,1)
 (0,2) | normal | 743 f |        2 | 0 a  |     |     | (0,2)
 (0,3) | normal | 743 f |        2 | 0 a  |     |     | (0,3)
(3 rows)
```

This is the MVCC backstage in Postgres. By storing multiple versions of the records you can run multiple transaction and queries in parallel not worrying about data consistency issues.
