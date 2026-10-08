CREATE TABLE IF NOT EXISTS user_identities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  normalized_email TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  email_verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (length(trim(email)) > 3),
  CHECK (normalized_email = lower(trim(normalized_email)))
);

DO $$
BEGIN
  IF EXISTS (
    SELECT lower(trim(email))
      FROM users
     GROUP BY lower(trim(email))
    HAVING COUNT(DISTINCT password_hash) > 1
  ) THEN
    RAISE EXCEPTION
      'Cannot consolidate duplicate emails with different password hashes';
  END IF;
END;
$$;

INSERT INTO user_identities
  (email, normalized_email, display_name, password_hash, is_active,
   created_at, updated_at)
SELECT DISTINCT ON (lower(trim(email)))
       trim(email), lower(trim(email)), display_name, password_hash, TRUE,
       created_at, updated_at
  FROM users
 ORDER BY lower(trim(email)), created_at, id
ON CONFLICT (normalized_email) DO NOTHING;

ALTER TABLE users ADD COLUMN IF NOT EXISTS identity_id UUID;

UPDATE users AS u
   SET identity_id = i.id
  FROM user_identities AS i
 WHERE i.normalized_email = lower(trim(u.email))
   AND u.identity_id IS NULL;

ALTER TABLE users ALTER COLUMN identity_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_identity_fk'
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT users_identity_fk
      FOREIGN KEY (identity_id) REFERENCES user_identities(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_workspace_identity_key'
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT users_workspace_identity_key
      UNIQUE (workspace_id, identity_id);
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS users_identity_idx ON users (identity_id);

