ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gender VARCHAR(30);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS birth_year INT;

UPDATE profiles
SET gender = NULLIF(substring(bio FROM '\[gender:([^\]]+)\]'), '')
WHERE gender IS NULL
  AND bio IS NOT NULL
  AND bio ~ '\[gender:[^\]]+\]';

UPDATE profiles
SET birth_year = NULLIF(substring(bio FROM '\[birth_year:([0-9]{4})\]'), '')::INT
WHERE birth_year IS NULL
  AND bio IS NOT NULL
  AND bio ~ '\[birth_year:[0-9]{4}\]';

UPDATE profiles
SET bio = btrim(
    regexp_replace(
        regexp_replace(COALESCE(bio, ''), '\[gender:[^\]]+\]', '', 'g'),
        '\[birth_year:[0-9]{4}\]',
        '',
        'g'
    )
)
WHERE bio IS NOT NULL
  AND (bio ~ '\[gender:[^\]]+\]' OR bio ~ '\[birth_year:[0-9]{4}\]');

ALTER TABLE profiles ADD CONSTRAINT profiles_birth_year_reasonable
CHECK (birth_year IS NULL OR (birth_year >= 1900 AND birth_year <= EXTRACT(YEAR FROM CURRENT_DATE)::INT));
