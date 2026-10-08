import { Pool } from 'pg';
import * as argon2 from 'argon2';

function required(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Falta la variable ${name}`);
  return value;
}

async function main(): Promise<void> {
  const databaseUrl = required('DATABASE_URL');
  const workspaceSlug = required('WORKSPACE_SLUG');
  const workspaceName = required('WORKSPACE_NAME');
  const email = required('ADMIN_EMAIL').toLowerCase();
  const displayName = required('ADMIN_NAME');
  const password = required('ADMIN_PASSWORD');
  if (password.length < 12) {
    throw new Error('ADMIN_PASSWORD debe tener al menos 12 caracteres');
  }

  const pool = new Pool({ connectionString: databaseUrl });
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const workspace = await client.query<{ id: string }>(
      `INSERT INTO workspaces (slug, name)
       VALUES ($1, $2)
       ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
       RETURNING id`,
      [workspaceSlug, workspaceName],
    );
    const workspaceId = workspace.rows[0]?.id;
    if (!workspaceId) throw new Error('No se pudo obtener el workspace');

    const existingMembership = await client.query(
      `SELECT 1 FROM users WHERE workspace_id = $1 AND lower(email) = lower($2)`,
      [workspaceId, email],
    );
    if (existingMembership.rowCount) {
      throw new Error('El usuario administrador ya existe en este workspace');
    }

    const identityResult = await client.query<{
      id: string;
      email: string;
      display_name: string;
      password_hash: string;
    }>(
      `SELECT id, email, display_name, password_hash
         FROM user_identities
        WHERE normalized_email = lower(trim($1))
        FOR UPDATE`,
      [email],
    );
    let identity = identityResult.rows[0];
    if (!identity) {
      const passwordHash = await argon2.hash(password, {
        type: argon2.argon2id,
      });
      const createdIdentity = await client.query<{
        id: string;
        email: string;
        display_name: string;
        password_hash: string;
      }>(
        `INSERT INTO user_identities
           (email, normalized_email, display_name, password_hash)
         VALUES ($1, lower(trim($1)), $2, $3)
         RETURNING id, email, display_name, password_hash`,
        [email, displayName, passwordHash],
      );
      identity = createdIdentity.rows[0];
    }

    await client.query(
      `INSERT INTO users
        (workspace_id, identity_id, email, display_name, password_hash, role)
       VALUES ($1, $2, $3, $4, $5, 'owner')`,
      [
        workspaceId,
        identity.id,
        identity.email,
        identity.display_name,
        identity.password_hash,
      ],
    );
    await client.query('COMMIT');
    console.log(`Workspace creado/verificado: ${workspaceSlug}`);
    console.log(`Administrador creado: ${email}`);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});

