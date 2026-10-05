import 'package:uuid/uuid.dart';

class Collection {
  final String id;
  final String workspaceId;
  final String clientId;
  final String? projectId;
  final String? visitId;
  final int amountCents;
  final DateTime date;
  final String? receivedByPartnerId;
  final String paymentMethod; // 'cash', 'yape', 'plin', 'transfer', 'other'
  final String? reference;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  // Non-persisted join metadata for UI
  final String? clientName;
  final String? projectName;
  final String? partnerName;

  Collection({
    required this.id,
    this.workspaceId = 'default',
    required this.clientId,
    this.projectId,
    this.visitId,
    required this.amountCents,
    required this.date,
    this.receivedByPartnerId,
    this.paymentMethod = 'cash',
    this.reference,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
    this.clientName,
    this.projectName,
    this.partnerName,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Collection.create({
    String? id,
    String workspaceId = 'default',
    required String clientId,
    String? projectId,
    String? visitId,
    required int amountCents,
    required DateTime date,
    String? receivedByPartnerId,
    String paymentMethod = 'cash',
    String? reference,
    String? notes,
    String? createdBy,
    String? clientName,
    String? projectName,
    String? partnerName,
  }) {
    if (amountCents <= 0) {
      throw ArgumentError('El monto del cobro debe ser mayor a cero.');
    }

    final validMethods = ['cash', 'yape', 'plin', 'transfer', 'other'];
    if (!validMethods.contains(paymentMethod)) {
      throw ArgumentError('Método de pago no válido: $paymentMethod');
    }

    final now = DateTime.now();
    return Collection(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      clientId: clientId,
      projectId: projectId,
      visitId: visitId,
      amountCents: amountCents,
      date: date,
      receivedByPartnerId: receivedByPartnerId,
      paymentMethod: paymentMethod,
      reference: reference?.trim(),
      notes: notes?.trim(),
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
      version: 1,
      clientName: clientName,
      projectName: projectName,
      partnerName: partnerName,
    );
  }

  double get amount => amountCents / 100.0;
  bool get isDeleted => deletedAt != null;

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'cash':
        return 'Efectivo';
      case 'yape':
        return 'Yape';
      case 'plin':
        return 'Plin';
      case 'transfer':
        return 'Transferencia Bancaria';
      case 'other':
      default:
        return 'Otro';
    }
  }
}

class ProjectBillingSummary {
  final String projectId;
  final int agreedAmountCents;
  final int collectedCents;

  ProjectBillingSummary({
    required this.projectId,
    required this.agreedAmountCents,
    required this.collectedCents,
  });

  /// Monto pendiente por cobrar
  int get receivableCents => (agreedAmountCents - collectedCents) > 0
      ? (agreedAmountCents - collectedCents)
      : 0;

  /// Detecta si el cliente pagó más de lo presupuestado
  bool get isOverpaid => collectedCents > agreedAmountCents;

  int get overpaidAmountCents =>
      isOverpaid ? (collectedCents - agreedAmountCents) : 0;

  double get agreedAmount => agreedAmountCents / 100.0;
  double get collected => collectedCents / 100.0;
  double get receivable => receivableCents / 100.0;
  double get overpaidAmount => overpaidAmountCents / 100.0;

  double get percentCollected {
    if (agreedAmountCents <= 0) return collectedCents > 0 ? 100.0 : 0.0;
    final pct = (collectedCents / agreedAmountCents) * 100.0;
    return pct > 100.0 ? 100.0 : pct;
  }
}
