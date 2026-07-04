-- name: CreateUserAndProfile :one
WITH new_user AS (
    INSERT INTO users (email, password_hash)
    VALUES ($1, $2)
    RETURNING id
)
INSERT INTO profiles (user_id, username, full_name)
SELECT id, $3, $4 FROM new_user
RETURNING user_id, username, full_name;

-- name: GetUserByID :one
SELECT u.id, u.email, p.username, p.full_name, p.avatar_url, p.bio, p.city
FROM users u
JOIN profiles p ON p.user_id = u.id
WHERE u.id = $1 LIMIT 1;

-- name: GetUserByEmail :one
SELECT u.id, u.email, u.password_hash, p.username, p.full_name, p.avatar_url, p.bio, p.city
FROM users u
JOIN profiles p ON p.user_id = u.id
WHERE u.email = $1 LIMIT 1;
