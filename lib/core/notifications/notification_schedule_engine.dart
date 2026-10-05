import '../models/maintenance_visit.dart';

class ScheduledVisitNotification {
  final int id;
  final String visitId;
  final int daysBefore;
  final DateTime scheduledAt;
  final String title;
  final String body;

  const ScheduledVisitNotification({
    required this.id,
    required this.visitId,
    required this.daysBefore,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });
}

class NotificationScheduleEngine {
  static const List<int> defaultOffsetsDays = [7, 3, 2, 1];
  static const int defaultHour = 9;

  /// Genera un ID determinístico de 32 bits a partir de visitId y días de anticipación
  static int generateNotificationId(String visitId, int daysBefore) {
    return (visitId.hashCode.abs() % 10000000) * 10 + (daysBefore % 10);
  }

  /// Retorna los IDs determinísticos que deben ser cancelados para una visita dada
  static List<int> getCancellationNotificationIds(
    String visitId, {
    List<int> offsets = defaultOffsetsDays,
  }) {
    return offsets
        .map((days) => generateNotificationId(visitId, days))
        .toList();
  }

  /// Calcula la fecha y hora de la alerta anticipada
  static DateTime calculateAlertDateTime(
    DateTime scheduledDate,
    int daysBefore, {
    int hour = defaultHour,
  }) {
    final alertDate = scheduledDate.subtract(Duration(days: daysBefore));
    return DateTime(alertDate.year, alertDate.month, alertDate.day, hour, 0);
  }

  /// Computa la lista de notificaciones futuras que deben ser programadas en el sistema
  static List<ScheduledVisitNotification> computeNotifications({
    required MaintenanceVisit visit,
    required DateTime now,
    String? planTitle,
    String? clientName,
    bool notificationsEnabled = true,
    int notificationHour = defaultHour,
    List<int> offsetsDays = defaultOffsetsDays,
  }) {
    if (!notificationsEnabled) return const [];
    if (!visit.isScheduled) return const [];

    final result = <ScheduledVisitNotification>[];

    for (final daysBefore in offsetsDays) {
      final alertDateTime = calculateAlertDateTime(
        visit.scheduledDate,
        daysBefore,
        hour: notificationHour,
      );

      // Descartar fechas pasadas o ya vencidas respecto al instante actual
      if (alertDateTime.isAfter(now)) {
        final id = generateNotificationId(visit.id, daysBefore);
        final timingText = switch (daysBefore) {
          7 => 'en 1 semana',
          3 => 'en 3 días',
          2 => 'en 2 días',
          1 => '¡MAÑANA!',
          _ => 'en $daysBefore días',
        };

        final clientPart = clientName != null && clientName.trim().isNotEmpty
            ? ': $clientName'
            : '';
        final title = 'Mantenimiento $timingText$clientPart';

        final dateStr =
            '${visit.scheduledDate.day.toString().padLeft(2, '0')}/${visit.scheduledDate.month.toString().padLeft(2, '0')}/${visit.scheduledDate.year}';
        final planPart = planTitle != null && planTitle.trim().isNotEmpty
            ? planTitle
            : 'Servicio programado';
        final body = '$planPart programado para el $dateStr.';

        result.add(
          ScheduledVisitNotification(
            id: id,
            visitId: visit.id,
            daysBefore: daysBefore,
            scheduledAt: alertDateTime,
            title: title,
            body: body,
          ),
        );
      }
    }

    return result;
  }
}
