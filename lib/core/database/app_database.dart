import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
    AppMetadata,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  AppDatabase.forTesting(DatabaseConnection super.connection);

  @override
  int get schemaVersion => 2;

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
    },
  );
}
