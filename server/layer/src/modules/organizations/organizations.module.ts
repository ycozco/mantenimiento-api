import { Module } from '@nestjs/common';

import { JwtAccessGuard } from '../auth/jwt-access.guard';
import { OrganizationsController } from './organizations.controller';
import { OrganizationsService } from './organizations.service';

@Module({
  controllers: [OrganizationsController],
  providers: [OrganizationsService, JwtAccessGuard],
})
export class OrganizationsModule {}

