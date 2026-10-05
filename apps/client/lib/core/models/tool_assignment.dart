import 'package:uuid/uuid.dart';

class ToolAssignment {
  final String id;
  final String workspaceId;
  final String toolId;
  final String? workerId;
  final String? projectId;
  final String? maintenanceVisitId;
  final DateTime assignedAt;
  final DateTime? expectedReturnAt;
  final DateTime? returnedAt;
  final String conditionOut;
  final String? conditionIn;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  const ToolAssignment({
    required this.id,
    this.workspaceId = 'default',
    required this.toolId,
    this.workerId,
    this.projectId,
    this.maintenanceVisitId,
    required this.assignedAt,
    this.expectedReturnAt,
    this.returnedAt,
    this.conditionOut = 'good',
    this.conditionIn,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  });

  factory ToolAssignment.create({
    String? id,
    String workspaceId = 'default',
    required String toolId,
    String? workerId,
    String? projectId,
    String? maintenanceVisitId,
    DateTime? assignedAt,
    DateTime? expectedReturnAt,
    String conditionOut = 'good',
    String? notes,
  }) {
    if (workerId == null && projectId == null && maintenanceVisitId == null) {
      throw ArgumentError(
        'ToolAssignment debe tener al menos un responsable o contexto (Trabajador, Obra o Visita).',
      );
    }

    final now = DateTime.now();
    return ToolAssignment(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      toolId: toolId,
      workerId: workerId,
      projectId: projectId,
      maintenanceVisitId: maintenanceVisitId,
      assignedAt: assignedAt ?? now,
      expectedReturnAt: expectedReturnAt,
      conditionOut: conditionOut,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );
  }

  bool get isActive => returnedAt == null && deletedAt == null;
  bool get isReturned => returnedAt != null;

  ToolAssignment copyWith({
    String? id,
    String? workspaceId,
    String? toolId,
    String? workerId,
    String? projectId,
    String? maintenanceVisitId,
    DateTime? assignedAt,
    DateTime? expectedReturnAt,
    DateTime? returnedAt,
    String? conditionOut,
    String? conditionIn,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? version,
    DateTime? deletedAt,
  }) {
    return ToolAssignment(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      toolId: toolId ?? this.toolId,
      workerId: workerId ?? this.workerId,
      projectId: projectId ?? this.projectId,
      maintenanceVisitId: maintenanceVisitId ?? this.maintenanceVisitId,
      assignedAt: assignedAt ?? this.assignedAt,
      expectedReturnAt: expectedReturnAt ?? this.expectedReturnAt,
      returnedAt: returnedAt ?? this.returnedAt,
      conditionOut: conditionOut ?? this.conditionOut,
      conditionIn: conditionIn ?? this.conditionIn,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'toolId': toolId,
      'workerId': workerId,
      'projectId': projectId,
      'maintenanceVisitId': maintenanceVisitId,
      'assignedAt': assignedAt.toIso8601String(),
      'expectedReturnAt': expectedReturnAt?.toIso8601String(),
      'returnedAt': returnedAt?.toIso8601String(),
      'conditionOut': conditionOut,
      'conditionIn': conditionIn,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'version': version,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory ToolAssignment.fromJson(Map<String, dynamic> json) {
    return ToolAssignment(
      id: json['id'] as String,
      workspaceId: json['workspaceId'] as String? ?? 'default',
      toolId: json['toolId'] as String,
      workerId: json['workerId'] as String?,
      projectId: json['projectId'] as String?,
      maintenanceVisitId: json['maintenanceVisitId'] as String?,
      assignedAt: DateTime.parse(json['assignedAt'] as String),
      expectedReturnAt: json['expectedReturnAt'] != null
          ? DateTime.parse(json['expectedReturnAt'] as String)
          : null,
      returnedAt: json['returnedAt'] != null
          ? DateTime.parse(json['returnedAt'] as String)
          : null,
      conditionOut: json['conditionOut'] as String? ?? 'good',
      conditionIn: json['conditionIn'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String?,
      updatedBy: json['updatedBy'] as String?,
      version: json['version'] as int? ?? 1,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
    );
  }
}
