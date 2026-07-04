-- Create system user for AI companion
INSERT INTO users (id, email, password_hash) 
VALUES (0, 'ai@zholdas.app', 'disabled') 
ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (user_id, username, full_name, role) 
VALUES (0, 'ai', 'Жорик (ИИ)', 'user') 
ON CONFLICT (user_id) DO NOTHING;
