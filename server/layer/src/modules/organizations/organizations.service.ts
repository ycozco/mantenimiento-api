import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { DatabaseService } from '../../database/database.service';
import { CreateOrganizationDto } from './dto/create-organization.dto';
import { UpdateOrganizationDto } from './dto/update-organization.dto';

type OrganizationContext = {
  id: string;
  workspaceId: string;
  identityId: string;
  email: string;
  displayName: string;
  passwordHash: string;
  role: string;
};

@Injectable()
export class OrganizationsService {
  constructor(private readonly db: DatabaseService) {}

  async listMine(userId: string, workspaceId: string) {
    const context = await this.context(userId, workspaceId);
    const result = await this.db.query(
      `SELECT w.id, w.name, w.slug, m.role,
              m.is_active AS "membershipActive",
              m.created_at AS "joinedAt",
              (w.id = $2::uuid) AS "isCurrent"
         FROM users m
         JOIN workspaces w ON w.id = m.workspace_id
        WHERE m.identity_id = $1 AND m.is_active = TRUE
          AND m.deleted_at IS NULL AND w.deleted_at IS NULL
        ORDER BY lower(w.name), w.id`,
      [context.identityId, workspaceId],
    );
    return { organizations: result.rows };
  }

  async create(userId: string, workspaceId: string, dto: CreateOrganizationDto) {
    const source = await this.context(userId, workspaceId);
    const name = dto.name.trim();
    const slug = (dto.slug ?? this.slugFromName(name)).trim();
    if (!slug) throw new BadRequestException('No se pudo crear un identificador');

    try {
      return await this.db.withTransaction(async (client) => {
        const created = await client.query<{ id: string; name: string; slug: string }>(
          `INSERT INTO workspaces (name, slug)
           VALUES ($1, $2)
           RETURNING id, name, slug`,
          [name, slug],
        );
        const organization = created.rows[0];
        await client.query(
          `INSERT INTO users
             (workspace_id, identity_id, email, display_name, password_hash, role)
           VALUES ($1, $2, $3, $4, $5, 'owner')`,
          [
            organization.id,
            source.identityId,
            source.email,
            source.displayName,
            source.passwordHash,
          ],
        );
        return { ...organization, role: 'owner' };
      });
    } catch (error) {
      if (this.isUniqueViolation(error)) {
        throw new ConflictException('Ese identificador de organizaciÃ³n ya existe');
      }
      throw error;
    }
  }

  async current(userId: string, workspaceId: string) {
    const result = await this.db.query(
      `SELECT w.id, w.name, w.slug, w.created_at AS "createdAt",
              u.role, u.created_at AS "memberSince"
         FROM users u
         JOIN user_identities i ON i.id = u.identity_id AND i.is_active = TRUE
         JOIN workspaces w ON w.id = u.workspace_id
        WHERE u.id = $1 AND u.workspace_id = $2 AND u.is_active = TRUE
          AND u.deleted_at IS NULL AND w.deleted_at IS NULL`,
      [userId, workspaceId],
    );
    if (!result.rows[0]) {
      throw new NotFoundException('OrganizaciÃ³n no encontrada');
    }
    return result.rows[0];
  }

  async updateCurrent(
    userId: string,
    workspaceId: string,
    dto: UpdateOrganizationDto,
  ) {
    if (dto.name === undefined && dto.slug === undefined) {
      throw new BadRequestException('Indica el nombre o el identificador');
    }
    const context = await this.context(userId, workspaceId);
    if (context.role !== 'owner' && context.role !== 'admin') {
      throw new ForbiddenException('Se requiere el rol administrador');
    }

    try {
      const result = await this.db.query(
        `UPDATE workspaces
            SET name = COALESCE($1, name),
                slug = COALESCE($2, slug),
                updated_at = NOW(), version = version + 1
          WHERE id = $3 AND deleted_at IS NULL
        RETURNING id, name, slug, created_at AS "createdAt"`,
        [dto.name?.trim() ?? null, dto.slug?.trim() ?? null, workspaceId],
      );
      if (!result.rows[0]) {
        throw new NotFoundException('OrganizaciÃ³n no encontrada');
      }
      return { ...result.rows[0], role: context.role };
    } catch (error) {
      if (this.isUniqueViolation(error)) {
        throw new ConflictException('Ese identificador de organizaciÃ³n ya existe');
      }
      throw error;
    }
  }

  private async context(
    userId: string,
    workspaceId: string,
  ): Promise<OrganizationContext> {
    const result = await this.db.query<OrganizationContext>(
      `SELECT u.id, u.workspace_id AS "workspaceId",
              i.id AS "identityId", i.email,
              i.display_name AS "displayName",
              i.password_hash AS "passwordHash", u.role
         FROM users u
         JOIN user_identities i ON i.id = u.identity_id AND i.is_active = TRUE
         JOIN workspaces w ON w.id = u.workspace_id
        WHERE u.id = $1 AND u.workspace_id = $2 AND u.is_active = TRUE
          AND u.deleted_at IS NULL AND w.deleted_at IS NULL`,
      [userId, workspaceId],
    );
    if (!result.rows[0]) {
      throw new NotFoundException('MembresÃ­a activa no encontrada');
    }
    return result.rows[0];
  }

  private slugFromName(name: string): string {
    return name
      .normalize('NFKD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 48)
      .replace(/-+$/g, '');
  }

  private isUniqueViolation(error: unknown): boolean {
    return (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      error.code === '23505'
    );
  }
}

