import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/services/backup_restore_service.dart';

void main() {
  late AppDatabase db;
  late BackupRestoreService backupService;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    backupService = BackupRestoreService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    '1. Export vacío: Genera estructura válida con listas vacías y metadatos',
    () async {
      final jsonStr = await backupService.exportBackupJson();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['backupFormatVersion'], equals(2));
      expect(map['schemaVersion'], equals(4));
      expect(map['workspaceId'], equals('default'));
      expect(map['createdAt'], isNotNull);

      final data = map['data'] as Map<String, dynamic>;
      expect(data['users'], isEmpty);
      expect(data['projects'], isEmpty);
      expect(data['clients'], isEmpty);
      expect(data['suppliers'], isEmpty);
    },
  );

  test(
    '2. Export completo y 3. Metadata: Exporta todas las entidades con su metadata',
    () async {
      final now = DateTime(2026, 10, 4, 15, 30);
      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(
              id: 'cli-1',
              name: 'Cliente Residencial',
              phone: const Value('999000111'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'proj-1',
              name: 'Paisajismo Jardín Central',
              clientId: const Value('cli-1'),
              budgetAmountCents: const Value(500000), // S/ 5,000.00
              startDate: now,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final jsonStr = await backupService.exportBackupJson();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['backupFormatVersion'], equals(2));
      expect(map['appVersion'], equals('1.0.0+1'));

      final data = map['data'] as Map<String, dynamic>;
      expect((data['clients'] as List).length, equals(1));
      expect((data['projects'] as List).length, equals(1));
    },
  );

  test(
    '4. Round-trip completo: Base original -> Export -> Limpieza -> Restore -> Base idéntica',
    () async {
      final now = DateTime(2026, 10, 4, 12, 0);

      // 1. Poblamos una base completa con grafo de dependencias
      await db
          .into(db.partners)
          .insert(
            PartnersCompanion.insert(
              id: 'partner-1',
              name: 'Socio Fundador',
              equityPercentage: const Value(50.0),
            ),
          );

      await db
          .into(db.workers)
          .insert(
            WorkersCompanion.insert(
              id: 'worker-1',
              name: 'Carlos Capataz',
              defaultRateCents: const Value(8000),
            ),
          );

      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(
              id: 'client-1',
              name: 'Inmobiliaria Los Pinos',
            ),
          );

      await db
          .into(db.clientLocations)
          .insert(
            ClientLocationsCompanion.insert(
              id: 'loc-1',
              clientId: 'client-1',
              name: const Value('Sede Miraflores'),
              address: 'Av. Larco 123',
            ),
          );

      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'proj-1',
              name: 'Jardines de Miraflores',
              clientId: const Value('client-1'),
              locationId: const Value('loc-1'),
              budgetAmountCents: const Value(1200000), // S/ 12,000.00
              startDate: now,
            ),
          );

      await db
          .into(db.maintenancePlans)
          .insert(
            MaintenancePlansCompanion.insert(
              id: 'plan-1',
              clientId: 'client-1',
              title: 'Mantenimiento Quincenal',
              nextDate: Value(now.add(const Duration(days: 15))),
            ),
          );

      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'visit-1',
              planId: 'plan-1',
              scheduledDate: now.add(const Duration(days: 15)),
            ),
          );

      await db
          .into(db.suppliers)
          .insert(
            SuppliersCompanion.insert(
              id: 'supp-1',
              name: 'Vivero Central S.A.C.',
              taxId: const Value('20555666777'),
            ),
          );

      await db
          .into(db.inventoryItems)
          .insert(
            InventoryItemsCompanion.insert(
              id: 'item-1',
              name: 'Abono Orgánico Compost',
              unit: const Value('saco'),
              defaultCostCents: const Value(3500),
            ),
          );

      await db
          .into(db.purchases)
          .insert(
            PurchasesCompanion.insert(
              id: 'purch-1',
              supplierId: const Value('supp-1'),
              date: now,
              totalAmountCents: 7000,
            ),
          );

      await db
          .into(db.purchaseItems)
          .insert(
            PurchaseItemsCompanion.insert(
              id: 'pitem-1',
              purchaseId: 'purch-1',
              itemId: 'item-1',
              quantity: 2.0,
              unitCostCents: 3500,
              totalCostCents: 7000,
            ),
          );

      await db
          .into(db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: 'mov-1',
              itemId: 'item-1',
              movementType: const Value('purchase_in'),
              quantity: 2.0,
              unitCostCents: const Value(3500),
              totalCostCents: const Value(7000),
              date: Value(now),
            ),
          );

      await db
          .into(db.tools)
          .insert(
            ToolsCompanion.insert(
              id: 'tool-1',
              name: 'Cortacésped Husqvarna',
              code: const Value('COR-01'),
            ),
          );

      await db
          .into(db.toolAssignments)
          .insert(
            ToolAssignmentsCompanion.insert(
              id: 'assign-1',
              toolId: 'tool-1',
              workerId: const Value('worker-1'),
              assignedAt: Value(now),
            ),
          );

      await db
          .into(db.workLogs)
          .insert(
            WorkLogsCompanion.insert(
              id: 'wlog-1',
              workerId: 'worker-1',
              projectId: const Value('proj-1'),
              date: now,
              paymentType: const Value('daily'),
              quantity: const Value(1.0),
              rateCents: const Value(8000),
              amountCents: const Value(8000),
            ),
          );

      await db
          .into(db.laborPayments)
          .insert(
            LaborPaymentsCompanion.insert(
              id: 'lpay-1',
              workerId: 'worker-1',
              paymentDate: now,
              amountCents: 8000,
              paymentMethod: const Value('cash'),
            ),
          );

      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-1',
              projectId: const Value('proj-1'),
              amountCents: const Value(4500),
              date: now,
              concept: 'Transporte y flete',
              paidByPartnerId: 'partner-1',
            ),
          );

      await db
          .into(db.capitalMovements)
          .insert(
            CapitalMovementsCompanion.insert(
              id: 'cap-1',
              partnerId: 'partner-1',
              type: const Value('contribution'),
              amountCents: const Value(500000),
              date: now,
            ),
          );

      await db
          .into(db.collections)
          .insert(
            CollectionsCompanion.insert(
              id: 'col-1',
              projectId: const Value('proj-1'),
              clientId: 'client-1',
              date: now,
              amountCents: const Value(600000),
              paymentMethod: const Value('transfer'),
            ),
          );

      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-1',
              parentType: 'project',
              parentId: 'proj-1',
              fileName: 'Plano General.pdf',
              provider: const Value('local'),
              localFilePath: const Value('C:\\docs\\plano.pdf'),
              fileSizeBytes: const Value(1024),
            ),
          );

      await db
          .into(db.appMetadata)
          .insert(
            AppMetadataCompanion.insert(
              key: 'company_settings',
              value: '{"companyName":"Decolumax RoundTrip"}',
              updatedAt: Value(now),
            ),
          );

      // 2. Exportar a JSON
      final jsonBackup = await backupService.exportBackupJson();

      // 3. Crear una base de datos limpia e independiente
      final cleanDb = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      final cleanBackupService = BackupRestoreService(cleanDb);

      // 4. Restaurar en la base limpia
      final result = await cleanBackupService.restoreBackupJson(jsonBackup);
      expect(result.success, isTrue);
      expect(result.totalEntitiesRestored, greaterThanOrEqualTo(20));

      // 5. Comparar datos funcionales recuperados
      final restoredClients = await cleanDb.select(cleanDb.clients).get();
      final restoredProjects = await cleanDb.select(cleanDb.projects).get();
      final restoredTools = await cleanDb.select(cleanDb.tools).get();
      final restoredCollections = await cleanDb
          .select(cleanDb.collections)
          .get();
      final restoredSettings = await (cleanDb.select(
        cleanDb.appMetadata,
      )..where((t) => t.key.equals('company_settings'))).getSingle();

      expect(restoredClients.first.name, equals('Inmobiliaria Los Pinos'));
      expect(restoredProjects.first.name, equals('Jardines de Miraflores'));
      expect(restoredProjects.first.budgetAmountCents, equals(1200000));
      expect(restoredTools.first.name, equals('Cortacésped Husqvarna'));
      expect(restoredCollections.first.amountCents, equals(600000));
      expect(restoredSettings.value, contains('Decolumax RoundTrip'));

      await cleanDb.close();
    },
  );

  test(
    '5. Integridad de Foreign Keys: Restaura respetando relaciones referenciales',
    () async {
      await db
          .into(db.clients)
          .insert(ClientsCompanion.insert(id: 'c1', name: 'Cliente Principal'));
      await db
          .into(db.clientLocations)
          .insert(
            ClientLocationsCompanion.insert(
              id: 'loc1',
              clientId: 'c1',
              address: 'Calle 1',
            ),
          );
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'p1',
              name: 'Obra 1',
              clientId: const Value('c1'),
              locationId: const Value('loc1'),
              startDate: DateTime.now(),
            ),
          );

      final backup = await backupService.exportBackupJson();
      final result = await backupService.restoreBackupJson(backup);

      expect(result.success, isTrue);

      // Verificar que la relación FK entre proyecto y location existe y no falló en SQLite
      final p = await (db.select(
        db.projects,
      )..where((t) => t.id.equals('p1'))).getSingle();
      expect(p.locationId, equals('loc1'));
    },
  );

  test(
    '6. Centavos exactos: Preserva precisión entera sin redondeos',
    () async {
      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(id: 'c-cents', name: 'Cliente Cents'),
          );
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'p-cents',
              name: 'Obra Cents',
              clientId: const Value('c-cents'),
              budgetAmountCents: const Value(123456789), // S/ 1,234,567.89
              startDate: DateTime.now(),
            ),
          );

      final backup = await backupService.exportBackupJson();
      await backupService.restoreBackupJson(backup);

      final p = await (db.select(
        db.projects,
      )..where((t) => t.id.equals('p-cents'))).getSingle();
      expect(p.budgetAmountCents, equals(123456789));
    },
  );

  test(
    '7. Fechas: Serializa y deserializa DateTime ISO 8601 conservando exactitud',
    () async {
      final specificDate = DateTime(2026, 8, 15, 14, 45);
      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(
              id: 'c-date',
              name: 'Cliente Fecha',
              createdAt: Value(specificDate),
              updatedAt: Value(specificDate),
            ),
          );

      final backup = await backupService.exportBackupJson();
      await backupService.restoreBackupJson(backup);

      final c = await (db.select(
        db.clients,
      )..where((t) => t.id.equals('c-date'))).getSingle();
      expect(c.createdAt, equals(specificDate));
    },
  );

  test(
    '8. Soft deletes: Registros con deletedAt se conservan con su fecha de eliminación',
    () async {
      final deletedTime = DateTime(2026, 9, 1, 10, 0);
      await db
          .into(db.workers)
          .insert(
            WorkersCompanion.insert(
              id: 'w-del',
              name: 'Trabajador Retirado',
              deletedAt: Value(deletedTime),
            ),
          );

      final backup = await backupService.exportBackupJson();
      await backupService.restoreBackupJson(backup);

      final w = await (db.select(
        db.workers,
      )..where((t) => t.id.equals('w-del'))).getSingle();
      expect(w.deletedAt, equals(deletedTime));
    },
  );

  test(
    '9. Attachments metadata: Metadatos y rutas se preservan sin bytes BLOB',
    () async {
      await db
          .into(db.clients)
          .insert(ClientsCompanion.insert(id: 'c-att', name: 'Cliente Att'));
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'p-att',
              name: 'Obra Att',
              clientId: const Value('c-att'),
              startDate: DateTime.now(),
            ),
          );
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'att-meta',
              parentType: 'project',
              parentId: 'p-att',
              fileName: 'Memoria_Descriptiva.pdf',
              provider: const Value('local'),
              localFilePath: const Value('C:\\archivos\\memoria.pdf'),
              fileSizeBytes: const Value(512000),
              mimeType: const Value('application/pdf'),
            ),
          );

      final backup = await backupService.exportBackupJson();
      expect(backup, contains('Memoria_Descriptiva.pdf'));
      expect(backup, contains('memoria.pdf'));

      await backupService.restoreBackupJson(backup);

      final att = await (db.select(
        db.attachments,
      )..where((t) => t.id.equals('att-meta'))).getSingle();
      expect(att.fileName, equals('Memoria_Descriptiva.pdf'));
      expect(att.localFilePath, equals('C:\\archivos\\memoria.pdf'));
      expect(att.fileSizeBytes, equals(512000));
    },
  );

  test('10. JSON corrupto: No crashea y retorna fallo descriptivo', () async {
    const corruptJson = '{"backupFormatVersion": 2, "data": { INCOMPLETO...';
    final result = await backupService.restoreBackupJson(corruptJson);

    expect(result.success, isFalse);
    expect(result.errorMessage, contains('Error de sintaxis JSON'));
  });

  test(
    '11. Versión incompatible: Rechaza backups con backupFormatVersion futura',
    () async {
      final futureBackup = jsonEncode({
        'backupFormatVersion': 99,
        'schemaVersion': 99,
        'data': {},
      });

      final result = await backupService.restoreBackupJson(futureBackup);
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('incompatible'));
    },
  );

  test(
    '12. Rollback: En caso de error, la transacción revierte y la base actual permanece intacta',
    () async {
      // 1. Estado inicial valioso
      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(id: 'c-preserve', name: 'Cliente Intacto'),
          );

      // 2. Intentar restaurar un JSON con FK inválida intencional (project apuntando a client inexistente en el payload)
      final invalidFkBackup = jsonEncode({
        'backupFormatVersion': 2,
        'schemaVersion': 2,
        'data': {
          'projects': [
            {
              'id': 'p-bad',
              'name': 'Obra Mala',
              'client_id': 'cliente-fantasma-inexistente',
              'start_date': DateTime.now().toIso8601String(),
            },
          ],
        },
      });

      // 3. Restaurar falla
      final result = await backupService.restoreBackupJson(invalidFkBackup);
      expect(result.success, isFalse);

      // 4. Comprobar que 'Cliente Intacto' NO fue borrado
      final clients = await db.select(db.clients).get();
      expect(clients.length, equals(1));
      expect(clients.first.name, equals('Cliente Intacto'));
    },
  );

  test(
    '13. Backup V1: Restaura formato antiguo mediante DataMigrationService',
    () async {
      final v1Json = jsonEncode({
        'version': 1,
        'socios': [
          {'id': 's1', 'nombre': 'Socio Antiguo', 'participacion': 50.0},
        ],
        'clientes': [
          {'id': 'c1', 'nombre': 'Cliente Antiguo'},
        ],
        'obras': [
          {
            'id': 'o1',
            'nombre': 'Obra Antigua',
            'clienteId': 'c1',
            'presupuesto': 1000.0,
            'fechaInicio': DateTime.now().toIso8601String(),
          },
        ],
        'gastos': [],
        'mantenimientos': [],
      });

      final result = await backupService.restoreBackupJson(v1Json);
      expect(result.success, isTrue);
      expect(result.backupFormatVersion, equals(1));

      final clients = await db.select(db.clients).get();
      expect(clients.any((c) => c.name == 'Cliente Antiguo'), isTrue);
    },
  );

  test(
    '14. Restore repetido e idempotente: Restaurar el mismo backup dos veces consecutivas funciona limpiamente',
    () async {
      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(id: 'c-idem', name: 'Cliente Idempotente'),
          );

      final backup = await backupService.exportBackupJson();

      final res1 = await backupService.restoreBackupJson(backup);
      expect(res1.success, isTrue);

      final res2 = await backupService.restoreBackupJson(backup);
      expect(res2.success, isTrue);

      final clients = await db.select(db.clients).get();
      expect(clients.length, equals(1));
      expect(clients.first.name, equals('Cliente Idempotente'));
    },
  );

  test(
    '15. No restaurar sync_queue obsoleto: La cola de sincronización no se exporta ni restaura',
    () async {
      // Insertamos una tarea pendiente en sync_queue
      await db
          .into(db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              entityTable: 'project',
              entityId: 'p1',
              operation: 'insert',
              payloadJson: '{}',
            ),
          );

      final backup = await backupService.exportBackupJson();
      final map = jsonDecode(backup) as Map<String, dynamic>;
      final data = map['data'] as Map<String, dynamic>;

      expect(data.containsKey('syncQueue'), isFalse);
      expect(data.containsKey('sync_queue'), isFalse);
    },
  );
}
