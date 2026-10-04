import '../constants/app_constants.dart';

class Worker {
  final String id;
  final String workspaceId;
  final String name;
  final String? phone;
  final String? specialty;
  final String defaultPaymentType;
  final int defaultRateCents;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  Worker({
    required this.id,
    this.workspaceId = AppConstants.defaultWorkspaceId,
    required this.name,
    this.phone,
    this.specialty,
    this.defaultPaymentType = AppConstants.paymentTypeDaily,
    this.defaultRateCents = 0,
    this.isActive = true,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  double get defaultRate => defaultRateCents / 100.0;

  String get paymentTypeLabel {
    switch (defaultPaymentType) {
      case AppConstants.paymentTypeHourly:
        return 'Por hora';
      case AppConstants.paymentTypeFixed:
        return 'Fijo / Destajo';
      case AppConstants.paymentTypeDaily:
      default:
        return 'Por día';
    }
  }

  Worker copyWith({
    String? id,
    String? workspaceId,
    String? name,
    String? phone,
    String? specialty,
    String? defaultPaymentType,
    int? defaultRateCents,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? version,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Worker(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      specialty: specialty ?? this.specialty,
      defaultPaymentType: defaultPaymentType ?? this.defaultPaymentType,
      defaultRateCents: defaultRateCents ?? this.defaultRateCents,
      isActive: isActive ?? this.isActive,
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
    'name': name,
    'phone': phone,
    'specialty': specialty,
    'defaultPaymentType': defaultPaymentType,
    'defaultRateCents': defaultRateCents,
    'isActive': isActive,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'createdBy': createdBy,
    'updatedBy': updatedBy,
    'version': version,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
    id: json['id'] as String,
    workspaceId:
        json['workspaceId'] as String? ?? AppConstants.defaultWorkspaceId,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    specialty: json['specialty'] as String?,
    defaultPaymentType:
        json['defaultPaymentType'] as String? ?? AppConstants.paymentTypeDaily,
    defaultRateCents: json['defaultRateCents'] as int? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
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
