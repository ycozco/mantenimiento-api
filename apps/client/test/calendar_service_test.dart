import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/calendar_event.dart';
import 'package:mantenimiento_app/core/models/tool.dart' as model;
import 'package:mantenimiento_app/core/models/tool_assignment.dart' as model;
import 'package:mantenimiento_app/core/repositories/tool_repository.dart';
import 'package:mantenimiento_app/core/services/calendar_service.dart';

void main() {
  late AppDatabase db;
  late CalendarService calendarService;
  late ToolRepository toolRepo;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    calendarService = CalendarService(db);
    toolRepo = ToolRepository(db);

    // Setup base clients
    await db
        .into(db.clients)
        .insert(
          ClientsCompanion.insert(id: 'client-1', name: 'Condominio El Prado'),
        );

    // Setup base maintenance plan
    await db
        .into(db.maintenancePlans)
        .insert(
          MaintenancePlansCompanion.insert(
            id: 'plan-1',
            clientId: 'client-1',
            title: 'Mantenimiento Semanal Áreas Verdes',
          ),
        );

    // Setup base worker for tool assignments
    await db
        .into(db.workers)
        .insert(WorkersCompanion.insert(id: 'worker-1', name: 'Operario Base'));
  });

  tearDown(() async {
    await db.close();
  });

  test('1. Visita programada aparece como evento de mantenimiento', () async {
    final scheduled = DateTime(2026, 10, 15, 10, 0);
    await db
        .into(db.maintenanceVisits)
        .insert(
          MaintenanceVisitsCompanion.insert(
            id: 'visit-1',
            planId: 'plan-1',
            scheduledDate: scheduled,
            status: const Value('pending'),
          ),
        );

    final events = await calendarService.getEvents();
    expect(events.length, equals(1));

    final event = events.first;
    expect(event.sourceType, equals(CalendarSourceType.maintenanceVisit));
    expect(event.sourceId, equals('visit-1'));
    expect(event.title, contains('Mantenimiento Semanal Áreas Verdes'));
    expect(event.subtitle, contains('Condominio El Prado'));
    expect(event.status, equals('pending'));
    expect(event.startDate, equals(scheduled.toLocal()));
  });

  test(
    '2. Visita cancelada se representa con su estado correspondiente',
    () async {
      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'visit-canc',
              planId: 'plan-1',
              scheduledDate: DateTime(2026, 10, 20),
              status: const Value('cancelled'),
            ),
          );

      final events = await calendarService.getEvents();
      expect(events.length, equals(1));
      expect(events.first.status, equals('cancelled'));
      expect(events.first.statusLabel, equals('Cancelado'));
    },
  );

  test('3. Visita completada histórica', () async {
    await db
        .into(db.maintenanceVisits)
        .insert(
          MaintenanceVisitsCompanion.insert(
            id: 'visit-comp',
            planId: 'plan-1',
            scheduledDate: DateTime(2026, 10, 1),
            status: const Value('completed'),
          ),
        );

    final events = await calendarService.getEvents();
    expect(events.length, equals(1));
    expect(events.first.status, equals('completed'));
    expect(events.first.statusLabel, equals('Completado'));
  });

  test(
    '4. Devolución de herramienta con expectedReturnAt aparece en calendario',
    () async {
      final tool = model.Tool.create(
        id: 'tool-honda',
        code: 'COR-01',
        name: 'Cortacésped Honda',
      );
      await toolRepo.createTool(tool);

      // Asignar con fecha esperada de retorno
      final returnDate = DateTime(2026, 10, 18, 17, 0);
      await toolRepo.assignTool(
        model.ToolAssignment.create(
          id: 'asg-tool-1',
          toolId: tool.id,
          workerId: 'worker-1',
          notes: 'Uso en sede norte',
          expectedReturnAt: returnDate,
        ),
      );

      final events = await calendarService.getEvents(
        filterType: CalendarSourceType.toolReturn,
      );
      expect(events.length, equals(1));

      final event = events.first;
      expect(event.sourceType, equals(CalendarSourceType.toolReturn));
      expect(event.sourceId, equals(tool.id));
      expect(event.title, contains('Cortacésped Honda'));
      expect(event.startDate, equals(returnDate.toLocal()));
    },
  );

  test('5. Proyecto/Obra con fechas de inicio y fin estimada', () async {
    final start = DateTime(2026, 10, 10);
    final targetEnd = DateTime(2026, 11, 10);

    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-1',
            clientId: const Value('client-1'),
            name: 'Paisajismo Edificio Panorámico',
            startDate: start,
            targetEndDate: Value(targetEnd),
            status: const Value('in_progress'),
          ),
        );

    final events = await calendarService.getEvents(
      filterType: CalendarSourceType.project,
    );
    expect(events.length, equals(1));

    final event = events.first;
    expect(event.sourceType, equals(CalendarSourceType.project));
    expect(event.sourceId, equals('proj-1'));
    expect(event.title, contains('Paisajismo Edificio Panorámico'));
    expect(event.startDate, equals(start.toLocal()));
    expect(event.endDate, equals(targetEnd.toLocal()));
  });

  test('6. Filtros de origen funcionan selectivamente', () async {
    // 1 visita
    await db
        .into(db.maintenanceVisits)
        .insert(
          MaintenanceVisitsCompanion.insert(
            id: 'v1',
            planId: 'plan-1',
            scheduledDate: DateTime(2026, 10, 10),
          ),
        );

    // 1 proyecto
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'p1',
            name: 'Obra Central',
            startDate: DateTime(2026, 10, 12),
          ),
        );

    // 1 herramienta
    final tool = model.Tool.create(id: 't1', name: 'Motosierra');
    await toolRepo.createTool(tool);
    await toolRepo.assignTool(
      model.ToolAssignment.create(
        id: 'asg-1',
        toolId: tool.id,
        workerId: 'worker-1',
        expectedReturnAt: DateTime(2026, 10, 14),
      ),
    );

    // Todos
    final allEvents = await calendarService.getEvents();
    expect(allEvents.length, equals(3));

    // Solo Mantenimientos
    final visitEvents = await calendarService.getEvents(
      filterType: CalendarSourceType.maintenanceVisit,
    );
    expect(visitEvents.length, equals(1));
    expect(
      visitEvents.first.sourceType,
      equals(CalendarSourceType.maintenanceVisit),
    );

    // Solo Obras
    final projectEvents = await calendarService.getEvents(
      filterType: CalendarSourceType.project,
    );
    expect(projectEvents.length, equals(1));
    expect(projectEvents.first.sourceType, equals(CalendarSourceType.project));

    // Solo Herramientas
    final toolEvents = await calendarService.getEvents(
      filterType: CalendarSourceType.toolReturn,
    );
    expect(toolEvents.length, equals(1));
    expect(toolEvents.first.sourceType, equals(CalendarSourceType.toolReturn));
  });

  test(
    '7. Orden cronológico estricto de eventos por startDate ascendente',
    () async {
      // Evento del día 20
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'p-tarde',
              name: 'Obra Tardía',
              startDate: DateTime(2026, 10, 20),
            ),
          );

      // Evento del día 5
      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'v-temprano',
              planId: 'plan-1',
              scheduledDate: DateTime(2026, 10, 5),
            ),
          );

      // Evento del día 12
      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'v-medio',
              planId: 'plan-1',
              scheduledDate: DateTime(2026, 10, 12),
            ),
          );

      final events = await calendarService.getEvents();
      expect(events.length, equals(3));
      expect(events[0].sourceId, equals('v-temprano'));
      expect(events[1].sourceId, equals('v-medio'));
      expect(events[2].sourceId, equals('p-tarde'));
    },
  );

  test(
    '8. Eventos el mismo día se ordenan por hora y conservan unicidad',
    () async {
      final date1 = DateTime(2026, 10, 15, 8, 30);
      final date2 = DateTime(2026, 10, 15, 14, 0);

      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'v-manana',
              planId: 'plan-1',
              scheduledDate: date1,
            ),
          );

      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'v-tarde',
              planId: 'plan-1',
              scheduledDate: date2,
            ),
          );

      final events = await calendarService.getEvents();
      expect(events.length, equals(2));
      expect(events[0].startDate, equals(date1.toLocal()));
      expect(events[1].startDate, equals(date2.toLocal()));
      expect(events[0].id, isNot(equals(events[1].id)));
    },
  );

  test('9. Navegación / sourceId válido en todos los orígenes', () async {
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-val',
            name: 'Obra Valid',
            startDate: DateTime(2026, 10, 10),
          ),
        );

    await db
        .into(db.maintenanceVisits)
        .insert(
          MaintenanceVisitsCompanion.insert(
            id: 'visit-val',
            planId: 'plan-1',
            scheduledDate: DateTime(2026, 10, 11),
          ),
        );

    final tool = model.Tool.create(id: 'tool-val', name: 'Taladro');
    await toolRepo.createTool(tool);
    await toolRepo.assignTool(
      model.ToolAssignment.create(
        id: 'asg-val',
        toolId: tool.id,
        workerId: 'worker-1',
        expectedReturnAt: DateTime(2026, 10, 12),
      ),
    );

    final events = await calendarService.getEvents();
    for (final e in events) {
      expect(e.sourceId, isNotEmpty);
      expect(e.id, isNotEmpty);
      if (e.sourceType == CalendarSourceType.project) {
        expect(e.sourceId, equals('proj-val'));
      } else if (e.sourceType == CalendarSourceType.maintenanceVisit) {
        expect(e.sourceId, equals('visit-val'));
      } else if (e.sourceType == CalendarSourceType.toolReturn) {
        expect(e.sourceId, equals('tool-val'));
      }
    }
  });

  test(
    '10. Cero duplicación de datos: el calendario deriva dinámicamente',
    () async {
      // Si la visita se reprograma, el calendario refleja la nueva fecha inmediatamente
      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'v-reprog',
              planId: 'plan-1',
              scheduledDate: DateTime(2026, 10, 10),
            ),
          );

      var events = await calendarService.getEvents();
      expect(events.first.startDate, equals(DateTime(2026, 10, 10).toLocal()));

      // Reprogramar en la tabla origen
      await (db.update(
        db.maintenanceVisits,
      )..where((t) => t.id.equals('v-reprog'))).write(
        MaintenanceVisitsCompanion(
          scheduledDate: Value(DateTime(2026, 10, 25)),
        ),
      );

      events = await calendarService.getEvents();
      expect(events.length, equals(1));
      expect(events.first.startDate, equals(DateTime(2026, 10, 25).toLocal()));
    },
  );
}
