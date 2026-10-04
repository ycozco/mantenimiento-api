import 'package:drift/drift.dart';
import '../database/app_database.dart' hide Worker;
import '../models/worker.dart';

class WorkerRepository {
  final AppDatabase db;

  WorkerRepository(this.db);

  Stream<List<Worker>> watchAllWorkers() {
    return (db.select(db.workers)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(_fromDrift).toList());
  }

  Stream<List<Worker>> watchActiveWorkers() {
    return (db.select(db.workers)
          ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(_fromDrift).toList());
  }

  Future<List<Worker>> getActiveWorkers() async {
    final rows =
        await (db.select(db.workers)
              ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return rows.map(_fromDrift).toList();
  }

  Future<Worker?> getWorkerById(String id) async {
    final row = await (db.select(
      db.workers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromDrift(row);
  }

  Stream<Worker?> watchWorker(String id) {
    return (db.select(db.workers)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _fromDrift(row));
  }

  Future<void> createWorker(Worker worker) async {
    if (worker.name.trim().isEmpty) {
      throw ArgumentError('El nombre del trabajador no puede estar vacío');
    }
    if (worker.defaultRateCents < 0) {
      throw ArgumentError('La tarifa predeterminada no puede ser negativa');
    }

    await db
        .into(db.workers)
        .insert(
          WorkersCompanion.insert(
            id: worker.id,
            workspaceId: Value(worker.workspaceId),
            name: worker.name.trim(),
            phone: Value(worker.phone),
            specialty: Value(worker.specialty),
            defaultPaymentType: Value(worker.defaultPaymentType),
            defaultRateCents: Value(worker.defaultRateCents),
            isActive: Value(worker.isActive),
            notes: Value(worker.notes),
            createdAt: Value(worker.createdAt),
            updatedAt: Value(worker.updatedAt),
            createdBy: Value(worker.createdBy),
            updatedBy: Value(worker.updatedBy),
            version: Value(worker.version),
            deletedAt: Value(worker.deletedAt),
          ),
        );
  }

  Future<void> updateWorker(Worker worker) async {
    if (worker.name.trim().isEmpty) {
      throw ArgumentError('El nombre del trabajador no puede estar vacío');
    }
    if (worker.defaultRateCents < 0) {
      throw ArgumentError('La tarifa predeterminada no puede ser negativa');
    }

    await (db.update(db.workers)..where((t) => t.id.equals(worker.id))).write(
      WorkersCompanion(
        name: Value(worker.name.trim()),
        phone: Value(worker.phone),
        specialty: Value(worker.specialty),
        defaultPaymentType: Value(worker.defaultPaymentType),
        defaultRateCents: Value(worker.defaultRateCents),
        isActive: Value(worker.isActive),
        notes: Value(worker.notes),
        updatedAt: Value(DateTime.now()),
        updatedBy: Value(worker.updatedBy),
        version: Value(worker.version + 1),
      ),
    );
  }

  Future<void> deactivateWorker(String id) async {
    await (db.update(db.workers)..where((t) => t.id.equals(id))).write(
      WorkersCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> activateWorker(String id) async {
    await (db.update(db.workers)..where((t) => t.id.equals(id))).write(
      WorkersCompanion(
        isActive: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteWorker(String id) async {
    // Soft delete para preservar el historial de jornadas de acuerdo al modelo
    await (db.update(db.workers)..where((t) => t.id.equals(id))).write(
      WorkersCompanion(
        isActive: const Value(false),
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Worker _fromDrift(dynamic row) {
    return Worker(
      id: row.id as String,
      workspaceId: row.workspaceId as String,
      name: row.name as String,
      phone: row.phone as String?,
      specialty: row.specialty as String?,
      defaultPaymentType: row.defaultPaymentType as String,
      defaultRateCents: row.defaultRateCents as int,
      isActive: row.isActive as bool,
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
