class LowStockAlert {
  final String itemId;
  final String itemName;
  final String sku;
  final double currentStock;
  final double minStockAlert;
  final String unit;
  final bool isOutOfStock;

  LowStockAlert({
    required this.itemId,
    required this.itemName,
    required this.sku,
    required this.currentStock,
    required this.minStockAlert,
    required this.unit,
    required this.isOutOfStock,
  });
}

class DashboardSummary {
  // Operaciones
  final int activeProjectsCount;
  final int activeWorkersCount;
  final int assignedToolsCount;
  final int toolsInMaintenanceCount;
  final int overdueToolReturnsCount;

  // Mantenimientos
  final int visitsTodayCount;
  final int visitsUpcoming7DaysCount;
  final int visitsOverdueCount;

  // Finanzas de Obras Activas
  final int activeProjectsAgreedRevenueCents;
  final int activeProjectsTotalCostCents;
  final int activeProjectsGrossMarginCents;
  final double activeProjectsGrossMarginPercent;
  final int activeProjectsCollectedCents;
  final int activeProjectsReceivableCents;

  // Pasivos Laborales
  final int totalPendingLaborDebtCents;

  // Inventario
  final int lowStockItemsCount;
  final int outOfStockItemsCount;
  final List<LowStockAlert> stockAlerts;

  DashboardSummary({
    this.activeProjectsCount = 0,
    this.activeWorkersCount = 0,
    this.assignedToolsCount = 0,
    this.toolsInMaintenanceCount = 0,
    this.overdueToolReturnsCount = 0,
    this.visitsTodayCount = 0,
    this.visitsUpcoming7DaysCount = 0,
    this.visitsOverdueCount = 0,
    this.activeProjectsAgreedRevenueCents = 0,
    this.activeProjectsTotalCostCents = 0,
    this.activeProjectsGrossMarginCents = 0,
    this.activeProjectsGrossMarginPercent = 0.0,
    this.activeProjectsCollectedCents = 0,
    this.activeProjectsReceivableCents = 0,
    this.totalPendingLaborDebtCents = 0,
    this.lowStockItemsCount = 0,
    this.outOfStockItemsCount = 0,
    this.stockAlerts = const [],
  });

  // Getters en Soles (double)
  double get activeProjectsAgreedRevenue =>
      activeProjectsAgreedRevenueCents / 100.0;
  double get activeProjectsTotalCost => activeProjectsTotalCostCents / 100.0;
  double get activeProjectsGrossMargin =>
      activeProjectsGrossMarginCents / 100.0;
  double get activeProjectsCollected => activeProjectsCollectedCents / 100.0;
  double get activeProjectsReceivable => activeProjectsReceivableCents / 100.0;
  double get totalPendingLaborDebt => totalPendingLaborDebtCents / 100.0;

  bool get hasUrgentAlerts =>
      visitsOverdueCount > 0 ||
      overdueToolReturnsCount > 0 ||
      outOfStockItemsCount > 0;
}
