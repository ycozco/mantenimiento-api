import 'dart:math';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/maintenance_financial_summary.dart';

class MaintenanceFinancialService {
  final AppDatabase _db;

  MaintenanceFinancialService(this._db);

  // ==================== VISIT FINANCIAL SUMMARY ====================

  Stream<MaintenanceFinancialSummary> watchVisitFinancials(String visitId) =>
      watchVisitFinancialSummary(visitId);

  Stream<MaintenanceFinancialSummary> watchVisitFinancialSummary(
    String visitId,
  ) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.maintenanceVisits,
            _db.maintenancePlans,
            _db.workLogs,
            _db.stockMovements,
            _db.expenses,
            _db.collections,
          },
        )
        .watch()
        .asyncMap((_) async {
          return await getVisitFinancialSummary(visitId);
        });
  }

  Future<MaintenanceFinancialSummary> getVisitFinancialSummary(
    String visitId,
  ) async {
    // 1. Visita y Plan padre
    final visitRow = await (_db.select(
      _db.maintenanceVisits,
    )..where((tbl) => tbl.id.equals(visitId))).getSingleOrNull();

    if (visitRow == null) {
      return MaintenanceFinancialSummary(
        entityId: visitId,
        entityType: 'visit',
        revenueCents: 0,
        collectedCents: 0,
        laborCostCents: 0,
        materialCostCents: 0,
        expensesCents: 0,
      );
    }

    final planRow = await (_db.select(
      _db.maintenancePlans,
    )..where((tbl) => tbl.id.equals(visitRow.planId))).getSingleOrNull();

    final billingType = planRow?.billingType ?? 'perVisit';

    // 2. Revenue de la visita
    int revenueCents = 0;
    if (billingType == 'perVisit' || billingType == 'custom') {
      revenueCents =
          visitRow.agreedPriceCents ?? (planRow?.agreedAmountCents ?? 0);
    } else if (billingType == 'monthly') {
      // En tarifa mensual el revenue se cobra y reconoce a nivel de Plan,
      // la visita individual sólo tiene precio explícito si se registró un override.
      revenueCents = visitRow.agreedPriceCents ?? 0;
    }

    // 3. Labor Cost = SUM(work_logs.amount_cents)
    final laborRow = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM work_logs WHERE maintenance_visit_id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(visitId)],
          readsFrom: {_db.workLogs},
        )
        .getSingle();
    final laborCostCents = laborRow.read<int>('total');

    // 4. Material Cost = SUM(stock_movements.total_cost_cents)
    final materialRow = await _db
        .customSelect(
          "SELECT COALESCE(SUM(total_cost_cents), 0) AS total FROM stock_movements WHERE visit_id = ? AND movement_type = 'consumption' AND deleted_at IS NULL",
          variables: [Variable.withString(visitId)],
          readsFrom: {_db.stockMovements},
        )
        .getSingle();
    final materialCostCents = materialRow.read<int>('total');

    // 5. Direct Expenses = SUM(expenses.amount_cents)
    final expensesRow = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM expenses WHERE visit_id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(visitId)],
          readsFrom: {_db.expenses},
        )
        .getSingle();
    final expensesCents = expensesRow.read<int>('total');

    // 6. Collected = SUM(collections.amount_cents)
    final collectedRow = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM collections WHERE visit_id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(visitId)],
          readsFrom: {_db.collections},
        )
        .getSingle();
    final collectedCents = collectedRow.read<int>('total');

    return MaintenanceFinancialSummary(
      entityId: visitId,
      entityType: 'visit',
      revenueCents: revenueCents,
      collectedCents: collectedCents,
      laborCostCents: laborCostCents,
      materialCostCents: materialCostCents,
      expensesCents: expensesCents,
    );
  }

  // ==================== PLAN FINANCIAL SUMMARY ====================

  Stream<MaintenanceFinancialSummary> watchPlanFinancials(String planId) =>
      watchPlanFinancialSummary(planId);

  Stream<MaintenanceFinancialSummary> watchPlanFinancialSummary(String planId) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.maintenancePlans,
            _db.maintenanceVisits,
            _db.workLogs,
            _db.stockMovements,
            _db.expenses,
            _db.collections,
          },
        )
        .watch()
        .asyncMap((_) async {
          return await getPlanFinancialSummary(planId);
        });
  }

  Future<MaintenanceFinancialSummary> getPlanFinancialSummary(
    String planId,
  ) async {
    final planRow = await (_db.select(
      _db.maintenancePlans,
    )..where((tbl) => tbl.id.equals(planId))).getSingleOrNull();

    if (planRow == null) {
      return MaintenanceFinancialSummary(
        entityId: planId,
        entityType: 'plan',
        revenueCents: 0,
        collectedCents: 0,
        laborCostCents: 0,
        materialCostCents: 0,
        expensesCents: 0,
      );
    }

    final visits =
        await (_db.select(_db.maintenanceVisits)..where(
              (tbl) => tbl.planId.equals(planId) & tbl.deletedAt.isNull(),
            ))
            .get();

    final billingType = planRow.billingType;
    int revenueCents = 0;

    if (billingType == 'perVisit') {
      // Suma de agreedPriceCents de las visitas registradas (o tarifa base si no tiene snapshot)
      for (final v in visits) {
        revenueCents += v.agreedPriceCents ?? planRow.agreedAmountCents;
      }
    } else if (billingType == 'monthly') {
      // No duplicar por visita dentro del mismo mes calendario.
      // Contar meses calendario distintos de visitas, mínimo 1 si existen visitas.
      final months = <int>{};
      for (final v in visits) {
        final key = v.scheduledDate.year * 12 + v.scheduledDate.month;
        months.add(key);
      }
      final billingCycles = max(1, months.length);
      revenueCents = planRow.agreedAmountCents * billingCycles;
    } else {
      // custom: suma de visitas cotizadas o tarifa base
      for (final v in visits) {
        revenueCents += v.agreedPriceCents ?? 0;
      }
      if (revenueCents == 0 && visits.isEmpty) {
        revenueCents = planRow.agreedAmountCents;
      }
    }

    // Costos agregados de todas las visitas del plan
    int laborCostCents = 0;
    int materialCostCents = 0;
    int expensesCents = 0;

    for (final v in visits) {
      final laborRow = await _db
          .customSelect(
            'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM work_logs WHERE maintenance_visit_id = ? AND deleted_at IS NULL',
            variables: [Variable.withString(v.id)],
            readsFrom: {_db.workLogs},
          )
          .getSingle();
      laborCostCents += laborRow.read<int>('total');

      final materialRow = await _db
          .customSelect(
            "SELECT COALESCE(SUM(total_cost_cents), 0) AS total FROM stock_movements WHERE visit_id = ? AND movement_type = 'consumption' AND deleted_at IS NULL",
            variables: [Variable.withString(v.id)],
            readsFrom: {_db.stockMovements},
          )
          .getSingle();
      materialCostCents += materialRow.read<int>('total');

      final expRow = await _db
          .customSelect(
            'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM expenses WHERE visit_id = ? AND deleted_at IS NULL',
            variables: [Variable.withString(v.id)],
            readsFrom: {_db.expenses},
          )
          .getSingle();
      expensesCents += expRow.read<int>('total');
    }

    // Collected: cobros asociados a planId OR a cualquiera de las visitas del plan
    final collectedRow = await _db
        .customSelect(
          'SELECT COALESCE(SUM(c.amount_cents), 0) AS total FROM collections c '
          'LEFT JOIN maintenance_visits v ON c.visit_id = v.id '
          'WHERE (c.plan_id = ? OR v.plan_id = ?) AND c.deleted_at IS NULL',
          variables: [Variable.withString(planId), Variable.withString(planId)],
          readsFrom: {_db.collections, _db.maintenanceVisits},
        )
        .getSingle();
    final collectedCents = collectedRow.read<int>('total');

    return MaintenanceFinancialSummary(
      entityId: planId,
      entityType: 'plan',
      revenueCents: revenueCents,
      collectedCents: collectedCents,
      laborCostCents: laborCostCents,
      materialCostCents: materialCostCents,
      expensesCents: expensesCents,
    );
  }

  // ==================== GLOBAL MAINTENANCE RECEIVABLES ====================

  /// Stream of total maintenance receivable cents across all active plans
  Stream<int> watchTotalReceivableMaintenanceCents() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.maintenancePlans,
            _db.maintenanceVisits,
            _db.collections,
          },
        )
        .watch()
        .asyncMap((_) async => await getTotalMaintenanceReceivableCents());
  }

  /// Calculates total maintenance receivable cents across all active plans
  Future<int> getTotalMaintenanceReceivableCents() async {
    final plans =
        await (_db.select(_db.maintenancePlans)..where(
              (tbl) => tbl.deletedAt.isNull() & tbl.isActive.equals(true),
            ))
            .get();

    int totalReceivable = 0;
    for (final p in plans) {
      final summary = await getPlanFinancialSummary(p.id);
      if (summary.receivableCents > 0) {
        totalReceivable += summary.receivableCents;
      }
    }
    return totalReceivable;
  }
}
