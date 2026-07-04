CREATE SCHEMA IF NOT EXISTS mobile;
SET search_path TO mobile, public;

CREATE TEMP TABLE legacy_user_map AS
SELECT u.id AS legacy_id, au.id AS auth_id, au.email
FROM users u
JOIN auth.users au ON lower(au.email) = lower(u.email);

DROP TABLE IF EXISTS user_sessions;

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_user_id_fkey;
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_creator_id_fkey;
ALTER TABLE event_participants DROP CONSTRAINT IF EXISTS event_participants_user_id_fkey;
ALTER TABLE event_messages DROP CONSTRAINT IF EXISTS event_messages_sender_id_fkey;
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_actor_id_fkey;
ALTER TABLE friendships DROP CONSTRAINT IF EXISTS friendships_user_id_fkey;
ALTER TABLE friendships DROP CONSTRAINT IF EXISTS friendships_friend_id_fkey;
ALTER TABLE user_reviews DROP CONSTRAINT IF EXISTS user_reviews_evaluator_id_fkey;
ALTER TABLE user_reviews DROP CONSTRAINT IF EXISTS user_reviews_ratee_id_fkey;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reporter_id_fkey;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reported_user_id_fkey;
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_banned_by_fkey;
ALTER TABLE user_bans DROP CONSTRAINT IF EXISTS user_bans_user_id_fkey;
ALTER TABLE user_bans DROP CONSTRAINT IF EXISTS user_bans_banned_by_fkey;
ALTER TABLE moderation_actions DROP CONSTRAINT IF EXISTS moderation_actions_moderator_id_fkey;
ALTER TABLE blocks DROP CONSTRAINT IF EXISTS blocks_blocker_id_fkey;
ALTER TABLE blocks DROP CONSTRAINT IF EXISTS blocks_blocked_id_fkey;
ALTER TABLE user_device_tokens DROP CONSTRAINT IF EXISTS user_device_tokens_user_id_fkey;

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_pkey;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS user_id_uuid uuid;
UPDATE profiles p SET user_id_uuid = m.auth_id FROM legacy_user_map m WHERE p.user_id = m.legacy_id;
DELETE FROM profiles WHERE user_id_uuid IS NULL;
ALTER TABLE profiles DROP COLUMN user_id;
ALTER TABLE profiles RENAME COLUMN user_id_uuid TO user_id;
ALTER TABLE profiles ADD PRIMARY KEY (user_id);
ALTER TABLE profiles ADD CONSTRAINT profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS banned_by_uuid uuid;
UPDATE profiles p SET banned_by_uuid = m.auth_id FROM legacy_user_map m WHERE p.banned_by = m.legacy_id;
ALTER TABLE profiles DROP COLUMN IF EXISTS banned_by;
ALTER TABLE profiles RENAME COLUMN banned_by_uuid TO banned_by;
ALTER TABLE profiles ADD CONSTRAINT profiles_banned_by_fkey FOREIGN KEY (banned_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE events ADD COLUMN IF NOT EXISTS creator_id_uuid uuid;
UPDATE events e SET creator_id_uuid = m.auth_id FROM legacy_user_map m WHERE e.creator_id = m.legacy_id;
DELETE FROM events WHERE creator_id_uuid IS NULL;
ALTER TABLE events DROP COLUMN creator_id;
ALTER TABLE events RENAME COLUMN creator_id_uuid TO creator_id;
ALTER TABLE events ALTER COLUMN creator_id SET NOT NULL;
ALTER TABLE events ADD CONSTRAINT events_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE event_participants ADD COLUMN IF NOT EXISTS user_id_uuid uuid;
UPDATE event_participants ep SET user_id_uuid = m.auth_id FROM legacy_user_map m WHERE ep.user_id = m.legacy_id;
DELETE FROM event_participants WHERE user_id_uuid IS NULL;
ALTER TABLE event_participants DROP CONSTRAINT IF EXISTS event_participants_event_id_user_id_key;
ALTER TABLE event_participants DROP COLUMN user_id;
ALTER TABLE event_participants RENAME COLUMN user_id_uuid TO user_id;
ALTER TABLE event_participants ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE event_participants ADD CONSTRAINT event_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE event_participants ADD CONSTRAINT event_participants_event_id_user_id_key UNIQUE (event_id, user_id);

ALTER TABLE event_messages ADD COLUMN IF NOT EXISTS sender_id_uuid uuid;
UPDATE event_messages em SET sender_id_uuid = m.auth_id FROM legacy_user_map m WHERE em.sender_id = m.legacy_id;
ALTER TABLE event_messages DROP COLUMN sender_id;
ALTER TABLE event_messages RENAME COLUMN sender_id_uuid TO sender_id;
ALTER TABLE event_messages ADD CONSTRAINT event_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS user_id_uuid uuid;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actor_id_uuid uuid;
UPDATE notifications n SET user_id_uuid = m.auth_id FROM legacy_user_map m WHERE n.user_id = m.legacy_id;
UPDATE notifications n SET actor_id_uuid = m.auth_id FROM legacy_user_map m WHERE n.actor_id = m.legacy_id;
DELETE FROM notifications WHERE user_id_uuid IS NULL;
ALTER TABLE notifications DROP COLUMN user_id;
ALTER TABLE notifications DROP COLUMN actor_id;
ALTER TABLE notifications RENAME COLUMN user_id_uuid TO user_id;
ALTER TABLE notifications RENAME COLUMN actor_id_uuid TO actor_id;
ALTER TABLE notifications ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE notifications ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE notifications ADD CONSTRAINT notifications_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE friendships ADD COLUMN IF NOT EXISTS user_id_uuid uuid;
ALTER TABLE friendships ADD COLUMN IF NOT EXISTS friend_id_uuid uuid;
UPDATE friendships f SET user_id_uuid = m.auth_id FROM legacy_user_map m WHERE f.user_id = m.legacy_id;
UPDATE friendships f SET friend_id_uuid = m.auth_id FROM legacy_user_map m WHERE f.friend_id = m.legacy_id;
DELETE FROM friendships WHERE user_id_uuid IS NULL OR friend_id_uuid IS NULL;
ALTER TABLE friendships DROP CONSTRAINT IF EXISTS idx_friendships_unique;
ALTER TABLE friendships DROP CONSTRAINT IF EXISTS chk_friendships_users_different;
ALTER TABLE friendships DROP COLUMN user_id;
ALTER TABLE friendships DROP COLUMN friend_id;
ALTER TABLE friendships RENAME COLUMN user_id_uuid TO user_id;
ALTER TABLE friendships RENAME COLUMN friend_id_uuid TO friend_id;
ALTER TABLE friendships ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE friendships ALTER COLUMN friend_id SET NOT NULL;
ALTER TABLE friendships ADD CONSTRAINT friendships_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE friendships ADD CONSTRAINT friendships_friend_id_fkey FOREIGN KEY (friend_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE friendships ADD CONSTRAINT idx_friendships_unique UNIQUE (user_id, friend_id);
ALTER TABLE friendships ADD CONSTRAINT chk_friendships_users_different CHECK (user_id <> friend_id);

ALTER TABLE user_reviews ADD COLUMN IF NOT EXISTS evaluator_id_uuid uuid;
ALTER TABLE user_reviews ADD COLUMN IF NOT EXISTS ratee_id_uuid uuid;
UPDATE user_reviews r SET evaluator_id_uuid = m.auth_id FROM legacy_user_map m WHERE r.evaluator_id = m.legacy_id;
UPDATE user_reviews r SET ratee_id_uuid = m.auth_id FROM legacy_user_map m WHERE r.ratee_id = m.legacy_id;
DELETE FROM user_reviews WHERE evaluator_id_uuid IS NULL OR ratee_id_uuid IS NULL;
ALTER TABLE user_reviews DROP CONSTRAINT IF EXISTS idx_user_reviews_unique;
ALTER TABLE user_reviews DROP CONSTRAINT IF EXISTS chk_user_reviews_different;
ALTER TABLE user_reviews DROP COLUMN evaluator_id;
ALTER TABLE user_reviews DROP COLUMN ratee_id;
ALTER TABLE user_reviews RENAME COLUMN evaluator_id_uuid TO evaluator_id;
ALTER TABLE user_reviews RENAME COLUMN ratee_id_uuid TO ratee_id;
ALTER TABLE user_reviews ALTER COLUMN evaluator_id SET NOT NULL;
ALTER TABLE user_reviews ALTER COLUMN ratee_id SET NOT NULL;
ALTER TABLE user_reviews ADD CONSTRAINT user_reviews_evaluator_id_fkey FOREIGN KEY (evaluator_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE user_reviews ADD CONSTRAINT user_reviews_ratee_id_fkey FOREIGN KEY (ratee_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE user_reviews ADD CONSTRAINT idx_user_reviews_unique UNIQUE (evaluator_id, ratee_id, event_id);
ALTER TABLE user_reviews ADD CONSTRAINT chk_user_reviews_different CHECK (evaluator_id <> ratee_id);

ALTER TABLE reports ADD COLUMN IF NOT EXISTS reporter_id_uuid uuid;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS reported_user_id_uuid uuid;
UPDATE reports r SET reporter_id_uuid = m.auth_id FROM legacy_user_map m WHERE r.reporter_id = m.legacy_id;
UPDATE reports r SET reported_user_id_uuid = m.auth_id FROM legacy_user_map m WHERE r.reported_user_id = m.legacy_id;
DELETE FROM reports WHERE reporter_id_uuid IS NULL;
ALTER TABLE reports DROP COLUMN reporter_id;
ALTER TABLE reports DROP COLUMN reported_user_id;
ALTER TABLE reports RENAME COLUMN reporter_id_uuid TO reporter_id;
ALTER TABLE reports RENAME COLUMN reported_user_id_uuid TO reported_user_id;
ALTER TABLE reports ALTER COLUMN reporter_id SET NOT NULL;
ALTER TABLE reports ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE reports ADD CONSTRAINT reports_reported_user_id_fkey FOREIGN KEY (reported_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE user_bans ADD COLUMN IF NOT EXISTS user_id_uuid uuid;
ALTER TABLE user_bans ADD COLUMN IF NOT EXISTS banned_by_uuid uuid;
UPDATE user_bans b SET user_id_uuid = m.auth_id FROM legacy_user_map m WHERE b.user_id = m.legacy_id;
UPDATE user_bans b SET banned_by_uuid = m.auth_id FROM legacy_user_map m WHERE b.banned_by = m.legacy_id;
DELETE FROM user_bans WHERE user_id_uuid IS NULL OR banned_by_uuid IS NULL;
ALTER TABLE user_bans DROP CONSTRAINT IF EXISTS unique_user_ban;
ALTER TABLE user_bans DROP COLUMN user_id;
ALTER TABLE user_bans DROP COLUMN banned_by;
ALTER TABLE user_bans RENAME COLUMN user_id_uuid TO user_id;
ALTER TABLE user_bans RENAME COLUMN banned_by_uuid TO banned_by;
ALTER TABLE user_bans ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE user_bans ALTER COLUMN banned_by SET NOT NULL;
ALTER TABLE user_bans ADD CONSTRAINT user_bans_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE user_bans ADD CONSTRAINT user_bans_banned_by_fkey FOREIGN KEY (banned_by) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE user_bans ADD CONSTRAINT unique_user_ban UNIQUE (user_id);

ALTER TABLE moderation_actions ADD COLUMN IF NOT EXISTS moderator_id_uuid uuid;
UPDATE moderation_actions ma SET moderator_id_uuid = m.auth_id FROM legacy_user_map m WHERE ma.moderator_id = m.legacy_id;
DELETE FROM moderation_actions WHERE moderator_id_uuid IS NULL;
ALTER TABLE moderation_actions DROP COLUMN moderator_id;
ALTER TABLE moderation_actions RENAME COLUMN moderator_id_uuid TO moderator_id;
ALTER TABLE moderation_actions ALTER COLUMN moderator_id SET NOT NULL;
ALTER TABLE moderation_actions ALTER COLUMN target_id TYPE text USING target_id::text;
ALTER TABLE moderation_actions ADD CONSTRAINT moderation_actions_moderator_id_fkey FOREIGN KEY (moderator_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE blocks ADD COLUMN IF NOT EXISTS blocker_id_uuid uuid;
ALTER TABLE blocks ADD COLUMN IF NOT EXISTS blocked_id_uuid uuid;
UPDATE blocks b SET blocker_id_uuid = m.auth_id FROM legacy_user_map m WHERE b.blocker_id = m.legacy_id;
UPDATE blocks b SET blocked_id_uuid = m.auth_id FROM legacy_user_map m WHERE b.blocked_id = m.legacy_id;
DELETE FROM blocks WHERE blocker_id_uuid IS NULL OR blocked_id_uuid IS NULL;
ALTER TABLE blocks DROP CONSTRAINT IF EXISTS unique_block;
ALTER TABLE blocks DROP CONSTRAINT IF EXISTS chk_self_block;
ALTER TABLE blocks DROP COLUMN blocker_id;
ALTER TABLE blocks DROP COLUMN blocked_id;
ALTER TABLE blocks RENAME COLUMN blocker_id_uuid TO blocker_id;
ALTER TABLE blocks RENAME COLUMN blocked_id_uuid TO blocked_id;
ALTER TABLE blocks ALTER COLUMN blocker_id SET NOT NULL;
ALTER TABLE blocks ALTER COLUMN blocked_id SET NOT NULL;
ALTER TABLE blocks ADD CONSTRAINT blocks_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE blocks ADD CONSTRAINT blocks_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE blocks ADD CONSTRAINT unique_block UNIQUE (blocker_id, blocked_id);
ALTER TABLE blocks ADD CONSTRAINT chk_self_block CHECK (blocker_id <> blocked_id);

ALTER TABLE user_device_tokens ADD COLUMN IF NOT EXISTS user_id_uuid uuid;
UPDATE user_device_tokens t SET user_id_uuid = m.auth_id FROM legacy_user_map m WHERE t.user_id = m.legacy_id;
DELETE FROM user_device_tokens WHERE user_id_uuid IS NULL;
ALTER TABLE user_device_tokens DROP COLUMN user_id;
ALTER TABLE user_device_tokens RENAME COLUMN user_id_uuid TO user_id;
ALTER TABLE user_device_tokens ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE user_device_tokens ADD CONSTRAINT user_device_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(user_id) ON DELETE CASCADE;

DROP INDEX IF EXISTS idx_notifications_user_created;
DROP INDEX IF EXISTS idx_friendships_user;
DROP INDEX IF EXISTS idx_friendships_friend;
DROP INDEX IF EXISTS idx_user_reviews_ratee;
DROP INDEX IF EXISTS idx_reports_reporter;
DROP INDEX IF EXISTS idx_reports_reported_user;
DROP INDEX IF EXISTS idx_blocks_blocker;
DROP INDEX IF EXISTS idx_blocks_blocked;
DROP INDEX IF EXISTS idx_user_bans_user;
DROP INDEX IF EXISTS idx_moderation_actions_moderator;

CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_friendships_user ON friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_friend ON friendships(friend_id);
CREATE INDEX IF NOT EXISTS idx_user_reviews_ratee ON user_reviews(ratee_id);
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user ON reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks(blocked_id);
CREATE INDEX IF NOT EXISTS idx_user_bans_user ON user_bans(user_id);
CREATE INDEX IF NOT EXISTS idx_moderation_actions_moderator ON moderation_actions(moderator_id);

ALTER TABLE users RENAME TO legacy_users;
