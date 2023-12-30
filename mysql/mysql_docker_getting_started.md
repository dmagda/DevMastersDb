# Getting Started With MySQL in Docker: From Setup to Sample App

Discover the fastest way to get a fully functional MySQL instance running in Docker with this comprehensive beginner's guide. Master the art of setting up MySQL in Docker, connecting to your database with various SQL tools, and integrating with a sample app on your host system or within a container. Perfect for beginners and seasoned pros alike!

TBD: video

Follow this guide to learn:
* How to start MySQL in a Docker container
* How to use the mysql client to open a database session within the container
* How to generate sample data with generate series
* How to connect to MySQL from the host with DBeaver
* How to connect to MySQL from an app running on the host OS and within a container

## Start MySQL in Docker

1. Create a sample network for a MySQL container and a sample app used in this guide:
    ```shell
    docker network create my-network
    ```
2. Create `mysql-volume` directory for the MySQL container's volume in your home dir. The volume is handy if you'd like to access the logs easily and don't want to lose data when the container is recreated from scratch:
    ```shell
    mkdir ~/mysql-volume
    ```
3. Start the latest MySQL container:
    ```shell
    docker run --name mysql --net my-network \
        -p 3306:3306 \
        -e MYSQL_ROOT_PASSWORD=password \
        -e MYSQL_USER=user \
        -e MYSQL_PASSWORD=password \
        -e MYSQL_DATABASE=sample_db \
        -v $HOME/mysql-volume:/var/lib/mysql \
        -d mysql:latest
    ```
    You can pick another version from the [MySQL official Docker repository](https://hub.docker.com/_/mysql).
4. Make sure the container has started:
    ```shell
    docker container ls -f name=mysql
    ```
5. Check the logs to make sure the initialization went well:
    ```shell
    docker container logs mysql -f
    ```
5. Connect to the container and open a database session using the *mysql* client:
    ```shell
    docker exec -it mysql mysql --database=sample_db --user=user --password=password 
    ```

Keep the mysql client session opened...

## Load Sample Data

Use the opened mysql client session to create a sample table and load it with mock data:

1. Create the table:
    ```sql
    create table pizza_order(id int, pizza_type text);
    ```
2. Insert 1000 records in the table:
    ```sql
    insert into pizza_order (id, pizza_type)
    with recursive seq as (
        select 1 as id
        union all
        select id + 1 from seq where id < 1000
    )
    select id,
        case floor(rand() * 4)
            when 0 then 'four cheese'
            when 1 then 'margherita'
            when 2 then 'veggie'
            else 'pepperoni'
        end
    from seq;
    ```
3. Select 5 records:
    ```sql
    select * from pizza_order limit 5;
    ```

## Connect With DBeaver

Start DBeaver on your host's operating system (OS) and connect to the MySQL instance running in the container.

TBD picture:

Use the following connection parameters:
* *Host* - localhost or 127.0.0.1
* *Port* - 3306 (was exposed in the Docker run command)
* *Database* - sample_db
* *Username* - user
* *Password* - password

Run the following query to find out the total number of orders for each pizza type:
```sql
select pizza_type, count(*) as total_orders
from pizza_order 
group by pizza_type order by total_orders desc;
```

## Connect From App Running on Host

Create a simple Node.js application, start it on the host's operating system and have it connected to the MySQL instance running in docker.


1. Create the `cool_app` folder for the app:
    ```shell
    mkdir cool_app 
    ```
2. Init a Node.js project:
    ```shell
    cd cool_app
    npm init -y
    ```
3. Add the *node-mysql2* module to the project:
    ```shell
    npm install mysql2
    ```
4. Open the app with Visual Studio Code:
    ```shell
    code .
    ```

Create the `main.js` file with the following contents:
```javascript
var mysql = require('mysql2');

const config = {
    host: 'localhost',
    port: '3306',
    database: 'sample_db',
    user: 'user',
    password: 'password',
};

const client = mysql.createConnection(config);
client.connect();

const res = client.query(
    'select pizza_type, count(*) as total_orders ' +
    'from pizza_order ' +
    'group by pizza_type order by total_orders desc',

    function (err, results) {
        if (err) {
            console.log(err);
        } else {
            for (row of results) {
                console.log(row.pizza_type + ': ' + row.total_orders);
            }
        }
        client.end();
    }
);
```

Start the app instance:
```shell
node main.js
```

An app instance will be started on your host operating system. It will connect to the MySQL container and print the following result:
```javascript
node main.js
four cheese: 269
veggie: 254
pepperoni: 239
margherita: 238
```

## Connect From App Running in Container

Create a docker image for the app and start it as a container alongside the MySQL instance.

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

2. Set the `host` parameter to `mysql` in the `main.js` logic:
    ```javascript
    const config = {
        host: 'mysql',
        ...
    }
    ```
    where `mysql` is the name of the MySQL container.

3. Build the image:
    ```shell
    docker build -t my-cool-app .
    ```

4. Start the app in a container in the same Docker network where you have the MySQL instance running:
    ```shell
    docker run --net my-network --name app my-cool-app
    ```

The app will start successfully in the container, connect to MySQL and print the following result:
```javascript
four cheese: 269
veggie: 254
pepperoni: 239
margherita: 238
```

Hope you found this tutorial useful! Reach out to me on Twitter (X) for any feedback, questions or suggestions you might have:
[![Twitter URL](https://img.shields.io/twitter/url/https/twitter.com/denismagda.svg?style=social&label=Follow%20%40DenisMagda)](https://twitter.com/DenisMagda)
