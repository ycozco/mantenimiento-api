import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AppConfig } from './config/app.config';
import { DatabaseModule } from './database/database.module';
import { AuthModule } from './modules/auth/auth.module';
import { HealthModule } from './modules/health/health.module';
import { SyncModule } from './modules/sync/sync.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    AuthModule,
    HealthModule,
    SyncModule,
  ],
  providers: [AppConfig],
  exports: [AppConfig],
})
export class AppModule {}
