# Getting Started With PostgreSQL in Docker

NOTE: the video is coming soon. The instructions below are for you, so that you can practice.



Follow this guide to learn:
* How to start Postgres in a Docker container
* How to use psql to open a database session within the container
* How to generate sample data with generate series
* How to connect to Postgres from the host with DBeaver
* How to connect to Postgres from an app running on the host OS and within a container

## Start Postgres in Docker

1. Create a sample network for a Postgres container and a sample app used in this guide:
    ```shell
    docker network create my-network
    ```
2. Start the Postgres container of version 16:
    ```shell
    docker run --name postgres --net my-network \
        -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=password \
        -p 5432:5432 \
        -d postgres:16.1
    ```
    You can pick another version from the [Postgres' official Docker repository](https://hub.docker.com/_/postgres).
3. Make sure the container is running:
    ```shell
    docker container ls -f name=postgres
    ```
4. Connect to the container and open a database session with *psql*:
    ```shell
    docker exec -it postgres psql -U postgres 
    ```

Keep the psql session open...

## Load Sample Data

Use the opened psql session to create a sample table and load it with mock data:

1. Create the table:
    ```sql
    create table pizza_order(id int, pizza_type text);
    ```
2. Insert 1000 records in the table:
    ```sql
    with recipe as (
        select array['four cheese', 'margherita', 'veggie', 'pepperoni'] as type
    )
    insert into pizza_order (id, pizza_type)
    select id, (select type[(id % 4) +1 ] from recipe)
    from generate_series(1, 1000) as id;
    ```
3. Select 5 records:
    ```sql
    select * from pizza_order limit 5;
    ```

## Connect With DBeaver

Start DBeaver on your host's operating system (OS) and connect to the Postgres instance running in the container.

TBD screenshot

Use the following connection parameters:
* *Host* - localhost or 127.0.0.1
* *Port* - 5432 (was exposed in the Docker run command)
* *Username* - postgres
* *Password* - password

## Connect From App Running on Host

Create a simple Node.js application, start it on the host's operating system and have it connected to the Postgres instance running in docker.


1. Create the `cool_app` folder for the app:
    ```shell
    mkdir cool_app 
    ```
2. Init a Node.js project:
    ```shell
    cd cool_app
    npm init -y
    ```
3. Add the *node-postgres* module to the project:
    ```shell
    npm install pg
    ```
4. Open the app with Visual Studio Code:
    ```shell
    code .
    ```

Create the `main.js` file with the following contents:
```javascript
var pg = require('pg');

const config = {
    host: '127.0.0.1',
    port: '5432',
    database: 'postgres',
    user: 'postgres',
    password: 'password',
};

async function mostPopularPizza() {
    const client = new pg.Client(config);
    await client.connect();

    const res = await client.query(
        'select pizza_type, count(*) as total_orders ' +
        'from pizza_order ' +
        'group by pizza_type order by total_orders desc');

    for (let row of res.rows) {
        console.log(row);
    }

    await client.end();
}

mostPopularPizza();
```

Start the app instance:
```shell
node main.js
```

An app instance will be started on your host operating system. It will connect to the Postgres container and print the following result:
```javascript
node main.js
{ pizza_type: 'veggie', total_orders: '250' }
{ pizza_type: 'margherita', total_orders: '250' }
{ pizza_type: 'four cheese', total_orders: '250' }
{ pizza_type: 'pepperoni', total_orders: '250' }
```

## Connect From App Running in Container

Create a docker image for the app and start it as a container alongside the Postgres instance.

1. Under the app's root directory create the following Dockerfile:
    ```docker
    # Use an official Node runtime as a parent image
    FROM node:16

    # Set the working directory in the container to /app
    WORKDIR /app

    # Copy the current directory contents into the container at /app
    COPY . /app

    # Install any needed packages specified in package.json
    RUN npm install

    # Define environment variable
    ENV NODE_ENV=production

    # Run app.js (or whatever your main file is) when the container launches
    CMD ["node", "main.js"]
    ```

2. Set the `host` parameter to `postgres` in the `main.js` logic:
    ```javascript
    const config = {
        host: 'postgres',
        ...
    }
    ```
    where `postgres` is the name of the Postgres container.

3. Build the image:
    ```shell
    docker build -t my-cool-app .
    ```

4. Start the app in a container in the same Docker network where you have the Postgres instance running:
    ```shell
    docker run --net my-network --name app my-cool-app
    ```

The app will start successfully in the container, connect to Postgres and print the following result:
```javascript
{ pizza_type: 'veggie', total_orders: '250' }
{ pizza_type: 'margherita', total_orders: '250' }
{ pizza_type: 'four cheese', total_orders: '250' }
{ pizza_type: 'pepperoni', total_orders: '250' }
```

Hope you found this tutorial useful! Reach out to me on Twitter (X) for any feedback, questions or suggestions you might have:
[![Twitter URL](https://img.shields.io/twitter/url/https/twitter.com/denismagda.svg?style=social&label=Follow%20%40DenisMagda)](https://twitter.com/DenisMagda)