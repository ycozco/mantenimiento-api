import {
  Injectable,
  NotFoundException,
  OnModuleInit,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as argon2 from 'argon2';
import { randomBytes, randomUUID } from 'node:crypto';

import { DatabaseService } from '../../database/database.service';
import { LoginDto } from './dto/login.dto';

type AuthUser = {
  id: string;
  workspaceId: string;
  workspaceSlug: string;
  email: string;
  displayName: string;
  role: string;
};

type SessionRow = AuthUser & {
  sessionId: string;
  deviceId: string;
  refreshTokenHash: string;
  expiresAt: Date;
};

type SessionClaims = {
  sub: string;
  workspaceId: string;
  sessionId: string;
  deviceId: string;
};

@Injectable()
export class AuthService implements OnModuleInit {
  private dummyPasswordHash = '';

  constructor(
    private readonly db: DatabaseService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit(): Promise<void> {
    this.dummyPasswordHash = await argon2.hash(
      randomBytes(32).toString('base64url'),
      { type: argon2.argon2id },
    );
  }

  async login(dto: LoginDto) {
    const result = await this.db.query<{
      id: string;
      workspace_id: string;
      workspace_slug: string;
      email: string;
      display_name: string;
      role: string;
      password_hash: string;
    }>(
      `SELECT u.id, u.workspace_id, w.slug AS workspace_slug,
              i.email, i.display_name, u.role, i.password_hash
         FROM users u
         JOIN user_identities i ON i.id = u.identity_id
         JOIN workspaces w ON w.id = u.workspace_id
        WHERE i.normalized_email = lower(trim($1))
          AND lower(w.slug) = lower($2)
          AND u.is_active = TRUE AND i.is_active = TRUE
          AND u.deleted_at IS NULL
          AND w.deleted_at IS NULL`,
      [dto.email.trim(), dto.workspaceSlug.trim()],
    );
    const row = result.rows[0];
    const passwordMatches = await argon2.verify(
      row?.password_hash ?? this.dummyPasswordHash,
      dto.password,
    );
    if (!row || !passwordMatches) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    const user: AuthUser = {
      id: row.id,
      workspaceId: row.workspace_id,
      workspaceSlug: row.workspace_slug,
      email: row.email,
      displayName: row.display_name,
      role: row.role,
    };
    const session = await this.createSession(user, dto.deviceId);
    return this.tokens(user, session.id, session.deviceId, session.refreshToken);
  }

  async refresh(refreshToken: string) {
    const parsed = this.parseRefreshToken(refreshToken);
    const result = await this.db.query<SessionRow>(
      `SELECT s.id AS "sessionId", s.refresh_token_hash AS "refreshTokenHash",
              s.device_id AS "deviceId",
              s.expires_at AS "expiresAt", u.id, u.workspace_id AS "workspaceId",
              w.slug AS "workspaceSlug", i.email, i.display_name AS "displayName",
              u.role
         FROM user_sessions s
         JOIN users u ON u.id = s.user_id AND u.workspace_id = s.workspace_id
         JOIN user_identities i ON i.id = u.identity_id AND i.is_active = TRUE
         JOIN workspaces w ON w.id = s.workspace_id
        WHERE s.id = $1 AND s.revoked_at IS NULL
          AND s.expires_at > NOW() AND u.is_active = TRUE
          AND u.deleted_at IS NULL AND w.deleted_at IS NULL`,
      [parsed.sessionId],
    );
    const session = result.rows[0];
    if (!session || !(await argon2.verify(session.refreshTokenHash, parsed.secret))) {
      throw new UnauthorizedException('Refresh token inválido');
    }

    const nextSecret = randomBytes(32).toString('base64url');
    const nextHash = await argon2.hash(nextSecret, { type: argon2.argon2id });
    const rotated = await this.db.query(
      `UPDATE user_sessions
          SET refresh_token_hash = $1, last_used_at = NOW()
        WHERE id = $2 AND refresh_token_hash = $3
          AND revoked_at IS NULL AND expires_at > NOW()
       RETURNING id`,
      [nextHash, session.sessionId, session.refreshTokenHash],
    );
    if (rotated.rowCount !== 1) {
      throw new UnauthorizedException('Refresh token inválido');
    }
    const user: AuthUser = {
      id: session.id,
      workspaceId: session.workspaceId,
      workspaceSlug: session.workspaceSlug,
      email: session.email,
      displayName: session.displayName,
      role: session.role,
    };
    return this.tokens(
      user,
      session.sessionId,
      session.deviceId,
      `${session.sessionId}.${nextSecret}`,
    );
  }

  async switchWorkspace(claims: SessionClaims, workspaceSlug: string) {
    const nextSessionId = randomUUID();
    const nextSecret = randomBytes(32).toString('base64url');
    const nextHash = await argon2.hash(nextSecret, { type: argon2.argon2id });
    const days = Number(this.config.get<string>('REFRESH_TOKEN_DAYS', '30'));
    const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

    const switched = await this.db.withTransaction(async (client) => {
      const active = await client.query<{
        identityId: string;
        deviceId: string;
      }>(
        `SELECT i.id AS "identityId", s.device_id AS "deviceId"
           FROM user_sessions s
           JOIN users u
             ON u.id = s.user_id AND u.workspace_id = s.workspace_id
           JOIN user_identities i ON i.id = u.identity_id
           JOIN workspaces w ON w.id = s.workspace_id
          WHERE s.id = $1 AND s.user_id = $2 AND s.workspace_id = $3
            AND s.device_id = $4 AND s.revoked_at IS NULL
            AND s.expires_at > NOW() AND u.is_active = TRUE
            AND u.deleted_at IS NULL AND i.is_active = TRUE
            AND w.deleted_at IS NULL
          FOR UPDATE OF s`,
        [
          claims.sessionId,
          claims.sub,
          claims.workspaceId,
          claims.deviceId,
        ],
      );
      const current = active.rows[0];
      if (!current) {
        throw new UnauthorizedException('Sesión revocada o inactiva');
      }

      const target = await client.query<AuthUser>(
        `SELECT u.id, u.workspace_id AS "workspaceId",
                w.slug AS "workspaceSlug", i.email,
                i.display_name AS "displayName", u.role
           FROM users u
           JOIN user_identities i ON i.id = u.identity_id
           JOIN workspaces w ON w.id = u.workspace_id
          WHERE i.id = $1 AND lower(w.slug) = lower($2)
            AND i.is_active = TRUE AND u.is_active = TRUE
            AND u.deleted_at IS NULL AND w.deleted_at IS NULL
          FOR UPDATE OF u, w`,
        [current.identityId, workspaceSlug.trim()],
      );
      const user = target.rows[0];
      if (!user) {
        throw new NotFoundException('No tienes acceso a esa organización');
      }

      const revoked = await client.query(
        `UPDATE user_sessions SET revoked_at = NOW()
          WHERE id = $1 AND revoked_at IS NULL
         RETURNING id`,
        [claims.sessionId],
      );
      if (revoked.rowCount !== 1) {
        throw new UnauthorizedException('La sesión ya no está activa');
      }

      await client.query(
        `INSERT INTO user_sessions
           (id, workspace_id, user_id, device_id, refresh_token_hash, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          nextSessionId,
          user.workspaceId,
          user.id,
          current.deviceId,
          nextHash,
          expiresAt,
        ],
      );
      return { user, deviceId: current.deviceId };
    });

    return this.tokens(
      switched.user,
      nextSessionId,
      switched.deviceId,
      `${nextSessionId}.${nextSecret}`,
    );
  }

  async logout(refreshToken: string): Promise<void> {
    const parsed = this.parseRefreshToken(refreshToken);
    const result = await this.db.query<{ refresh_token_hash: string }>(
      `SELECT s.refresh_token_hash
         FROM user_sessions s
         JOIN users u ON u.id = s.user_id AND u.workspace_id = s.workspace_id
         JOIN user_identities i ON i.id = u.identity_id AND i.is_active = TRUE
         JOIN workspaces w ON w.id = s.workspace_id
        WHERE s.id = $1 AND s.revoked_at IS NULL AND s.expires_at > NOW()
          AND u.is_active = TRUE AND u.deleted_at IS NULL
          AND w.deleted_at IS NULL`,
      [parsed.sessionId],
    );
    const row = result.rows[0];
    if (!row || !(await argon2.verify(row.refresh_token_hash, parsed.secret))) {
      throw new UnauthorizedException('Refresh token inválido');
    }
    const revoked = await this.db.query(
      `UPDATE user_sessions SET revoked_at = COALESCE(revoked_at, NOW())
        WHERE id = $1 AND refresh_token_hash = $2 AND revoked_at IS NULL
       RETURNING id`,
      [parsed.sessionId, row.refresh_token_hash],
    );
    if (revoked.rowCount !== 1) {
      throw new UnauthorizedException('Refresh token inválido');
    }
  }

  private async createSession(user: AuthUser, deviceId?: string) {
    const id = randomUUID();
    const actualDeviceId = deviceId ?? randomUUID();
    const secret = randomBytes(32).toString('base64url');
    const hash = await argon2.hash(secret, { type: argon2.argon2id });
    const days = Number(this.config.get<string>('REFRESH_TOKEN_DAYS', '30'));
    const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
    await this.db.query(
      `INSERT INTO user_sessions
        (id, workspace_id, user_id, device_id, refresh_token_hash, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [id, user.workspaceId, user.id, actualDeviceId, hash, expiresAt],
    );
    return { id, deviceId: actualDeviceId, refreshToken: `${id}.${secret}` };
  }

  private async tokens(
    user: AuthUser,
    sessionId: string,
    deviceId: string,
    refreshToken: string,
  ) {
    const accessToken = await this.jwt.signAsync({
      sub: user.id,
      workspaceId: user.workspaceId,
      role: user.role,
      sessionId,
      deviceId,
    });
    return { accessToken, refreshToken, user };
  }

  private parseRefreshToken(refreshToken: string) {
    const separator = refreshToken.indexOf('.');
    if (separator <= 0 || separator === refreshToken.length - 1) {
      throw new UnauthorizedException('Refresh token inválido');
    }
    const sessionId = refreshToken.slice(0, separator);
    if (
      !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        sessionId,
      )
    ) {
      throw new UnauthorizedException('Refresh token inválido');
    }
    return { sessionId, secret: refreshToken.slice(separator + 1) };
  }
}

