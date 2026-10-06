import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { AppConfig } from './config/app.config';
import { DatabaseModule } from './database/database.module';
import { HealthModule } from './modules/health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    HealthModule,
  ],
  providers: [AppConfig],
  exports: [AppConfig],
})
export class AppModule {}
