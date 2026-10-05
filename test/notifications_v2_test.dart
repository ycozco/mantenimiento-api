import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/models/maintenance_plan.dart';
import 'package:mantenimiento_app/core/models/maintenance_visit.dart';
import 'package:mantenimiento_app/core/notifications/notification_schedule_engine.dart';

void main() {
  group('T-15: Pruebas de Notificaciones Locales V2 para MaintenanceVisit', () {
    final baseNow = DateTime(2026, 10, 1, 8, 0); // 1 de Octubre a las 08:00 AM

    test(
      '1. Cálculo de reglas de anticipación: -7, -3, -2 y -1 días a las 09:00 AM',
      () {
        final scheduledDate = DateTime(2026, 10, 20); // 20 de Octubre

        final d7 = NotificationScheduleEngine.calculateAlertDateTime(
          scheduledDate,
          7,
          hour: 9,
        );
        final d3 = NotificationScheduleEngine.calculateAlertDateTime(
          scheduledDate,
          3,
          hour: 9,
        );
        final d2 = NotificationScheduleEngine.calculateAlertDateTime(
          scheduledDate,
          2,
          hour: 9,
        );
        final d1 = NotificationScheduleEngine.calculateAlertDateTime(
          scheduledDate,
          1,
          hour: 9,
        );

        expect(d7, equals(DateTime(2026, 10, 13, 9, 0)));
        expect(d3, equals(DateTime(2026, 10, 17, 9, 0)));
        expect(d2, equals(DateTime(2026, 10, 18, 9, 0)));
        expect(d1, equals(DateTime(2026, 10, 19, 9, 0)));
      },
    );

    test(
      '2. Visita futura programada a 15 días genera las 4 alertas completas',
      () {
        final visit = MaintenanceVisit(
          id: 'visit-future-1',
          planId: 'plan-1',
          scheduledDate: DateTime(2026, 10, 20),
          status: VisitStatus.scheduled,
        );

        final notifs = NotificationScheduleEngine.computeNotifications(
          visit: visit,
          now: baseNow,
          planTitle: 'Poda y Riego Tecnificado',
          clientName: 'Edificio Los Álamos',
          notificationsEnabled: true,
        );

        expect(notifs.length, equals(4));
        expect(notifs[0].daysBefore, equals(7));
        expect(notifs[0].scheduledAt, equals(DateTime(2026, 10, 13, 9, 0)));
        expect(notifs[0].title, contains('en 1 semana: Edificio Los Álamos'));

        expect(notifs[1].daysBefore, equals(3));
        expect(notifs[1].scheduledAt, equals(DateTime(2026, 10, 17, 9, 0)));
        expect(notifs[1].title, contains('en 3 días: Edificio Los Álamos'));

        expect(notifs[2].daysBefore, equals(2));
        expect(notifs[2].scheduledAt, equals(DateTime(2026, 10, 18, 9, 0)));
        expect(notifs[2].title, contains('en 2 días: Edificio Los Álamos'));

        expect(notifs[3].daysBefore, equals(1));
        expect(notifs[3].scheduledAt, equals(DateTime(2026, 10, 19, 9, 0)));
        expect(notifs[3].title, contains('¡MAÑANA!: Edificio Los Álamos'));
      },
    );

    test(
      '3. Fechas ya vencidas/próximas: no genera alertas absurdas de fechas pasadas',
      () {
        // Visita dentro de 2 días (3 de Octubre)
        final visit = MaintenanceVisit(
          id: 'visit-soon',
          planId: 'plan-1',
          scheduledDate: DateTime(2026, 10, 3),
          status: VisitStatus.scheduled,
        );

        final notifs = NotificationScheduleEngine.computeNotifications(
          visit: visit,
          now: baseNow, // 1 de Octubre a las 08:00 AM
        );

        // Alerta -7 (26 de Septiembre) y -3 (30 de Septiembre) ya pasaron.
        // Solo deben programarse -2 (1 de Octubre a las 09:00 AM) y -1 (2 de Octubre a las 09:00 AM)
        expect(notifs.length, equals(2));
        expect(notifs.map((n) => n.daysBefore), containsAll([2, 1]));
        expect(notifs.map((n) => n.daysBefore), isNot(contains(7)));
        expect(notifs.map((n) => n.daysBefore), isNot(contains(3)));
      },
    );

    test('4. Notification ID estable y determinístico', () {
      final id1 = NotificationScheduleEngine.generateNotificationId(
        'visit-uuid-1234',
        7,
      );
      final id2 = NotificationScheduleEngine.generateNotificationId(
        'visit-uuid-1234',
        7,
      );
      final idDiffOffset = NotificationScheduleEngine.generateNotificationId(
        'visit-uuid-1234',
        3,
      );
      final idDiffVisit = NotificationScheduleEngine.generateNotificationId(
        'visit-uuid-5678',
        7,
      );

      expect(
        id1,
        equals(id2),
        reason: 'Mismo visitId y mismo offset debe generar ID idéntico',
      );
      expect(
        id1,
        isNot(equals(idDiffOffset)),
        reason: 'Diferente offset genera diferente ID',
      );
      expect(
        id1,
        isNot(equals(idDiffVisit)),
        reason: 'Diferente visita genera diferente ID',
      );
      expect(id1, isPositive);
    });

    test(
      '5. Cancelación: genera lista determinística de IDs a cancelar para una visita',
      () {
        final ids = NotificationScheduleEngine.getCancellationNotificationIds(
          'visit-uuid-1234',
        );

        expect(ids.length, equals(4));
        expect(
          ids[0],
          equals(
            NotificationScheduleEngine.generateNotificationId(
              'visit-uuid-1234',
              7,
            ),
          ),
        );
        expect(
          ids[1],
          equals(
            NotificationScheduleEngine.generateNotificationId(
              'visit-uuid-1234',
              3,
            ),
          ),
        );
        expect(
          ids[2],
          equals(
            NotificationScheduleEngine.generateNotificationId(
              'visit-uuid-1234',
              2,
            ),
          ),
        );
        expect(
          ids[3],
          equals(
            NotificationScheduleEngine.generateNotificationId(
              'visit-uuid-1234',
              1,
            ),
          ),
        );
      },
    );

    test(
      '6. Reprogramación: cambia la fecha y genera nuevas fechas de alerta',
      () {
        final visitOriginal = MaintenanceVisit(
          id: 'visit-reprog',
          planId: 'plan-1',
          scheduledDate: DateTime(2026, 10, 15),
          status: VisitStatus.scheduled,
        );

        final notifsOriginal = NotificationScheduleEngine.computeNotifications(
          visit: visitOriginal,
          now: baseNow,
        );

        final visitReprogramada = visitOriginal.copyWith(
          scheduledDate: DateTime(2026, 10, 25),
        );

        final notifsReprog = NotificationScheduleEngine.computeNotifications(
          visit: visitReprogramada,
          now: baseNow,
        );

        expect(notifsOriginal.length, equals(4));
        expect(notifsReprog.length, equals(4));

        // La alerta -7 pasa del 8 de Octubre al 18 de Octubre
        expect(
          notifsOriginal.first.scheduledAt,
          equals(DateTime(2026, 10, 8, 9, 0)),
        );
        expect(
          notifsReprog.first.scheduledAt,
          equals(DateTime(2026, 10, 18, 9, 0)),
        );
      },
    );

    test('7. Completado: Visita completada no genera notificaciones', () {
      final completedVisit = MaintenanceVisit(
        id: 'visit-done',
        planId: 'plan-1',
        scheduledDate: DateTime(2026, 10, 20),
        status: VisitStatus.completed,
      );

      final notifs = NotificationScheduleEngine.computeNotifications(
        visit: completedVisit,
        now: baseNow,
      );

      expect(notifs, isEmpty);
    });

    test('8. Cancelado: Visita cancelada no genera notificaciones', () {
      final cancelledVisit = MaintenanceVisit(
        id: 'visit-cancelled',
        planId: 'plan-1',
        scheduledDate: DateTime(2026, 10, 20),
        status: VisitStatus.cancelled,
      );

      final notifs = NotificationScheduleEngine.computeNotifications(
        visit: cancelledVisit,
        now: baseNow,
      );

      expect(notifs, isEmpty);
    });

    test(
      '9. Siguiente visita: Plan recurrente genera nueva visita con sus propias notificaciones',
      () {
        final plan = MaintenancePlan(
          id: 'plan-mensual',
          title: 'Mantenimiento Mensual de Áreas Verdes',
          clientId: 'client-1',
          frequencyType: 'monthly',
          nextDate: DateTime(2026, 10, 15),
        );

        // Simulamos la generación del siguiente ciclo
        final nextCycleDate = plan.calculateNextCycle(DateTime(2026, 10, 15));
        final nextVisit = MaintenanceVisit(
          id: 'visit-ciclo-2',
          planId: plan.id,
          scheduledDate: nextCycleDate,
          status: VisitStatus.scheduled,
        );

        final notifs = NotificationScheduleEngine.computeNotifications(
          visit: nextVisit,
          now: DateTime(2026, 10, 15, 12, 0),
          planTitle: plan.title,
        );

        expect(notifs.length, equals(4));
        expect(notifs.first.visitId, equals('visit-ciclo-2'));
        expect(
          notifs.first.scheduledAt.isAfter(DateTime(2026, 10, 15)),
          isTrue,
        );
      },
    );

    test(
      '10. Notificaciones desactivadas a nivel de dispositivo no generan alertas',
      () {
        final visit = MaintenanceVisit(
          id: 'visit-disabled',
          planId: 'plan-1',
          scheduledDate: DateTime(2026, 10, 20),
          status: VisitStatus.scheduled,
        );

        final notifs = NotificationScheduleEngine.computeNotifications(
          visit: visit,
          now: baseNow,
          notificationsEnabled: false, // Desactivado por usuario
        );

        expect(notifs, isEmpty);
      },
    );
  });
}
