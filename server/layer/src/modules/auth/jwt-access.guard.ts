import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

import { DatabaseService } from '../../database/database.service';

type AccessClaims = {
  sub?: unknown;
  workspaceId?: unknown;
  role?: unknown;
  sessionId?: unknown;
  deviceId?: unknown;
  [claim: string]: unknown;
};

@Injectable()
export class JwtAccessGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly db: DatabaseService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<{
      headers: { authorization?: string };
      user?: unknown;
    }>();
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Bearer token requerido');
    }
    let claims: AccessClaims;
    try {
      claims = await this.jwt.verifyAsync<AccessClaims>(header.slice(7));
    } catch {
      throw new UnauthorizedException('Access token invÃ¡lido');
    }

    if (
      typeof claims.sub !== 'string' ||
      typeof claims.workspaceId !== 'string' ||
      typeof claims.sessionId !== 'string' ||
      typeof claims.deviceId !== 'string'
    ) {
      throw new UnauthorizedException('Access token invÃ¡lido');
    }

    const session = await this.db.query<{ role: string }>(
      `SELECT u.role
         FROM user_sessions s
         JOIN users u
           ON u.id = s.user_id AND u.workspace_id = s.workspace_id
         JOIN user_identities i ON i.id = u.identity_id
         JOIN workspaces w ON w.id = s.workspace_id
        WHERE s.id = $1 AND s.user_id = $2 AND s.workspace_id = $3
          AND s.device_id = $4 AND s.revoked_at IS NULL
          AND s.expires_at > NOW() AND u.is_active = TRUE
          AND u.deleted_at IS NULL AND i.is_active = TRUE
          AND w.deleted_at IS NULL`,
      [claims.sessionId, claims.sub, claims.workspaceId, claims.deviceId],
    );
    const activeSession = session.rows[0];
    if (!activeSession) {
      throw new UnauthorizedException('SesiÃ³n revocada o inactiva');
    }
    request.user = { ...claims, role: activeSession.role };
    return true;
  }
}

