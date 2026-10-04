import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/inventory_item.dart' as model;
import '../models/stock_movement.dart' as model;

class InventoryRepository {
  final AppDatabase _db;

  InventoryRepository(this._db);

  // ==================== INVENTORY ITEMS ====================

  Stream<List<model.InventoryItem>> watchActiveItems() {
    return (_db.select(_db.inventoryItems)
          ..where((tbl) => tbl.deletedAt.isNull() & tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch()
        .map((rows) => rows.map(_mapItemRowToModel).toList());
  }

  Stream<List<model.InventoryItem>> watchAllItems() {
    return (_db.select(_db.inventoryItems)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch()
        .map((rows) => rows.map(_mapItemRowToModel).toList());
  }

  Future<model.InventoryItem?> getItem(String id) async {
    final row =
        await (_db.select(_db.inventoryItems)
              ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
            .getSingleOrNull();
    return row != null ? _mapItemRowToModel(row) : null;
  }

  Future<void> createItem(model.InventoryItem item) async {
    await _db
        .into(_db.inventoryItems)
        .insert(
          InventoryItemsCompanion(
            id: Value(item.id),
            workspaceId: Value(item.workspaceId),
            sku: Value(item.sku),
            name: Value(item.name),
            category: Value(item.category),
            unit: Value(item.unit),
            minStockAlert: Value(item.minStockAlert),
            defaultCostCents: Value(item.defaultCostCents),
            isActive: Value(item.isActive),
            notes: Value(item.notes),
            createdAt: Value(item.createdAt),
            updatedAt: Value(item.updatedAt),
            version: Value(item.version),
          ),
        );
  }

  Future<void> updateItem(model.InventoryItem item) async {
    final now = DateTime.now();
    await (_db.update(
      _db.inventoryItems,
    )..where((tbl) => tbl.id.equals(item.id))).write(
      InventoryItemsCompanion(
        sku: Value(item.sku),
        name: Value(item.name),
        category: Value(item.category),
        unit: Value(item.unit),
        minStockAlert: Value(item.minStockAlert),
        defaultCostCents: Value(item.defaultCostCents),
        isActive: Value(item.isActive),
        notes: Value(item.notes),
        updatedAt: Value(now),
        version: Value(item.version + 1),
      ),
    );
  }

  Future<void> deleteItem(String id) async {
    final now = DateTime.now();
    await (_db.update(
      _db.inventoryItems,
    )..where((tbl) => tbl.id.equals(id))).write(
      InventoryItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // ==================== STOCK CALCULATIONS ====================

  /// Calculates stock strictly as SUM(quantity) of all non-deleted movements
  Future<double> getItemStock(String itemId) async {
    final rows =
        await (_db.select(_db.stockMovements)..where(
              (tbl) => tbl.itemId.equals(itemId) & tbl.deletedAt.isNull(),
            ))
            .get();

    double total = 0.0;
    for (final r in rows) {
      total += r.quantity;
    }
    return total;
  }

  /// Reactively watches stock level for a single item
  Stream<double> watchItemStock(String itemId) {
    return (_db.select(_db.stockMovements)
          ..where((tbl) => tbl.itemId.equals(itemId) & tbl.deletedAt.isNull()))
        .watch()
        .map((rows) {
          double total = 0.0;
          for (final r in rows) {
            total += r.quantity;
          }
          return total;
        });
  }

  // ==================== MOVEMENTS & CONSUMPTIONS ====================

  Stream<List<model.StockMovement>> watchItemMovements(String itemId) {
    return (_db.select(_db.stockMovements)
          ..where((tbl) => tbl.itemId.equals(itemId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]))
        .watch()
        .map((rows) => rows.map(_mapMovementRowToModel).toList());
  }

  Stream<List<model.StockMovement>> watchProjectMovements(String projectId) {
    return (_db.select(_db.stockMovements)
          ..where(
            (tbl) => tbl.projectId.equals(projectId) & tbl.deletedAt.isNull(),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]))
        .watch()
        .map((rows) => rows.map(_mapMovementRowToModel).toList());
  }

  Stream<List<model.StockMovement>> watchVisitMovements(String visitId) {
    return (_db.select(_db.stockMovements)
          ..where((tbl) => tbl.visitId.equals(visitId) & tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]))
        .watch()
        .map((rows) => rows.map(_mapMovementRowToModel).toList());
  }

  /// Records a movement in the inventory ledger.
  /// Enforces:
  /// 1. Negative stock rejection (unless explicitly overridden).
  /// 2. XOR integrity between Project and MaintenanceVisit.
  /// 3. Infallible cost snapshot preservation.
  Future<void> recordMovement(
    model.StockMovement movement, {
    bool allowNegativeStock = false,
  }) async {
    if (movement.projectId != null && movement.visitId != null) {
      throw ArgumentError(
        'Integridad violada: Un movimiento no puede asociarse simultáneamente a Obra y Visita.',
      );
    }

    // Check negative stock rejection for outflows
    if (movement.isOutflow && !allowNegativeStock) {
      final currentStock = await getItemStock(movement.itemId);
      final newStock =
          currentStock + movement.quantity; // movement.quantity is negative
      if (newStock < -0.0001) {
        throw StateError(
          'Operación rechazada: Stock insuficiente para el item. Stock actual: $currentStock, solicitado: ${movement.quantityAbs}',
        );
      }
    }

    await _db
        .into(_db.stockMovements)
        .insert(
          StockMovementsCompanion(
            id: Value(movement.id),
            workspaceId: Value(movement.workspaceId),
            itemId: Value(movement.itemId),
            movementType: Value(movement.movementType),
            quantity: Value(movement.quantity),
            unitCostCents: Value(movement.unitCostCents),
            totalCostCents: Value(movement.totalCostCents),
            projectId: Value(movement.projectId),
            visitId: Value(movement.visitId),
            purchaseId: Value(movement.purchaseId),
            date: Value(movement.date),
            notes: Value(movement.notes),
            createdAt: Value(movement.createdAt),
            updatedAt: Value(movement.updatedAt),
            version: Value(movement.version),
          ),
        );
  }

  /// Helper to record material consumption for Obra or Visit
  Future<void> recordConsumption({
    required String itemId,
    required double quantity,
    required int unitCostCents,
    String? projectId,
    String? visitId,
    DateTime? date,
    String? notes,
    bool allowNegativeStock = false,
  }) async {
    final movement = model.StockMovement.create(
      itemId: itemId,
      movementType: 'consumption',
      quantity: quantity,
      unitCostCents: unitCostCents,
      projectId: projectId,
      visitId: visitId,
      date: date,
      notes: notes,
    );
    await recordMovement(movement, allowNegativeStock: allowNegativeStock);
  }

  Future<void> deleteMovement(String movementId) async {
    final now = DateTime.now();
    await (_db.update(
      _db.stockMovements,
    )..where((tbl) => tbl.id.equals(movementId))).write(
      StockMovementsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // ==================== MATERIAL COST DERIVATIONS ====================

  /// Obra material cost: SUM(totalCostCents) of consumptions associated to the project
  Stream<int> watchProjectMaterialCostCents(String projectId) {
    return (_db.select(_db.stockMovements)..where(
          (tbl) =>
              tbl.projectId.equals(projectId) &
              tbl.deletedAt.isNull() &
              tbl.movementType.equals('consumption'),
        ))
        .watch()
        .map((rows) {
          int sum = 0;
          for (final r in rows) {
            sum += r.totalCostCents;
          }
          return sum;
        });
  }

  /// Maintenance visit material cost: SUM(totalCostCents) of consumptions associated to the visit
  Stream<int> watchVisitMaterialCostCents(String visitId) {
    return (_db.select(_db.stockMovements)..where(
          (tbl) =>
              tbl.visitId.equals(visitId) &
              tbl.deletedAt.isNull() &
              tbl.movementType.equals('consumption'),
        ))
        .watch()
        .map((rows) {
          int sum = 0;
          for (final r in rows) {
            sum += r.totalCostCents;
          }
          return sum;
        });
  }

  // ==================== MAPPERS ====================

  model.InventoryItem _mapItemRowToModel(InventoryItem row) {
    return model.InventoryItem(
      id: row.id,
      workspaceId: row.workspaceId,
      sku: row.sku,
      name: row.name,
      category: row.category,
      unit: row.unit,
      minStockAlert: row.minStockAlert,
      defaultCostCents: row.defaultCostCents,
      isActive: row.isActive,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      version: row.version,
      deletedAt: row.deletedAt,
    );
  }

  model.StockMovement _mapMovementRowToModel(StockMovement row) {
    return model.StockMovement(
      id: row.id,
      workspaceId: row.workspaceId,
      itemId: row.itemId,
      movementType: row.movementType,
      quantity: row.quantity,
      unitCostCents: row.unitCostCents,
      totalCostCents: row.totalCostCents,
      projectId: row.projectId,
      visitId: row.visitId,
      purchaseId: row.purchaseId,
      date: row.date,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      version: row.version,
      deletedAt: row.deletedAt,
    );
  }
}
