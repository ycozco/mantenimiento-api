import 'package:drift/drift.dart' hide isNull, isNotNull;

import '../database/app_database.dart';
import '../models/collection.dart' as model;

class CollectionRepository {
  final AppDatabase _db;

  CollectionRepository(this._db);

  // ==================== COLLECTIONS ====================

  Stream<List<model.Collection>> watchProjectCollections(String projectId) {
    final query = (_db.select(_db.collections)
      ..where((tbl) => tbl.projectId.equals(projectId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]));

    return query.watch().asyncMap((rows) async {
      final collections = <model.Collection>[];
      for (final r in rows) {
        String? clientName;
        final client = await (_db.select(
          _db.clients,
        )..where((tbl) => tbl.id.equals(r.clientId))).getSingleOrNull();
        clientName = client?.name;

        String? partnerName;
        if (r.receivedByPartnerId != null) {
          final partner =
              await (_db.select(_db.partners)
                    ..where((tbl) => tbl.id.equals(r.receivedByPartnerId!)))
                  .getSingleOrNull();
          partnerName = partner?.name;
        }

        collections.add(
          _mapRowToModel(r, clientName: clientName, partnerName: partnerName),
        );
      }
      return collections;
    });
  }

  Stream<List<model.Collection>> watchClientCollections(String clientId) {
    final query = (_db.select(_db.collections)
      ..where((tbl) => tbl.clientId.equals(clientId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]));

    return query.watch().asyncMap((rows) async {
      final collections = <model.Collection>[];
      for (final r in rows) {
        String? partnerName;
        if (r.receivedByPartnerId != null) {
          final partner =
              await (_db.select(_db.partners)
                    ..where((tbl) => tbl.id.equals(r.receivedByPartnerId!)))
                  .getSingleOrNull();
          partnerName = partner?.name;
        }

        collections.add(_mapRowToModel(r, partnerName: partnerName));
      }
      return collections;
    });
  }

  Stream<List<model.Collection>> watchAllCollections() {
    final query = (_db.select(_db.collections)
      ..where((tbl) => tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]));

