import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/constants/app_constants.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/worker.dart' as model;
import 'package:mantenimiento_app/core/models/work_log.dart' as model;
import 'package:mantenimiento_app/core/repositories/worker_repository.dart';
import 'package:mantenimiento_app/core/repositories/work_log_repository.dart';

void main() {
  late AppDatabase db;
  late WorkerRepository workerRepo;
  late WorkLogRepository workLogRepo;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    workerRepo = WorkerRepository(db);
    workLogRepo = WorkLogRepository(db);

    // Insertar un cliente y una obra base para asociar jornadas
    await db
        .into(db.clients)
        .insert(ClientsCompanion.insert(id: 'c1', name: 'Cliente Base'));
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'p1',
            name: 'Obra Los Sauces',
            startDate: DateTime(2026, 10, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('T-02: Pruebas de Worker (Trabajador)', () {
    test(
      '1. Crear trabajador con valores mínimos y defaultRateCents',
      () async {
        final worker = model.Worker(
          id: 'w1',
          name: 'Juan Pérez',
          phone: '999111222',
          specialty: 'Albañil',
          defaultPaymentType: AppConstants.paymentTypeDaily,
          defaultRateCents: 7000, // S/ 70.00
        );

        await workerRepo.createWorker(worker);

        final fetched = await workerRepo.getWorkerById('w1');
        expect(fetched, isNotNull);
        expect(fetched!.name, 'Juan Pérez');
        expect(fetched.phone, '999111222');
        expect(fetched.specialty, 'Albañil');
        expect(fetched.defaultPaymentType, AppConstants.paymentTypeDaily);
        expect(fetched.defaultRateCents, 7000);
        expect(fetched.defaultRate, 70.0);
        expect(fetched.isActive, isTrue);
      },
    );

    test('2. Editar trabajador actualiza campos y versión', () async {
      final worker = model.Worker(
        id: 'w2',
        name: 'Pedro Ramos',
        defaultRateCents: 6000,
      );
      await workerRepo.createWorker(worker);

      final updated = worker.copyWith(
        name: 'Pedro Ramos Maestro',
        specialty: 'Jardinero',
        defaultRateCents: 7500,
      );
      await workerRepo.updateWorker(updated);

      final fetched = await workerRepo.getWorkerById('w2');
      expect(fetched!.name, 'Pedro Ramos Maestro');
      expect(fetched.specialty, 'Jardinero');
      expect(fetched.defaultRateCents, 7500);
      expect(fetched.version, 2);
    });

    test(
      '3 & 4. Desactivar trabajador: no aparece en selector activo',
      () async {
        final worker1 = model.Worker(id: 'w_act', name: 'Activo 1');
        final worker2 = model.Worker(id: 'w_inact', name: 'Inactivo 1');

        await workerRepo.createWorker(worker1);
        await workerRepo.createWorker(worker2);

        await workerRepo.deactivateWorker('w_inact');

        final activeWorkers = await workerRepo.getActiveWorkers();
        expect(activeWorkers.map((w) => w.id), contains('w_act'));
        expect(activeWorkers.map((w) => w.id), isNot(contains('w_inact')));

        // En la lista completa sigue existiendo
        final allWorkers = await workerRepo.watchAllWorkers().first;
        expect(allWorkers.map((w) => w.id), containsAll(['w_act', 'w_inact']));
      },
    );

    test('5. Trabajador inactivo conserva su historial completo', () async {
      final worker = model.Worker(id: 'w_hist', name: 'Mario');
      await workerRepo.createWorker(worker);

      final log = model.WorkLog(
        id: 'log_hist_1',
        workerId: 'w_hist',
        projectId: 'p1',
        date: DateTime(2026, 10, 2),
        paymentType: AppConstants.paymentTypeDaily,
        quantity: 1,
        rateCents: 8000,
      );
      await workLogRepo.createWorkLog(log);

      // Desactivar el trabajador
      await workerRepo.deactivateWorker('w_hist');

      // Consultar historial de jornadas
      final logs = await workLogRepo.getWorkerWorkLogs('w_hist');
      expect(logs.length, 1);
      expect(logs.first.id, 'log_hist_1');
      expect(logs.first.amountCents, 8000);
    });
  });

  group('T-02: Pruebas de WorkLog y Modos de Pago', () {
    test('WorkLog daily: Worker S/ 70/día x 1 día = S/ 70', () async {
      final worker = model.Worker(
        id: 'w_daily',
        name: 'Juan',
        defaultPaymentType: AppConstants.paymentTypeDaily,
        defaultRateCents: 7000,
      );
      await workerRepo.createWorker(worker);

      final log = model.WorkLog(
        id: 'log_d1',
        workerId: 'w_daily',
        projectId: 'p1',
        date: DateTime(2026, 10, 1),
        paymentType: AppConstants.paymentTypeDaily,
        quantity: 1.0,
        rateCents: worker.defaultRateCents,
      );
      await workLogRepo.createWorkLog(log);

      final saved = await workLogRepo.getProjectWorkLogs('p1');
      expect(saved.first.amountCents, 7000);
      expect(saved.first.amount, 70.0);
    });

    test('WorkLog hourly: S/ 12/hora x 6.5 horas = S/ 78', () async {
      final worker = model.Worker(
        id: 'w_hourly',
        name: 'Pedro',
        defaultPaymentType: AppConstants.paymentTypeHourly,
        defaultRateCents: 1200,
      );
      await workerRepo.createWorker(worker);

      final log = model.WorkLog(
        id: 'log_h1',
        workerId: 'w_hourly',
        projectId: 'p1',
        date: DateTime(2026, 10, 1),
        paymentType: AppConstants.paymentTypeHourly,
        quantity: 6.5,
        rateCents: 1200,
      );
      await workLogRepo.createWorkLog(log);

      final saved = await workLogRepo.getProjectWorkLogs('p1');
      expect(saved.first.amountCents, 7800);
      expect(saved.first.amount, 78.0);
    });

    test('WorkLog fixed: S/ 150 fijo = S/ 150', () async {
      final worker = model.Worker(
        id: 'w_fixed',
        name: 'Carlos',
        defaultPaymentType: AppConstants.paymentTypeFixed,
        defaultRateCents: 15000,
      );
      await workerRepo.createWorker(worker);

      final log = model.WorkLog(
        id: 'log_f1',
        workerId: 'w_fixed',
        projectId: 'p1',
        date: DateTime(2026, 10, 1),
        paymentType: AppConstants.paymentTypeFixed,
        quantity: 1.0,
        rateCents: 15000,
      );
      await workLogRepo.createWorkLog(log);

      final saved = await workLogRepo.getProjectWorkLogs('p1');
      expect(saved.first.amountCents, 15000);
      expect(saved.first.amount, 150.0);
    });

    test(
      'Snapshot histórico: cambiar Worker de S/ 70 a S/ 80 no altera WorkLog anterior',
      () async {
        final worker = model.Worker(
          id: 'w_snap',
          name: 'Juan Histórico',
          defaultRateCents: 7000,
        );
        await workerRepo.createWorker(worker);

        // Jornada en octubre a S/ 70
        final logOctubre = model.WorkLog(
          id: 'log_oct',
          workerId: 'w_snap',
          projectId: 'p1',
          date: DateTime(2026, 10, 1),
          paymentType: AppConstants.paymentTypeDaily,
          quantity: 1.0,
          rateCents: worker.defaultRateCents,
        );
        await workLogRepo.createWorkLog(logOctubre);

        // En diciembre se sube la tarifa de Juan a S/ 80
        final workerActualizado = worker.copyWith(defaultRateCents: 8000);
        await workerRepo.updateWorker(workerActualizado);

        // La jornada histórica DEBE continuar costando S/ 70 (7000 cents)
        final logs = await workLogRepo.getProjectWorkLogs('p1');
        expect(logs.first.rateCents, 7000);
        expect(logs.first.amountCents, 7000);
        expect(logs.first.amount, 70.0);
      },
    );

    test(
      'Override: Worker = S/ 70, jornada registrada manualmente a S/ 80',
      () async {
        final worker = model.Worker(
          id: 'w_over',
          name: 'Operario Override',
          defaultRateCents: 7000,
        );
        await workerRepo.createWorker(worker);

        // Registrar jornada acordada hoy a S/ 80
        final log = model.WorkLog(
          id: 'log_over_1',
          workerId: 'w_over',
          projectId: 'p1',
          date: DateTime(2026, 10, 1),
          paymentType: AppConstants.paymentTypeDaily,
          quantity: 1.0,
          rateCents: 8000, // override manual
        );
        await workLogRepo.createWorkLog(log);

        // WorkLog tiene S/ 80
        final savedLog = await workLogRepo.getProjectWorkLogs('p1');
        expect(savedLog.first.rateCents, 8000);
        expect(savedLog.first.amountCents, 8000);

        // Worker mantiene su tarifa predeterminada intacta en S/ 70
        final savedWorker = await workerRepo.getWorkerById('w_over');
        expect(savedWorker!.defaultRateCents, 7000);
      },
    );

    test(
      'Project cost: Juan S/ 70 + Pedro S/ 80 en Obra A -> Costo laboral derivado S/ 150',
      () async {
        final juan = model.Worker(
          id: 'w_j',
          name: 'Juan',
          defaultRateCents: 7000,
        );
        final pedro = model.Worker(
          id: 'w_p',
          name: 'Pedro',
          defaultRateCents: 8000,
        );
        await workerRepo.createWorker(juan);
        await workerRepo.createWorker(pedro);

        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log_j',
            workerId: 'w_j',
            projectId: 'p1',
            date: DateTime(2026, 10, 1),
            quantity: 1.0,
            rateCents: 7000,
          ),
        );
        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log_p',
            workerId: 'w_p',
            projectId: 'p1',
            date: DateTime(2026, 10, 1),
            quantity: 1.0,
            rateCents: 8000,
          ),
        );

        final totalLaborCents = await workLogRepo.getProjectLaborCostCents(
          'p1',
        );
        expect(totalLaborCents, 15000); // S/ 150.00 exactos
        expect(totalLaborCents / 100.0, 150.0);
      },
    );

    test(
      'Context constraint: WorkLog con projectId + maintenanceVisitId simultáneos falla',
      () async {
        final worker = model.Worker(id: 'w_ctx', name: 'Test Ctx');
        await workerRepo.createWorker(worker);

        expect(
          () => workLogRepo.createWorkLog(
            model.WorkLog(
              id: 'log_invalido_1',
              workerId: 'w_ctx',
              projectId: 'p1',
              maintenanceVisitId: 'v1', // Ambos a la vez prohíbidos por XOR
              date: DateTime(2026, 10, 1),
              quantity: 1.0,
              rateCents: 5000,
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('Context constraint: WorkLog sin contexto falla', () async {
      final worker = model.Worker(id: 'w_ctx2', name: 'Test Ctx 2');
      await workerRepo.createWorker(worker);

      expect(
        () => workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log_invalido_2',
            workerId: 'w_ctx2',
            projectId: null,
            maintenanceVisitId: null, // Ninguno prohibido
            date: DateTime(2026, 10, 1),
            quantity: 1.0,
            rateCents: 5000,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'Foreign key: Inserción de WorkLog con Worker inexistente es rechazada por SQLite',
      () async {
        expect(
          workLogRepo.createWorkLog(
            model.WorkLog(
              id: 'log_fk_fail',
              workerId: 'obrero_fantasma_999',
              projectId: 'p1',
              date: DateTime(2026, 10, 1),
              quantity: 1.0,
              rateCents: 5000,
            ),
          ),
          throwsException,
        );
      },
    );

    test(
      'Soft delete: WorkLog anulado no suma al costo laboral de la obra',
      () async {
        final worker = model.Worker(id: 'w_soft', name: 'Trabajador Soft');
        await workerRepo.createWorker(worker);

        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log_valido',
            workerId: 'w_soft',
            projectId: 'p1',
            date: DateTime(2026, 10, 1),
            quantity: 1.0,
            rateCents: 5000, // S/ 50
          ),
        );

        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log_a_anular',
            workerId: 'w_soft',
            projectId: 'p1',
            date: DateTime(2026, 10, 2),
            quantity: 1.0,
            rateCents: 3000, // S/ 30
          ),
        );

        // Costo antes de anular: 50 + 30 = S/ 80
        expect(await workLogRepo.getProjectLaborCostCents('p1'), 8000);

        // Anular la jornada de S/ 30
        await workLogRepo.voidWorkLog('log_a_anular');

        // Costo después de anular: S/ 50
        expect(await workLogRepo.getProjectLaborCostCents('p1'), 5000);

        // Las jornadas activas devuelven solo 1
        final logsActivos = await workLogRepo.getProjectWorkLogs('p1');
        expect(logsActivos.length, 1);
        expect(logsActivos.first.id, 'log_valido');
      },
    );
  });
}
