import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';

enum VisitStatus { scheduled, inProgress, completed, cancelled }

extension VisitStatusExt on VisitStatus {
  String get nameCode {
    switch (this) {
      case VisitStatus.scheduled:
        return 'scheduled';
      case VisitStatus.inProgress:
        return 'inProgress';
      case VisitStatus.completed:
        return 'completed';
      case VisitStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case VisitStatus.scheduled:
        return 'Programada';
      case VisitStatus.inProgress:
        return 'En Progreso';
      case VisitStatus.completed:
        return 'Completada';
      case VisitStatus.cancelled:
        return 'Cancelada';
    }
  }

  static VisitStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
      case 'enprogreso':
        return VisitStatus.inProgress;
      case 'completed':
      case 'completada':
        return VisitStatus.completed;
      case 'cancelled':
      case 'cancelada':
        return VisitStatus.cancelled;
      case 'scheduled':
      case 'programada':
      default:
        return VisitStatus.scheduled;
    }
  }
}

class MaintenanceVisit {
  final String id;
  final String workspaceId;
  final String planId;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final VisitStatus status;
  final String? technicianNotes;
  final int? agreedPriceCents;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final DateTime? deletedAt;

  MaintenanceVisit({
    String? id,
    String? workspaceId,
    required this.planId,
    required this.scheduledDate,
    this.completedDate,
    this.status = VisitStatus.scheduled,
    this.technicianNotes,
    this.agreedPriceCents,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.createdBy,
    this.updatedBy,
    this.version = 1,
    this.deletedAt,
  }) : id = id ?? const Uuid().v4(),
       workspaceId = workspaceId ?? AppConstants.defaultWorkspaceId,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  double? get agreedPrice =>
      agreedPriceCents != null ? agreedPriceCents! / 100.0 : null;
  bool get isCompleted => status == VisitStatus.completed;
  bool get isCancelled => status == VisitStatus.cancelled;
  bool get isInProgress => status == VisitStatus.inProgress;
  bool get isScheduled => status == VisitStatus.scheduled;
  bool get isDeleted => deletedAt != null;

  MaintenanceVisit copyWith({
    String? id,
    String? workspaceId,
    String? planId,
    DateTime? scheduledDate,
    DateTime? completedDate,
    VisitStatus? status,
    String? technicianNotes,
    int? agreedPriceCents,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? version,
    DateTime? deletedAt,
  }) {
    return MaintenanceVisit(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      planId: planId ?? this.planId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      status: status ?? this.status,
      technicianNotes: technicianNotes ?? this.technicianNotes,
      agreedPriceCents: agreedPriceCents ?? this.agreedPriceCents,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
