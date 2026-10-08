import {
  Body,
  Controller,
  Get,
  Post,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';

import { AuthAuditService } from './auth-audit.service';
import { AuthService } from './auth.service';
import { AuthRateLimitService } from './auth-rate-limit.service';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { SwitchWorkspaceDto } from './dto/switch-workspace.dto';
import { JwtAccessGuard } from './jwt-access.guard';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly rateLimit: AuthRateLimitService,
    private readonly audit: AuthAuditService,
  ) {}

  @Post('login')
  async login(
    @Body() dto: LoginDto,
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    const clientIp = this.clientIp(request);
    await this.rateLimit.assertLoginAllowed(
      dto.email,
      clientIp,
    );
    try {
      const result = await this.auth.login(dto);
      await this.audit.record({
        eventType: 'auth.login',
        outcome: 'success',
        clientIp,
        workspaceId: result.user.workspaceId,
        userId: result.user.id,
        metadata: { workspaceSlug: result.user.workspaceSlug },
      });
      return result;
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        await this.audit.record({
          eventType: 'auth.login',
          outcome: 'failure',
          clientIp,
          metadata: { workspaceSlug: dto.workspaceSlug.trim().toLowerCase() },
        });
      }
      throw error;
    }
  }

  @Post('refresh')
  async refresh(
    @Body() dto: RefreshDto,
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    const clientIp = this.clientIp(request);
    await this.rateLimit.assertAuthEndpointAllowed('refresh', clientIp);
    try {
      const result = await this.auth.refresh(dto.refreshToken);
      await this.audit.record({
        eventType: 'auth.refresh',
        outcome: 'success',
        clientIp,
        workspaceId: result.user.workspaceId,
        userId: result.user.id,
      });
      return result;
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        await this.audit.record({
          eventType: 'auth.refresh',
          outcome: 'failure',
          clientIp,
        });
      }
      throw error;
    }
  }

  @Post('logout')
  async logout(
    @Body() dto: RefreshDto,
    @Req() request: { ip?: string; socket?: { remoteAddress?: string } },
  ) {
    const clientIp = this.clientIp(request);
    await this.rateLimit.assertAuthEndpointAllowed('logout', clientIp);
    try {
      await this.auth.logout(dto.refreshToken);
      await this.audit.record({
        eventType: 'auth.logout',
        outcome: 'success',
        clientIp,
      });
      return { ok: true };
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        await this.audit.record({
          eventType: 'auth.logout',
          outcome: 'failure',
          clientIp,
        });
      }
      throw error;
    }
  }

  @Post('switch-workspace')
  @UseGuards(JwtAccessGuard)
  async switchWorkspace(
    @Body() dto: SwitchWorkspaceDto,
    @Req()
    request: {
      ip?: string;
      socket?: { remoteAddress?: string };
      user: {
        sub: string;
        workspaceId: string;
        sessionId: string;
        deviceId: string;
      };
    },
  ) {
    const clientIp = this.clientIp(request);
    await this.rateLimit.assertAuthEndpointAllowed('workspace-switch', clientIp);
    try {
      const result = await this.auth.switchWorkspace(
        request.user,
        dto.workspaceSlug,
      );
      await this.audit.record({
        eventType: 'auth.workspace_switch',
        outcome: 'success',
        clientIp,
        workspaceId: result.user.workspaceId,
        userId: result.user.id,
        metadata: { workspaceSlug: result.user.workspaceSlug },
      });
      return result;
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        await this.audit.record({
          eventType: 'auth.workspace_switch',
          outcome: 'failure',
          clientIp,
        });
      }
      throw error;
    }
  }

  @Get('me')
  @UseGuards(JwtAccessGuard)
  me(@Req() request: { user: Record<string, unknown> }) {
    return request.user;
  }

  private clientIp(request: {
    ip?: string;
    socket?: { remoteAddress?: string };
  }): string {
    return request.ip ?? request.socket?.remoteAddress ?? 'unknown';
  }
}

