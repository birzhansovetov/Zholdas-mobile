CREATE TABLE IF NOT EXISTS system_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO system_settings (key, value, description)
VALUES
    ('ai_enabled', 'true', 'Enables AI chat and recommendations'),
    ('ai_rate_limit_per_10m', '8', 'Maximum AI requests per user per 10 minutes'),
    ('default_city', 'Almaty', 'Default city for app forms and fallbacks')
ON CONFLICT (key) DO NOTHING;
