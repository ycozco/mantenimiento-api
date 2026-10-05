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
        String? clientName;
        if (r.clientId != null) {
          final client = await (_db.select(
            _db.clients,
          )..where((tbl) => tbl.id.equals(r.clientId!))).getSingleOrNull();
          clientName = client?.name;
        }

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

    await _db
        .into(_db.collections)
        .insert(
          CollectionsCompanion(
            id: Value(collection.id),
            workspaceId: Value(collection.workspaceId),
            clientId: Value(collection.clientId),
            projectId: Value(collection.projectId),
            visitId: Value(collection.visitId),
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