    return query.watch().asyncMap((rows) async {
      final collections = <model.Collection>[];
      for (final r in rows) {
        final client = await (_db.select(
          _db.clients,
        )..where((tbl) => tbl.id.equals(r.clientId))).getSingleOrNull();
        final clientName = client?.name;

        String? projectName;
        if (r.projectId != null) {
          final project = await (_db.select(
            _db.projects,
          )..where((tbl) => tbl.id.equals(r.projectId!))).getSingleOrNull();
          projectName = project?.name;
        }

        String? partnerName;
        if (r.receivedByPartnerId != null) {
          final partner =
              await (_db.select(_db.partners)
                    ..where((tbl) => tbl.id.equals(r.receivedByPartnerId!)))
                  .getSingleOrNull();
          partnerName = partner?.name;
        }

        collections.add(
          _mapRowToModel(
            r,
            clientName: clientName,
            projectName: projectName,
            partnerName: partnerName,
          ),
        );
      }
      return collections;
    });
  }

  Future<void> recordCollection(model.Collection collection) async {
    if (collection.amountCents <= 0) {
      throw ArgumentError('El monto del cobro debe ser mayor a cero.');
    }

    final contextCount =
        (collection.projectId != null ? 1 : 0) +
        (collection.visitId != null ? 1 : 0) +
        (collection.planId != null ? 1 : 0);
    if (contextCount != 1) {
      throw ArgumentError(
        'Un cobro debe estar asociado exactamente a un único contexto: Obra (projectId), Visita (visitId) o Plan (planId).',
      );
    }

    await _db
        .into(_db.collections)
        .insert(
          CollectionsCompanion(
            id: Value(collection.id),
            workspaceId: Value(collection.workspaceId),
            clientId: Value(collection.clientId),
            projectId: Value(collection.projectId),
            visitId: Value(collection.visitId),
            planId: Value(collection.planId),
            amountCents: Value(collection.amountCents),
            date: Value(collection.date),
            receivedByPartnerId: Value(collection.receivedByPartnerId),
            paymentMethod: Value(collection.paymentMethod),
            reference: Value(collection.reference),
            notes: Value(collection.notes),
            createdAt: Value(collection.createdAt),
            updatedAt: Value(collection.updatedAt),
            version: Value(collection.version),
          ),
        );
  }

  Stream<List<model.Collection>> watchVisitCollections(String visitId) {
    final query = (_db.select(_db.collections)
      ..where((tbl) => tbl.visitId.equals(visitId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]));

    return query.watch().asyncMap((rows) async {
      final collections = <model.Collection>[];
      for (final r in rows) {
        String? clientName;
        final client = await (_db.select(
          _db.clients,
        )..where((tbl) => tbl.id.equals(r.clientId))).getSingleOrNull();
        clientName = client?.name;
        collections.add(_mapRowToModel(r, clientName: clientName));
      }
      return collections;
    });
  }

  Stream<List<model.Collection>> watchPlanCollections(String planId) {
    return (_db.select(_db.maintenanceVisits)
          ..where((tbl) => tbl.planId.equals(planId) & tbl.deletedAt.isNull()))
        .watch()
        .asyncMap((visits) async {
          final visitIds = visits.map((v) => v.id).toList();
          final query = _db.select(_db.collections)
            ..where(
              (tbl) =>
                  (tbl.planId.equals(planId) |
                      (visitIds.isNotEmpty
                          ? tbl.visitId.isIn(visitIds)
                          : const Constant(false))) &
                  tbl.deletedAt.isNull(),
            )
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.date)]);
          final rows = await query.get();
          return rows.map(_mapRowToModel).toList();
        });
  }

  Stream<int> watchVisitCollectedCents(String visitId) {
    return (_db.select(
          _db.collections,
        )..where((tbl) => tbl.visitId.equals(visitId) & tbl.deletedAt.isNull()))
        .watch()
        .map((rows) {
          int total = 0;
          for (final r in rows) {
            total += r.amountCents;
          }
          return total;
        });
  }

  Future<int> getVisitCollectedCents(String visitId) async {
    final rows =
        await (_db.select(_db.collections)..where(
              (tbl) => tbl.visitId.equals(visitId) & tbl.deletedAt.isNull(),
            ))
            .get();
    int total = 0;
    for (final r in rows) {
      total += r.amountCents;
    }
    return total;
  }

  Stream<int> watchPlanCollectedCents(String planId) {
    return _db
        .customSelect(
          'SELECT COALESCE(SUM(c.amount_cents), 0) AS total FROM collections c '
          'LEFT JOIN maintenance_visits v ON c.visit_id = v.id '
          'WHERE (c.plan_id = ? OR v.plan_id = ?) AND c.deleted_at IS NULL',
          variables: [Variable.withString(planId), Variable.withString(planId)],
          readsFrom: {_db.collections, _db.maintenanceVisits},
        )
        .watchSingle()
        .map((row) => row.read<int>('total'));
  }

  Future<int> getPlanCollectedCents(String planId) async {
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(c.amount_cents), 0) AS total FROM collections c '
          'LEFT JOIN maintenance_visits v ON c.visit_id = v.id '
          'WHERE (c.plan_id = ? OR v.plan_id = ?) AND c.deleted_at IS NULL',
          variables: [Variable.withString(planId), Variable.withString(planId)],
          readsFrom: {_db.collections, _db.maintenanceVisits},
        )
        .getSingle();
    return row.read<int>('total');
  }

  Future<void> deleteCollection(String collectionId) async {
    final now = DateTime.now();
    await (_db.update(
      _db.collections,
    )..where((tbl) => tbl.id.equals(collectionId))).write(
      CollectionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  // ==================== BILLING / RECEIVABLES DERIVATIONS ====================

  /// Stream of total collected amount for a project in cents
  Stream<int> watchProjectCollectedCents(String projectId) {
    return (_db.select(_db.collections)..where(
          (tbl) => tbl.projectId.equals(projectId) & tbl.deletedAt.isNull(),
        ))
        .watch()
        .map((rows) {
          int total = 0;
          for (final r in rows) {
            total += r.amountCents;
          }
          return total;
        });
  }

  /// Reactively computes billing summary (agreed, collected, receivable, overpayment)
  Stream<model.ProjectBillingSummary> watchProjectBillingSummary(
    String projectId,
    int agreedAmountCents,
  ) {
    return watchProjectCollectedCents(projectId).map((collected) {
      return model.ProjectBillingSummary(
        projectId: projectId,
        agreedAmountCents: agreedAmountCents,
        collectedCents: collected,
      );
    });
  }

  Future<model.ProjectBillingSummary> getProjectBillingSummary(
    String projectId,
    int agreedAmountCents,
  ) async {
    final rows =
        await (_db.select(_db.collections)..where(
              (tbl) => tbl.projectId.equals(projectId) & tbl.deletedAt.isNull(),
            ))
            .get();

    int collected = 0;
    for (final r in rows) {
      collected += r.amountCents;
    }

    return model.ProjectBillingSummary(
      projectId: projectId,
      agreedAmountCents: agreedAmountCents,
      collectedCents: collected,
    );
  }

  model.Collection _mapRowToModel(
    Collection row, {
    String? clientName,
    String? projectName,
    String? partnerName,
  }) {
    return model.Collection(
      id: row.id,
      workspaceId: row.workspaceId,
      clientId: row.clientId,
      projectId: row.projectId,
      visitId: row.visitId,
      planId: row.planId,
      amountCents: row.amountCents,
      date: row.date,
      receivedByPartnerId: row.receivedByPartnerId,
      paymentMethod: row.paymentMethod,
      reference: row.reference,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      version: row.version,
      deletedAt: row.deletedAt,
      clientName: clientName,
      projectName: projectName,
      partnerName: partnerName,
    );
  }
}
