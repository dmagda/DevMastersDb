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
    overview_lexemes tsvector,
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

