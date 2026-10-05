import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/labor_payment.dart' as model;
import 'package:mantenimiento_app/core/models/work_log.dart' as model;
import 'package:mantenimiento_app/core/models/worker.dart' as model;
import 'package:mantenimiento_app/core/repositories/labor_payment_repository.dart';
import 'package:mantenimiento_app/core/repositories/work_log_repository.dart';
import 'package:mantenimiento_app/core/repositories/worker_repository.dart';

void main() {
  late AppDatabase db;
  late WorkerRepository workerRepo;
  late WorkLogRepository workLogRepo;
  late LaborPaymentRepository paymentRepo;

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
    paymentRepo = LaborPaymentRepository(db);

    // Sembrar Obra de prueba
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-cayma',
            name: 'Obra Cayma',
            startDate: DateTime(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('T-03: Pruebas de LaborPayment y Saldos de Trabajadores', () {
    test('1. Pago parcial: reduce saldo pendiente correctamente', () async {
      // Worker con tarifa S/ 70/día
      final worker = model.Worker(
        id: 'w-juan',
        name: 'Juan Perez',
        defaultRateCents: 7000,
      );
      await workerRepo.createWorker(worker);

      // Jornada: 1 día = S/ 70.00 devengado
      await workLogRepo.createWorkLog(
        model.WorkLog(
          id: 'log-1',
          workerId: worker.id,
          projectId: 'proj-cayma',
          date: DateTime(2026, 2, 1),
          quantity: 1.0,
          rateCents: 7000,
          amountCents: 7000,
        ),
      );

      // Saldo antes de pago: devengado = 7000, pagado = 0, saldo = 7000
      var balance = await paymentRepo.getWorkerBalance(worker.id);
      expect(balance.accruedCents, 7000);
      expect(balance.paidCents, 0);
      expect(balance.balanceCents, 7000);
      expect(balance.hasPendingDebt, isTrue);

      // Pago parcial de S/ 40.00
      await paymentRepo.createPayment(
        model.LaborPayment(
          id: 'pay-1',
          workerId: worker.id,
          amountCents: 4000,
          paymentMethod: 'cash',
        ),
      );

      balance = await paymentRepo.getWorkerBalance(worker.id);
      expect(balance.accruedCents, 7000);
      expect(balance.paidCents, 4000);
      expect(balance.balanceCents, 3000); // S/ 30.00 pendiente
      expect(balance.balance, 30.0);
      expect(balance.hasPendingDebt, isTrue);
      expect(balance.isSettled, isFalse);
    });

    test('2. Pago completo: saldo queda exactamente liquidado (0)', () async {
      final worker = model.Worker(
        id: 'w-pedro',
        name: 'Pedro Gomez',
        defaultRateCents: 8000,
      );
      await workerRepo.createWorker(worker);

      await workLogRepo.createWorkLog(
        model.WorkLog(
          id: 'log-2',
          workerId: worker.id,
          projectId: 'proj-cayma',
          date: DateTime(2026, 2, 1),
          quantity: 1.0,
          rateCents: 8000,
          amountCents: 8000,
        ),
      );

      // Pago total de S/ 80.00
      await paymentRepo.createPayment(
        model.LaborPayment(
          id: 'pay-2',
          workerId: worker.id,
          amountCents: 8000,
          paymentMethod: 'yape',
        ),
      );

      final balance = await paymentRepo.getWorkerBalance(worker.id);
      expect(balance.accruedCents, 8000);
      expect(balance.paidCents, 8000);
      expect(balance.balanceCents, 0);
      expect(balance.isSettled, isTrue);
      expect(balance.hasPendingDebt, isFalse);
    });

    test('3. Múltiples pagos acumulan correctamente el total pagado', () async {
      final worker = model.Worker(
        id: 'w-carlos',
        name: 'Carlos Diaz',
        defaultRateCents: 10000,
      );
      await workerRepo.createWorker(worker);

      // 2 jornadas de S/ 100 = S/ 200 devengado
      await workLogRepo.createWorkLog(
        model.WorkLog(
          id: 'log-3a',
          workerId: worker.id,
          projectId: 'proj-cayma',
          date: DateTime(2026, 2, 1),
          quantity: 1.0,
          rateCents: 10000,
          amountCents: 10000,
        ),
      );
      await workLogRepo.createWorkLog(
        model.WorkLog(
          id: 'log-3b',
          workerId: worker.id,
          projectId: 'proj-cayma',
          date: DateTime(2026, 2, 2),
          quantity: 1.0,
          rateCents: 10000,
          amountCents: 10000,
        ),
      );

      // Pagos en partes: S/ 50 + S/ 70 + S/ 80 = S/ 200
      await paymentRepo.createPayment(
        model.LaborPayment(
          id: 'p-1',
          workerId: worker.id,
          amountCents: 5000,
          paymentMethod: 'cash',
        ),
      );
      await paymentRepo.createPayment(
        model.LaborPayment(
          id: 'p-2',
          workerId: worker.id,
          amountCents: 7000,
          paymentMethod: 'plin',
        ),
      );
      await paymentRepo.createPayment(
        model.LaborPayment(
          id: 'p-3',
          workerId: worker.id,
          amountCents: 8000,
          paymentMethod: 'transfer',
        ),
      );

      final payments = await paymentRepo.getWorkerPayments(worker.id);
      expect(payments.length, 3);

      final balance = await paymentRepo.getWorkerBalance(worker.id);
      expect(balance.accruedCents, 20000);
      expect(balance.paidCents, 20000);
      expect(balance.balanceCents, 0);
    });

    test(
      '4. Adelanto: pago mayor al devengado produce saldo negativo',
      () async {
        final worker = model.Worker(
          id: 'w-raul',
          name: 'Raul Castro',
          defaultRateCents: 7000,
        );
        await workerRepo.createWorker(worker);

        // Devengado: 1 jornada = S/ 70
        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log-4',
            workerId: worker.id,
            projectId: 'proj-cayma',
            date: DateTime(2026, 2, 1),
            quantity: 1.0,
            rateCents: 7000,
            amountCents: 7000,
          ),
        );

        // Adelanto de S/ 100
        await paymentRepo.createPayment(
          model.LaborPayment(
            id: 'pay-adelanto',
            workerId: worker.id,
            amountCents: 10000,
          ),
        );

        final balance = await paymentRepo.getWorkerBalance(worker.id);
        expect(balance.accruedCents, 7000);
        expect(balance.paidCents, 10000);
        expect(balance.balanceCents, -3000); // -S/ 30.00
        expect(balance.hasAdvancePayment, isTrue);
        expect(balance.hasPendingDebt, isFalse);
      },
    );

    test(
      '5. Anulación (Soft Delete): pago anulado ya no resta del saldo',
      () async {
        final worker = model.Worker(
          id: 'w-mario',
          name: 'Mario Soto',
          defaultRateCents: 7000,
        );
        await workerRepo.createWorker(worker);

        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log-5',
            workerId: worker.id,
            projectId: 'proj-cayma',
            date: DateTime(2026, 2, 1),
            quantity: 1.0,
            rateCents: 7000,
            amountCents: 7000,
          ),
        );

        await paymentRepo.createPayment(
          model.LaborPayment(
            id: 'pay-anular',
            workerId: worker.id,
            amountCents: 5000,
          ),
        );

        var balance = await paymentRepo.getWorkerBalance(worker.id);
        expect(balance.paidCents, 5000);

        // Anular pago
        await paymentRepo.voidPayment('pay-anular');

        balance = await paymentRepo.getWorkerBalance(worker.id);
        expect(balance.paidCents, 0);
        expect(balance.balanceCents, 7000);

        final activePayments = await paymentRepo.getWorkerPayments(worker.id);
        expect(activePayments, isEmpty);
      },
    );

    test('6. Modificación de pago actualiza monto y versión', () async {
      final worker = model.Worker(
        id: 'w-luis',
        name: 'Luis Vera',
        defaultRateCents: 7000,
      );
      await workerRepo.createWorker(worker);

      final pago = model.LaborPayment(
        id: 'pay-edit',
        workerId: worker.id,
        amountCents: 3000,
        paymentMethod: 'cash',
      );
      await paymentRepo.createPayment(pago);

      // Editar pago a S/ 50
      final pagoActualizado = pago.copyWith(
        amountCents: 5000,
        paymentMethod: 'yape',
        notes: 'Ajustado a S/ 50',
      );
      await paymentRepo.updatePayment(pagoActualizado);

      final pagos = await paymentRepo.getWorkerPayments(worker.id);
      expect(pagos.first.amountCents, 5000);
      expect(pagos.first.paymentMethod, 'yape');
      expect(pagos.first.notes, 'Ajustado a S/ 50');
      expect(pagos.first.version, 2);
    });

    test(
      '7. Foreign key Worker: pago a trabajador inexistente es rechazado por SQLite',
      () async {
        final pagoInvalido = model.LaborPayment(
          id: 'pay-fk-error',
          workerId: 'worker-fantasma',
          amountCents: 5000,
        );

        expect(
          () async => paymentRepo.createPayment(pagoInvalido),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      '8. Foreign key Project: pago con obra inexistente es rechazado por SQLite',
      () async {
        final worker = model.Worker(
          id: 'w-alberto',
          name: 'Alberto Rios',
          defaultRateCents: 7000,
        );
        await workerRepo.createWorker(worker);

        final pagoConObraInvalida = model.LaborPayment(
          id: 'pay-proj-error',
          workerId: worker.id,
          projectId: 'obra-no-existe',
          amountCents: 5000,
        );

        expect(
          () async => paymentRepo.createPayment(pagoConObraInvalida),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      '9. Validación amountCents > 0: monto 0 o negativo es rechazado',
      () async {
        final worker = model.Worker(
          id: 'w-val',
          name: 'Val Worker',
          defaultRateCents: 7000,
        );
        await workerRepo.createWorker(worker);

        final pagoCero = model.LaborPayment(
          id: 'pay-zero',
          workerId: worker.id,
          amountCents: 0,
        );
        expect(
          () async => paymentRepo.createPayment(pagoCero),
          throwsArgumentError,
        );

        final pagoNegativo = model.LaborPayment(
          id: 'pay-neg',
          workerId: worker.id,
          amountCents: -500,
        );
        expect(
          () async => paymentRepo.createPayment(pagoNegativo),
          throwsArgumentError,
        );
      },
    );

    test(
      '10. Regla crítica: WorkLog permanece intacto al registrar pago',
      () async {
        final worker = model.Worker(
          id: 'w-invar',
          name: 'Invar Worker',
          defaultRateCents: 7000,
        );
        await workerRepo.createWorker(worker);

        final workLog = model.WorkLog(
          id: 'log-invar',
          workerId: worker.id,
          projectId: 'proj-cayma',
          date: DateTime(2026, 2, 1),
          quantity: 1.0,
          rateCents: 7000,
          amountCents: 7000,
          paymentType: 'daily',
          notes: 'Jornada inicial intacta',
        );
        await workLogRepo.createWorkLog(workLog);

        // Realizar pago
        await paymentRepo.createPayment(
          model.LaborPayment(
            id: 'pay-invar',
            workerId: worker.id,
            amountCents: 7000,
          ),
        );

        // Verificar que el WorkLog NO sufrió ninguna mutación
        final logs = await workLogRepo.getWorkerWorkLogs(worker.id);
        expect(logs.length, 1);
        final logAfter = logs.first;
        expect(logAfter.amountCents, 7000);
        expect(logAfter.quantity, 1.0);
        expect(logAfter.rateCents, 7000);
        expect(logAfter.notes, 'Jornada inicial intacta');
        expect(logAfter.version, 1);
      },
    );

    test(
      '11. Regla crítica: LaborPayment NO altera ni duplica el costo laboral de Obra',
      () async {
        final worker = model.Worker(
          id: 'w-cost',
          name: 'Cost Worker',
          defaultRateCents: 9000,
        );
        await workerRepo.createWorker(worker);

        // Jornada en Obra Cayma: S/ 90.00
        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log-cost',
            workerId: worker.id,
            projectId: 'proj-cayma',
            date: DateTime(2026, 2, 1),
            quantity: 1.0,
            rateCents: 9000,
            amountCents: 9000,
          ),
        );

        // Costo laboral de Obra Cayma debe ser S/ 90.00
        var projectLaborCost = await workLogRepo.getProjectLaborCostCents(
          'proj-cayma',
        );
        expect(projectLaborCost, 9000);

        // Pagar al trabajador asociando la obra al pago
        await paymentRepo.createPayment(
          model.LaborPayment(
            id: 'pay-cost',
            workerId: worker.id,
            projectId: 'proj-cayma',
            amountCents: 9000,
          ),
        );

        // El costo laboral de la obra debe seguir siendo estrictamente S/ 90.00
        projectLaborCost = await workLogRepo.getProjectLaborCostCents(
          'proj-cayma',
        );
        expect(projectLaborCost, 9000);
      },
    );

    test(
      '12. Cálculo de saldo exacto en céntimos con múltiples jornadas y pagos',
      () async {
        final worker = model.Worker(
          id: 'w-complex',
          name: 'Complex Worker',
          defaultRateCents: 7500,
        );
        await workerRepo.createWorker(worker);

        // Jornada 1: 1.5 días @ S/ 75.00 = S/ 112.50 (11250 cents)
        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'c-log-1',
            workerId: worker.id,
            projectId: 'proj-cayma',
            date: DateTime(2026, 2, 1),
            quantity: 1.5,
            rateCents: 7500,
            amountCents: 11250,
          ),
        );

        // Jornada 2: 0.5 días @ S/ 75.00 = S/ 37.50 (3750 cents)
        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'c-log-2',
            workerId: worker.id,
            projectId: 'proj-cayma',
            date: DateTime(2026, 2, 2),
            quantity: 0.5,
            rateCents: 7500,
            amountCents: 3750,
          ),
        );

        // Total devengado = 11250 + 3750 = 15000 cents (S/ 150.00)
        var balance = await paymentRepo.getWorkerBalance(worker.id);
        expect(balance.accruedCents, 15000);
        expect(balance.paidCents, 0);
        expect(balance.balanceCents, 15000);

        // Pago 1: S/ 60.25 (6025 cents)
        await paymentRepo.createPayment(
          model.LaborPayment(
            id: 'c-pay-1',
            workerId: worker.id,
            amountCents: 6025,
          ),
        );

        balance = await paymentRepo.getWorkerBalance(worker.id);
        expect(balance.paidCents, 6025);
        expect(balance.balanceCents, 8975); // S/ 89.75
        expect(balance.balance, 89.75);

        // Pago 2: S/ 89.75 (8975 cents)
        await paymentRepo.createPayment(
          model.LaborPayment(
            id: 'c-pay-2',
            workerId: worker.id,
            amountCents: 8975,
          ),
        );

        balance = await paymentRepo.getWorkerBalance(worker.id);
        expect(balance.paidCents, 15000);
        expect(balance.balanceCents, 0);
        expect(balance.isSettled, isTrue);
      },
    );
  });
}
