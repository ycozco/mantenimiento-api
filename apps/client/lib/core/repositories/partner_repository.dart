import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../database/app_database.dart';
import '../models/capital_movement.dart' as model;

class PartnerRepository {
  final AppDatabase _db;

  PartnerRepository(this._db);

  // ==================== CAPITAL MOVEMENTS ====================

  Stream<List<model.CapitalMovement>> watchPartnerMovements(
    String partnerId, {
    String? type,
    String? projectId,
  }) {
    final query = _db.select(_db.capitalMovements)
      ..where((tbl) {
        var predicate =
            tbl.partnerId.equals(partnerId) & tbl.deletedAt.isNull();
        if (type != null) {
          predicate = predicate & tbl.type.equals(type);
        }
        if (projectId != null) {
          predicate = predicate & tbl.projectId.equals(projectId);
        }
        return predicate;
      })
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);

    return query.watch().asyncMap((rows) async {
      final movements = <model.CapitalMovement>[];
      for (final r in rows) {
        String? partnerName;
        final partnerRow = await (_db.select(
          _db.partners,
        )..where((tbl) => tbl.id.equals(r.partnerId))).getSingleOrNull();
        partnerName = partnerRow?.name;

        String? projectName;
        if (r.projectId != null) {
          final projectRow = await (_db.select(
            _db.projects,
          )..where((tbl) => tbl.id.equals(r.projectId!))).getSingleOrNull();
          projectName = projectRow?.name;
        }

        movements.add(
          _mapRowToModel(r, partnerName: partnerName, projectName: projectName),
        );
      }
      return movements;
    });
  }

  Future<void> recordCapitalMovement(model.CapitalMovement movement) async {
    if (movement.amountCents <= 0) {
      throw ArgumentError('El monto del movimiento debe ser mayor a cero.');
    }

    await _db
        .into(_db.capitalMovements)
        .insert(
          CapitalMovementsCompanion(
            id: Value(movement.id),
            workspaceId: Value(movement.workspaceId),
            partnerId: Value(movement.partnerId),
            projectId: Value(movement.projectId),
            type: Value(movement.type),
            amountCents: Value(movement.amountCents),
            date: Value(movement.date),
            notes: Value(movement.notes),
            createdAt: Value(movement.createdAt),
            updatedAt: Value(movement.updatedAt),
            version: Value(movement.version),
          ),
        );
  }

  Future<void> deleteCapitalMovement(String movementId) async {
    final now = DateTime.now();
    await (_db.update(
      _db.capitalMovements,
    )..where((tbl) => tbl.id.equals(movementId))).write(
      CapitalMovementsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // ==================== BALANCE DERIVATION ====================

  /// Reactively computes the partner's balance ledger
  Stream<model.PartnerBalanceSummary> watchPartnerBalance(String partnerId) {
    return (_db.select(_db.capitalMovements)..where(
          (tbl) => tbl.partnerId.equals(partnerId) & tbl.deletedAt.isNull(),
        ))
        .watch()
        .map((rows) => _computeSummary(partnerId, rows));
  }

  Future<model.PartnerBalanceSummary> getPartnerBalance(
    String partnerId,
  ) async {
    final rows =
        await (_db.select(_db.capitalMovements)..where(
              (tbl) => tbl.partnerId.equals(partnerId) & tbl.deletedAt.isNull(),
            ))
            .get();
    return _computeSummary(partnerId, rows);
  }

  model.PartnerBalanceSummary _computeSummary(
    String partnerId,
    List<CapitalMovement> rows,
  ) {
    int contributions = 0;
    int withdrawals = 0;
    int partnerExpenses = 0;
    int profitDistributions = 0;
    int adjustments = 0;

    for (final r in rows) {
      switch (r.type) {
        case 'contribution':
          contributions += r.amountCents;
          break;
        case 'withdrawal':
          withdrawals += r.amountCents;
          break;
        case 'partnerExpense':
          partnerExpenses += r.amountCents;
          break;
        case 'profitDistribution':
          profitDistributions += r.amountCents;
          break;
        case 'adjustment':
          adjustments += r.amountCents;
          break;
      }
    }

    return model.PartnerBalanceSummary(
      partnerId: partnerId,
      contributionsCents: contributions,
      withdrawalsCents: withdrawals,
      partnerExpensesCents: partnerExpenses,
      profitDistributionsCents: profitDistributions,
      adjustmentsCents: adjustments,
    );
  }

  model.CapitalMovement _mapRowToModel(
    CapitalMovement row, {
    String? partnerName,
    String? projectName,
  }) {
    return model.CapitalMovement(
      id: row.id,
      workspaceId: row.workspaceId,
      partnerId: row.partnerId,
      projectId: row.projectId,
      type: row.type,
      amountCents: row.amountCents,
      date: row.date,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      version: row.version,
      deletedAt: row.deletedAt,
      partnerName: partnerName,
      projectName: projectName,
    );
  }
}
