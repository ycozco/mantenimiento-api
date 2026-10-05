class ProjectFinancialSummary {
  final String projectId;
  final int revenueCents; // Presupuesto o valor pactado de venta
  final int laborCostCents; // Suma de WorkLogs
  final int materialCostCents; // Suma de StockMovements de consumo
  final int expensesCostCents; // Suma de Expenses directos
  final int otherCostsCents; // Otros costos directos
  final int collectedCents; // Suma de Collections activas

  ProjectFinancialSummary({
    required this.projectId,
    required this.revenueCents,
    this.laborCostCents = 0,
    this.materialCostCents = 0,
    this.expensesCostCents = 0,
    this.otherCostsCents = 0,
    this.collectedCents = 0,
  });

  /// Alias de Presupuesto/Valor Acordado
  int get agreedRevenueCents => revenueCents;
  double get agreedRevenue => revenue;

  /// Costo Total = Mano de Obra + Materiales + Gastos Directos + Otros
  int get totalCostCents =>
      laborCostCents + materialCostCents + expensesCostCents + otherCostsCents;

  /// Margen Bruto = Venta Pactada - Costo Total
  int get grossMarginCents => revenueCents - totalCostCents;

  /// Porcentaje de Margen Bruto = (Margen / Venta) * 100
  double get grossMarginPercent {
    if (revenueCents <= 0) {
      return totalCostCents > 0 ? -100.0 : 0.0;
    }
    return (grossMarginCents / revenueCents) * 100.0;
  }

  /// Es rentable si el margen bruto >= 0
  bool get isProfitable => grossMarginCents >= 0;

  /// Por Cobrar = max(0, Venta - Cobrado)
  int get receivableCents =>
      (revenueCents - collectedCents) > 0 ? (revenueCents - collectedCents) : 0;

  /// Sobrepago = Cobrado > Venta
  bool get isOverpaid => collectedCents > revenueCents;
  int get overpaidAmountCents =>
      isOverpaid ? (collectedCents - revenueCents) : 0;

  /// Porcentaje de Cobro
  double get percentCollected {
    if (revenueCents <= 0) return collectedCents > 0 ? 100.0 : 0.0;
    final pct = (collectedCents / revenueCents) * 100.0;
    return pct > 100.0 ? 100.0 : pct;
  }

  // Getters convertidos a Soles (double)
  double get revenue => revenueCents / 100.0;
  double get laborCost => laborCostCents / 100.0;
  double get materialCost => materialCostCents / 100.0;
  double get expensesCost => expensesCostCents / 100.0;
  double get otherCosts => otherCostsCents / 100.0;
  double get totalCost => totalCostCents / 100.0;
  double get grossMargin => grossMarginCents / 100.0;
  double get collected => collectedCents / 100.0;
  double get receivable => receivableCents / 100.0;
  double get overpaidAmount => overpaidAmountCents / 100.0;
}
