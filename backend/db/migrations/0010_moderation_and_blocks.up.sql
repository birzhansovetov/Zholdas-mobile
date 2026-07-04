-- Add role and ban fields to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'user' CHECK (role IN ('user', 'moderator', 'admin'));
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS banned_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS banned_by INT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS ban_reason TEXT;

-- Create user_bans table
CREATE TABLE IF NOT EXISTS user_bans (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    banned_by INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_ban UNIQUE (user_id)
);

-- Create moderation_actions table
CREATE TABLE IF NOT EXISTS moderation_actions (
    id SERIAL PRIMARY KEY,
    moderator_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action_type VARCHAR(100) NOT NULL, -- 'ban', 'unban', 'close_report'
    target_type VARCHAR(100) NOT NULL, -- 'user', 'event', 'message'
    target_id INT NOT NULL,
    details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create blocks table
CREATE TABLE IF NOT EXISTS blocks (
    id SERIAL PRIMARY KEY,
    blocker_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_block UNIQUE (blocker_id, blocked_id),
    CONSTRAINT chk_self_block CHECK (blocker_id <> blocked_id)
);

-- Indexing for high performance queries
CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks(blocked_id);
CREATE INDEX IF NOT EXISTS idx_user_bans_user ON user_bans(user_id);
CREATE INDEX IF NOT EXISTS idx_moderation_actions_moderator ON moderation_actions(moderator_id);

-- Triggers for automatic status updates on user_bans changes
CREATE OR REPLACE FUNCTION trg_user_bans_insert()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE profiles 
    SET is_banned = TRUE, 
        banned_at = NEW.created_at, 
        banned_by = NEW.banned_by, 
        ban_reason = NEW.reason
    WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_bans_insert_trigger ON user_bans;
CREATE TRIGGER trg_user_bans_insert_trigger
AFTER INSERT ON user_bans
FOR EACH ROW EXECUTE FUNCTION trg_user_bans_insert();

CREATE OR REPLACE FUNCTION trg_user_bans_delete()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE profiles 
    SET is_banned = FALSE, 
        banned_at = NULL, 
        banned_by = NULL, 
        ban_reason = NULL
    WHERE user_id = OLD.user_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_bans_delete_trigger ON user_bans;
CREATE TRIGGER trg_user_bans_delete_trigger
AFTER DELETE ON user_bans
FOR EACH ROW EXECUTE FUNCTION trg_user_bans_delete();
