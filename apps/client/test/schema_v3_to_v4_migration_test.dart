import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/services/backup_restore_service.dart';

void main() {
  group('T-20/T-24 Drift Schema 3 -> Schema 5 Migration & Hardening', () {
    test('Migra base de datos Schema 3 a Schema 5 con datos reales preservados', () async {
      // 1. Crear una base de datos SQLite en memoria en versión 3 (estado pre-T-20)
      final appDb = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA user_version = 3;');
            rawDb.execute('PRAGMA foreign_keys = ON;');

            // Tablas básicas en Schema 3 (sin workspace_id en partners, clients, client_locations, projects)
            rawDb.execute('''
        CREATE TABLE users (
          id TEXT NOT NULL PRIMARY KEY,
          workspace_id TEXT NOT NULL DEFAULT 'default',
          email TEXT NOT NULL UNIQUE,
          display_name TEXT NOT NULL,
          role TEXT NOT NULL DEFAULT 'owner',
          avatar_color INTEGER NOT NULL DEFAULT 4284378891,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          version INTEGER NOT NULL DEFAULT 1,
          deleted_at INTEGER
        );
      ''');

            rawDb.execute('''
        CREATE TABLE partners (
          id TEXT NOT NULL PRIMARY KEY,
          user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
          name TEXT NOT NULL,
          phone TEXT,
          equity_percentage REAL NOT NULL DEFAULT 50.0,
          avatar_color INTEGER NOT NULL DEFAULT 4284378891,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          version INTEGER NOT NULL DEFAULT 1,
          deleted_at INTEGER
        );
      ''');

            rawDb.execute('''
        CREATE TABLE clients (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          contact_person TEXT,
          phone TEXT,
          email TEXT,
          tax_id TEXT,
          notes TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          version INTEGER NOT NULL DEFAULT 1,
          deleted_at INTEGER
        );
      ''');

            rawDb.execute('''
        CREATE TABLE client_locations (
          id TEXT NOT NULL PRIMARY KEY,
          client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
          name TEXT NOT NULL DEFAULT 'Principal',
          address TEXT NOT NULL,
          district TEXT,
          reference TEXT,
          latitude REAL,
          longitude REAL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          version INTEGER NOT NULL DEFAULT 1,
          deleted_at INTEGER
        );
      ''');

            rawDb.execute('''
        CREATE TABLE projects (
          id TEXT NOT NULL PRIMARY KEY,
          code TEXT,
          name TEXT NOT NULL,
          client_id TEXT REFERENCES clients(id) ON DELETE SET NULL,
          location_id TEXT REFERENCES client_locations(id) ON DELETE SET NULL,
          description TEXT,
          budget_amount_cents INTEGER NOT NULL DEFAULT 0,
          start_date INTEGER NOT NULL,
          target_end_date INTEGER,
          actual_end_date INTEGER,
          status TEXT NOT NULL DEFAULT 'inProgress',
          assigned_partner_ids_json TEXT NOT NULL DEFAULT '[]',
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          version INTEGER NOT NULL DEFAULT 1,
          deleted_at INTEGER
        );
      ''');

            rawDb.execute('''
        CREATE TABLE maintenance_plans (
          id TEXT NOT NULL PRIMARY KEY,
          workspace_id TEXT NOT NULL DEFAULT 'default',
          title TEXT NOT NULL,
          client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
          location_id TEXT REFERENCES client_locations(id) ON DELETE SET NULL,
          description TEXT,
          frequency_type TEXT NOT NULL DEFAULT 'unMes',
          interval_days INTEGER NOT NULL DEFAULT 30,
          next_date INTEGER,
          estimated_cost_cents INTEGER NOT NULL DEFAULT 0,
          billing_type TEXT NOT NULL DEFAULT 'perVisit',
          agreed_amount_cents INTEGER NOT NULL DEFAULT 0,
          assigned_partner_ids_json TEXT NOT NULL DEFAULT '[]',
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          created_by TEXT,
          updated_by TEXT,
          version INTEGER NOT NULL DEFAULT 1,
          deleted_at INTEGER
        );
      ''');

            rawDb.execute('''
        CREATE TABLE maintenance_visits (
          id TEXT NOT NULL PRIMARY KEY,
          workspace_id TEXT NOT NULL DEFAULT 'default',
          plan_id TEXT NOT NULL REFERENCES maintenance_plans(id) ON DELETE CASCADE,
          scheduled_date INTEGER NOT NULL,
          completed_date INTEGER,
          status TEXT NOT NULL DEFAULT 'scheduled',
          technician_notes TEXT,
          agreed_price_cents INTEGER,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          created_by TEXT,
          updated_by TEXT,
          version INTEGER NOT NULL DEFAULT 1,
          deleted_at INTEGER
        );
      ''');

            // Collections en versión 3 (sin el CHECK constraint de exclusividad)
            rawDb.execute('''
        CREATE TABLE collections (
          id TEXT NOT NULL PRIMARY KEY,
          workspace_id TEXT NOT NULL DEFAULT 'default',
          client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
          project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
          visit_id TEXT REFERENCES maintenance_visits(id) ON DELETE SET NULL,
          plan_id TEXT REFERENCES maintenance_plans(id) ON DELETE SET NULL,
          amount_cents INTEGER NOT NULL DEFAULT 0,
          date INTEGER NOT NULL,
          received_by_partner_id TEXT REFERENCES partners(id) ON DELETE SET NULL,
          payment_method TEXT NOT NULL DEFAULT 'cash',
          reference TEXT,
          notes TEXT,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          created_by TEXT,
          updated_by TEXT,
          version INTEGER NOT NULL DEFAULT 1,
          deleted_at INTEGER
        );
      ''');

            // Otras tablas mínimas requeridas por AppDatabase
            rawDb.execute(
              "CREATE TABLE workers (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', name TEXT NOT NULL, default_payment_type TEXT NOT NULL DEFAULT 'daily', default_rate_cents INTEGER NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE inventory_items (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', name TEXT NOT NULL, category TEXT NOT NULL DEFAULT 'plants', unit TEXT NOT NULL DEFAULT 'unit', min_stock_alert REAL NOT NULL DEFAULT 0.0, default_cost_cents INTEGER NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE suppliers (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', name TEXT NOT NULL, is_active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE purchases (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', supplier_id TEXT REFERENCES suppliers(id), total_amount_cents INTEGER NOT NULL, date INTEGER NOT NULL, document_type TEXT NOT NULL DEFAULT 'invoice', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE purchase_items (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', purchase_id TEXT NOT NULL REFERENCES purchases(id) ON DELETE CASCADE, item_id TEXT NOT NULL REFERENCES inventory_items(id), quantity REAL NOT NULL, unit_cost_cents INTEGER NOT NULL, total_cost_cents INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE stock_movements (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', item_id TEXT NOT NULL REFERENCES inventory_items(id), movement_type TEXT NOT NULL DEFAULT 'consumption', quantity REAL NOT NULL, unit_cost_cents INTEGER NOT NULL DEFAULT 0, total_cost_cents INTEGER NOT NULL DEFAULT 0, project_id TEXT, visit_id TEXT, purchase_id TEXT, date INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE tools (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', name TEXT NOT NULL, category TEXT NOT NULL DEFAULT 'manual', purchase_price_cents INTEGER NOT NULL DEFAULT 0, current_status TEXT NOT NULL DEFAULT 'available', condition TEXT NOT NULL DEFAULT 'good', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE tool_assignments (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', tool_id TEXT NOT NULL REFERENCES tools(id), assigned_at INTEGER NOT NULL, condition_out TEXT NOT NULL DEFAULT 'good', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE work_logs (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', worker_id TEXT NOT NULL REFERENCES workers(id), date INTEGER NOT NULL, project_id TEXT, maintenance_visit_id TEXT, payment_type TEXT NOT NULL DEFAULT 'daily', quantity REAL NOT NULL DEFAULT 1.0, rate_cents INTEGER NOT NULL DEFAULT 0, amount_cents INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE labor_payments (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', worker_id TEXT NOT NULL REFERENCES workers(id), amount_cents INTEGER NOT NULL, payment_date INTEGER NOT NULL, payment_method TEXT NOT NULL DEFAULT 'cash', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE expenses (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', concept TEXT NOT NULL, category TEXT NOT NULL DEFAULT 'otro', amount_cents INTEGER NOT NULL DEFAULT 0, date INTEGER NOT NULL, paid_by_partner_id TEXT NOT NULL REFERENCES partners(id), split_mode TEXT NOT NULL DEFAULT 'equitativo', split_ratios_json TEXT NOT NULL DEFAULT '{}', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE capital_movements (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', partner_id TEXT NOT NULL REFERENCES partners(id), type TEXT NOT NULL DEFAULT 'contribution', amount_cents INTEGER NOT NULL DEFAULT 0, date INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE attachments (id TEXT NOT NULL PRIMARY KEY, workspace_id TEXT NOT NULL DEFAULT 'default', parent_type TEXT NOT NULL, parent_id TEXT NOT NULL, fileName TEXT NOT NULL, file_size_bytes INTEGER NOT NULL DEFAULT 0, mime_type TEXT NOT NULL DEFAULT 'image/jpeg', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at INTEGER);",
            );
            rawDb.execute(
              "CREATE TABLE sync_queue (id INTEGER PRIMARY KEY AUTOINCREMENT, workspace_id TEXT NOT NULL DEFAULT 'default', entity_table TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL, payload_json TEXT NOT NULL, queued_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT);",
            );
            rawDb.execute(
              "CREATE TABLE app_metadata (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL);",
            );

            // 2. Poblar con datos representativos de Schema 3
            final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            rawDb.execute(
              "INSERT INTO partners (id, name, phone, equity_percentage, created_at, updated_at) VALUES ('p-mig-1', 'Socio Andino', '987111222', 50.0, $nowSec, $nowSec);",
            );
            rawDb.execute(
              "INSERT INTO clients (id, name, phone, created_at, updated_at) VALUES ('c-mig-1', 'Residencial San Jerónimo', '555-1234', $nowSec, $nowSec);",
            );
            rawDb.execute(
              "INSERT INTO client_locations (id, client_id, name, address, created_at, updated_at) VALUES ('loc-mig-1', 'c-mig-1', 'Bloque B', 'Av. Arequipa 100', $nowSec, $nowSec);",
            );
            rawDb.execute(
              "INSERT INTO projects (id, name, client_id, location_id, budget_amount_cents, start_date, created_at, updated_at) VALUES ('proj-mig-1', 'Remodelación Jardines', 'c-mig-1', 'loc-mig-1', 450000, $nowSec, $nowSec, $nowSec);",
            );
            rawDb.execute(
              "INSERT INTO maintenance_plans (id, workspace_id, title, client_id, billing_type, agreed_amount_cents, created_at, updated_at) VALUES ('plan-mig-1', 'default', 'Mantenimiento Mensual', 'c-mig-1', 'monthly', 120000, $nowSec, $nowSec);",
            );
            rawDb.execute(
              "INSERT INTO collections (id, workspace_id, client_id, project_id, amount_cents, date, created_at, updated_at) VALUES ('col-mig-1', 'default', 'c-mig-1', 'proj-mig-1', 200000, $nowSec, $nowSec, $nowSec);",
            );
            rawDb.execute(
              "INSERT INTO collections (id, workspace_id, client_id, plan_id, amount_cents, date, created_at, updated_at) VALUES ('col-mig-2', 'default', 'c-mig-1', 'plan-mig-1', 60000, $nowSec, $nowSec, $nowSec);",
            );
            rawDb.execute(
              "INSERT INTO sync_queue (workspace_id, entity_table, entity_id, operation, payload_json, queued_at) VALUES ('default', 'clients', 'c-mig-1', 'UPSERT', '{}', $nowSec);",
            );
          },
        ),
      );

      // 4. Validar versión final
      expect(appDb.schemaVersion, equals(5));

      // 5. Validar que las 4 tablas baseline contienen workspace_id = 'default'
      final pRows = await appDb.select(appDb.partners).get();
      expect(pRows.length, equals(1));
      expect(pRows.first.id, equals('p-mig-1'));
      expect(pRows.first.name, equals('Socio Andino'));
      expect(pRows.first.workspaceId, equals('default'));

      final queueRows = await appDb.select(appDb.syncQueue).get();
      expect(queueRows.length, equals(1));
      expect(queueRows.first.operationId, isNotEmpty);
      expect(queueRows.first.entityTable, equals('clients'));
      expect(queueRows.first.status, equals('PENDING'));

      final cRows = await appDb.select(appDb.clients).get();
      expect(cRows.length, equals(1));
      expect(cRows.first.id, equals('c-mig-1'));
      expect(cRows.first.workspaceId, equals('default'));

      final locRows = await appDb.select(appDb.clientLocations).get();
      expect(locRows.length, equals(1));
      expect(locRows.first.id, equals('loc-mig-1'));
      expect(locRows.first.workspaceId, equals('default'));

      final projRows = await appDb.select(appDb.projects).get();
      expect(projRows.length, equals(1));
      expect(projRows.first.id, equals('proj-mig-1'));
      expect(projRows.first.workspaceId, equals('default'));
      expect(projRows.first.budgetAmountCents, equals(450000));

      // 6. Validar que los cobros existentes sobrevivieron íntegros a la recreación
      final colRows = await appDb.select(appDb.collections).get();
      expect(colRows.length, equals(2));
      final colProj = colRows.firstWhere((c) => c.id == 'col-mig-1');
      expect(colProj.amountCents, equals(200000));
      expect(colProj.projectId, equals('proj-mig-1'));
      expect(colProj.planId, isNull);

      final colPlan = colRows.firstWhere((c) => c.id == 'col-mig-2');
      expect(colPlan.amountCents, equals(60000));
      expect(colPlan.planId, equals('plan-mig-1'));
      expect(colPlan.projectId, isNull);

      // 7. Validar enforcement del constraint SQLite CHECK en collections
      // Intentar insertar cobro con contexto dual (project_id Y plan_id simultáneos) a nivel SQLite
      expect(
        () async => await appDb
            .into(appDb.collections)
            .insert(
              CollectionsCompanion.insert(
                id: 'col-invalido-dual',
                clientId: 'c-mig-1',
                projectId: const Value('proj-mig-1'),
                planId: const Value('plan-mig-1'),
                amountCents: const Value(10000),
                date: DateTime.now(),
              ),
            ),
        throwsA(anything),
      );

      // Intentar insertar cobro sin ningún contexto (project, visit, plan todos nulos)
      expect(
        () async => await appDb
            .into(appDb.collections)
            .insert(
              CollectionsCompanion.insert(
                id: 'col-invalido-huerfano',
                clientId: 'c-mig-1',
                amountCents: const Value(10000),
                date: DateTime.now(),
              ),
            ),
        throwsA(anything),
      );

      // Intentar insertar monto <= 0
      expect(
        () async => await appDb
            .into(appDb.collections)
            .insert(
              CollectionsCompanion.insert(
                id: 'col-invalido-monto',
                clientId: 'c-mig-1',
                projectId: const Value('proj-mig-1'),
                amountCents: const Value(0),
                date: DateTime.now(),
              ),
            ),
        throwsA(anything),
      );

      // Inserción válida con exactamente 1 contexto debe tener éxito
      await appDb
          .into(appDb.collections)
          .insert(
            CollectionsCompanion.insert(
              id: 'col-valido-nuevo',
              clientId: 'c-mig-1',
              projectId: const Value('proj-mig-1'),
              amountCents: const Value(15000),
              date: DateTime.now(),
            ),
          );

      final totalCols = await appDb.select(appDb.collections).get();
      expect(totalCols.length, equals(3));

      // 8. Validar Backup/Restore en Schema 5
      final backupService = BackupRestoreService(appDb);
      final jsonBackup = await backupService.exportBackupJson();
      expect(jsonBackup, contains('"schemaVersion": 5'));
      expect(jsonBackup, contains('"workspaceId": "default"'));

      await appDb.close();
    });
  });
}
