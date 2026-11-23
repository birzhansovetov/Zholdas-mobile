-- Email waitlist collected by the landing page at zholdas.app.
CREATE TABLE IF NOT EXISTS waitlist (
    id SERIAL PRIMARY KEY,
    email VARCHAR(254) NOT NULL UNIQUE,
    lang VARCHAR(5) NOT NULL DEFAULT 'ru',
    platform VARCHAR(10) NOT NULL DEFAULT 'any',
    source VARCHAR(50) NOT NULL DEFAULT 'landing',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;
