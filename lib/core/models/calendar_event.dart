enum CalendarSourceType { maintenanceVisit, project, toolReturn }

class CalendarEvent {
  final String id;
  final CalendarSourceType sourceType;
  final String sourceId;
  final String title;
  final String? subtitle;
  final DateTime startDate;
  final DateTime? endDate;
  final String
  status; // 'pending', 'in_progress', 'completed', 'cancelled', 'overdue'
  final String priority; // 'normal', 'high', 'urgent'
  final Map<String, dynamic> metadata;

  CalendarEvent({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.title,
    this.subtitle,
    required this.startDate,
    this.endDate,
    required this.status,
    this.priority = 'normal',
    this.metadata = const {},
  });

  bool get isOverdue {
    if (status == 'completed' || status == 'cancelled') return false;
    return startDate.isBefore(DateTime.now());
  }

  String get sourceTypeLabel {
    switch (sourceType) {
      case CalendarSourceType.maintenanceVisit:
        return 'Mantenimiento';
      case CalendarSourceType.project:
        return 'Obra';
      case CalendarSourceType.toolReturn:
        return 'Herramienta';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      case 'in_progress':
        return 'En Curso';
      case 'overdue':
        return 'Vencido';
      case 'pending':
      default:
        return 'Programado';
    }
  }
}
