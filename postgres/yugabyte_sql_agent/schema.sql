CREATE EXTENSION IF NOT EXISTS vector;

DROP TABLE IF EXISTS movie CASCADE;

CREATE TABLE movie(
    id integer PRIMARY KEY,
    adult text,
    belongs_to_collection jsonb,
    budget integer,
    genres jsonb,
    homepage text,
    imdb_id text,
    original_language text,
    original_title text,
    overview text,
    overview_vector vector(1536),
    popularity numeric,
    poster_path text,
    production_companies jsonb,
    production_countries jsonb,
    release_date date,
    revenue integer,
    runtime numeric,
    spoken_languages jsonb,
    status text,
    tagline text,
    title text,
    video text,
    vote_average numeric,
    vote_count integer
);

DROP TABLE IF EXISTS user_account CASCADE;

CREATE TABLE user_account(
    id uuid PRIMARY KEY,
    email text NOT NULL,
    password text NOT NULL,
    full_name text NOT NULL,
    user_location text
);

DROP TABLE IF EXISTS user_library;

CREATE TABLE user_library(
    user_id uuid NOT NULL,
    movie_id integer NOT NULL,
    start_watch_time int NOT NULL DEFAULT 0,
    added_time timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_account(id),
    FOREIGN KEY (movie_id) REFERENCES movie(id),
    PRIMARY KEY (user_id, movie_id)
);

