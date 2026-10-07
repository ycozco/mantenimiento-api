import { Module } from '@nestjs/common';
import { JwtAccessGuard } from '../auth/jwt-access.guard';
import { SyncController } from './sync.controller';
import { NatsMailboxService } from './nats-mailbox.service';

@Module({
  controllers: [SyncController],
  providers: [NatsMailboxService, JwtAccessGuard],
})
export class SyncModule {}
