/// Financial summary model derived dynamically for a MaintenanceVisit or MaintenancePlan.
/// Pure computed representation — no financial totals are stored statically.
class MaintenanceFinancialSummary {
  final String entityId;
  final String entityType; // 'visit' | 'plan'
  final int revenueCents;
  final int collectedCents;
  final int laborCostCents;
  final int materialCostCents;
  final int expensesCents;

  const MaintenanceFinancialSummary({
    required this.entityId,
    required this.entityType,
    required this.revenueCents,
    required this.collectedCents,
    required this.laborCostCents,
    required this.materialCostCents,
    required this.expensesCents,
  });

  /// Derived Total Cost = Labor + Material + Direct Expenses
  int get totalCostCents => laborCostCents + materialCostCents + expensesCents;

  /// Derived Receivable = Revenue - Collected (minimum 0)
  int get receivableCents =>
      (revenueCents - collectedCents) > 0 ? (revenueCents - collectedCents) : 0;

  /// Derived Gross Margin = Revenue - Total Cost
  int get grossMarginCents => revenueCents - totalCostCents;

  /// Derived Gross Margin Percentage
  double get grossMarginPercent {
    if (revenueCents <= 0) return 0.0;
    return (grossMarginCents / revenueCents) * 100.0;
  }

  bool get isOverpaid => collectedCents > revenueCents;
  int get overpaidCents => isOverpaid ? (collectedCents - revenueCents) : 0;

  double get revenue => revenueCents / 100.0;
  double get collected => collectedCents / 100.0;
  double get receivable => receivableCents / 100.0;
  double get totalCost => totalCostCents / 100.0;
  double get laborCost => laborCostCents / 100.0;
  double get materialCost => materialCostCents / 100.0;
  double get expenses => expensesCents / 100.0;
  double get grossMargin => grossMarginCents / 100.0;
  double get overpaid => overpaidCents / 100.0;
}
