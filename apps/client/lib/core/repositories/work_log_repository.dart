import 'package:drift/drift.dart';
import '../database/app_database.dart' hide WorkLog;
import '../models/work_log.dart';

class WorkLogRepository {
  final AppDatabase db;

  WorkLogRepository(this.db);

  void _validate(WorkLog log) {
    if (log.workerId.trim().isEmpty) {
      throw ArgumentError('El trabajador es obligatorio');
    }
    if (log.quantity <= 0) {
      throw ArgumentError('La cantidad debe ser mayor a 0');
    }
    if (log.rateCents < 0) {
      throw ArgumentError('La tarifa no puede ser negativa');
    }
    if (log.amountCents < 0) {
      throw ArgumentError('El monto total no puede ser negativo');
    }
    final hasProject = log.projectId != null && log.projectId!.isNotEmpty;
    final hasVisit =
        log.maintenanceVisitId != null && log.maintenanceVisitId!.isNotEmpty;
    if (!((hasProject && !hasVisit) || (!hasProject && hasVisit))) {
      throw ArgumentError(
        'La jornada debe pertenecer exactamente a una Obra o a una Visita de Mantenimiento (XOR)',
      );
    }
  }

  Stream<List<WorkLog>> watchProjectWorkLogs(String projectId) {
    return (db.select(db.workLogs)
          ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch()
        .map((rows) => rows.map(_fromDrift).toList());
  }

  Future<List<WorkLog>> getProjectWorkLogs(String projectId) async {
    final rows =
        await (db.select(db.workLogs)
              ..where(
                (t) => t.projectId.equals(projectId) & t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(_fromDrift).toList();
  }

  Stream<List<WorkLog>> watchWorkerWorkLogs(String workerId) {
    return (db.select(db.workLogs)
          ..where((t) => t.workerId.equals(workerId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch()
        .map((rows) => rows.map(_fromDrift).toList());
  }

  Future<List<WorkLog>> getWorkerWorkLogs(String workerId) async {
    final rows =
        await (db.select(db.workLogs)
              ..where((t) => t.workerId.equals(workerId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.date)]))
            .get();
    return rows.map(_fromDrift).toList();
  }

  Stream<int> watchProjectLaborCostCents(String projectId) {
    final sumColumn = db.workLogs.amountCents.sum();
    final query = db.selectOnly(db.workLogs)
      ..addColumns([sumColumn])
      ..where(
        db.workLogs.projectId.equals(projectId) &
            db.workLogs.deletedAt.isNull(),
      );

    return query.watchSingle().map((row) => row.read(sumColumn) ?? 0);
  }

  Future<int> getProjectLaborCostCents(String projectId) async {
    final sumColumn = db.workLogs.amountCents.sum();
    final query = db.selectOnly(db.workLogs)
      ..addColumns([sumColumn])
      ..where(
        db.workLogs.projectId.equals(projectId) &
            db.workLogs.deletedAt.isNull(),
      );

    final row = await query.getSingle();
    return row.read(sumColumn) ?? 0;
  }

  Future<int> getWorkerTotalDevengadoCents(String workerId) async {
    final sumColumn = db.workLogs.amountCents.sum();
    final query = db.selectOnly(db.workLogs)
      ..addColumns([sumColumn])
      ..where(
        db.workLogs.workerId.equals(workerId) & db.workLogs.deletedAt.isNull(),
      );

    final row = await query.getSingle();
    return row.read(sumColumn) ?? 0;
  }

  Future<int> getWorkerTotalJornadas(String workerId) async {
    final countColumn = db.workLogs.id.count();
    final query = db.selectOnly(db.workLogs)
      ..addColumns([countColumn])
      ..where(
        db.workLogs.workerId.equals(workerId) & db.workLogs.deletedAt.isNull(),
      );

    final row = await query.getSingle();
    return row.read(countColumn) ?? 0;
  }

  Future<void> createWorkLog(WorkLog log) async {
    _validate(log);

    await db
        .into(db.workLogs)
        .insert(
          WorkLogsCompanion.insert(
            id: log.id,
            workspaceId: Value(log.workspaceId),
            workerId: log.workerId,
            date: log.date,
            projectId: Value(log.projectId),
            maintenanceVisitId: Value(log.maintenanceVisitId),
            paymentType: Value(log.paymentType),
            quantity: Value(log.quantity),
            rateCents: Value(log.rateCents),
            amountCents: Value(log.amountCents),
            notes: Value(log.notes),
            createdAt: Value(log.createdAt),
            updatedAt: Value(log.updatedAt),
            createdBy: Value(log.createdBy),
            updatedBy: Value(log.updatedBy),
            version: Value(log.version),
            deletedAt: Value(log.deletedAt),
          ),
        );
  }

  Future<void> updateWorkLog(WorkLog log) async {
    _validate(log);

    await (db.update(db.workLogs)..where((t) => t.id.equals(log.id))).write(
      WorkLogsCompanion(
        workerId: Value(log.workerId),
        date: Value(log.date),
        projectId: Value(log.projectId),
        maintenanceVisitId: Value(log.maintenanceVisitId),
        paymentType: Value(log.paymentType),
        quantity: Value(log.quantity),
        rateCents: Value(log.rateCents),
        amountCents: Value(log.amountCents),
        notes: Value(log.notes),
        updatedAt: Value(DateTime.now()),
        updatedBy: Value(log.updatedBy),
        version: Value(log.version + 1),
      ),
    );
  }

  Future<void> voidWorkLog(String id) async {
    await (db.update(db.workLogs)..where((t) => t.id.equals(id))).write(
      WorkLogsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  WorkLog _fromDrift(dynamic row) {
    return WorkLog(
      id: row.id as String,
      workspaceId: row.workspaceId as String,
      workerId: row.workerId as String,
      projectId: row.projectId as String?,
      maintenanceVisitId: row.maintenanceVisitId as String?,
      date: row.date as DateTime,
      paymentType: row.paymentType as String,
      quantity: (row.quantity as num).toDouble(),
      rateCents: row.rateCents as int,
      amountCents: row.amountCents as int,
      notes: row.notes as String?,
      createdAt: row.createdAt as DateTime,
      updatedAt: row.updatedAt as DateTime,
      createdBy: row.createdBy as String?,
      updatedBy: row.updatedBy as String?,
      version: row.version as int,
      deletedAt: row.deletedAt as DateTime?,
    );
  }
}
