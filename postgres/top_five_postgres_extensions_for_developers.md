# Top Five PostgreSQL Extensions for Application Developers

In this guide, we'll work through the top five PostgreSQL extensions for application developers. We'll start with the most obvious extensions such as pgvector and go down to the least known such as pg_anonimyze.

**Hands-On Video Tutorial: TBD**

## Deploy Extensible Postgres in Cloud

It's usually not a brainer to deploy a Postgres instance with one of its extensions. However it might be a tedious task to get an instance with several extensions.

In this tutorial, we're going to experiment with the five extensions. We'll be using [Tembo](http://tembo.io/) that lets us deploy a free instance of Postgres in the cloud and enable 200+ Postgres extensions with a single button click.

1. Go to [https://cloud.tembo.io](https://cloud.tembo.io)

2. Create a free Hobby instance.

## Create Sample Application

Create a sample NodeJS project that we'll use to experiment with the extensions.

1. Create a new node project:

    ```shell
    mkdir postgres-extensions-demo && cd postgres-extensions-demo
    npm init
    ```

2. Add the Postgres driver:

    ```shell
    npm install pg
    ```

3. Open the project in your favorite IDE such as Visual Studio:

    ```shell
    code .
    ```

Next, create the `index.js` file with the logic that connects to the database:

```javascript
const { Client } = require("pg");
const fs = require("fs");


const dbEndpoint = {
    host: "YOUR_TEMBO_URL",
    port: 5432,
    database: "postgres",
    user: "postgres",
    password: "YOUR_TEMBO_PWD",
    ssl: {
        rejectUnauthorized: false,
        ca: fs.readFileSync("PATH_TO_YOUR_TEMBO_CERT/ca.crt").toString()
    }
};

(async () => {
    const client = new Client(dbEndpoint);
    await client.connect();

    const res = await client.query("SELECT * FROM pg_extension");

    res.rows.forEach(row => {
        console.log(row.extname, row.extversion);
    });

    await client.end();
})();
```

Make sure that the app starts, connects to Tembo and returns the currently pre-installed extensions:

```shell
node index.js
```

## Number 5: pgvector

We're opening our rank with the most obvious Postgres extension - pgvector. The extension adds vector data types, operations, and access methods that turn Postgres into a vector database. With pgvector, application developers can easily build gen AI applications.

1. Go to your Tembo instance and enable the `pgvector` extension.

2. Preload the sample data set using psql or other tools. The files are located under the `postgres/datasets/movies` folder:

```shell
psql YOUR_TEMBO_CONNECTION_STRING -f v1.1__create_movie_table.sql

psql YOUR_TEMBO_CONNECTION_STRING -f V1.2__load_movie_dataset_with_embeddings.sql
```

Next, update the application logic to support the vector similarity search over the movie data set:

1. Install the OpenAI module:

    ```shell
    npm install openai
    ```

2. Store your OpenAI API key in the `openai.key` file on the file system.

3. Import the library into the app logic:

    ```javascript
    const { OpenAI } = require("openai");
    ```

4. Update the application code as follows:

    ```javascript
    (async () => {
        const client = new Client(dbEndpoint);
        await client.connect();
    
        await recommendMovies(client, "long long ago in a galaxy far far away");
    
        await client.end();
    })();
    
    async function recommendMovies(client, prompt) {
        const openAI = new OpenAI({
            apiKey: fs.readFileSync("/Users/dmagda/Downloads/openai.key").toString().trim()
        });
    
        const promptEmbedding = await openAI.embeddings.create({
            model: "text-embedding-ada-002",
            input: prompt
        });
    
        const result = await client.query("select title, overview from movie " +
            "where 1 - (overview_vector <=> $1) > 0.7 " +
            "order by 1 - (overview_vector <=> $1) desc limit 3",
            ['[' + promptEmbedding.data[0].embedding + ']']);
    
        for (const row of result.rows) {
            console.log(row.title);
            console.log(row.overview, "\n");
        }
    }
    ```

## Number 4: Stored procedures in your programming language

This is a category of extension that lets you write and execute stored procedures in your favorite programming language.

In this tutorial, we'll take a look at the plv8 extension that lets create stored procedures in JavaScript.

1. Go to your Tembo instance and enable plv8.

2. Connect to your Tembo instance using psql or other tool and deploy this function written in JavaScript:

    ```sql
    CREATE OR REPLACE FUNCTION whoIsThat() RETURNS json AS $$

    let version = plv8.execute('SELECT version()');
    let message = "Hello, that's me. Postgres!";

    return {"msg": message, ver: version};
    $$LANGUAGE plv8;
    ```

3. Update and execute the application logic by making a call to the stored procedure:

    ```javascript
    (async () => {
        const openAI = new OpenAI({
            apiKey: fs.readFileSync("/Users/dmagda/Downloads/openai.key").toString().trim()
        });
        const client = new Client(dbEndpoint);
        await client.connect();

        const res = await client.query("select whoIsThat()");

        console.log(res.rows[0].whoisthat);

        await client.end();

    })();
    ```

Bonus! With the [PgCompute library](https://github.com/dmagda/pg-compute-node) you can execute JavaScript functions on the database directly from the application logic.

1. Import the library to the project:

    ```shell
    npm install pg-compute
    ```

2. Import the library into the app logic:

    ```javascript
    const { PgCompute } = require("pg-compute");
    ```

3. Initialize PgCompute along with the other used libraries:

    ```javascript
    (async () => {
        const client = new Client(dbEndpoint);
        await client.connect();

        const compute = new PgCompute(client);
        await compute.init(client);

        await client.end();

    })();
    ```

4. Add a simple function to the app logic and execute it via the compute APIs:

    ```javascript
    (async () => {
        const client = new Client(dbEndpoint);
        await client.connect();

        const compute = new PgCompute(client);
        await compute.init(client);

        const result = await compute.run(client, justDoThis);
        console.log(result);

        await client.end();

    })();

    function justDoThis() {
        const ver = plv8.execute("select version()");
        const greeting = "Again, that's Postgres. Not your laptop!";

        return { msg: greeting, version: ver };
    }
    ```

    Feel free to change the implementation of the `justDoThis()` function and restart the app. The new version of the function will be automatically deployed and executed on Postgres.

```javascript
function justDoItV2(name) {
    const extensions = plv8.execute("select * from pg_extension");

    const msg = `Hello ${name}! Check my extensions`;

    return { msg: msg, extensions: extensions };
}

(async () => {
    const client = new Client(dbEndpoint);
    await client.connect();

    const pgCompute = new PgCompute();
    await pgCompute.init(client);

    const res = await pgCompute.run(client, justDoItV2, "Denis");
    console.log(res);

    await client.end();
})();
```

## Number 3: Foreign Data Wrappers

Postgres foreign data wrappers (FDWs) let Postgres access data stored in other systems - MySQL, flat files, Oracle, S3, MongoDB, and more data sources with services.

With that capability, you can create apps that just use Postgres as a database and let Postgres pull or update data stored in other systems. From the application standpoint, you don't need to add and maintain logic that accesses other databases and systems.

## Number 2: pgmq

The [pgmq](https://github.com/tembo-io/pgmq) lets you use Postgres as a lightweight message queue for your apps and microservices. It's similar to [Amazon Simple Queue Service](https://aws.amazon.com/sqs/).

In addition to the SQL interface, there are several client libraries that are built on top of the SQL APIs. In this tutorial, we'll be using pgmq-js - the client-side library for JavaScript.

1. Go to your Tembo instance and enable the pgmq extension.

2. Add the pgmq-js library to the application:

    ```shell
    npm install pgmq-js
    ```

3. Add the library to the app logic:

    ```javascript
    const { Pgmq } = require("pgmq-js");

    ```

4. Initialize the queue interface:

    ```javascript
    (async () => {
        const client = new Client(dbEndpoint);
        await client.connect();

        const queue = await Pgmq.new(dbEndpoint);

        await client.end();

    })();
    ```

5. Update the app logic by sending and reading messages from the queue:

    ```javascript
    (async () => {
        const client = new Client(dbEndpoint);
        await client.connect();

        const queue = await Pgmq.new(dbEndpoint);

        await testQueue(queue);

        await client.end();

    })();

    async function testQueue(pgmq) {
        const myQueue = "postgres_queue";

        await pgmq.queue.create(myQueue);
        console.log("Queue created");

        const msg = { id: 1, name: "first message" };
        console.log("Sending message to queue");

        const msgId = await pgmq.msg.send(myQueue, msg);
        console.log("Message sent with id", msgId);

        let msgReceived = await pgmq.msg.read(myQueue);
        console.log("Message received", msgReceived);

        msgReceived = await pgmq.msg.read(myQueue);
        console.log("Message received", msgReceived);

        msgReceived = await pgmq.msg.pop(myQueue);
        console.log("Message poped", msgReceived);

        msgReceived = await pgmq.msg.read(myQueue);
        console.log("Message received", msgReceived);

        await pgmq.queue.drop(myQueue);
    }
    ```

## Number 1: pg_anonimize

The [pg_anonymize](https://github.com/rjuju/pg_anonymize) extension allows to perform data anonymization transparently on the database. This might be useful if you'd like a subset of the data to be anonymized for specific application users, in testing, etc.

Note, that there is another comparable extension - [postgresql_anonymizer](https://postgresql-anonymizer.readthedocs.io/en/stable/) - which you might want to use instead.

1. Go to your Tembo instance and enable the pg_anonymize extension. Also, you might need to load the extension manually (once, there was an issue on the Tembo end):

    ```sql
    LOAD 'pg_anonymize';
    ```

2. Create a user role that will see anonymized data:

    ```sql
    CREATE ROLE test_user WITH LOGIN PASSWORD 'password' NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;

    GRANT CONNECT ON DATABASE postgres TO test_user;

    GRANT SELECT ON TABLE user_account TO test_user;
    ```

3. Ask pg_anonymize to anonimize data for the created user:

    ```sql
    LOAD 'pg_anonymize';
    SECURITY LABEL FOR pg_anonymize ON ROLE test_user IS 'anonymize';
    ```

4. Load the extension for the `test_user` (whenever it opens a new session):

    ```sql
    ALTER ROLE test_user SET session_preload_libraries = 'pg_anonymize';
    ```

Create a table with the private user information and anonymize it for the created user:

1. Load the schema from the `postgres/datasets/movies/V1.3__create_user_table.sql` file.

2. Anonymize several columns:

    ```sql
    SECURITY LABEL FOR pg_anonymize ON COLUMN public.user_account.email
    IS $$substr(email, 1, 2) || '*****'$$;

    SECURITY LABEL FOR pg_anonymize ON COLUMN public.user_account.password
    IS $$'strong password'::text$$;

    SECURITY LABEL FOR pg_anonymize ON COLUMN public.user_account.full_name
    IS $$substr(full_name, 1, 3) || '*****'$$;
    ```

Finally, update the application code by connecting to Postgres using the `test_user` that must see anonymized data:

```javascript
const dbEndpoint = {
    host: "org-homeoffice-inst-tembocar.data-1.use1.tembo.io",
    port: 5432,
    database: "postgres",
    user: "test_user",
    password: "password",
    ssl: {
        rejectUnauthorized: false,
        ca: fs.readFileSync("/Users/dmagda/Downloads/ca.crt").toString()
    }
};

(async () => {
    const client = new Client(dbEndpoint);
    await client.connect();

    const res = await client.query("select full_name, email, password, user_location " +
        "from user_account"
    );

    console.log(res.rows);

    await client.end();
})();
```
