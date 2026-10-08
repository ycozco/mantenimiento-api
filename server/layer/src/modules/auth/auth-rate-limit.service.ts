import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'node:crypto';
import { PoolClient } from 'pg';

import { DatabaseService } from '../../database/database.service';
import { AuthAuditService } from './auth-audit.service';

type BucketResult = {
  attempts: number;
  retryAfterSeconds: number;
};

@Injectable()
export class AuthRateLimitService {
  private requestsSinceCleanup = 0;

  constructor(
    private readonly db: DatabaseService,
    private readonly config: ConfigService,
    private readonly audit: AuthAuditService,
  ) {}

  async assertLoginAllowed(email: string, clientIp: string): Promise<void> {
    const secret = this.config.getOrThrow<string>('JWT_ACCESS_SECRET');
    const normalizedEmail = email.trim().normalize('NFKC').toLowerCase();
    await this.assertWithinLimits(
      [
        {
          key: this.bucketKey(
            secret,
            'login-email-ip',
            JSON.stringify([normalizedEmail, clientIp]),
          ),
          limit: 5,
          windowSeconds: 15 * 60,
        },
        {
          key: this.bucketKey(secret, 'login-ip', clientIp),
          limit: 30,
          windowSeconds: 60,
        },
      ],
      clientIp,
      'auth.login.rate_limited',
    );
  }

  async assertAuthEndpointAllowed(
    endpoint: 'refresh' | 'logout' | 'workspace-switch',
    clientIp: string,
  ): Promise<void> {
    const secret = this.config.getOrThrow<string>('JWT_ACCESS_SECRET');
    await this.assertWithinLimits(
      [
        {
          key: this.bucketKey(secret, `auth-${endpoint}-ip`, clientIp),
          limit: endpoint === 'workspace-switch' ? 30 : 60,
          windowSeconds: 60,
        },
      ],
      clientIp,
      endpoint === 'workspace-switch'
        ? 'auth.workspace_switch'
        : `auth.${endpoint}`,
    );
  }

  private async assertWithinLimits(
    buckets: Array<{ key: string; limit: number; windowSeconds: number }>,
    clientIp: string,
    eventType:
      | 'auth.login.rate_limited'
      | 'auth.refresh'
      | 'auth.logout'
      | 'auth.workspace_switch',
  ): Promise<void> {
    const results = await this.db.withTransaction(async (client) => {
      const consumed = [];
      for (const bucket of buckets) {
        consumed.push({
          ...bucket,
          result: await this.consumeBucket(
            client,
            bucket.key,
            bucket.limit,
            bucket.windowSeconds,
          ),
        });
      }
      return consumed;
    });

    this.requestsSinceCleanup += 1;
    if (this.requestsSinceCleanup >= 250) {
      this.requestsSinceCleanup = 0;
      void this.db.query(
        `DELETE FROM auth_rate_limit_buckets
          WHERE window_started_at < NOW() - INTERVAL '1 day';
         DELETE FROM auth_audit_events
          WHERE occurred_at < NOW() - INTERVAL '180 days'`,
      ).catch(() => undefined);
    }

    const exceeded = results.filter(
      ({ limit, result }) => result.attempts > limit,
    );
    if (exceeded.length > 0) {
      await this.audit.record({
        eventType,
        outcome: 'rate_limited',
        clientIp,
        metadata: { endpoint: eventType.replace('auth.', '') },
      });
      throw new HttpException(
        {
          statusCode: HttpStatus.TOO_MANY_REQUESTS,
          message: 'Demasiados intentos. Espera antes de volver a intentarlo.',
          retryAfterSeconds: Math.max(
            ...exceeded.map(({ result }) => result.retryAfterSeconds),
          ),
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private async consumeBucket(
    client: PoolClient,
    key: string,
    limit: number,
    windowSeconds: number,
  ): Promise<BucketResult> {
    const result = await client.query<BucketResult>(
      `INSERT INTO auth_rate_limit_buckets
         (bucket_key, window_started_at, attempts)
       VALUES ($1, NOW(), 1)
       ON CONFLICT (bucket_key) DO UPDATE
         SET window_started_at = CASE
               WHEN auth_rate_limit_buckets.window_started_at <=
                    NOW() - make_interval(secs => $2::double precision)
               THEN NOW()
               ELSE auth_rate_limit_buckets.window_started_at
             END,
             attempts = CASE
               WHEN auth_rate_limit_buckets.window_started_at <=
                    NOW() - make_interval(secs => $2::double precision)
               THEN 1
               ELSE auth_rate_limit_buckets.attempts + 1
             END
       RETURNING attempts,
         GREATEST(
           0,
           CEIL(EXTRACT(EPOCH FROM (
             window_started_at + make_interval(secs => $2::double precision) - NOW()
           )))
         )::integer AS "retryAfterSeconds"`,
      [key, windowSeconds],
    );
    return result.rows[0];
  }

  private bucketKey(secret: string, scope: string, value: string): string {
    return createHmac('sha256', secret)
      .update(`${scope}:${value}`)
      .digest('hex');
  }
}

