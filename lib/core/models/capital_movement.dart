import 'package:uuid/uuid.dart';

class CapitalMovement {
  final String id;
  final String workspaceId;
  final String partnerId;
  final String? projectId;
  final String
  type; // 'contribution', 'withdrawal', 'partnerExpense', 'profitDistribution', 'adjustment'
  final int amountCents;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  // Non-persisted join metadata for UI
  final String? partnerName;
  final String? projectName;

  CapitalMovement({
    required this.id,
    this.workspaceId = 'default',
    required this.partnerId,
    this.projectId,
    required this.type,
    required this.amountCents,
    required this.date,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
    this.partnerName,
    this.projectName,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory CapitalMovement.create({
    String? id,
    String workspaceId = 'default',
    required String partnerId,
    String? projectId,
    required String type,
    required int amountCents,
    required DateTime date,
    String? notes,
    String? createdBy,
    String? partnerName,
    String? projectName,
  }) {
    if (amountCents <= 0) {
      throw ArgumentError('El monto del movimiento debe ser mayor a cero.');
    }

    final validTypes = [
      'contribution',
      'withdrawal',
      'partnerExpense',
      'profitDistribution',
      'adjustment',
    ];
    if (!validTypes.contains(type)) {
      throw ArgumentError('Tipo de movimiento de capital no válido: $type');
    }

    final now = DateTime.now();
    return CapitalMovement(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      partnerId: partnerId,
      projectId: projectId,
      type: type,
      amountCents: amountCents,
      date: date,
      notes: notes?.trim(),
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
      version: 1,
      partnerName: partnerName,
      projectName: projectName,
    );
  }

  double get amount => amountCents / 100.0;
  bool get isDeleted => deletedAt != null;

  String get typeLabel {
    switch (type) {
      case 'contribution':
        return 'Aporte de Capital';
      case 'withdrawal':
        return 'Retiro de Capital';
      case 'partnerExpense':
        return 'Gasto Pagado Personalmente';
      case 'profitDistribution':
        return 'Distribución de Utilidades';
      case 'adjustment':
        return 'Ajuste de Capital';
      default:
        return type;
    }
  }

  bool get isCredit => type == 'contribution' || type == 'partnerExpense';
}

class PartnerBalanceSummary {
  final String partnerId;
  final int contributionsCents;
  final int withdrawalsCents;
  final int partnerExpensesCents;
  final int profitDistributionsCents;
  final int adjustmentsCents;

  PartnerBalanceSummary({
    required this.partnerId,
    required this.contributionsCents,
    required this.withdrawalsCents,
    required this.partnerExpensesCents,
    required this.profitDistributionsCents,
    required this.adjustmentsCents,
  });

  /// Saldo neto = (Aportes + Gastos Personales) - (Retiros + Distribuciones) + Ajustes
  int get netBalanceCents =>
      (contributionsCents + partnerExpensesCents) -
      (withdrawalsCents + profitDistributionsCents) +
      adjustmentsCents;

  double get contributions => contributionsCents / 100.0;
  double get withdrawals => withdrawalsCents / 100.0;
  double get partnerExpenses => partnerExpensesCents / 100.0;
  double get profitDistributions => profitDistributionsCents / 100.0;
  double get adjustments => adjustmentsCents / 100.0;
  double get netBalance => netBalanceCents / 100.0;
}
