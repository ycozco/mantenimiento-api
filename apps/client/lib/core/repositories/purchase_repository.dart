import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/purchase.dart' as model;
import '../models/purchase_item.dart' as model;
import '../models/supplier.dart' as model;

class PurchaseItemDraft {
  final String itemId;
  final double quantity;
  final int unitCostCents;

  PurchaseItemDraft({
    required this.itemId,
    required this.quantity,
    required this.unitCostCents,
  }) {
    if (quantity <= 0) {
      throw ArgumentError('La cantidad debe ser mayor a 0');
    }
    if (unitCostCents < 0) {
      throw ArgumentError('El costo no puede ser negativo');
    }
  }

  int get totalCostCents => (quantity * unitCostCents).round();
}

class PurchaseRepository {
  final AppDatabase _db;

  PurchaseRepository(this._db);

  // ==================== SUPPLIERS ====================

  Stream<List<model.Supplier>> watchActiveSuppliers() {
    return (_db.select(_db.suppliers)
          ..where((tbl) => tbl.deletedAt.isNull() & tbl.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch()
        .map((rows) => rows.map(_mapSupplierRowToModel).toList());
  }

  Stream<List<model.Supplier>> watchAllSuppliers() {
    return (_db.select(_db.suppliers)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.name)]))
        .watch()
        .map((rows) => rows.map(_mapSupplierRowToModel).toList());
  }

  Future<model.Supplier?> getSupplier(String id) async {
    final row =
        await (_db.select(_db.suppliers)
              ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
            .getSingleOrNull();
    return row != null ? _mapSupplierRowToModel(row) : null;
  }

  Future<void> createSupplier(model.Supplier supplier) async {
    await _db
        .into(_db.suppliers)
        .insert(
          SuppliersCompanion(
            id: Value(supplier.id),
            workspaceId: Value(supplier.workspaceId),
            name: Value(supplier.name),
            contactName: Value(supplier.contactName),
            phone: Value(supplier.phone),
            email: Value(supplier.email),
            taxId: Value(supplier.taxId),
            address: Value(supplier.address),
            isActive: Value(supplier.isActive),
            notes: Value(supplier.notes),
            createdAt: Value(supplier.createdAt),
            updatedAt: Value(supplier.updatedAt),
            version: Value(supplier.version),
          ),
        );
  }

  Future<void> updateSupplier(model.Supplier supplier) async {
    final now = DateTime.now();
    await (_db.update(
      _db.suppliers,
    )..where((tbl) => tbl.id.equals(supplier.id))).write(
      SuppliersCompanion(
        name: Value(supplier.name),
        contactName: Value(supplier.contactName),
        phone: Value(supplier.phone),
        email: Value(supplier.email),
        taxId: Value(supplier.taxId),
        address: Value(supplier.address),
        isActive: Value(supplier.isActive),
        notes: Value(supplier.notes),
        updatedAt: Value(now),
        version: Value(supplier.version + 1),
      ),
    );
  }

  Future<void> deleteSupplier(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.suppliers)..where((tbl) => tbl.id.equals(id))).write(
      SuppliersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // ==================== PURCHASES & KARDEX ATOMICITY ====================

  Stream<List<model.Purchase>> watchPurchases() {
    final query = (_db.select(_db.purchases)
      ..where((tbl) => tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]));

    return query.watch().asyncMap((rows) async {
      final purchases = <model.Purchase>[];
      for (final r in rows) {
        String? supplierName;
        if (r.supplierId != null) {
          final sup = await (_db.select(
            _db.suppliers,
          )..where((tbl) => tbl.id.equals(r.supplierId!))).getSingleOrNull();
          supplierName = sup?.name;
        }

        String? partnerName;
        if (r.paidByPartnerId != null) {
          final part =
              await (_db.select(_db.partners)
                    ..where((tbl) => tbl.id.equals(r.paidByPartnerId!)))
                  .getSingleOrNull();
          partnerName = part?.name;
        }

        purchases.add(
          _mapPurchaseRowToModel(
            r,
            supplierName: supplierName,
            partnerName: partnerName,
          ),
        );
      }
      return purchases;
    });
  }

  Stream<List<model.PurchaseItem>> watchPurchaseItems(String purchaseId) {
    final query = (_db.select(_db.purchaseItems)
      ..where(
        (tbl) => tbl.purchaseId.equals(purchaseId) & tbl.deletedAt.isNull(),
      )
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]));

    return query.watch().asyncMap((rows) async {
      final items = <model.PurchaseItem>[];
      for (final r in rows) {
        final invItem = await (_db.select(
          _db.inventoryItems,
        )..where((tbl) => tbl.id.equals(r.itemId))).getSingleOrNull();

        items.add(
          model.PurchaseItem(
            id: r.id,
            workspaceId: r.workspaceId,
            purchaseId: r.purchaseId,
            itemId: r.itemId,
            quantity: r.quantity,
            unitCostCents: r.unitCostCents,
            totalCostCents: r.totalCostCents,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
            version: r.version,
            deletedAt: r.deletedAt,
            itemName: invItem?.name,
            itemUnit: invItem?.unit,
          ),
        );
      }
      return items;
    });
  }

  Future<model.Purchase?> getPurchase(String id) async {
    final row =
        await (_db.select(_db.purchases)
              ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) return null;

    String? supplierName;
    if (row.supplierId != null) {
      final sup = await (_db.select(
        _db.suppliers,
      )..where((tbl) => tbl.id.equals(row.supplierId!))).getSingleOrNull();
      supplierName = sup?.name;
    }

    String? partnerName;
    if (row.paidByPartnerId != null) {
      final part = await (_db.select(
        _db.partners,
      )..where((tbl) => tbl.id.equals(row.paidByPartnerId!))).getSingleOrNull();
      partnerName = part?.name;
    }

    return _mapPurchaseRowToModel(
      row,
      supplierName: supplierName,
      partnerName: partnerName,
    );
  }

  /// Atomically records a purchase, its line items, and the corresponding Kardex StockMovements.
  Future<String> recordPurchase({
    required model.Purchase purchase,
    required List<PurchaseItemDraft> items,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Una compra debe contener al menos un producto.');
    }

    int computedTotal = 0;
    for (final item in items) {
      computedTotal += item.totalCostCents;
    }

    return await _db.transaction(() async {
      // 1. Insert Purchase
      await _db
          .into(_db.purchases)
          .insert(
            PurchasesCompanion(
              id: Value(purchase.id),
              workspaceId: Value(purchase.workspaceId),
              supplierId: Value(purchase.supplierId),
              paidByPartnerId: Value(purchase.paidByPartnerId),
              totalAmountCents: Value(computedTotal),
              date: Value(purchase.date),
              documentType: Value(purchase.documentType),
              invoiceNumber: Value(purchase.invoiceNumber),
              notes: Value(purchase.notes),
              createdAt: Value(purchase.createdAt),
              updatedAt: Value(purchase.updatedAt),
              version: Value(purchase.version),
            ),
          );

      // 2. Insert Purchase Items & Stock Movements
      final now = DateTime.now();
      for (final draft in items) {
        final itemId = draft.itemId;
        final purchaseItemId = const Uuid().v4();

        await _db
            .into(_db.purchaseItems)
            .insert(
              PurchaseItemsCompanion(
                id: Value(purchaseItemId),
                workspaceId: Value(purchase.workspaceId),
                purchaseId: Value(purchase.id),
                itemId: Value(itemId),
                quantity: Value(draft.quantity),
                unitCostCents: Value(draft.unitCostCents),
                totalCostCents: Value(draft.totalCostCents),
                createdAt: Value(now),
                updatedAt: Value(now),
                version: const Value(1),
              ),
            );

        // Kardex ledger entry (Positive quantity for stock in)
        await _db
            .into(_db.stockMovements)
            .insert(
              StockMovementsCompanion(
                id: Value(const Uuid().v4()),
                workspaceId: Value(purchase.workspaceId),
                itemId: Value(itemId),
                movementType: const Value('purchase'),
                quantity: Value(draft.quantity),
                unitCostCents: Value(draft.unitCostCents),
                totalCostCents: Value(draft.totalCostCents),
                purchaseId: Value(purchase.id),
                date: Value(purchase.date),
                notes: Value(
                  'Entrada por compra ${purchase.invoiceNumber != null ? "#${purchase.invoiceNumber}" : purchase.documentType}',
                ),
                createdAt: Value(now),
                updatedAt: Value(now),
                version: const Value(1),
              ),
            );

        // Update defaultCostCents on InventoryItem to keep latest cost reference
        await (_db.update(
          _db.inventoryItems,
        )..where((tbl) => tbl.id.equals(itemId))).write(
          InventoryItemsCompanion(
            defaultCostCents: Value(draft.unitCostCents),
            updatedAt: Value(now),
          ),
        );
      }

      return purchase.id;
    });
  }

  /// Cancels an existing purchase, softly deleting its lines and reverting Kardex movements safely.
  Future<void> cancelPurchase(String purchaseId, {String? reason}) async {
    final now = DateTime.now();

    await _db.transaction(() async {
      final purchase =
          await (_db.select(_db.purchases)..where(
                (tbl) => tbl.id.equals(purchaseId) & tbl.deletedAt.isNull(),
              ))
              .getSingleOrNull();

      if (purchase == null) {
        throw StateError('La compra no existe o ya ha sido anulada.');
      }

      // Check all movements associated with this purchase
      final movements =
          await (_db.select(_db.stockMovements)..where(
                (tbl) =>
                    tbl.purchaseId.equals(purchaseId) & tbl.deletedAt.isNull(),
              ))
              .get();

      // Guard against negative stock: if current stock without this purchase would drop below zero
      for (final mov in movements) {
        final allItemMovements =
            await (_db.select(_db.stockMovements)..where(
                  (tbl) =>
                      tbl.itemId.equals(mov.itemId) & tbl.deletedAt.isNull(),
                ))
                .get();

        double currentStock = 0.0;
        for (final m in allItemMovements) {
          currentStock += m.quantity;
        }

        final stockAfterReversal = currentStock - mov.quantity;
        if (stockAfterReversal < -0.0001) {
          final item = await (_db.select(
            _db.inventoryItems,
          )..where((tbl) => tbl.id.equals(mov.itemId))).getSingleOrNull();
          throw StateError(
            'No se puede anular la compra: el stock de "${item?.name ?? mov.itemId}" ya fue consumido (Stock actual: $currentStock, a revertir: ${mov.quantity}).',
          );
        }
      }

      // Soft delete purchase
      await (_db.update(
        _db.purchases,
      )..where((tbl) => tbl.id.equals(purchaseId))).write(
        PurchasesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          notes: Value(
            reason != null
                ? '${purchase.notes ?? ""}\n[ANULADO: $reason]'.trim()
                : purchase.notes,
          ),
        ),
      );

      // Soft delete purchase items
      await (_db.update(
        _db.purchaseItems,
      )..where((tbl) => tbl.purchaseId.equals(purchaseId))).write(
        PurchaseItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );

      // Soft delete kardex movements
      await (_db.update(
        _db.stockMovements,
      )..where((tbl) => tbl.purchaseId.equals(purchaseId))).write(
        StockMovementsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  // ==================== MAPPERS ====================

  model.Supplier _mapSupplierRowToModel(Supplier row) {
    return model.Supplier(
      id: row.id,
      workspaceId: row.workspaceId,
      name: row.name,
      contactName: row.contactName,
      phone: row.phone,
      email: row.email,
      taxId: row.taxId,
      address: row.address,
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

  model.Purchase _mapPurchaseRowToModel(
    Purchase row, {
    String? supplierName,
    String? partnerName,
  }) {
    return model.Purchase(
      id: row.id,
      workspaceId: row.workspaceId,
      supplierId: row.supplierId,
      paidByPartnerId: row.paidByPartnerId,
      totalAmountCents: row.totalAmountCents,
      date: row.date,
      documentType: row.documentType,
      invoiceNumber: row.invoiceNumber,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      version: row.version,
      deletedAt: row.deletedAt,
      supplierName: supplierName,
      partnerName: partnerName,
    );
  }
}
