import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import 'tables/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Partners,
    Workers,
    Clients,
    ClientLocations,
    Projects,
    MaintenancePlans,
    MaintenanceVisits,
    InventoryItems,
    Suppliers,
    Purchases,
    PurchaseItems,
    StockMovements,
    Tools,
    ToolAssignments,
    WorkLogs,
    LaborPayments,
    Expenses,
    CapitalMovements,
    Collections,
    Attachments,
    SyncQueue,
    SyncInbox,
    AppMetadata,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  AppDatabase.forTesting(DatabaseConnection super.connection);

  @override
  int get schemaVersion => 6;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'decolumax_mantenimiento_db',
      native: const DriftNativeOptions(shareAcrossIsolates: true),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(purchaseItems);
        await m.addColumn(suppliers, suppliers.contactName);
        await m.addColumn(suppliers, suppliers.email);
        await m.addColumn(suppliers, suppliers.isActive);
        await m.addColumn(purchases, purchases.documentType);
        await m.addColumn(purchases, purchases.notes);
        await m.addColumn(capitalMovements, capitalMovements.projectId);
        await m.addColumn(collections, collections.reference);
      }
      if (from < 3) {
        await m.addColumn(maintenancePlans, maintenancePlans.billingType);
        await m.addColumn(maintenancePlans, maintenancePlans.agreedAmountCents);
        await m.addColumn(
          maintenanceVisits,
          maintenanceVisits.agreedPriceCents,
        );
        await m.addColumn(collections, collections.planId);
      }
      if (from < 4) {
        await m.addColumn(partners, partners.workspaceId);
        await m.addColumn(clients, clients.workspaceId);
        await m.addColumn(clientLocations, clientLocations.workspaceId);
        await m.addColumn(projects, projects.workspaceId);

        // Recreación segura de collections aplicando el CHECK constraint de exclusividad de contexto
        await customStatement('PRAGMA foreign_keys = OFF;');
        await customStatement('''
          CREATE TABLE collections_temp (
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
            deleted_at INTEGER,
            CHECK (((project_id IS NOT NULL) + (visit_id IS NOT NULL) + (plan_id IS NOT NULL)) = 1),
            CHECK (amount_cents > 0)
          );
        ''');
        await customStatement('''
          INSERT INTO collections_temp (
            id, workspace_id, client_id, project_id, visit_id, plan_id,
            amount_cents, date, received_by_partner_id, payment_method,
            reference, notes, created_at, updated_at, created_by, updated_by,
            version, deleted_at
          )
          SELECT
            id, workspace_id, client_id, project_id, visit_id, plan_id,
            amount_cents, date, received_by_partner_id, payment_method,
            reference, notes, created_at, updated_at, created_by, updated_by,
            version, deleted_at
          FROM collections;
        ''');
        await customStatement('DROP TABLE collections;');
        await customStatement(
          'ALTER TABLE collections_temp RENAME TO collections;',
        );
        await customStatement('PRAGMA foreign_keys = ON;');
      }
      if (from < 5) {
        final legacyRows = await customSelect('''
          SELECT id, workspace_id, entity_table, entity_id, operation,
                 payload_json, queued_at, attempts, last_error
          FROM sync_queue
          ORDER BY id ASC
        ''').get();

        await customStatement(
          'ALTER TABLE sync_queue RENAME TO sync_queue_legacy',
        );
        await m.createTable(syncQueue);

        const uuid = Uuid();
        for (final row in legacyRows) {
          final queuedAt = DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('queued_at'),
          );
          await into(syncQueue).insert(
            SyncQueueCompanion.insert(
              id: Value(row.read<int>('id')),
              workspaceId: Value(row.read<String>('workspace_id')),
              operationId: uuid.v4(),
              entityTable: row.read<String>('entity_table'),
              entityId: row.read<String>('entity_id'),
              operation: row.read<String>('operation'),
              baseVersion: const Value(1),
              payloadJson: row.read<String>('payload_json'),
              queuedAt: Value(queuedAt),
              attempts: Value(row.read<int>('attempts')),
              nextAttemptAt: Value(queuedAt),
              lastError: Value(row.read<String?>('last_error')),
              status: const Value('PENDING'),
            ),
          );
        }

        await customStatement('DROP TABLE sync_queue_legacy');
        await customStatement(
          'CREATE INDEX sync_queue_status_idx ON sync_queue(status, next_attempt_at)',
        );
      }
      if (from < 6) {
        await m.createTable(syncInbox);
      }
    },
  );
}
