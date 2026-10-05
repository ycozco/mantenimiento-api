import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/calendar_event.dart';

class CalendarService {
  final AppDatabase _db;

  CalendarService(this._db);

  /// Stream reactivo que emite eventos consolidados del calendario
  Stream<List<CalendarEvent>> watchEvents({
    CalendarSourceType? filterType,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.maintenanceVisits,
            _db.maintenancePlans,
            _db.clients,
            _db.projects,
            _db.toolAssignments,
            _db.tools,
          },
        )
        .watch()
        .asyncMap((_) async {
          return await getEvents(
            filterType: filterType,
            fromDate: fromDate,
            toDate: toDate,
          );
        });
  }

  /// Obtiene los eventos consolidados del calendario para un rango y filtro dados
  Future<List<CalendarEvent>> getEvents({
    CalendarSourceType? filterType,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final List<CalendarEvent> events = [];
    final now = DateTime.now();

    // 1. Visitas de Mantenimiento
    if (filterType == null ||
        filterType == CalendarSourceType.maintenanceVisit) {
      final visitQuery =
          _db.select(_db.maintenanceVisits).join([
            innerJoin(
              _db.maintenancePlans,
              _db.maintenancePlans.id.equalsExp(_db.maintenanceVisits.planId),
            ),
            innerJoin(
              _db.clients,
              _db.clients.id.equalsExp(_db.maintenancePlans.clientId),
            ),
          ])..where(
            _db.maintenanceVisits.deletedAt.isNull() &
                _db.maintenancePlans.deletedAt.isNull(),
          );

      final rows = await visitQuery.get();
      for (final r in rows) {
        final visit = r.readTable(_db.maintenanceVisits);
        final plan = r.readTable(_db.maintenancePlans);
        final client = r.readTable(_db.clients);

        final date = visit.scheduledDate.toLocal();

        // Rango de fechas
        if (fromDate != null && date.isBefore(fromDate)) continue;
        if (toDate != null && date.isAfter(toDate)) continue;

        String status = visit.status;
        String priority = 'normal';
        if (status == 'pending' && date.isBefore(now)) {
          status = 'overdue';
          priority = 'urgent';
        }

        events.add(
          CalendarEvent(
            id: 'visit-${visit.id}',
            sourceType: CalendarSourceType.maintenanceVisit,
            sourceId: visit.id,
            title: 'Mantenimiento: ${plan.title}',
            subtitle: 'Cliente: ${client.name}',
            startDate: date,
            status: status,
            priority: priority,
            metadata: {
              'planId': plan.id,
              'clientId': client.id,
              'notes': visit.technicianNotes,
            },
          ),
        );
      }
    }

    // 2. Obras (Proyectos)
    if (filterType == null || filterType == CalendarSourceType.project) {
      final projectQuery = _db.select(_db.projects).join([
        leftOuterJoin(
          _db.clients,
          _db.clients.id.equalsExp(_db.projects.clientId),
        ),
      ])..where(_db.projects.deletedAt.isNull());

      final rows = await projectQuery.get();
      for (final r in rows) {
        final project = r.readTable(_db.projects);
        final client = r.readTableOrNull(_db.clients);

        final startDate = project.startDate.toLocal();

        if (fromDate != null && startDate.isBefore(fromDate)) continue;
        if (toDate != null && startDate.isAfter(toDate)) continue;

        events.add(
          CalendarEvent(
            id: 'project-${project.id}',
            sourceType: CalendarSourceType.project,
            sourceId: project.id,
            title: 'Obra: ${project.name}',
            subtitle: client != null ? 'Cliente: ${client.name}' : null,
            startDate: startDate,
            endDate: project.targetEndDate?.toLocal(),
            status: project.status,
            priority: project.status == 'in_progress' ? 'normal' : 'low',
            metadata: {'budgetAmountCents': project.budgetAmountCents},
          ),
        );
      }
    }

    // 3. Devoluciones de Herramientas
    if (filterType == null || filterType == CalendarSourceType.toolReturn) {
      final toolQuery =
          _db.select(_db.toolAssignments).join([
            innerJoin(
              _db.tools,
              _db.tools.id.equalsExp(_db.toolAssignments.toolId),
            ),
          ])..where(
            _db.toolAssignments.deletedAt.isNull() &
                _db.toolAssignments.returnedAt.isNull() &
                _db.toolAssignments.expectedReturnAt.isNotNull(),
          );

      final rows = await toolQuery.get();
      for (final r in rows) {
        final assignment = r.readTable(_db.toolAssignments);
        final tool = r.readTable(_db.tools);

        final returnDate = assignment.expectedReturnAt!.toLocal();

        if (fromDate != null && returnDate.isBefore(fromDate)) continue;
        if (toDate != null && returnDate.isAfter(toDate)) continue;

        final isOverdue = returnDate.isBefore(now);
        final status = isOverdue ? 'overdue' : 'pending';
        final priority = isOverdue ? 'urgent' : 'normal';

        events.add(
          CalendarEvent(
            id: 'tool-return-${assignment.id}',
            sourceType: CalendarSourceType.toolReturn,
            sourceId: tool.id,
            title: 'Retorno: ${tool.name}',
            subtitle: 'Código: ${tool.code ?? "N/A"}',
            startDate: returnDate,
            status: status,
            priority: priority,
            metadata: {
              'assignmentId': assignment.id,
              'toolId': tool.id,
              'workerId': assignment.workerId,
              'projectId': assignment.projectId,
            },
          ),
        );
      }
    }

    // Orden cronológico estricto por startDate ascendente
    events.sort((a, b) => a.startDate.compareTo(b.startDate));

    return events;
  }
}
