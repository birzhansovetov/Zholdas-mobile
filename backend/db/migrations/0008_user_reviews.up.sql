CREATE TABLE IF NOT EXISTS user_reviews (
    id SERIAL PRIMARY KEY,
    evaluator_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ratee_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id INT NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT idx_user_reviews_unique UNIQUE (evaluator_id, ratee_id, event_id),
    CONSTRAINT chk_user_reviews_different CHECK (evaluator_id <> ratee_id)
);

CREATE INDEX IF NOT EXISTS idx_user_reviews_ratee ON user_reviews(ratee_id);
CREATE INDEX IF NOT EXISTS idx_user_reviews_event ON user_reviews(event_id);
