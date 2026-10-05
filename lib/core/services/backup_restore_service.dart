import 'dart:convert';
import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../database/data_migration_service.dart';

class BackupRestoreResult {
  final bool success;
  final int totalEntitiesRestored;
  final String? errorMessage;
  final int backupFormatVersion;

  const BackupRestoreResult({
    required this.success,
    this.totalEntitiesRestored = 0,
    this.errorMessage,
    this.backupFormatVersion = 2,
  });

  factory BackupRestoreResult.success({
    required int totalEntitiesRestored,
    int backupFormatVersion = 2,
  }) {
    return BackupRestoreResult(
      success: true,
      totalEntitiesRestored: totalEntitiesRestored,
      backupFormatVersion: backupFormatVersion,
    );
  }

  factory BackupRestoreResult.failure(String message, {int version = 2}) {
    return BackupRestoreResult(
      success: false,
      errorMessage: message,
      backupFormatVersion: version,
    );
  }
}

class BackupRestoreService {
  final AppDatabase db;
  static const int currentBackupFormatVersion = 2;
  static const int currentSchemaVersion = 4;
  static const String appVersion = '1.0.0+1';

  BackupRestoreService(this.db);

  /// Genera un respaldo JSON completo con todos los datos V2 y metadatos
  Future<String> exportBackupJson({
    String workspaceId = AppConstants.defaultWorkspaceId,
  }) async {
    // 1. Consultar todas las entidades (incluyendo soft-deletes para trazabilidad)
    final users = await db.select(db.users).get();
    final partners = await db.select(db.partners).get();
    final workers = await db.select(db.workers).get();
    final clients = await db.select(db.clients).get();
    final clientLocations = await db.select(db.clientLocations).get();
    final projects = await db.select(db.projects).get();
    final maintenancePlans = await db.select(db.maintenancePlans).get();
    final maintenanceVisits = await db.select(db.maintenanceVisits).get();
    final suppliers = await db.select(db.suppliers).get();
    final inventoryItems = await db.select(db.inventoryItems).get();
    final purchases = await db.select(db.purchases).get();
    final purchaseItems = await db.select(db.purchaseItems).get();
    final stockMovements = await db.select(db.stockMovements).get();
    final tools = await db.select(db.tools).get();
    final toolAssignments = await db.select(db.toolAssignments).get();
    final workLogs = await db.select(db.workLogs).get();
    final laborPayments = await db.select(db.laborPayments).get();
    final expenses = await db.select(db.expenses).get();
    final capitalMovements = await db.select(db.capitalMovements).get();
    final collections = await db.select(db.collections).get();
    final attachments = await db.select(db.attachments).get();
    final appMetadata = await db.select(db.appMetadata).get();

    // 2. Estructurar el diccionario de datos
    // Nota arquitectónica: sync_queue es intencionalmente omitida por tratarse de infraestructura efímera
    final data = <String, dynamic>{
      'users': users.map((e) => e.toJson()).toList(),
      'partners': partners.map((e) => e.toJson()).toList(),
      'workers': workers.map((e) => e.toJson()).toList(),
      'clients': clients.map((e) => e.toJson()).toList(),
      'clientLocations': clientLocations.map((e) => e.toJson()).toList(),
      'projects': projects.map((e) => e.toJson()).toList(),
      'maintenancePlans': maintenancePlans.map((e) => e.toJson()).toList(),
      'maintenanceVisits': maintenanceVisits.map((e) => e.toJson()).toList(),
      'suppliers': suppliers.map((e) => e.toJson()).toList(),
      'inventoryItems': inventoryItems.map((e) => e.toJson()).toList(),
      'purchases': purchases.map((e) => e.toJson()).toList(),
      'purchaseItems': purchaseItems.map((e) => e.toJson()).toList(),
      'stockMovements': stockMovements.map((e) => e.toJson()).toList(),
      'tools': tools.map((e) => e.toJson()).toList(),
      'toolAssignments': toolAssignments.map((e) => e.toJson()).toList(),
      'workLogs': workLogs.map((e) => e.toJson()).toList(),
      'laborPayments': laborPayments.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'capitalMovements': capitalMovements.map((e) => e.toJson()).toList(),
      'collections': collections.map((e) => e.toJson()).toList(),
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'appMetadata': appMetadata.map((e) => e.toJson()).toList(),
    };

    final root = <String, dynamic>{
      'backupFormatVersion': currentBackupFormatVersion,
      'schemaVersion': currentSchemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'appVersion': appVersion,
      'workspaceId': workspaceId,
      'data': data,
    };

    return const JsonEncoder.withIndent('  ').convert(root);
  }

