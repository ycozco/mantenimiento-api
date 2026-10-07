import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../constants/app_constants.dart';

/// Persists local mutations that must eventually be sent to the server.
///
/// The caller must invoke [enqueue] inside the same Drift transaction as the
/// business mutation. This keeps the local entity and its Outbox record
/// atomic: either both are committed or neither is.
class SyncQueueRepository {
  final AppDatabase _db;
  final String workspaceId;
  static const _uuid = Uuid();

  SyncQueueRepository(
    this._db, {
    this.workspaceId = AppConstants.defaultWorkspaceId,
  }) {
    if (workspaceId.trim().isEmpty) {
      throw ArgumentError.value(
        workspaceId,
        'workspaceId',
        'No puede estar vacío',
      );
    }
  }

  Future<void> enqueue({
    required String workspaceId,
    required String entityTable,
    required String entityId,
    required String operation,
    required int baseVersion,
    required Map<String, dynamic> payload,
    DateTime? queuedAt,
  }) async {
    _requireWorkspace(workspaceId);
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
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'Debe ser mayor que cero');
    }
    final cutoff = (now ?? DateTime.now()).toUtc();
    return (_db.select(_db.syncQueue)
          ..where(
            (row) =>
                row.workspaceId.equals(workspaceId) &
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

  /// Watches this workspace's local operations for diagnostics and UI status.
  /// This is only an Outbox view; it does not imply delivery to another device.
  Stream<List<SyncQueueData>> watchRecent({int limit = 100}) {
    if (limit < 1) {
      throw ArgumentError.value(limit, 'limit', 'Debe ser mayor que cero');
    }
    return (_db.select(_db.syncQueue)
          ..where((row) => row.workspaceId.equals(workspaceId))
          ..orderBy([
            (row) => OrderingTerm.desc(row.queuedAt),
            (row) => OrderingTerm.desc(row.id),
          ])
          ..limit(limit))
        .watch();
  }

  /// Atomically claims one due operation so concurrent send loops cannot
  /// publish the same row at the same time.
  Future<bool> markSending(String operationId, {DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).toUtc();
    return _db.transaction(() async {
      final row = await (_db.select(_db.syncQueue)
            ..where(
              (item) =>
                  item.workspaceId.equals(workspaceId) &
                  item.operationId.equals(operationId),
            ))
          .getSingleOrNull();
      if (row == null ||
          row.status != 'PENDING' ||
          row.nextAttemptAt.isAfter(cutoff)) {
        return false;
      }
      await (_db.update(_db.syncQueue)
            ..where(
              (item) =>
                  item.workspaceId.equals(workspaceId) &
                  item.operationId.equals(operationId) &
                  item.status.equals('PENDING'),
            ))
          .write(
            SyncQueueCompanion(
              status: const Value('SENDING'),
              attempts: Value(row.attempts + 1),
              lastError: const Value(null),
            ),
          );
      return true;
    });
  }

  Future<bool> markDelivered(String operationId) async {
    final changed = await (_db.update(_db.syncQueue)
          ..where(
            (row) =>
                row.workspaceId.equals(workspaceId) &
                row.operationId.equals(operationId) &
                row.status.equals('SENDING'),
          ))
        .write(const SyncQueueCompanion(status: Value('DELIVERED')));
    return changed == 1;
  }

  Future<bool> scheduleRetry(
    String operationId, {
    required DateTime retryAt,
    required String error,
  }) async {
    final changed = await (_db.update(_db.syncQueue)
          ..where(
            (row) =>
                row.workspaceId.equals(workspaceId) &
                row.operationId.equals(operationId) &
                row.status.equals('SENDING'),
          ))
        .write(
          SyncQueueCompanion(
            status: const Value('PENDING'),
            nextAttemptAt: Value(retryAt.toUtc()),
            lastError: Value(error),
          ),
        );
    return changed == 1;
  }

  void _requireWorkspace(String entityWorkspaceId) {
    if (entityWorkspaceId != workspaceId) {
      throw StateError(
        'La operación pertenece a otra organización y no puede añadirse a esta cola.',
      );
    }
  }
}
