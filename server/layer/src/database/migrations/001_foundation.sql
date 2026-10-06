CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS workspaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id),
  email TEXT NOT NULL,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'owner',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  version INTEGER NOT NULL DEFAULT 1,
  deleted_at TIMESTAMPTZ,
  UNIQUE (workspace_id, id),
  CHECK (length(trim(email)) > 3),
  CHECK (role IN ('owner', 'admin', 'member'))
);

CREATE UNIQUE INDEX IF NOT EXISTS users_workspace_email_idx
  ON users (workspace_id, lower(email));

CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL,
  user_id UUID NOT NULL,
  device_id UUID NOT NULL,
  refresh_token_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  last_used_at TIMESTAMPTZ,
  UNIQUE (workspace_id, id),
  FOREIGN KEY (workspace_id, user_id)
    REFERENCES users (workspace_id, id)
);

CREATE TABLE IF NOT EXISTS workspace_sequences (
  workspace_id UUID PRIMARY KEY REFERENCES workspaces(id),
  next_seq BIGINT NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION next_workspace_seq(p_workspace_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE result BIGINT;
BEGIN
  INSERT INTO workspace_sequences (workspace_id)
  VALUES (p_workspace_id)
  ON CONFLICT (workspace_id) DO NOTHING;

  UPDATE workspace_sequences
  SET next_seq = next_seq + 1
  WHERE workspace_id = p_workspace_id
  RETURNING next_seq INTO result;

  RETURN result;
END;
$$;

CREATE TABLE IF NOT EXISTS sync_changes (
  workspace_id UUID NOT NULL REFERENCES workspaces(id),
  server_seq BIGINT NOT NULL,
  operation_id UUID NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  operation TEXT NOT NULL,
  version INTEGER NOT NULL,
  payload JSONB NOT NULL,
  server_received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (workspace_id, server_seq),
  UNIQUE (workspace_id, operation_id),
  CHECK (operation IN ('UPSERT', 'DELETE'))
);

CREATE INDEX IF NOT EXISTS sync_changes_pull_idx
  ON sync_changes (workspace_id, server_seq);

CREATE TABLE IF NOT EXISTS sync_idempotency_log (
  workspace_id UUID NOT NULL,
  operation_id UUID NOT NULL,
  device_id UUID NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  status TEXT NOT NULL,
  server_seq BIGINT,
  response_payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (workspace_id, operation_id),
  CHECK (status IN ('ACCEPTED', 'CONFLICT', 'REJECTED'))
);

CREATE INDEX IF NOT EXISTS sync_idempotency_retention_idx
  ON sync_idempotency_log (created_at);