  /// Restaura una copia de seguridad validando versión, FKs y atomicidad
  Future<BackupRestoreResult> restoreBackupJson(String jsonString) async {
    final trimmed = jsonString.trim();
    if (trimmed.isEmpty) {
      return BackupRestoreResult.failure(
        'El contenido del respaldo está vacío.',
      );
    }

    Map<String, dynamic> root;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return BackupRestoreResult.failure(
          'El archivo de respaldo no tiene formato de objeto JSON válido.',
        );
      }
      root = decoded;
    } catch (e) {
      return BackupRestoreResult.failure('Error de sintaxis JSON: $e');
    }

    // 1. Compatibilidad con versión 1 (modelo antiguo de JSON con 'socios' o 'version == 1')
    final isV1 =
        (root['version'] == 1 ||
            root['backupFormatVersion'] == 1 ||
            root.containsKey('socios') ||
            root.containsKey('mantenimientos')) &&
        !root.containsKey('backupFormatVersion');

    if (isV1) {
      return await _restoreV1Backup(trimmed);
    }

    // 2. Validación de metadatos V2
    final backupVersion = root['backupFormatVersion'];
    if (backupVersion == null || backupVersion is! int) {
      return BackupRestoreResult.failure(
        'Falta metadata requerida: backupFormatVersion.',
      );
    }

    if (backupVersion > currentBackupFormatVersion) {
      return BackupRestoreResult.failure(
        'Versión de respaldo incompatible: $backupVersion (Máxima soportada: $currentBackupFormatVersion). Actualice la aplicación.',
        version: backupVersion,
      );
    }

    final rawData = root['data'];
    if (rawData == null || rawData is! Map<String, dynamic>) {
      return BackupRestoreResult.failure(
        'Estructura corrupta: falta el nodo "data".',
      );
    }

    // 3. Restauración Transaccional respetando orden de dependencias FK
    try {
      int restoredCount = 0;

      await db.transaction(() async {
        // A. Purgar en orden inverso a las llaves foráneas (hijos primero)
        await db.delete(db.attachments).go();
        await db.delete(db.collections).go();
        await db.delete(db.capitalMovements).go();
        await db.delete(db.expenses).go();
        await db.delete(db.laborPayments).go();
        await db.delete(db.workLogs).go();
        await db.delete(db.toolAssignments).go();
        await db.delete(db.stockMovements).go();
        await db.delete(db.purchaseItems).go();
        await db.delete(db.purchases).go();
        await db.delete(db.tools).go();
        await db.delete(db.inventoryItems).go();
        await db.delete(db.suppliers).go();
        await db.delete(db.maintenanceVisits).go();
        await db.delete(db.maintenancePlans).go();
        await db.delete(db.projects).go();
        await db.delete(db.clientLocations).go();
        await db.delete(db.clients).go();
        await db.delete(db.workers).go();
        await db.delete(db.partners).go();
        await db.delete(db.users).go();
        await db.delete(db.appMetadata).go();

        // B. Insertar en orden estricto de dependencias padre -> hijo
        if (rawData['users'] is List) {
          for (final item in rawData['users'] as List) {
            await db
                .into(db.users)
                .insert(User.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['partners'] is List) {
          for (final item in rawData['partners'] as List) {
            await db
                .into(db.partners)
                .insert(Partner.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['workers'] is List) {
          for (final item in rawData['workers'] as List) {
            await db
                .into(db.workers)
                .insert(Worker.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['clients'] is List) {
          for (final item in rawData['clients'] as List) {
            await db
                .into(db.clients)
                .insert(Client.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['clientLocations'] is List) {
          for (final item in rawData['clientLocations'] as List) {
            await db
                .into(db.clientLocations)
                .insert(ClientLocation.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['projects'] is List) {
          for (final item in rawData['projects'] as List) {
            await db
                .into(db.projects)
                .insert(Project.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['maintenancePlans'] is List) {
          for (final item in rawData['maintenancePlans'] as List) {
            await db
                .into(db.maintenancePlans)
                .insert(MaintenancePlan.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['maintenanceVisits'] is List) {
          for (final item in rawData['maintenanceVisits'] as List) {
            await db
                .into(db.maintenanceVisits)
                .insert(
                  MaintenanceVisit.fromJson(item as Map<String, dynamic>),
                );
            restoredCount++;
          }
        }

        if (rawData['suppliers'] is List) {
          for (final item in rawData['suppliers'] as List) {
            await db
                .into(db.suppliers)
                .insert(Supplier.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['inventoryItems'] is List) {
          for (final item in rawData['inventoryItems'] as List) {
            await db
                .into(db.inventoryItems)
                .insert(InventoryItem.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['purchases'] is List) {
          for (final item in rawData['purchases'] as List) {
            await db
                .into(db.purchases)
                .insert(Purchase.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['purchaseItems'] is List) {
          for (final item in rawData['purchaseItems'] as List) {
            await db
                .into(db.purchaseItems)
                .insert(PurchaseItem.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['stockMovements'] is List) {
          for (final item in rawData['stockMovements'] as List) {
            await db
                .into(db.stockMovements)
                .insert(StockMovement.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['tools'] is List) {
          for (final item in rawData['tools'] as List) {
            await db
                .into(db.tools)
                .insert(Tool.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['toolAssignments'] is List) {
          for (final item in rawData['toolAssignments'] as List) {
            await db
                .into(db.toolAssignments)
                .insert(ToolAssignment.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['workLogs'] is List) {
          for (final item in rawData['workLogs'] as List) {
            await db
                .into(db.workLogs)
                .insert(WorkLog.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['laborPayments'] is List) {
          for (final item in rawData['laborPayments'] as List) {
            await db
                .into(db.laborPayments)
                .insert(LaborPayment.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['expenses'] is List) {
          for (final item in rawData['expenses'] as List) {
            await db
                .into(db.expenses)
                .insert(Expense.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['capitalMovements'] is List) {
          for (final item in rawData['capitalMovements'] as List) {
            await db
                .into(db.capitalMovements)
                .insert(CapitalMovement.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['collections'] is List) {
          for (final item in rawData['collections'] as List) {
            await db
                .into(db.collections)
                .insert(Collection.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['attachments'] is List) {
          for (final item in rawData['attachments'] as List) {
            await db
                .into(db.attachments)
                .insert(Attachment.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }

        if (rawData['appMetadata'] is List) {
          for (final item in rawData['appMetadata'] as List) {
            await db
                .into(db.appMetadata)
                .insert(AppMetadataData.fromJson(item as Map<String, dynamic>));
            restoredCount++;
          }
        }
      });

      return BackupRestoreResult.success(totalEntitiesRestored: restoredCount);
    } catch (e) {
      return BackupRestoreResult.failure(
        'Error en transacción de restauración: $e',
      );
    }
  }

  /// Restaura un backup en formato V1 mediante DataMigrationService
  Future<BackupRestoreResult> _restoreV1Backup(String jsonStr) async {
    try {
      final migrationService = DataMigrationService(db);
      await db.transaction(() async {
        await db.delete(db.attachments).go();
        await db.delete(db.collections).go();
        await db.delete(db.capitalMovements).go();
        await db.delete(db.expenses).go();
        await db.delete(db.laborPayments).go();
        await db.delete(db.workLogs).go();
        await db.delete(db.toolAssignments).go();
        await db.delete(db.stockMovements).go();
        await db.delete(db.purchaseItems).go();
        await db.delete(db.purchases).go();
        await db.delete(db.tools).go();
        await db.delete(db.inventoryItems).go();
        await db.delete(db.suppliers).go();
        await db.delete(db.maintenanceVisits).go();
        await db.delete(db.maintenancePlans).go();
        await db.delete(db.projects).go();
        await db.delete(db.clientLocations).go();
        await db.delete(db.clients).go();
        await db.delete(db.partners).go();

        await migrationService.executeMigrationFromJson(jsonStr);
      });

      final clientsCount = await db.select(db.clients).get();
      final projectsCount = await db.select(db.projects).get();
      final plansCount = await db.select(db.maintenancePlans).get();

      return BackupRestoreResult.success(
        totalEntitiesRestored:
            clientsCount.length + projectsCount.length + plansCount.length,
        backupFormatVersion: 1,
      );
    } catch (e) {
      return BackupRestoreResult.failure(
        'Error al restaurar respaldo formato V1: $e',
        version: 1,
      );
    }
  }
}
