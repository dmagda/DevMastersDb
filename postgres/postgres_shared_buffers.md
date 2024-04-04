# Postgres Internals in Action: Shared Memory and Buffers

PostgreSQL uses shared memory to expedite access to the database by caching data in memory and to coordinate the execution of requests from multiple standalone Postgres backends/sessions. In this episode, we're looking into shared buffers, one of the areas of shared memory that holds table data for read and write operations.

**Watch the Video**: <https://www.youtube.com/watch?v=TBmDBw1IIoY>
[![@DevMastersDB](https://github.com/dmagda/DevMastersDb/assets/1537233/a0ab1395-e3fe-4fec-af5d-1032022d85e9)](https://www.youtube.com/watch?v=TBmDBw1IIoY)

## Shared Buffers Basics

Create and populate the table with sample data:

```sql
create table account (id int, balance money);

insert into account (id, balance) 
select id, floor(random() * 1000 + 1)::int::money
from generate_series(1, 100) as id;
```

Show that the data is retrieved from the shared buffer:

```sql
explain (analyze, buffers, costs off) select * from account where id = 10;

explain (analyze, buffers, costs off) select * from account;
```

The data set is so tiny that even when I try to get all 1000 records, Postgres said that it had to read just one buffer:

```output
explain (analyze, buffers, costs off) select * from account;
                           QUERY PLAN
-----------------------------------------------------------------
 Seq Scan on account (actual time=0.017..0.049 rows=100 loops=1)
   Buffers: shared hit=1
 Planning Time: 0.064 ms
 Execution Time: 0.113 ms
(4 rows)
```

The size of a buffer is 8KB. It's equal to the size of the page:
<https://postgrespro.com/blog/pgsql/5967951>

## Explore Buffer Cache Internals

Active the `pg_buffercache` extension to look into the buffer internals:
<https://www.postgresql.org/docs/current/pgbuffercache.html>

```sql
create extension pg_buffercache;
```

The buffer cache is used by both system and user tables:

```sql
select * from pg_buffercache_summary();
```

```output
buffers_used | buffers_unused | buffers_dirty | buffers_pinned |   usagecount_avg
--------------+----------------+---------------+----------------+--------------------
          541 |          15843 |             5 |              0 | 3.7393715341959335
```

You can see how those buffers are distributed by running this function:

```sql
SELECT n.nspname, c.relname, count(*) AS buffers
FROM pg_buffercache b JOIN pg_class c
ON b.relfilenode = pg_relation_filenode(c.oid) AND
  b.reldatabase IN (0, (SELECT oid FROM pg_database
                        WHERE datname = current_database()))
JOIN pg_namespace n ON n.oid = c.relnamespace
GROUP BY n.nspname, c.relname
ORDER BY 3 DESC
LIMIT 10;
```

Let's see how many buffers are used by our `account` table:

```sql
SELECT bufferid,
  relblocknumber,
  isdirty,
  usagecount,
  pinning_backends
FROM pg_buffercache
WHERE relfilenode = pg_relation_filenode('account'::regclass);
```

```output
bufferid | relblocknumber | isdirty | usagecount | pinning_backends
----------+----------------+---------+------------+------------------
      519 |              0 | f       |          5 |                0
```

You see only one buffer which explains why the explain analyze returns `shared hit=1`.
Presently, all the data fits into one page/buffer:

```sql
SELECT setting, unit FROM pg_settings WHERE name = 'shared_buffers';
```

```output
 setting | unit
---------+------
 16384   | 8kB
(1 row)
```

## Changing the Usage Count and Dirty Flags

* Read any record to see the `usagecount` parameter going up. Suprisingly, you'll see that the `usagecount` is not increased and capped by `5`! <https://postgrespro.com/list/thread-id/1496903>

* Update `balance` for any record to see the `isdirty` flag flipping to `t`.

## Creating More Shared Buffers

Add more data to the table to see the database allocation additional buffers:

```sql
insert into account (id, balance) 
select id, floor(random() * 1000 + 1)::int::money
from generate_series(101, 100000) as id;
```

Now, you'll see that the table has many buffers associated with it:

```sql
explain (analyze, buffers) select * from account;
                                                 QUERY PLAN
------------------------------------------------------------------------------------------------------------
 Seq Scan on account  (cost=0.00..155.00 rows=10000 width=12) (actual time=0.109..1.390 rows=10000 loops=1)
   Buffers: shared hit=55
 Planning Time: 0.765 ms
 Execution Time: 2.143 ms
(4 rows)
```

Postgres still has to scan all the buffers even when you need a specific record:

```sql
explain (analyze, buffers) select * from account where id = 5;
                                             QUERY PLAN
----------------------------------------------------------------------------------------------------
 Seq Scan on account  (cost=0.00..180.00 rows=1 width=12) (actual time=0.014..1.031 rows=1 loops=1)
   Filter: (id = 5)
   Rows Removed by Filter: 9999
   Buffers: shared hit=55
 Planning:
   Buffers: shared hit=10
 Planning Time: 2.287 ms
 Execution Time: 1.058 ms
(8 rows)
```

You can create index to address this and to see that indexes also use the shared buffer.

## Creating Primary Key

Add the primary key:

```sql
alter table account add primary key(id);
vacuum analyze;
```

Try to read for the specific record one more time:

```sql
explain (analyze, buffers) select * from account where id = 5;
                                                      QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------
 Index Scan using account_pkey on account  (cost=0.29..8.30 rows=1 width=12) (actual time=0.396..0.406 rows=1 loops=1)
   Index Cond: (id = 5)
   Buffers: shared hit=1 read=2
 Planning:
   Buffers: shared hit=9
 Planning Time: 0.747 ms
 Execution Time: 0.562 ms
(7 rows)
```

* `shared hit=1` - Postgres found one index buffer/page in the shared memory.
* `read=2` - Postgres had to read the two more pages/buffers either from the OS cache or disk.

If you run the same query one more time, you'll find Postgres reading all the data from the shared buffer:

```sql
explain (analyze, buffers) select * from account where id = 5;
                                                      QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------
 Index Scan using account_pkey on account  (cost=0.29..8.30 rows=1 width=12) (actual time=0.096..0.098 rows=1 loops=1)
   Index Cond: (id = 5)
   Buffers: shared hit=3
 Planning Time: 0.108 ms
 Execution Time: 0.146 ms
(5 rows)
```

Run this query to confim the index has several buffers:

```sql
SELECT bufferid,
  relblocknumber,
  isdirty,
  usagecount,
  pinning_backends
FROM pg_buffercache
WHERE relfilenode = pg_relation_filenode('account_pkey'::regclass);
```

```output
bufferid | isdirty | usagecount | pinning_backends
----------+---------+------------+------------------
     1010 | f       |          1 |                0
     1011 | f       |          2 |                0
     1012 | f       |          3 |                0
     1045 | f       |          2 |                0
(4 rows)
```

## Testing From Another Backend

Let's make sure that the shared memory is in fact shared between several Postgres processes.

Open **another psql session** and run the same request that you've just executed in the previous session:

```sql
explain (analyze, buffers) select * from account where id = 5;
                                                      QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------
 Index Scan using account_pkey on account  (cost=0.29..8.30 rows=1 width=12) (actual time=0.096..0.098 rows=1 loops=1)
   Index Cond: (id = 5)
   Buffers: shared hit=3
 Planning Time: 0.108 ms
 Execution Time: 0.146 ms
(5 rows)
```

You'll see that all the pages were served from the shared buffers.

Now, in this second session, query for a record that you've never queried before:

```sql
explain (analyze, buffers) select * from account where id = 2500;
```

```output
                                                      QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------
 Index Scan using account_pkey on account  (cost=0.29..8.30 rows=1 width=12) (actual time=1.635..1.645 rows=1 loops=1)
   Index Cond: (id = 2500)
   Buffers: shared hit=2 read=1
 Planning Time: 0.911 ms
 Execution Time: 1.933 ms
```

You'll see that one of the pages were read from the OS cache or disk (`read=1`). But if you run the same request from the other session, then the `shared hit=3`.

Btw, the number of the buffers used by the index will keep going up if you continue querying for the records that are not cached yet (query for some record in one session and run the following query in another):

```sql
SELECT bufferid,
  isdirty,
  usagecount,
  pinning_backends
FROM pg_buffercache
WHERE relfilenode = pg_relation_filenode('account_pkey'::regclass);

 bufferid | isdirty | usagecount | pinning_backends
----------+---------+------------+------------------
     1007 | f       |          1 |                0
     1008 | f       |          1 |                0
     1009 | f       |          2 |                0
     1010 | f       |          2 |                0
     1011 | f       |          2 |                0
     1012 | f       |          5 |                0
     1045 | f       |          3 |                0
```

Job done!
