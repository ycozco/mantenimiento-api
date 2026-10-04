import 'package:drift/drift.dart';
import '../database/app_database.dart' hide LaborPayment;
import '../models/labor_payment.dart';

class WorkerBalance {
  final int accruedCents;
  final int paidCents;

  const WorkerBalance({required this.accruedCents, required this.paidCents});

  int get balanceCents => accruedCents - paidCents;
  double get accrued => accruedCents / 100.0;
  double get paid => paidCents / 100.0;
  double get balance => balanceCents / 100.0;

  bool get isSettled => balanceCents == 0;
  bool get hasPendingDebt => balanceCents > 0;
  bool get hasAdvancePayment => balanceCents < 0;
}

class LaborPaymentRepository {
  final AppDatabase db;

  LaborPaymentRepository(this.db);

  void _validate(LaborPayment payment) {
    if (payment.workerId.trim().isEmpty) {
      throw ArgumentError('El trabajador es obligatorio');
    }
    if (payment.amountCents <= 0) {
      throw ArgumentError('El monto del pago debe ser mayor a 0');
    }
  }

  Stream<List<LaborPayment>> watchWorkerPayments(String workerId) {
    return (db.select(db.laborPayments)
          ..where((t) => t.workerId.equals(workerId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)]))
        .watch()
        .map((rows) => rows.map(_fromDrift).toList());
  }

  Future<List<LaborPayment>> getWorkerPayments(String workerId) async {
    final rows =
        await (db.select(db.laborPayments)
              ..where((t) => t.workerId.equals(workerId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)]))
            .get();
    return rows.map(_fromDrift).toList();
  }

  Stream<List<LaborPayment>> watchProjectPayments(String projectId) {
    return (db.select(db.laborPayments)
          ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)]))
        .watch()
        .map((rows) => rows.map(_fromDrift).toList());
  }

  Future<int> getWorkerTotalPaidCents(String workerId) async {
    final sumColumn = db.laborPayments.amountCents.sum();
    final query = db.selectOnly(db.laborPayments)
      ..addColumns([sumColumn])
      ..where(
        db.laborPayments.workerId.equals(workerId) &
            db.laborPayments.deletedAt.isNull(),
      );

    final row = await query.getSingle();
    return row.read(sumColumn) ?? 0;
  }

  Stream<int> watchWorkerTotalPaidCents(String workerId) {
    final sumColumn = db.laborPayments.amountCents.sum();
    final query = db.selectOnly(db.laborPayments)
      ..addColumns([sumColumn])
      ..where(
        db.laborPayments.workerId.equals(workerId) &
            db.laborPayments.deletedAt.isNull(),
      );

    return query.watchSingle().map((row) => row.read(sumColumn) ?? 0);
  }

  Future<WorkerBalance> getWorkerBalance(String workerId) async {
    // 1. Devengado (WorkLogs)
    final workLogSum = db.workLogs.amountCents.sum();
    final workLogQuery = db.selectOnly(db.workLogs)
      ..addColumns([workLogSum])
      ..where(
        db.workLogs.workerId.equals(workerId) & db.workLogs.deletedAt.isNull(),
      );
    final workLogRow = await workLogQuery.getSingle();
    final accrued = workLogRow.read(workLogSum) ?? 0;

    // 2. Pagado (LaborPayments)
    final paid = await getWorkerTotalPaidCents(workerId);

    return WorkerBalance(accruedCents: accrued, paidCents: paid);
  }

  Future<void> createPayment(LaborPayment payment) async {
    _validate(payment);

    await db
        .into(db.laborPayments)
        .insert(
          LaborPaymentsCompanion.insert(
            id: payment.id,
            workspaceId: Value(payment.workspaceId),
            workerId: payment.workerId,
            projectId: Value(payment.projectId),
            amountCents: payment.amountCents,
            paymentDate: payment.paymentDate,
            paymentMethod: Value(payment.paymentMethod),
            paidByPartnerId: Value(payment.paidByPartnerId),
            notes: Value(payment.notes),
            createdAt: Value(payment.createdAt),
            updatedAt: Value(payment.updatedAt),
            createdBy: Value(payment.createdBy),
            updatedBy: Value(payment.updatedBy),
            version: Value(payment.version),
            deletedAt: Value(payment.deletedAt),
          ),
        );
  }

  Future<void> updatePayment(LaborPayment payment) async {
    _validate(payment);

    await (db.update(
      db.laborPayments,
    )..where((t) => t.id.equals(payment.id))).write(
      LaborPaymentsCompanion(
        projectId: Value(payment.projectId),
        amountCents: Value(payment.amountCents),
        paymentDate: Value(payment.paymentDate),
        paymentMethod: Value(payment.paymentMethod),
        paidByPartnerId: Value(payment.paidByPartnerId),
        notes: Value(payment.notes),
        updatedAt: Value(DateTime.now()),
        updatedBy: Value(payment.updatedBy),
        version: Value(payment.version + 1),
      ),
    );
  }

  Future<void> voidPayment(String paymentId) async {
    await (db.update(
      db.laborPayments,
    )..where((t) => t.id.equals(paymentId))).write(
      LaborPaymentsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  LaborPayment _fromDrift(dynamic row) {
    return LaborPayment(
      id: row.id,
      workspaceId: row.workspaceId,
      workerId: row.workerId,
      projectId: row.projectId,
      amountCents: row.amountCents,
      paymentDate: row.paymentDate,
      paymentMethod: row.paymentMethod,
      paidByPartnerId: row.paidByPartnerId,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      updatedBy: row.updatedBy,
      version: row.version,
      deletedAt: row.deletedAt,
    );
  }
}
