import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/repositories/sync_queue_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('outbox is workspace-scoped and retries through explicit states', () async {
    final orgA = SyncQueueRepository(db, workspaceId: 'org-a');
    final orgB = SyncQueueRepository(db, workspaceId: 'org-b');
    final now = DateTime.utc(2026, 10, 6, 12);

    await orgA.enqueue(
      workspaceId: 'org-a',
      entityTable: 'workers',
      entityId: 'worker-a',
      operation: 'UPSERT',
      baseVersion: 1,
      payload: const {'name': 'Ana'},
      queuedAt: now,
    );
    await orgB.enqueue(
      workspaceId: 'org-b',
      entityTable: 'workers',
      entityId: 'worker-b',
      operation: 'UPSERT',
      baseVersion: 1,
      payload: const {'name': 'Bruno'},
      queuedAt: now,
    );

    final pendingA = await orgA.pending(now: now);
    final pendingB = await orgB.pending(now: now);
    expect(pendingA.map((row) => row.entityId), ['worker-a']);
    expect(pendingB.map((row) => row.entityId), ['worker-b']);

    final operationA = pendingA.single.operationId;
    final operationB = pendingB.single.operationId;
    expect(await orgA.markSending(operationB, now: now), isFalse);
    expect(await orgA.markSending(operationA, now: now), isTrue);
    expect(await orgA.markSending(operationA, now: now), isFalse);
    expect((await orgA.pending(now: now)), isEmpty);

    final retryAt = now.add(const Duration(minutes: 1));
    expect(
      await orgA.scheduleRetry(
        operationA,
        retryAt: retryAt,
        error: 'offline',
      ),
      isTrue,
    );
    expect(await orgA.pending(now: now), isEmpty);
    expect((await orgA.pending(now: retryAt)).single.attempts, 1);
    expect(await orgA.markSending(operationA, now: retryAt), isTrue);
    expect(await orgA.markDelivered(operationA), isTrue);
    expect(await orgA.pending(now: retryAt), isEmpty);

    await expectLater(
      orgA.enqueue(
        workspaceId: 'org-b',
        entityTable: 'workers',
        entityId: 'worker-b',
        operation: 'UPSERT',
        baseVersion: 1,
        payload: const {},
      ),
      throwsStateError,
    );
  });
}
