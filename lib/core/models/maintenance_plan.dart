import 'package:uuid/uuid.dart';

class MaintenancePlan {
  final String id;
  final String workspaceId;
  final String title;
  final String clientId;
  final String? locationId;
  final String? description;
  final String frequencyType;
  final int intervalDays;
  final DateTime nextDate;
  final int estimatedCostCents;
  final String billingType; // 'perVisit', 'monthly', 'custom'
  final int agreedAmountCents;
  final List<String> assignedPartnerIds;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  MaintenancePlan({
    String? id,
    String? workspaceId,
    required this.title,
    required this.clientId,
    this.locationId,
    this.description,
    this.frequencyType = 'unMes',
    this.intervalDays = 30,
    required this.nextDate,
    this.estimatedCostCents = 0,
    this.billingType = 'perVisit',
    this.agreedAmountCents = 0,
    this.assignedPartnerIds = const [],
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  }) : id = id ?? const Uuid().v4(),
       workspaceId = workspaceId ?? '00000000-0000-0000-0000-000000000001',
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  double get estimatedCost => estimatedCostCents / 100.0;
  double get agreedAmount => agreedAmountCents / 100.0;
  bool get isDeleted => deletedAt != null;

  DateTime calculateNextCycle([DateTime? fromDate]) {
    final base = fromDate ?? DateTime.now();
    return base.add(Duration(days: intervalDays > 0 ? intervalDays : 30));
  }

  MaintenancePlan copyWith({
    String? id,
    String? workspaceId,
    String? title,
    String? clientId,
    String? locationId,
    String? description,
    String? frequencyType,
    int? intervalDays,
    DateTime? nextDate,
    int? estimatedCostCents,
    String? billingType,
    int? agreedAmountCents,
    List<String>? assignedPartnerIds,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? version,
    DateTime? deletedAt,
  }) {
    return MaintenancePlan(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      title: title ?? this.title,
      clientId: clientId ?? this.clientId,
      locationId: locationId ?? this.locationId,
      description: description ?? this.description,
      frequencyType: frequencyType ?? this.frequencyType,
      intervalDays: intervalDays ?? this.intervalDays,
      nextDate: nextDate ?? this.nextDate,
      estimatedCostCents: estimatedCostCents ?? this.estimatedCostCents,
      billingType: billingType ?? this.billingType,
      agreedAmountCents: agreedAmountCents ?? this.agreedAmountCents,
      assignedPartnerIds: assignedPartnerIds ?? this.assignedPartnerIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
