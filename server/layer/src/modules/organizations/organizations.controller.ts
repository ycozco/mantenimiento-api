import {
  Body,
  Controller,
  Get,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { JwtAccessGuard } from '../auth/jwt-access.guard';
import { CreateOrganizationDto } from './dto/create-organization.dto';
import { UpdateOrganizationDto } from './dto/update-organization.dto';
import { OrganizationsService } from './organizations.service';

type AuthenticatedRequest = {
  user: { sub: string; workspaceId: string };
};

@Controller('organizations')
@UseGuards(JwtAccessGuard)
export class OrganizationsController {
  constructor(private readonly organizations: OrganizationsService) {}

  @Get()
  listMine(@Req() request: AuthenticatedRequest) {
    return this.organizations.listMine(
      request.user.sub,
      request.user.workspaceId,
    );
  }

  @Post()
  create(
    @Req() request: AuthenticatedRequest,
    @Body() dto: CreateOrganizationDto,
  ) {
    return this.organizations.create(
      request.user.sub,
      request.user.workspaceId,
      dto,
    );
  }

  @Get('current')
  current(@Req() request: AuthenticatedRequest) {
    return this.organizations.current(
      request.user.sub,
      request.user.workspaceId,
    );
  }

  @Patch('current')
  updateCurrent(
    @Req() request: AuthenticatedRequest,
    @Body() dto: UpdateOrganizationDto,
  ) {
    return this.organizations.updateCurrent(
      request.user.sub,
      request.user.workspaceId,
      dto,
    );
  }
}

