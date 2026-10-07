import {
  Injectable,
  OnModuleDestroy,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { jetstream, jetstreamManager } from '@nats-io/jetstream';
import { NatsConnection } from '@nats-io/nats-core';
import { connect } from '@nats-io/transport-node';

export type EncryptedOperation = {
  workspaceId: string;
  operationId: string;
  entityType: string;
  entityId: string;
  schemaVersion: number;
  nonce: string;
  ciphertext: string;
  actorId: string;
  deviceId: string;
  createdAt: string;
};

export type PulledOperation = EncryptedOperation & { sequence: string };

@Injectable()
export class NatsMailboxService implements OnModuleDestroy {
  private connection?: Promise<NatsConnection>;
  private readonly encoder = new TextEncoder();

  constructor(private readonly config: ConfigService) {}

  async publish(operation: EncryptedOperation): Promise<string> {
    const nc = await this.getConnection();
    try {
      const js = jetstream(nc);
      const subject = `deco.${operation.workspaceId}.${operation.entityType}`;
      const ack = await js.publish(subject, this.encoder.encode(JSON.stringify(operation)), {
        msgID: `${operation.workspaceId}:${operation.operationId}`,
      });
      return String(ack.seq);
    } catch {
      throw new ServiceUnavailableException('No se pudo guardar la operación en JetStream');
    }
  }

  async pull(
    workspaceId: string,
    after: string,
    limit: number,
  ): Promise<{ changes: PulledOperation[]; cursor: string; hasMore: boolean }> {
    const nc = await this.getConnection();
    const stream = this.config.get<string>('NATS_SYNC_STREAM', 'DECO_SYNC');
    try {
      const jsm = await jetstreamManager(nc);
      const info = await jsm.streams.info(stream);
      const last = BigInt(info.state.last_seq);
      let cursor = BigInt(after);
      const changes: PulledOperation[] = [];
      let scanned = 0;
      const scanLimit = Math.min(2000, Math.max(limit * 20, 500));

      while (cursor < last && changes.length < limit && scanned < scanLimit) {
        cursor += 1n;
        scanned += 1;
        if (cursor > BigInt(Number.MAX_SAFE_INTEGER)) {
          throw new Error('Stream sequence exceeded the supported range');
        }
        const result = await jsm.streams.getMessage(stream, { seq: Number(cursor) });
        if (!result?.data) continue;
        let operation: EncryptedOperation;
        try {
          operation = JSON.parse(
            new TextDecoder().decode(result.data),
          ) as EncryptedOperation;
        } catch {
          throw new Error(`Invalid operation payload at sequence ${cursor}`);
        }
        if (operation.workspaceId !== workspaceId) continue;
        changes.push({ ...operation, sequence: String(result.seq ?? cursor) });
      }

      return {
        changes,
        cursor: cursor.toString(),
        hasMore: cursor < last,
      };
    } catch {
      throw new ServiceUnavailableException('No se pudieron leer cambios de JetStream');
    }
  }

  async onModuleDestroy(): Promise<void> {
    if (!this.connection) return;
    try {
      await (await this.connection).drain();
    } catch {
      // The broker may already have closed the connection during shutdown.
    }
  }

  private async getConnection(): Promise<NatsConnection> {
    if (!this.connection) {
      const servers = this.config.get<string>('NATS_URL');
      const user = this.config.get<string>('NATS_SYNC_USER');
      const pass = this.config.get<string>('NATS_SYNC_PASSWORD');
      if (!servers || !user || !pass) {
        throw new ServiceUnavailableException('La conexión NATS no está configurada');
      }
      this.connection = connect({
        servers,
        user,
        pass,
        name: 'decolumax-sync-api',
        maxReconnectAttempts: -1,
        reconnectTimeWait: 1000,
        timeout: 5000,
      }).catch((error: unknown) => {
        this.connection = undefined;
        throw new ServiceUnavailableException('No se pudo conectar con NATS', {
          cause: error,
        });
      });
    }
    return this.connection;
  }
}
