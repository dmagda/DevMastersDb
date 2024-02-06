INSERT INTO user_account(id, email, PASSWORD, full_name, user_location)
    VALUES ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'user1@gmail.com', '$2a$10$s17IziaW1967UZGW/Q8diOqX0qCzABGBykf/BK6xvO/qElLKkWV6a', 'John Doe', 'New York'),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'user2@gmail.com', '$2a$10$s17IziaW1967UZGW/Q8diOqX0qCzABGBykf/BK6xvO/qElLKkWV6a', 'Emely Smith', 'San Francisco'),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'user3@gmail.com', '$2a$10$s17IziaW1967UZGW/Q8diOqX0qCzABGBykf/BK6xvO/qElLKkWV6a', 'Michael Williams', 'Los Angeles'),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'user4@gmail.com', '$2a$10$s17IziaW1967UZGW/Q8diOqX0qCzABGBykf/BK6xvO/qElLKkWV6a', 'Jessica Brown', 'Boston');

WITH user_data AS (
    SELECT id FROM user_account WHERE email = 'user1@gmail.com')
INSERT INTO user_library(user_id, movie_id, start_watch_time, added_time)
SELECT
    (SELECT id FROM user_data),
    id, 0,CURRENT_TIMESTAMP
FROM
    movie
WHERE id IN (
    SELECT id FROM movie ORDER BY RANDOM() LIMIT 30
);

WITH user_data AS (
    SELECT id FROM user_account WHERE email = 'user2@gmail.com')
INSERT INTO user_library(user_id, movie_id, start_watch_time, added_time)
SELECT
    (SELECT id FROM user_data),
    id, 0,CURRENT_TIMESTAMP
FROM
    movie
WHERE id IN (
    SELECT id FROM movie ORDER BY RANDOM() LIMIT 15
);

WITH user_data AS (
    SELECT id FROM user_account WHERE email = 'user3@gmail.com')
INSERT INTO user_library(user_id, movie_id, start_watch_time, added_time)
SELECT
    (SELECT id FROM user_data),
    id, 0,CURRENT_TIMESTAMP
FROM
    movie
WHERE id IN (
    SELECT id FROM movie ORDER BY RANDOM() LIMIT 25
);

WITH user_data AS (
    SELECT id FROM user_account WHERE email = 'user4@gmail.com')
INSERT INTO user_library(user_id, movie_id, start_watch_time, added_time)
SELECT
    (SELECT id FROM user_data),
    id, 0,CURRENT_TIMESTAMP
FROM
    movie
WHERE id IN (
    SELECT id FROM movie ORDER BY RANDOM() LIMIT 45
);

