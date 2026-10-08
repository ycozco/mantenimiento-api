import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'node:crypto';

import { DatabaseService } from '../../database/database.service';

export type AuthAuditEvent = {
  eventType:
    | 'auth.login'
    | 'auth.login.rate_limited'
    | 'auth.refresh'
    | 'auth.logout'
    | 'auth.workspace_switch';
  outcome: 'success' | 'failure' | 'rate_limited';
  clientIp?: string;
  workspaceId?: string;
  userId?: string;
  deviceId?: string;
  metadata?: Record<string, string | number | boolean | null>;
};

@Injectable()
export class AuthAuditService {
  private readonly logger = new Logger(AuthAuditService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly config: ConfigService,
  ) {}

  async record(event: AuthAuditEvent): Promise<void> {
    try {
      const secret = this.config.getOrThrow<string>('JWT_ACCESS_SECRET');
      const clientFingerprint = event.clientIp
        ? createHmac('sha256', secret)
            .update(`audit-client:${event.clientIp}`)
            .digest('hex')
        : null;
      await this.db.query(
        `INSERT INTO auth_audit_events
           (event_type, outcome, workspace_id, user_id, device_id,
            client_fingerprint, metadata)
         VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)`,
        [
          event.eventType,
          event.outcome,
          event.workspaceId ?? null,
          event.userId ?? null,
          event.deviceId ?? null,
          clientFingerprint,
          JSON.stringify(event.metadata ?? {}),
        ],
      );
    } catch (error) {
      this.logger.warn(
        `No se pudo guardar evento de autenticaciÃ³n (${event.eventType}/${event.outcome}): ${error instanceof Error ? error.message : 'error desconocido'}`,
      );
    }
  }
}

