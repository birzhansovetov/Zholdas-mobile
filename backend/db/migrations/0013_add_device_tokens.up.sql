CREATE TABLE IF NOT EXISTS user_device_tokens (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    device_token VARCHAR(255) NOT NULL UNIQUE,
    platform VARCHAR(50) DEFAULT 'ios',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
