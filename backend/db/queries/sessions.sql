-- name: CreateSession :one
INSERT INTO user_sessions (user_id, refresh_token_hash, expires_at)
VALUES ($1, $2, $3)
RETURNING id, user_id, refresh_token_hash, expires_at, created_at;

-- name: GetSessionByHash :one
SELECT id, user_id, refresh_token_hash, expires_at, created_at
FROM user_sessions
WHERE refresh_token_hash = $1 LIMIT 1;

-- name: DeleteSession :exec
DELETE FROM user_sessions
WHERE refresh_token_hash = $1;

-- name: DeleteUserSessions :exec
DELETE FROM user_sessions
WHERE user_id = $1;
