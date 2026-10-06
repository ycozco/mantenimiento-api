import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart' hide Worker;
import 'package:mantenimiento_app/core/models/worker.dart';
import 'package:mantenimiento_app/core/repositories/worker_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('worker reads and writes stay within the repository workspace', () async {
    final orgA = WorkerRepository(db, workspaceId: 'org-a');
    final orgB = WorkerRepository(db, workspaceId: 'org-b');

    await orgA.createWorker(Worker(id: 'worker-a', name: 'Ana', workspaceId: 'org-a'));
    await orgB.createWorker(Worker(id: 'worker-b', name: 'Bruno', workspaceId: 'org-b'));

    expect((await orgA.getActiveWorkers()).map((worker) => worker.id), ['worker-a']);
    expect((await orgB.getActiveWorkers()).map((worker) => worker.id), ['worker-b']);
    expect(await orgA.getWorkerById('worker-b'), isNull);
    expect(await orgB.getWorkerById('worker-a'), isNull);
    expect((await orgA.watchAllWorkers().first).map((worker) => worker.id), ['worker-a']);

    await orgA.deactivateWorker('worker-b');
    expect((await orgB.getWorkerById('worker-b'))!.isActive, isTrue);

    await expectLater(
      orgA.updateWorker(Worker(id: 'worker-b', name: 'Changed', workspaceId: 'org-b')),
      throwsStateError,
    );
  });
}
