import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/tool.dart' as model;
import 'package:mantenimiento_app/core/models/tool_assignment.dart' as model;
import 'package:mantenimiento_app/core/repositories/tool_repository.dart';

void main() {
  late AppDatabase db;
  late ToolRepository repo;
  const testWorkspace = 'test-workspace';

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    repo = ToolRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('T-06: Pruebas de Tools y ToolAssignments (Ciclo de Vida y Custodia)', () {
    test('1. Crear herramienta nace en estado available', () async {
      final desbrozadora = model.Tool.create(
        workspaceId: testWorkspace,
        code: 'DESB-001',
        name: 'Desbrozadora Stihl FS 55',
        category: 'motorized',
        brandModel: 'Stihl FS 55',
        purchasePriceCents: 150000, // S/ 1500.00
      );
      await repo.createTool(desbrozadora);

      final guardada = await repo.getTool(desbrozadora.id);
      expect(guardada, isNotNull);
      expect(guardada!.currentStatus, 'available');
      expect(guardada.condition, 'good');
      expect(guardada.isAvailable, isTrue);
    });

    test('2. Asignar herramienta cambia estado a assigned', () async {
      final podadora = model.Tool.create(
        workspaceId: testWorkspace,
        code: 'POD-001',
        name: 'Podadora de Altura',
      );
      await repo.createTool(podadora);

      // Crear trabajador para asignación
      final workerRow = await db
          .into(db.workers)
          .insertReturning(
            WorkersCompanion.insert(id: const Uuid().v4(), name: 'Juan Perez'),
          );

      // Asignar
      final asignacion = model.ToolAssignment.create(
        workspaceId: testWorkspace,
        toolId: podadora.id,
        workerId: workerRow.id,
      );
      await repo.assignTool(asignacion);

      // Herramienta debe estar assigned
      final toolActualizada = await repo.getTool(podadora.id);
      expect(toolActualizada!.currentStatus, 'assigned');
      expect(toolActualizada.isAssigned, isTrue);

      final asignacionActiva = await repo.getActiveAssignment(podadora.id);
      expect(asignacionActiva, isNotNull);
      expect(asignacionActiva!.workerId, workerRow.id);
      expect(asignacionActiva.returnedAt, isNull);
    });

    test(
      '3. Invariante Crítica: Segunda asignación activa simultánea es RECHAZADA',
      () async {
        final taladro = model.Tool.create(name: 'Taladro Percutor');
        await repo.createTool(taladro);

        final worker1 = await db
            .into(db.workers)
            .insertReturning(
              WorkersCompanion.insert(
                id: const Uuid().v4(),
                name: 'Carlos Ruiz',
              ),
            );
        final worker2 = await db
            .into(db.workers)
            .insertReturning(
              WorkersCompanion.insert(
                id: const Uuid().v4(),
                name: 'Manuel Gomez',
              ),
            );

        // Primera asignación a Carlos
        final asignacion1 = model.ToolAssignment.create(
          toolId: taladro.id,
          workerId: worker1.id,
        );
        await repo.assignTool(asignacion1);

        // Segunda asignación simultánea a Manuel mientras está prestada
        final asignacion2 = model.ToolAssignment.create(
          toolId: taladro.id,
          workerId: worker2.id,
        );

        expect(
          () async => await repo.assignTool(asignacion2),
          throwsA(isA<StateError>()),
        );

        // El custodio sigue siendo Carlos exclusivamente
        final activo = await repo.getActiveAssignment(taladro.id);
        expect(activo!.workerId, worker1.id);
      },
    );

    test('4. Devolver herramienta cambia estado a available', () async {
      final tijera = model.Tool.create(name: 'Tijera de Podar Bypass');
      await repo.createTool(tijera);

      final worker = await db
          .into(db.workers)
          .insertReturning(
            WorkersCompanion.insert(id: const Uuid().v4(), name: 'Pedro Soto'),
          );

      final asignacion = model.ToolAssignment.create(
        toolId: tijera.id,
        workerId: worker.id,
      );
      await repo.assignTool(asignacion);

      // Registrar devolución
      await repo.returnTool(
        assignmentId: asignacion.id,
        conditionIn: 'good',
        notes: 'Devuelta limpia y afilada',
      );

      final tool = await repo.getTool(tijera.id);
      expect(tool!.currentStatus, 'available');
      expect(tool.isAvailable, isTrue);

      final activa = await repo.getActiveAssignment(tijera.id);
      expect(activa, isNull); // Ya no hay custodia activa
    });

    test(
      '5. Reasignar tras devolución: Historial de custodia se conserva íntegro',
      () async {
        final motosierra = model.Tool.create(name: 'Motosierra Husqvarna');
        await repo.createTool(motosierra);

        final w1 = await db
            .into(db.workers)
            .insertReturning(
              WorkersCompanion.insert(
                id: const Uuid().v4(),
                name: 'Trabajador 1',
              ),
            );
        final w2 = await db
            .into(db.workers)
            .insertReturning(
              WorkersCompanion.insert(
                id: const Uuid().v4(),
                name: 'Trabajador 2',
              ),
            );

        // 1. Prestada a W1
        final a1 = model.ToolAssignment.create(
          toolId: motosierra.id,
          workerId: w1.id,
        );
        await repo.assignTool(a1);

        // 2. Devuelta por W1
        await repo.returnTool(assignmentId: a1.id);

        // 3. Prestada a W2
        final a2 = model.ToolAssignment.create(
          toolId: motosierra.id,
          workerId: w2.id,
        );
        await repo.assignTool(a2);

        // Historial total debe tener exactamente 2 registros cronológicos
        final historial = await repo.watchToolHistory(motosierra.id).first;
        expect(historial.length, 2);
        expect(
          historial.any((h) => h.workerId == w1.id && h.isReturned),
          isTrue,
        );
        expect(historial.any((h) => h.workerId == w2.id && h.isActive), isTrue);
      },
    );

    test('6. Asignación directa a Obra (Project)', () async {
      final pala = model.Tool.create(name: 'Pala Carbonera');
      await repo.createTool(pala);

      final client = await db
          .into(db.clients)
          .insertReturning(
            ClientsCompanion.insert(
              id: const Uuid().v4(),
              name: 'Cliente Obra',
            ),
          );
      final project = await db
          .into(db.projects)
          .insertReturning(
            ProjectsCompanion.insert(
              id: const Uuid().v4(),
              clientId: Value(client.id),
              name: 'Obra Cerco',
              startDate: DateTime.now(),
            ),
          );

      final asignacionObra = model.ToolAssignment.create(
        toolId: pala.id,
        projectId: project.id,
      );
      await repo.assignTool(asignacionObra);

      final obraTools = await repo
          .watchProjectActiveAssignments(project.id)
          .first;
      expect(obraTools.length, 1);
      expect(obraTools.first.toolId, pala.id);
    });

    test('7. Asignación directa a Visita de Mantenimiento', () async {
      final soplador = model.Tool.create(name: 'Soplador de Hojas');
      await repo.createTool(soplador);

      final client = await db
          .into(db.clients)
          .insertReturning(
            ClientsCompanion.insert(
              id: const Uuid().v4(),
              name: 'Cliente Visita',
            ),
          );
      final plan = await db
          .into(db.maintenancePlans)
          .insertReturning(
            MaintenancePlansCompanion.insert(
              id: const Uuid().v4(),
              clientId: client.id,
              title: 'Mantenimiento Mensual',
              nextDate: Value(DateTime.now()),
            ),
          );
      final visit = await db
          .into(db.maintenanceVisits)
          .insertReturning(
            MaintenanceVisitsCompanion.insert(
              id: const Uuid().v4(),
              planId: plan.id,
              scheduledDate: DateTime.now(),
            ),
          );

      final asignacionVisita = model.ToolAssignment.create(
        toolId: soplador.id,
        maintenanceVisitId: visit.id,
      );
      await repo.assignTool(asignacionVisita);

      final visitTools = await repo.watchVisitActiveAssignments(visit.id).first;
      expect(visitTools.length, 1);
      expect(visitTools.first.toolId, soplador.id);
    });

    test(
      '8. FK de SQLite: Asignar herramienta inexistente es rechazado',
      () async {
        final worker = await db
            .into(db.workers)
            .insertReturning(
              WorkersCompanion.insert(
                id: const Uuid().v4(),
                name: 'Trabajador',
              ),
            );

        final asignacionInvalida = model.ToolAssignment.create(
          toolId: 'tool-no-existe-en-db',
          workerId: worker.id,
        );

        expect(
          () async => await repo.assignTool(asignacionInvalida),
          throwsA(anything),
        );
      },
    );

    test(
      '9. Herramienta en mantenimiento o retirada NO puede asignarse',
      () async {
        final cortasetos = model.Tool.create(name: 'Cortasetos Stihl');
        await repo.createTool(cortasetos);

        // Enviar a taller
        await repo.sendToMaintenance(cortasetos.id);
        var tool = await repo.getTool(cortasetos.id);
        expect(tool!.currentStatus, 'maintenance');

        final worker = await db
            .into(db.workers)
            .insertReturning(
              WorkersCompanion.insert(id: const Uuid().v4(), name: 'Operario'),
            );

        // Intentar asignar en mantenimiento debe fallar
        expect(
          () async => await repo.assignTool(
            model.ToolAssignment.create(
              toolId: cortasetos.id,
              workerId: worker.id,
            ),
          ),
          throwsA(isA<StateError>()),
        );

        // Marcar disponible, luego retirar/dar de baja
        await repo.markAvailable(cortasetos.id);
        await repo.retireTool(
          cortasetos.id,
          reason: 'Motor fundido, incosteable',
        );

        tool = await repo.getTool(cortasetos.id);
        expect(tool!.currentStatus, 'retired');

        // Intentar asignar herramienta retirada debe fallar
        expect(
          () async => await repo.assignTool(
            model.ToolAssignment.create(
              toolId: cortasetos.id,
              workerId: worker.id,
            ),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
