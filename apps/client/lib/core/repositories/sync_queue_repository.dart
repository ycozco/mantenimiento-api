import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Persists local mutations that must eventually be sent to the server.
///
/// The caller must invoke [enqueue] inside the same Drift transaction as the
/// business mutation. This keeps the local entity and its Outbox record
/// atomic: either both are committed or neither is.
class SyncQueueRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  SyncQueueRepository(this._db);

  Future<void> enqueue({
    required String workspaceId,
    required String entityTable,
    required String entityId,
    required String operation,
    required int baseVersion,
    required Map<String, dynamic> payload,
    DateTime? queuedAt,
  }) async {
    final timestamp = (queuedAt ?? DateTime.now()).toUtc();
    await _db.into(_db.syncQueue).insert(
      SyncQueueCompanion.insert(
        workspaceId: Value(workspaceId),
        operationId: _uuid.v4(),
        entityTable: entityTable,
        entityId: entityId,
        operation: operation,
        baseVersion: Value(baseVersion),
        payloadJson: jsonEncode(payload),
        queuedAt: Value(timestamp),
        nextAttemptAt: Value(timestamp),
        status: const Value('PENDING'),
      ),
    );
  }

  Future<List<SyncQueueData>> pending({DateTime? now, int limit = 100}) {
    final cutoff = (now ?? DateTime.now()).toUtc();
    return (_db.select(_db.syncQueue)
          ..where(
            (row) =>
                row.status.equals('PENDING') &
                row.nextAttemptAt.isSmallerOrEqualValue(cutoff),
          )
          ..orderBy([
            (row) => OrderingTerm.asc(row.nextAttemptAt),
            (row) => OrderingTerm.asc(row.id),
          ])
          ..limit(limit))
        .get();
  }
}
