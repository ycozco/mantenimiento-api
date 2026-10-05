import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/dashboard_summary.dart';
import 'project_financial_service.dart';

class DashboardService {
  final AppDatabase _db;
  final ProjectFinancialService _financialService;

  DashboardService(this._db, [ProjectFinancialService? financialService])
    : _financialService = financialService ?? ProjectFinancialService(_db);

  /// Stream reactivo que emite el resumen actualizado del Dashboard
  Stream<DashboardSummary> watchDashboardSummary() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _db.projects,
            _db.maintenanceVisits,
            _db.workers,
            _db.tools,
            _db.toolAssignments,
            _db.inventoryItems,
            _db.stockMovements,
            _db.workLogs,
            _db.expenses,
            _db.collections,
            _db.laborPayments,
          },
        )
        .watch()
        .asyncMap((_) async {
          return await getDashboardSummary();
        });
  }

  /// Calcula el resumen consolidado del Dashboard en un momento dado
  Future<DashboardSummary> getDashboardSummary() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final next7DaysEnd = todayEnd.add(const Duration(days: 7));

    // 1. Obras Activas
    final activeProjects =
        await (_db.select(_db.projects)..where(
              (tbl) =>
                  tbl.deletedAt.isNull() &
                  tbl.status.isNotIn(['completed', 'cancelled']),
            ))
            .get();

    int activeProjectsAgreedRevenueCents = 0;
    int activeProjectsTotalCostCents = 0;
    int activeProjectsCollectedCents = 0;
    int activeProjectsReceivableCents = 0;

    for (final p in activeProjects) {
      final summary = await _financialService.getProjectFinancialSummary(
        p.id,
        p.budgetAmountCents,
      );
      activeProjectsAgreedRevenueCents += summary.agreedRevenueCents;
      activeProjectsTotalCostCents += summary.totalCostCents;
      activeProjectsCollectedCents += summary.collectedCents;
      activeProjectsReceivableCents += summary.receivableCents;
    }

    final activeProjectsGrossMarginCents =
        activeProjectsAgreedRevenueCents - activeProjectsTotalCostCents;
    final activeProjectsGrossMarginPercent =
        activeProjectsAgreedRevenueCents > 0
        ? (activeProjectsGrossMarginCents / activeProjectsAgreedRevenueCents) *
              100.0
        : 0.0;

    // 2. Visitas de Mantenimiento
    final activeVisits =
        await (_db.select(_db.maintenanceVisits)..where(
              (tbl) =>
                  tbl.deletedAt.isNull() &
                  tbl.status.isNotIn(['completed', 'cancelled']),
            ))
            .get();

    int visitsTodayCount = 0;
    int visitsUpcoming7DaysCount = 0;
    int visitsOverdueCount = 0;

    for (final v in activeVisits) {
      final date = v.scheduledDate.toLocal();
      if (date.isBefore(todayStart)) {
        visitsOverdueCount++;
      } else if (date.isAfter(todayEnd) && date.isBefore(next7DaysEnd)) {
        visitsUpcoming7DaysCount++;
      } else if (!date.isBefore(todayStart) && !date.isAfter(todayEnd)) {
        visitsTodayCount++;
      }
    }

    // 3. Trabajadores Activos
    final activeWorkersRow = await _db
        .customSelect(
          'SELECT COUNT(*) AS total FROM workers WHERE is_active = 1 AND deleted_at IS NULL',
          readsFrom: {_db.workers},
        )
        .getSingle();
    final activeWorkersCount = activeWorkersRow.read<int>('total');

    // 4. Herramientas
    final assignedToolsRow = await _db
        .customSelect(
          'SELECT COUNT(*) AS total FROM tool_assignments WHERE returned_at IS NULL AND deleted_at IS NULL',
          readsFrom: {_db.toolAssignments},
        )
        .getSingle();
    final assignedToolsCount = assignedToolsRow.read<int>('total');

    final toolsInMaintenanceRow = await _db
        .customSelect(
          'SELECT COUNT(*) AS total FROM tools WHERE current_status = "maintenance" AND deleted_at IS NULL',
          readsFrom: {_db.tools},
        )
        .getSingle();
    final toolsInMaintenanceCount = toolsInMaintenanceRow.read<int>('total');

    final overdueToolReturnsRow = await _db
        .customSelect(
          'SELECT COUNT(*) AS total FROM tool_assignments WHERE returned_at IS NULL AND expected_return_at < ? AND deleted_at IS NULL',
          variables: [Variable.withDateTime(now)],
          readsFrom: {_db.toolAssignments},
        )
        .getSingle();
    final overdueToolReturnsCount = overdueToolReturnsRow.read<int>('total');

    // 5. Inventario y Alertas de Stock
    final items =
        await (_db.select(_db.inventoryItems)..where(
              (tbl) => tbl.deletedAt.isNull() & tbl.isActive.equals(true),
            ))
            .get();

    int lowStockItemsCount = 0;
    int outOfStockItemsCount = 0;
    final List<LowStockAlert> stockAlerts = [];

    for (final item in items) {
      final stockRow = await _db
          .customSelect(
            'SELECT COALESCE(SUM(quantity), 0.0) AS current_stock FROM stock_movements WHERE item_id = ? AND deleted_at IS NULL',
            variables: [Variable.withString(item.id)],
            readsFrom: {_db.stockMovements},
          )
          .getSingle();
      final currentStock = stockRow.read<double>('current_stock');

      if (currentStock <= 0) {
        outOfStockItemsCount++;
        stockAlerts.add(
          LowStockAlert(
            itemId: item.id,
            itemName: item.name,
            sku: item.sku ?? '',
            currentStock: currentStock,
            minStockAlert: item.minStockAlert,
            unit: item.unit,
            isOutOfStock: true,
          ),
        );
      } else if (currentStock <= item.minStockAlert) {
        lowStockItemsCount++;
        stockAlerts.add(
          LowStockAlert(
            itemId: item.id,
            itemName: item.name,
            sku: item.sku ?? '',
            currentStock: currentStock,
            minStockAlert: item.minStockAlert,
            unit: item.unit,
            isOutOfStock: false,
          ),
        );
      }
    }

    // 6. Pasivos Laborales (Jornadas devengadas vs Pagos laborales)
    final accruedRow = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM work_logs WHERE deleted_at IS NULL',
          readsFrom: {_db.workLogs},
        )
        .getSingle();
    final totalAccruedLaborCents = accruedRow.read<int>('total');

    final paidRow = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM labor_payments WHERE deleted_at IS NULL',
          readsFrom: {_db.laborPayments},
        )
        .getSingle();
    final totalPaidLaborCents = paidRow.read<int>('total');

    final totalPendingLaborDebtCents =
        (totalAccruedLaborCents - totalPaidLaborCents) > 0
        ? (totalAccruedLaborCents - totalPaidLaborCents)
        : 0;

    return DashboardSummary(
      activeProjectsCount: activeProjects.length,
      activeWorkersCount: activeWorkersCount,
      assignedToolsCount: assignedToolsCount,
      toolsInMaintenanceCount: toolsInMaintenanceCount,
      overdueToolReturnsCount: overdueToolReturnsCount,
      visitsTodayCount: visitsTodayCount,
      visitsUpcoming7DaysCount: visitsUpcoming7DaysCount,
      visitsOverdueCount: visitsOverdueCount,
      activeProjectsAgreedRevenueCents: activeProjectsAgreedRevenueCents,
      activeProjectsTotalCostCents: activeProjectsTotalCostCents,
      activeProjectsGrossMarginCents: activeProjectsGrossMarginCents,
      activeProjectsGrossMarginPercent: activeProjectsGrossMarginPercent,
      activeProjectsCollectedCents: activeProjectsCollectedCents,
      activeProjectsReceivableCents: activeProjectsReceivableCents,
      totalPendingLaborDebtCents: totalPendingLaborDebtCents,
      lowStockItemsCount: lowStockItemsCount,
      outOfStockItemsCount: outOfStockItemsCount,
      stockAlerts: stockAlerts,
    );
  }
}
