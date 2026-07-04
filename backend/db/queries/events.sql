-- name: CreateEvent :one
INSERT INTO events (creator_id, title, description, category, location_name, location, start_time, end_time, max_participants, status)
VALUES ($1, $2, $3, $4, $5, ST_SetSRID(ST_MakePoint($6::float8, $7::float8), 4326)::geography, $8, $9, $10, $11)
RETURNING id, creator_id, title, description, category, location_name, 
          (ST_Y(location::geometry))::float8 AS latitude, 
          (ST_X(location::geometry))::float8 AS longitude, 
          start_time, end_time, max_participants, status, created_at;

-- name: GetNearbyEvents :many
SELECT id, creator_id, title, description, category, location_name,
       (ST_Y(location::geometry))::float8 AS latitude,  -- Latitude
       (ST_X(location::geometry))::float8 AS longitude, -- Longitude
       ST_Distance(location, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography)::float8 AS distance_meters
FROM events
WHERE status = 'active'
  AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1::float8, $2::float8), 4326)::geography, $3::float8)
ORDER BY distance_meters ASC
LIMIT $4 OFFSET $5;

-- name: UpdateEventStatus :exec
UPDATE events
SET status = $2
WHERE id = $1;

-- name: GetEventByID :one
SELECT id, creator_id, title, description, category, location_name,
       (ST_Y(location::geometry))::float8 AS latitude,
       (ST_X(location::geometry))::float8 AS longitude,
       start_time, end_time, max_participants, status, created_at
FROM events
WHERE id = $1 LIMIT 1;
