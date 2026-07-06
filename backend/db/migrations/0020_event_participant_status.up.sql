ALTER TABLE event_participants
ADD COLUMN IF NOT EXISTS participant_status VARCHAR(20) NOT NULL DEFAULT 'going';

ALTER TABLE event_participants
DROP CONSTRAINT IF EXISTS chk_event_participants_status;

ALTER TABLE event_participants
ADD CONSTRAINT chk_event_participants_status
CHECK (participant_status IN ('going', 'late', 'arrived', 'not_going'));

UPDATE event_participants
SET participant_status = 'arrived'
WHERE arrived_at IS NOT NULL
  AND participant_status <> 'arrived';

CREATE INDEX IF NOT EXISTS idx_event_participants_status
ON event_participants(event_id, participant_status);
