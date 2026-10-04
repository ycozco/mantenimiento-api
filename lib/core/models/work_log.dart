import '../constants/app_constants.dart';

class WorkLog {
  final String id;
  final String workspaceId;
  final String workerId;
  final String? projectId;
  final String? maintenanceVisitId;
  final DateTime date;
  final String paymentType;
  final double quantity;
  final int rateCents;
  final int amountCents;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  WorkLog({
    required this.id,
    this.workspaceId = AppConstants.defaultWorkspaceId,
    required this.workerId,
    this.projectId,
    this.maintenanceVisitId,
    required this.date,
    this.paymentType = AppConstants.paymentTypeDaily,
    required this.quantity,
    required this.rateCents,
    int? amountCents,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  }) : amountCents =
           amountCents ??
           calculateAmountCents(
             paymentType: paymentType,
             quantity: quantity,
             rateCents: rateCents,
           ),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  double get rate => rateCents / 100.0;
  double get amount => amountCents / 100.0;

  static int calculateAmountCents({
    required String paymentType,
    required double quantity,
    required int rateCents,
  }) {
    if (paymentType == AppConstants.paymentTypeFixed) {
      return rateCents;
    }
    return (quantity * rateCents).round();
  }

  String get paymentTypeLabel {
    switch (paymentType) {
      case AppConstants.paymentTypeHourly:
        return 'Por hora';
      case AppConstants.paymentTypeFixed:
        return 'Fijo / Destajo';
      case AppConstants.paymentTypeDaily:
      default:
        return 'Por día';
    }
  }

  String get quantityFormatted {
    if (paymentType == AppConstants.paymentTypeFixed) {
      return '1 destajo';
    }
    final formattedQty = quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toString();
    if (paymentType == AppConstants.paymentTypeHourly) {
      return '$formattedQty hr(s)';
    }
    return '$formattedQty día(s)';
  }

  WorkLog copyWith({
    String? id,
    String? workspaceId,
    String? workerId,
    String? projectId,
    String? maintenanceVisitId,
    DateTime? date,
    String? paymentType,
    double? quantity,
    int? rateCents,
    int? amountCents,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? version,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    final nextPaymentType = paymentType ?? this.paymentType;
    final nextQuantity = quantity ?? this.quantity;
    final nextRateCents = rateCents ?? this.rateCents;

    return WorkLog(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      workerId: workerId ?? this.workerId,
      projectId: projectId ?? this.projectId,
      maintenanceVisitId: maintenanceVisitId ?? this.maintenanceVisitId,
      date: date ?? this.date,
      paymentType: nextPaymentType,
      quantity: nextQuantity,
      rateCents: nextRateCents,
      amountCents:
          amountCents ??
          calculateAmountCents(
            paymentType: nextPaymentType,
            quantity: nextQuantity,
            rateCents: nextRateCents,
          ),
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'workerId': workerId,
    'projectId': projectId,
    'maintenanceVisitId': maintenanceVisitId,
    'date': date.toIso8601String(),
    'paymentType': paymentType,
    'quantity': quantity,
    'rateCents': rateCents,
    'amountCents': amountCents,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'createdBy': createdBy,
    'updatedBy': updatedBy,
    'version': version,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory WorkLog.fromJson(Map<String, dynamic> json) => WorkLog(
    id: json['id'] as String,
    workspaceId:
        json['workspaceId'] as String? ?? AppConstants.defaultWorkspaceId,
    workerId: json['workerId'] as String,
    projectId: json['projectId'] as String?,
    maintenanceVisitId: json['maintenanceVisitId'] as String?,
    date: DateTime.parse(json['date'] as String),
    paymentType:
        json['paymentType'] as String? ?? AppConstants.paymentTypeDaily,
    quantity: (json['quantity'] as num).toDouble(),
    rateCents: json['rateCents'] as int? ?? 0,
    amountCents: json['amountCents'] as int?,
    notes: json['notes'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
    updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : null,
    createdBy: json['createdBy'] as String?,
    updatedBy: json['updatedBy'] as String?,
    version: json['version'] as int? ?? 1,
    deletedAt: json['deletedAt'] != null
        ? DateTime.parse(json['deletedAt'] as String)
        : null,
  );
}
