DROP ROLE IF EXISTS sql_agent;

DROP TABLE IF EXISTS product_inventory;

DROP TABLE IF EXISTS purchases;

DROP TABLE IF EXISTS users;

DROP TABLE IF EXISTS products;

DROP TYPE IF EXISTS shoe_color;

DROP TYPE IF EXISTS shoe_width;

DROP EXTENSION IF EXISTS pg_trgm;

-- Create read-only user
CREATE ROLE sql_agent WITH LOGIN PASSWORD 'password' NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;

GRANT CONNECT ON DATABASE postgres TO sql_agent;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT
SELECT ON TABLES TO sql_agent;

GRANT USAGE ON SCHEMA public TO sql_agent;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO sql_agent;

-- pg_trgm uses similarity of alphanumeric text based on trigram matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

SET pg_trgm.similarity_threshold = 0.6;

-- Creating ENUM types for color and width
CREATE TYPE shoe_color AS ENUM(
    'red',
    'green',
    'blue',
    'black',
    'white',
    'yellow',
    'orange',
    'purple',
    'grey',
    'pink'
);

CREATE TYPE shoe_width AS ENUM(
    'narrow',
    'medium',
    'wide'
);

CREATE TABLE products(
    product_id serial PRIMARY KEY,
    name varchar(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    color shoe_color[],
    width shoe_width[]
);

CREATE TABLE users(
    user_id serial PRIMARY KEY,
    username varchar(255) UNIQUE NOT NULL,
    email varchar(255) UNIQUE NOT NULL
);

CREATE TABLE purchases(
    purchase_id serial PRIMARY KEY,
    user_id int REFERENCES users(user_id),
    product_id int REFERENCES products(product_id),
    purchase_date timestamp DEFAULT CURRENT_TIMESTAMP,
    quantity int NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL
);

CREATE TABLE product_inventory(
    inventory_id serial PRIMARY KEY,
    product_id int REFERENCES products(product_id),
    size int NOT NULL,
    color shoe_color,
    width shoe_width,
    quantity int NOT NULL,
    CHECK (quantity >= 0)
);

