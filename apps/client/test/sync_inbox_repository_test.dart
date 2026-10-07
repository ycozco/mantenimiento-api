import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/repositories/sync_inbox_repository.dart';

void main() {
  test(
    'persists encrypted changes before advancing workspace cursor',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = SyncInboxRepository(db, workspaceId: 'workspace-a');

      await repository.savePage(
        changes: [
          {
            'workspaceId': 'workspace-a',
            'operationId': 'operation-1',
            'entityType': 'maintenance_visit',
            'entityId': 'entity-1',
            'schemaVersion': 1,
            'nonce': 'bm9uY2U=',
            'ciphertext': 'Y2lwaGVydGV4dA==',
            'sequence': '7',
          },
        ],
        nextCursor: '7',
      );

      expect(await repository.cursor, '7');
      final received = await repository.watchRecent().first;
      expect(received, hasLength(1));
      expect(received.single.ciphertext, 'Y2lwaGVydGV4dA==');
      expect(received.single.serverSequence, 7);

      await db.close();
    },
  );

  test(
    'rejects cross-workspace envelopes without advancing the cursor',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = SyncInboxRepository(db, workspaceId: 'workspace-a');

      await expectLater(
        repository.savePage(
          changes: [
            {
              'workspaceId': 'workspace-b',
              'operationId': 'operation-2',
              'entityType': 'maintenance_visit',
              'entityId': 'entity-2',
              'schemaVersion': 1,
              'nonce': 'bm9uY2U=',
              'ciphertext': 'Y2lwaGVydGV4dA==',
              'sequence': '8',
            },
          ],
          nextCursor: '8',
        ),
        throwsStateError,
      );

      expect(await repository.cursor, '0');
      await db.close();
    },
  );
}
