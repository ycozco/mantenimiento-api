import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';

enum PaymentMethod { cash, yape, plin, transfer, other }

extension PaymentMethodExt on PaymentMethod {
  String get nameCode {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.yape:
        return 'yape';
      case PaymentMethod.plin:
        return 'plin';
      case PaymentMethod.transfer:
        return 'transfer';
      case PaymentMethod.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.yape:
        return 'Yape';
      case PaymentMethod.plin:
        return 'Plin';
      case PaymentMethod.transfer:
        return 'Transferencia Bancaria';
      case PaymentMethod.other:
        return 'Otro';
    }
  }

  static PaymentMethod fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'yape':
        return PaymentMethod.yape;
      case 'plin':
        return PaymentMethod.plin;
      case 'transfer':
      case 'transferencia':
        return PaymentMethod.transfer;
      case 'other':
      case 'otro':
        return PaymentMethod.other;
      case 'cash':
      case 'efectivo':
      default:
        return PaymentMethod.cash;
    }
  }
}

class LaborPayment {
  final String id;
  final String workspaceId;
  final String workerId;
  final String? projectId;
  final int amountCents;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? paidByPartnerId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  LaborPayment({
    String? id,
    String? workspaceId,
    required this.workerId,
    this.projectId,
    required this.amountCents,
    DateTime? paymentDate,
    this.paymentMethod = 'cash',
    this.paidByPartnerId,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  }) : id = id ?? const Uuid().v4(),
       workspaceId = workspaceId ?? AppConstants.defaultWorkspaceId,
       paymentDate = paymentDate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  double get amount => amountCents / 100.0;
  bool get isDeleted => deletedAt != null;
  PaymentMethod get methodEnum => PaymentMethodExt.fromString(paymentMethod);

  LaborPayment copyWith({
    String? id,
    String? workspaceId,
    String? workerId,
    String? projectId,
    int? amountCents,
    DateTime? paymentDate,
    String? paymentMethod,
    String? paidByPartnerId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? version,
    DateTime? deletedAt,
  }) {
    return LaborPayment(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      workerId: workerId ?? this.workerId,
      projectId: projectId ?? this.projectId,
      amountCents: amountCents ?? this.amountCents,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidByPartnerId: paidByPartnerId ?? this.paidByPartnerId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
