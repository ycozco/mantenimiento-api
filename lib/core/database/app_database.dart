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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  AppDatabase.forTesting(DatabaseConnection super.connection);

  @override
  int get schemaVersion => 1;

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
  );
}
