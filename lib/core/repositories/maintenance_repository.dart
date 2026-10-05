import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart'
    hide MaintenancePlan, MaintenanceVisit, WorkLog;
import '../models/maintenance_plan.dart';
import '../models/maintenance_visit.dart';
import '../models/work_log.dart';

class MaintenanceRepository {
  final AppDatabase db;

  MaintenanceRepository(this.db);

  Stream<List<MaintenancePlan>> watchActivePlans() {
    return (db.select(db.maintenancePlans)
          ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.nextDate)]))
        .watch()
        .map((rows) => rows.map(_planFromDrift).toList());
  }

  Stream<List<MaintenancePlan>> watchAllPlans() {
    return (db.select(db.maintenancePlans)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.title)]))
        .watch()
        .map((rows) => rows.map(_planFromDrift).toList());
  }

  Future<MaintenancePlan?> getPlanById(String id) async {
    final row = await (db.select(
      db.maintenancePlans,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _planFromDrift(row);
  }

  Future<void> createPlan(
    MaintenancePlan plan, {
    DateTime? firstVisitDate,
  }) async {
    if (plan.title.trim().isEmpty) {
      throw ArgumentError('El título del plan es obligatorio');
    }
    if (plan.clientId.trim().isEmpty) {
      throw ArgumentError('El cliente es obligatorio');
    }

    await db.transaction(() async {
      final scheduledFirstDate = firstVisitDate ?? plan.nextDate;

      // 1. Guardar Plan Recurrente
      await db
          .into(db.maintenancePlans)
          .insert(
            MaintenancePlansCompanion.insert(
              id: plan.id,
              workspaceId: Value(plan.workspaceId),
              title: plan.title.trim(),
              clientId: plan.clientId,
              locationId: Value(plan.locationId),
              description: Value(plan.description),
              frequencyType: Value(plan.frequencyType),
              intervalDays: Value(plan.intervalDays),
              nextDate: Value(scheduledFirstDate),
              estimatedCostCents: Value(plan.estimatedCostCents),
              assignedPartnerIdsJson: Value(
                jsonEncode(plan.assignedPartnerIds),
              ),
              isActive: Value(plan.isActive),
              createdAt: Value(plan.createdAt),
              updatedAt: Value(plan.updatedAt),
              createdBy: Value(plan.createdBy),
              updatedBy: Value(plan.updatedBy),
              version: Value(plan.version),
              deletedAt: Value(plan.deletedAt),
            ),
          );

      // 2. Programar automáticamente la primera visita
      final firstVisit = MaintenanceVisit(
        planId: plan.id,
        scheduledDate: scheduledFirstDate,
        status: VisitStatus.scheduled,
      );

      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: firstVisit.id,
              workspaceId: Value(firstVisit.workspaceId),
              planId: firstVisit.planId,
              scheduledDate: firstVisit.scheduledDate,
              status: Value(firstVisit.status.nameCode),
              createdAt: Value(firstVisit.createdAt),
              updatedAt: Value(firstVisit.updatedAt),
              version: Value(firstVisit.version),
            ),
          );
    });
  }

  Future<void> updatePlan(MaintenancePlan plan) async {
    if (plan.title.trim().isEmpty) {
      throw ArgumentError('El título del plan no puede estar vacío');
    }

    await (db.update(
      db.maintenancePlans,
    )..where((t) => t.id.equals(plan.id))).write(
      MaintenancePlansCompanion(
        title: Value(plan.title.trim()),
        locationId: Value(plan.locationId),
        description: Value(plan.description),
        frequencyType: Value(plan.frequencyType),
        intervalDays: Value(plan.intervalDays),
        nextDate: Value(plan.nextDate),
        estimatedCostCents: Value(plan.estimatedCostCents),
        assignedPartnerIdsJson: Value(jsonEncode(plan.assignedPartnerIds)),
        isActive: Value(plan.isActive),
        updatedAt: Value(DateTime.now()),
        updatedBy: Value(plan.updatedBy),
        version: Value(plan.version + 1),
      ),
    );
  }

  Future<void> deletePlan(String planId) async {
    await db.transaction(() async {
      final now = DateTime.now();
      await (db.update(
        db.maintenancePlans,
      )..where((t) => t.id.equals(planId))).write(
        MaintenancePlansCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );

      // Cancelar visitas que estuvieran programadas
      await (db.update(db.maintenanceVisits)..where(
            (t) => t.planId.equals(planId) & t.status.equals('scheduled'),
          ))
          .write(
            MaintenanceVisitsCompanion(
              status: const Value('cancelled'),
              updatedAt: Value(now),
            ),
          );
    });
  }

  // --- VISITAS (HISTORIAL REAL DE EJECUCIÓN) ---

  Stream<List<MaintenanceVisit>> watchVisitsForPlan(String planId) {
    return (db.select(db.maintenanceVisits)
          ..where((t) => t.planId.equals(planId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.scheduledDate)]))
        .watch()
        .map((rows) => rows.map(_visitFromDrift).toList());
  }

  Future<List<MaintenanceVisit>> getVisitsForPlan(String planId) async {
    final rows =
        await (db.select(db.maintenanceVisits)
              ..where((t) => t.planId.equals(planId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.scheduledDate)]))
            .get();
    return rows.map(_visitFromDrift).toList();
  }

  Future<MaintenanceVisit?> getVisitById(String id) async {
    final row = await (db.select(
      db.maintenanceVisits,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _visitFromDrift(row);
  }

  Future<void> createVisit(MaintenanceVisit visit) async {
    await db
        .into(db.maintenanceVisits)
        .insert(
          MaintenanceVisitsCompanion.insert(
            id: visit.id,
            workspaceId: Value(visit.workspaceId),
            planId: visit.planId,
            scheduledDate: visit.scheduledDate,
            completedDate: Value(visit.completedDate),
            status: Value(visit.status.nameCode),
            technicianNotes: Value(visit.technicianNotes),
            createdAt: Value(visit.createdAt),
            updatedAt: Value(visit.updatedAt),
            version: Value(visit.version),
            deletedAt: Value(visit.deletedAt),
          ),
        );
  }

  Future<void> startVisit(String visitId) async {
    await (db.update(
      db.maintenanceVisits,
    )..where((t) => t.id.equals(visitId))).write(
      MaintenanceVisitsCompanion(
        status: const Value('inProgress'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Completa una visita preservando el historial y programa la siguiente visita.
  Future<MaintenanceVisit> completeVisit(
    String visitId, {
    DateTime? executedDate,
    String? notes,
  }) async {
    return await db.transaction(() async {
      final now = executedDate ?? DateTime.now();

      // 1. Obtener visita actual
      final visitRow = await (db.select(
        db.maintenanceVisits,
      )..where((t) => t.id.equals(visitId))).getSingle();
      final currentVisit = _visitFromDrift(visitRow);

      // 2. Marcar visita actual como completada
      await (db.update(
        db.maintenanceVisits,
      )..where((t) => t.id.equals(visitId))).write(
        MaintenanceVisitsCompanion(
          status: const Value('completed'),
          completedDate: Value(now),
          technicianNotes: notes != null
              ? Value(notes)
              : Value(currentVisit.technicianNotes),
          updatedAt: Value(DateTime.now()),
          version: Value(currentVisit.version + 1),
        ),
      );

      // 3. Obtener el plan padre
      final planRow = await (db.select(
        db.maintenancePlans,
      )..where((t) => t.id.equals(currentVisit.planId))).getSingle();
      final plan = _planFromDrift(planRow);

      // 4. Calcular la próxima fecha del plan a partir de la fecha de ejecución
      final nextDate = plan.calculateNextCycle(now);

      // 5. Actualizar nextDate del Plan
      await (db.update(
        db.maintenancePlans,
      )..where((t) => t.id.equals(plan.id))).write(
        MaintenancePlansCompanion(
          nextDate: Value(nextDate),
          updatedAt: Value(DateTime.now()),
          version: Value(plan.version + 1),
        ),
      );

      // 6. Programar la siguiente visita
      final nextVisit = MaintenanceVisit(
        planId: plan.id,
        scheduledDate: nextDate,
        status: VisitStatus.scheduled,
      );

      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: nextVisit.id,
              workspaceId: Value(nextVisit.workspaceId),
              planId: nextVisit.planId,
              scheduledDate: nextVisit.scheduledDate,
              status: Value(nextVisit.status.nameCode),
              createdAt: Value(nextVisit.createdAt),
              updatedAt: Value(nextVisit.updatedAt),
              version: Value(nextVisit.version),
            ),
          );

      return currentVisit.copyWith(
        status: VisitStatus.completed,
        completedDate: now,
        technicianNotes: notes ?? currentVisit.technicianNotes,
      );
    });
  }

  Future<void> cancelVisit(String visitId, {String? reason}) async {
    await (db.update(
      db.maintenanceVisits,
    )..where((t) => t.id.equals(visitId))).write(
      MaintenanceVisitsCompanion(
        status: const Value('cancelled'),
        technicianNotes: reason != null ? Value(reason) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> rescheduleVisit(
    String visitId,
    DateTime newScheduledDate,
  ) async {
    await (db.update(
      db.maintenanceVisits,
    )..where((t) => t.id.equals(visitId))).write(
      MaintenanceVisitsCompanion(
        scheduledDate: Value(newScheduledDate),
        status: const Value('scheduled'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // --- COSTOS LABORALES ASOCIADOS A LA VISITA ---

  Stream<int> watchVisitLaborCostCents(String visitId) {
    final sumColumn = db.workLogs.amountCents.sum();
    final query = db.selectOnly(db.workLogs)
      ..addColumns([sumColumn])
      ..where(
        db.workLogs.maintenanceVisitId.equals(visitId) &
            db.workLogs.deletedAt.isNull(),
      );

    return query.watchSingle().map((row) => row.read(sumColumn) ?? 0);
  }

  Future<int> getVisitLaborCostCents(String visitId) async {
    final sumColumn = db.workLogs.amountCents.sum();
    final query = db.selectOnly(db.workLogs)
      ..addColumns([sumColumn])
      ..where(
        db.workLogs.maintenanceVisitId.equals(visitId) &
            db.workLogs.deletedAt.isNull(),
      );

    final row = await query.getSingle();
    return row.read(sumColumn) ?? 0;
  }

  Stream<List<WorkLog>> watchVisitWorkLogs(String visitId) {
    return (db.select(db.workLogs)
          ..where(
            (t) => t.maintenanceVisitId.equals(visitId) & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (r) => WorkLog(
                  id: r.id,
                  workspaceId: r.workspaceId,
                  workerId: r.workerId,
                  projectId: r.projectId,
                  maintenanceVisitId: r.maintenanceVisitId,
                  date: r.date,
                  paymentType: r.paymentType,
                  quantity: r.quantity,
                  rateCents: r.rateCents,
                  amountCents: r.amountCents,
                  notes: r.notes,
                  createdAt: r.createdAt,
                  updatedAt: r.updatedAt,
                  createdBy: r.createdBy,
                  updatedBy: r.updatedBy,
                  version: r.version,
                  deletedAt: r.deletedAt,
                ),
              )
              .toList(),
        );
  }

  MaintenancePlan _planFromDrift(dynamic row) {
    List<String> partnerIds = [];
    try {
      if (row.assignedPartnerIdsJson != null) {
        final decoded = jsonDecode(row.assignedPartnerIdsJson);
        if (decoded is List) {
          partnerIds = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    return MaintenancePlan(
      id: row.id,
      workspaceId: row.workspaceId,
      title: row.title,
      clientId: row.clientId,
      locationId: row.locationId,
      description: row.description,
      frequencyType: row.frequencyType,
      intervalDays: row.intervalDays,
      nextDate: row.nextDate ?? DateTime.now(),
      estimatedCostCents: row.estimatedCostCents,
      assignedPartnerIds: partnerIds,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      version: row.version,
      deletedAt: row.deletedAt,
    );
  }

  MaintenanceVisit _visitFromDrift(dynamic row) {
    return MaintenanceVisit(
      id: row.id,
      workspaceId: row.workspaceId,
      planId: row.planId,
      scheduledDate: row.scheduledDate,
      completedDate: row.completedDate,
      status: VisitStatusExt.fromString(row.status),
      technicianNotes: row.technicianNotes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      version: row.version,
      deletedAt: row.deletedAt,
    );
  }
}
