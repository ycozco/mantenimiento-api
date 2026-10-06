import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { readdir, readFile } from 'node:fs/promises';
import { basename, join } from 'node:path';

import { DatabaseService } from './database.service';

@Injectable()
export class MigrationService implements OnModuleInit {
  private readonly logger = new Logger(MigrationService.name);

  constructor(
    private readonly db: DatabaseService,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit(): Promise<void> {
    if (this.config.get<string>('RUN_MIGRATIONS', 'false') !== 'true') {
      return;
    }
    if (!this.db.configured) {
      throw new Error('RUN_MIGRATIONS=true requiere DATABASE_URL');
    }
    await this.run();
  }

  async run(): Promise<void> {
    const directory = join(__dirname, 'migrations');
    const files = (await readdir(directory))
      .filter((file) => /^\d+_.+\.sql$/.test(file))
      .sort();

    await this.db.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    const applied = await this.db.query<{ version: string }>(
      'SELECT version FROM schema_migrations',
    );
    const appliedVersions = new Set(applied.rows.map((row) => row.version));

    for (const file of files) {
      const version = basename(file, '.sql');
      if (appliedVersions.has(version)) continue;

      const sql = await readFile(join(directory, file), 'utf8');
      await this.db.withTransaction(async (client) => {
        await client.query(sql);
        await client.query(
          'INSERT INTO schema_migrations (version) VALUES ($1)',
          [version],
        );
      });
      this.logger.log(`Applied migration ${version}`);
    }
  }
}
