ALTER TABLE event_participants ADD COLUMN IF NOT EXISTS arrived_at TIMESTAMP WITH TIME ZONE;

CREATE TABLE IF NOT EXISTS event_reminders (
    id SERIAL PRIMARY KEY,
    event_id INT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    reminder_type VARCHAR(20) NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(event_id, user_id, reminder_type)
);

CREATE INDEX IF NOT EXISTS idx_event_participants_arrived ON event_participants(event_id, arrived_at);
CREATE INDEX IF NOT EXISTS idx_event_reminders_event_user ON event_reminders(event_id, user_id);
