INSERT INTO event_participants (event_id, user_id, participant_status)
SELECT e.id, e.creator_id, 'going' FROM events e
WHERE NOT EXISTS (SELECT 1 FROM event_participants ep WHERE ep.event_id = e.id AND ep.user_id = e.creator_id)
  AND EXISTS (SELECT 1 FROM profiles p WHERE p.user_id = e.creator_id);
