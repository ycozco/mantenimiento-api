-- The primary key (workspace_id, server_seq) already supports pull queries.
DROP INDEX IF EXISTS sync_changes_pull_idx;
