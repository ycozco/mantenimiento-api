import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

class SyncInboxRepository {
  SyncInboxRepository(this._db, {required this.workspaceId});

  final AppDatabase _db;
  final String workspaceId;
  String get _cursorKey => 'sync_cursor_v1_$workspaceId';

  Future<String> get cursor async {
    final row = await (_db.select(
      _db.appMetadata,
    )..where((item) => item.key.equals(_cursorKey))).getSingleOrNull();
    return row?.value ?? '0';
  }

  Stream<List<SyncInboxData>> watchRecent({int limit = 50}) =>
      (_db.select(_db.syncInbox)
            ..where((row) => row.workspaceId.equals(workspaceId))
            ..orderBy([(row) => OrderingTerm.desc(row.serverSequence)])
            ..limit(limit))
          .watch();

  /// Persists all ciphertext before advancing the cursor in one local transaction.
  Future<void> savePage({
    required List<Map<String, dynamic>> changes,
    required String nextCursor,
  }) async {
    await _db.transaction(() async {
      for (final change in changes) {
        if (change['workspaceId'] != workspaceId) {
          throw StateError('El servidor devolvió un cambio de otro workspace.');
        }
        await _db.customStatement(
          'INSERT OR IGNORE INTO sync_inbox '
          '(operation_id, workspace_id, entity_type, entity_id, schema_version, nonce, ciphertext, server_sequence) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            change['operationId'],
            workspaceId,
            change['entityType'],
            change['entityId'],
            change['schemaVersion'],
            change['nonce'],
            change['ciphertext'],
            int.parse(change['sequence'] as String),
          ],
        );
      }
      await _db
          .into(_db.appMetadata)
          .insertOnConflictUpdate(
            AppMetadataCompanion.insert(key: _cursorKey, value: nextCursor),
          );
    });
  }

  String describe(SyncInboxData row) => jsonEncode({
    'operationId': row.operationId,
    'entityType': row.entityType,
    'entityId': row.entityId,
    'schemaVersion': row.schemaVersion,
    'sequence': row.serverSequence,
    'status': row.status,
  });
}
