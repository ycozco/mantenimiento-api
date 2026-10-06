import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AppConfig {
  constructor(private readonly config: ConfigService) {}

  get port(): number {
    const rawPort = this.config.get<string>('PORT', '3000');
    const port = Number(rawPort);
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error(`PORT inválido: ${rawPort}`);
    }
    return port;
  }

  get apiPrefix(): string {
    return this.config.get<string>('API_PREFIX', 'api/v1').replace(/^\/+|\/+$/g, '');
  }

  get environment(): string {
    return this.config.get<string>('NODE_ENV', 'development');
  }
}
