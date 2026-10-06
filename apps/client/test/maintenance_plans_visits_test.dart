import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/maintenance_plan.dart' as model;
import 'package:mantenimiento_app/core/models/maintenance_visit.dart' as model;
import 'package:mantenimiento_app/core/models/work_log.dart' as model;
import 'package:mantenimiento_app/core/models/worker.dart' as model;
import 'package:mantenimiento_app/core/repositories/maintenance_repository.dart';
import 'package:mantenimiento_app/core/repositories/work_log_repository.dart';
import 'package:mantenimiento_app/core/repositories/worker_repository.dart';

void main() {
  late AppDatabase db;
  late MaintenanceRepository maintenanceRepo;
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
    maintenanceRepo = MaintenanceRepository(db);
    workerRepo = WorkerRepository(db);
    workLogRepo = WorkLogRepository(db);

    // Sembrar cliente base para foreign keys
    await db
        .into(db.clients)
        .insert(
          ClientsCompanion.insert(id: 'client-bbva', name: 'BBVA Continental'),
        );

    // Sembrar trabajador
    await workerRepo.createWorker(
      model.Worker(
        id: 'worker-jard',
        name: 'Jardinero Uno',
        defaultRateCents: 6000,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('T-04: Pruebas de MaintenancePlan y MaintenanceVisit', () {
    test('1. Crear plan: programa automáticamente la primera visita', () async {
      final plan = model.MaintenancePlan(
        id: 'plan-1',
        title: 'Mantenimiento Jardines BBVA',
        clientId: 'client-bbva',
        frequencyType: 'unMes',
        intervalDays: 30,
        nextDate: DateTime(2026, 3, 1),
      );

      await maintenanceRepo.createPlan(plan);

      // Verificar que el plan existe en base de datos
      final planDb = await maintenanceRepo.getPlanById('plan-1');
      expect(planDb, isNotNull);
      expect(planDb!.title, 'Mantenimiento Jardines BBVA');
      expect(planDb.intervalDays, 30);
      expect(planDb.nextDate, DateTime(2026, 3, 1));

      // Verificar que se creó la primera visita programada
      final visits = await maintenanceRepo.getVisitsForPlan('plan-1');
      expect(visits.length, 1);
      final firstVisit = visits.first;
      expect(firstVisit.planId, 'plan-1');
      expect(firstVisit.scheduledDate, DateTime(2026, 3, 1));
      expect(firstVisit.status, model.VisitStatus.scheduled);
      expect(firstVisit.completedDate, isNull);

      final queued = await db.select(db.syncQueue).get();
      expect(queued.length, 2);
      expect(queued.map((item) => item.operationId).toSet().length, 2);
      expect(queued.every((item) => item.status == 'PENDING'), isTrue);
      expect(
        queued.every((item) => item.workspaceId == plan.workspaceId),
        isTrue,
      );
      final planPayload = jsonDecode(
        queued.firstWhere((item) => item.entityTable == 'maintenance_plans').payloadJson,
      ) as Map<String, dynamic>;
      expect(planPayload['id'], 'plan-1');
      expect(planPayload['version'], 1);
    });

    test(
      '2. Iniciar visita: cambia estado a inProgress sin mutar plan',
      () async {
        final plan = model.MaintenancePlan(
          id: 'plan-prog',
          title: 'Plan Podado',
          clientId: 'client-bbva',
          intervalDays: 30,
          nextDate: DateTime(2026, 3, 1),
        );
        await maintenanceRepo.createPlan(plan);

        final visits = await maintenanceRepo.getVisitsForPlan('plan-prog');
        final visitId = visits.first.id;

        await maintenanceRepo.startVisit(visitId);

        final updatedVisit = await maintenanceRepo.getVisitById(visitId);
        expect(updatedVisit!.status, model.VisitStatus.inProgress);
        expect(updatedVisit.isInProgress, isTrue);

        final planDb = await maintenanceRepo.getPlanById('plan-prog');
        expect(planDb!.nextDate, DateTime(2026, 3, 1));
      },
    );

    test(
      '3. Completar visita: conserva historial inmutable y programa siguiente ciclo',
      () async {
        final plan = model.MaintenancePlan(
          id: 'plan-ciclo',
          title: 'Mantenimiento Mensual',
          clientId: 'client-bbva',
          frequencyType: 'unMes',
          intervalDays: 30,
          nextDate: DateTime(2026, 3, 1),
        );
        await maintenanceRepo.createPlan(plan);

        final visitsInitial = await maintenanceRepo.getVisitsForPlan(
          'plan-ciclo',
        );
        final firstVisitId = visitsInitial.first.id;

        // Completar la visita el 01/03/2026
        final executionDate = DateTime(2026, 3, 1, 14, 0);
        await maintenanceRepo.completeVisit(
          firstVisitId,
          executedDate: executionDate,
          notes: 'Mantenimiento ejecutado satisfactoriamente',
        );

        // Comprobar que la primera visita PERMANECE con sus datos
        final completedVisit = await maintenanceRepo.getVisitById(firstVisitId);
        expect(completedVisit!.status, model.VisitStatus.completed);
        expect(completedVisit.isCompleted, isTrue);
        expect(completedVisit.completedDate, executionDate);
        expect(
          completedVisit.technicianNotes,
          'Mantenimiento ejecutado satisfactoriamente',
        );

        // Comprobar que el Plan actualizó su próxima fecha: 30 días después
        final expectedNextDate = executionDate.add(const Duration(days: 30));
        final planDb = await maintenanceRepo.getPlanById('plan-ciclo');
        expect(planDb!.nextDate, expectedNextDate);

        // Comprobar que en el historial ahora existen 2 visitas (1 completada, 1 programada)
        final allVisits = await maintenanceRepo.getVisitsForPlan('plan-ciclo');
        expect(allVisits.length, 2);

        final nextVisit = allVisits.firstWhere((v) => v.id != firstVisitId);
        expect(nextVisit.status, model.VisitStatus.scheduled);
        expect(nextVisit.scheduledDate, expectedNextDate);
        expect(nextVisit.completedDate, isNull);
      },
    );

    test(
      '4. Múltiples visitas completadas conservan historial íntegro',
      () async {
        final plan = model.MaintenancePlan(
          id: 'plan-multi',
          title: 'Mantenimiento Riego',
          clientId: 'client-bbva',
          intervalDays: 15,
          nextDate: DateTime(2026, 1, 1),
        );
        await maintenanceRepo.createPlan(plan);

        // Ciclo 1: 01/01/2026
        var visits = await maintenanceRepo.getVisitsForPlan('plan-multi');
        var scheduledVisit = visits.firstWhere((v) => v.isScheduled);
        await maintenanceRepo.completeVisit(
          scheduledVisit.id,
          executedDate: DateTime(2026, 1, 1),
        );

        // Ciclo 2: 16/01/2026
        visits = await maintenanceRepo.getVisitsForPlan('plan-multi');
        scheduledVisit = visits.firstWhere((v) => v.isScheduled);
        await maintenanceRepo.completeVisit(
          scheduledVisit.id,
          executedDate: DateTime(2026, 1, 16),
        );

        // Ciclo 3: 31/01/2026
        visits = await maintenanceRepo.getVisitsForPlan('plan-multi');
        scheduledVisit = visits.firstWhere((v) => v.isScheduled);
        await maintenanceRepo.completeVisit(
          scheduledVisit.id,
          executedDate: DateTime(2026, 1, 31),
        );

        // Historial total: 3 completadas + 1 programada siguiente = 4 visitas
        final totalVisits = await maintenanceRepo.getVisitsForPlan(
          'plan-multi',
        );
        expect(totalVisits.length, 4);

        final completed = totalVisits.where((v) => v.isCompleted).toList();
        expect(completed.length, 3);
        expect(
          completed.any((v) => v.completedDate == DateTime(2026, 1, 1)),
          isTrue,
        );
        expect(
          completed.any((v) => v.completedDate == DateTime(2026, 1, 16)),
          isTrue,
        );
        expect(
          completed.any((v) => v.completedDate == DateTime(2026, 1, 31)),
          isTrue,
        );

        final nextScheduled = totalVisits.firstWhere((v) => v.isScheduled);
        expect(
          nextScheduled.scheduledDate,
          DateTime(2026, 1, 31).add(const Duration(days: 15)),
        );
      },
    );

    test(
      '5. WorkLog asociado a MaintenanceVisit y costo laboral derivado',
      () async {
        final plan = model.MaintenancePlan(
          id: 'plan-work',
          title: 'Plan Podado Alto',
          clientId: 'client-bbva',
          intervalDays: 30,
          nextDate: DateTime(2026, 3, 1),
        );
        await maintenanceRepo.createPlan(plan);
        final visits = await maintenanceRepo.getVisitsForPlan('plan-work');
        final visitId = visits.first.id;

        // Registrar 2 jornadas asociadas a la visita
        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log-v1',
            workerId: 'worker-jard',
            maintenanceVisitId: visitId,
            date: DateTime(2026, 3, 1),
            quantity: 1.0,
            rateCents: 6000,
            amountCents: 6000,
            notes: 'Jornada día 1',
          ),
        );
        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log-v2',
            workerId: 'worker-jard',
            maintenanceVisitId: visitId,
            date: DateTime(2026, 3, 1),
            quantity: 0.5,
            rateCents: 6000,
            amountCents: 3000,
            notes: 'Media jornada apoyo',
          ),
        );

        // Verificar costo laboral derivado de la visita
        final visitLaborCost = await maintenanceRepo.getVisitLaborCostCents(
          visitId,
        );
        expect(visitLaborCost, 9000); // S/ 90.00

        // Verificar consulta de jornadas de la visita
        final visitLogs = await maintenanceRepo
            .watchVisitWorkLogs(visitId)
            .first;
        expect(visitLogs.length, 2);
        expect(visitLogs.any((l) => l.id == 'log-v1'), isTrue);
        expect(visitLogs.any((l) => l.id == 'log-v2'), isTrue);
      },
    );

    test(
      '6. Regla XOR: WorkLog no puede tener projectId y maintenanceVisitId simultáneos ni vacíos',
      () async {
        // Intento con ambos
        final logAmbos = model.WorkLog(
          id: 'log-err-ambos',
          workerId: 'worker-jard',
          projectId: 'proj-alguna',
          maintenanceVisitId: 'visit-alguna',
          date: DateTime(2026, 3, 1),
          quantity: 1.0,
          rateCents: 6000,
          amountCents: 6000,
        );
        expect(
          () async => workLogRepo.createWorkLog(logAmbos),
          throwsArgumentError,
        );

        // Intento sin ninguno
        final logNinguno = model.WorkLog(
          id: 'log-err-ninguno',
          workerId: 'worker-jard',
          date: DateTime(2026, 3, 1),
          quantity: 1.0,
          rateCents: 6000,
          amountCents: 6000,
        );
        expect(
          () async => workLogRepo.createWorkLog(logNinguno),
          throwsArgumentError,
        );
      },
    );

    test(
      '7. Visita cancelada: cambia a cancelled y no programa siguiente ciclo',
      () async {
        final plan = model.MaintenancePlan(
          id: 'plan-canc',
          title: 'Plan Temporal',
          clientId: 'client-bbva',
          intervalDays: 30,
          nextDate: DateTime(2026, 3, 1),
        );
        await maintenanceRepo.createPlan(plan);
        final visits = await maintenanceRepo.getVisitsForPlan('plan-canc');
        final visitId = visits.first.id;

        await maintenanceRepo.cancelVisit(visitId, reason: 'Lluvia torrencial');

        final cancelledVisit = await maintenanceRepo.getVisitById(visitId);
        expect(cancelledVisit!.status, model.VisitStatus.cancelled);
        expect(cancelledVisit.isCancelled, isTrue);
        expect(cancelledVisit.technicianNotes, 'Lluvia torrencial');

        // No se creó una visita automática extra
        final allVisits = await maintenanceRepo.getVisitsForPlan('plan-canc');
        expect(allVisits.length, 1);
      },
    );

    test(
      '8. Cambio de frecuencia en Plan no altera visitas históricas ya ejecutadas',
      () async {
        final plan = model.MaintenancePlan(
          id: 'plan-freq',
          title: 'Plan Frecuencia Dinámica',
          clientId: 'client-bbva',
          intervalDays: 15,
          nextDate: DateTime(2026, 1, 1),
        );
        await maintenanceRepo.createPlan(plan);

        final visits = await maintenanceRepo.getVisitsForPlan('plan-freq');
        await maintenanceRepo.completeVisit(
          visits.first.id,
          executedDate: DateTime(2026, 1, 1),
        );

        // Modificar plan de 15 días a 45 días
        final planActualizado = plan.copyWith(
          frequencyType: 'unMesYMedio',
          intervalDays: 45,
        );
        await maintenanceRepo.updatePlan(planActualizado);

        // La visita histórica completada permanece intacta con su fecha 01/01/2026
        final historicVisit = await maintenanceRepo.getVisitById(
          visits.first.id,
        );
        expect(historicVisit!.completedDate, DateTime(2026, 1, 1));
        expect(historicVisit.isCompleted, isTrue);

        // El plan tiene ahora 45 días de frecuencia
        final planDb = await maintenanceRepo.getPlanById('plan-freq');
        expect(planDb!.intervalDays, 45);
        expect(planDb.frequencyType, 'unMesYMedio');
      },
    );

    test(
      '9. Eliminación (Soft Delete) de Plan cancela visitas programadas pendientes',
      () async {
        final plan = model.MaintenancePlan(
          id: 'plan-del',
          title: 'Plan a Eliminar',
          clientId: 'client-bbva',
          intervalDays: 30,
          nextDate: DateTime(2026, 3, 1),
        );
        await maintenanceRepo.createPlan(plan);

        await maintenanceRepo.deletePlan('plan-del');

        final planDb = await maintenanceRepo.getPlanById('plan-del');
        expect(planDb!.isDeleted, isTrue);

        final visits = await maintenanceRepo.getVisitsForPlan('plan-del');
        expect(visits.first.status, model.VisitStatus.cancelled);
      },
    );
  });
}
