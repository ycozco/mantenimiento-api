import {
  Controller,
  Get,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { DatabaseService } from '../../database/database.service';

@Controller('health')
export class HealthController {
  constructor(
    private readonly config: ConfigService,
    private readonly db: DatabaseService,
  ) {}

  @Get()
  getHealth() {
    return {
      status: 'ok',
      service: 'decolumax-server',
      environment: this.config.get<string>('NODE_ENV', 'development'),
      timestamp: new Date().toISOString(),
    };
  }

  @Get('ready')
  async getReadiness() {
    if (!this.db.configured) {
      throw new ServiceUnavailableException('DATABASE_URL no configurada');
    }
    try {
      await this.db.query('SELECT 1');
      return { status: 'ready' };
    } catch {
      throw new ServiceUnavailableException('PostgreSQL no disponible');
    }
  }
}
