import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/project_financial_summary.dart';

class ProjectFinancialService {
  final AppDatabase _db;

  ProjectFinancialService(this._db);

  // ==================== PROJECT FINANCIAL PROFITABILITY ====================

  /// Reactively computes the unified financial summary of a project.
  /// Listens to all underlying operational and collection tables without duplicating data.
  Stream<ProjectFinancialSummary> watchProjectFinancialSummary(
    String projectId,
    int revenueCents,
  ) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.workLogs,
            _db.stockMovements,
            _db.expenses,
            _db.collections,
          },
        )
        .watch()
        .asyncMap((_) async {
          return await getProjectFinancialSummary(projectId, revenueCents);
        });
  }

  /// Calculates the project financial summary at a given moment
  Future<ProjectFinancialSummary> getProjectFinancialSummary(
    String projectId,
    int revenueCents,
  ) async {
    // 1. Labor Cost = SUM(work_logs.amount_cents)
    final laborRow = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM work_logs WHERE project_id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(projectId)],
          readsFrom: {_db.workLogs},
        )
        .getSingle();
    final laborCostCents = laborRow.read<int>('total');

    // 2. Material Cost = SUM(stock_movements.total_cost_cents)
    final materialRow = await _db
        .customSelect(
          "SELECT COALESCE(SUM(total_cost_cents), 0) AS total FROM stock_movements WHERE project_id = ? AND movement_type = 'consumption' AND deleted_at IS NULL",
          variables: [Variable.withString(projectId)],
          readsFrom: {_db.stockMovements},
        )
        .getSingle();
    final materialCostCents = materialRow.read<int>('total');

    // 3. Direct Expenses = SUM(expenses.amount_cents)
    final expensesRow = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM expenses WHERE project_id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(projectId)],
          readsFrom: {_db.expenses},
        )
        .getSingle();
    final expensesCostCents = expensesRow.read<int>('total');

    // 4. Collections = SUM(collections.amount_cents)
    final collectionsRow = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM collections WHERE project_id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(projectId)],
          readsFrom: {_db.collections},
        )
        .getSingle();
    final collectedCents = collectionsRow.read<int>('total');

    return ProjectFinancialSummary(
      projectId: projectId,
      revenueCents: revenueCents,
      laborCostCents: laborCostCents,
      materialCostCents: materialCostCents,
      expensesCostCents: expensesCostCents,
      collectedCents: collectedCents,
    );
  }

  // ==================== MAINTENANCE VISIT COSTS ====================

  /// Reactively computes the total execution cost of a maintenance visit
  Stream<int> watchMaintenanceVisitTotalCostCents(String visitId) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.workLogs, _db.stockMovements, _db.expenses},
        )
        .watch()
        .asyncMap((_) async {
          final laborRow = await _db
              .customSelect(
                'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM work_logs WHERE maintenance_visit_id = ? AND deleted_at IS NULL',
                variables: [Variable.withString(visitId)],
                readsFrom: {_db.workLogs},
              )
              .getSingle();

          final materialRow = await _db
              .customSelect(
                "SELECT COALESCE(SUM(total_cost_cents), 0) AS total FROM stock_movements WHERE visit_id = ? AND movement_type = 'consumption' AND deleted_at IS NULL",
                variables: [Variable.withString(visitId)],
                readsFrom: {_db.stockMovements},
              )
              .getSingle();

          final expensesRow = await _db
              .customSelect(
                'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM expenses WHERE visit_id = ? AND deleted_at IS NULL',
                variables: [Variable.withString(visitId)],
                readsFrom: {_db.expenses},
              )
              .getSingle();

          return laborRow.read<int>('total') +
              materialRow.read<int>('total') +
              expensesRow.read<int>('total');
        });
  }

  /// Total historical cost of all visits of a maintenance plan
  Stream<int> watchPlanHistoricalCostCents(String planId) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.maintenanceVisits,
            _db.workLogs,
            _db.stockMovements,
            _db.expenses,
          },
        )
        .watch()
        .asyncMap((_) async {
          // Find all visits for plan
          final visits =
              await (_db.select(_db.maintenanceVisits)..where(
                    (tbl) => tbl.planId.equals(planId) & tbl.deletedAt.isNull(),
                  ))
                  .get();

          int totalCost = 0;
          for (final v in visits) {
            final laborRow = await _db
                .customSelect(
                  'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM work_logs WHERE maintenance_visit_id = ? AND deleted_at IS NULL',
                  variables: [Variable.withString(v.id)],
                  readsFrom: {_db.workLogs},
                )
                .getSingle();

            final materialRow = await _db
                .customSelect(
                "SELECT COALESCE(SUM(total_cost_cents), 0) AS total FROM stock_movements WHERE visit_id = ? AND movement_type = 'consumption' AND deleted_at IS NULL",
                  variables: [Variable.withString(v.id)],
                  readsFrom: {_db.stockMovements},
                )
                .getSingle();

            final expensesRow = await _db
                .customSelect(
                  'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM expenses WHERE visit_id = ? AND deleted_at IS NULL',
                  variables: [Variable.withString(v.id)],
                  readsFrom: {_db.expenses},
                )
                .getSingle();

            totalCost +=
                laborRow.read<int>('total') +
                materialRow.read<int>('total') +
                expensesRow.read<int>('total');
          }

          return totalCost;
        });
  }
}
