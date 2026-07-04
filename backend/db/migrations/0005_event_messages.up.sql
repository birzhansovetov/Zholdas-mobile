CREATE TABLE IF NOT EXISTS event_messages (
    id SERIAL PRIMARY KEY,
    event_id INT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    sender_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for loading event chat history in chronological order
CREATE INDEX IF NOT EXISTS idx_event_messages_lookup ON event_messages(event_id, created_at ASC);
