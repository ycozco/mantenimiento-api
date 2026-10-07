import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAccessGuard } from '../auth/jwt-access.guard';
import { PullChangesQueryDto, PushOperationDto } from './dto/push-operation.dto';
import { NatsMailboxService } from './nats-mailbox.service';

type AuthenticatedRequest = {
  user: {
    sub: string;
    workspaceId: string;
    sessionId: string;
    deviceId: string;
  };
};

@Controller('sync')
@UseGuards(JwtAccessGuard)
export class SyncController {
  constructor(private readonly mailbox: NatsMailboxService) {}

  @Post('push')
  async push(@Req() req: AuthenticatedRequest, @Body() dto: PushOperationDto) {
    const sequence = await this.mailbox.publish({
      ...dto,
      workspaceId: req.user.workspaceId,
      actorId: req.user.sub,
      deviceId: req.user.deviceId,
      createdAt: new Date().toISOString(),
    });
    return { accepted: true, operationId: dto.operationId, sequence };
  }

  @Get('pull')
  pull(@Req() req: AuthenticatedRequest, @Query() query: PullChangesQueryDto) {
    return this.mailbox.pull(req.user.workspaceId, query.cursor, query.limit);
  }
}
