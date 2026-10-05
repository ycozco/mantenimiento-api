import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/maintenance_visit.dart';
import '../models/mantenimiento.dart';
import 'notification_schedule_engine.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notificación abierta: ${response.payload}');
      },
    );

    _isInitialized = true;
    await solicitarPermisos();
  }

  Future<bool> solicitarPermisos() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidImplementation
          ?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Cancela todas las notificaciones programadas para una visita
  Future<void> cancelarAlertasVisita(String visitId) async {
    if (kIsWeb || !_isInitialized) return;
    final ids = NotificationScheduleEngine.getCancellationNotificationIds(
      visitId,
    );
    for (final id in ids) {
      try {
        await _notificationsPlugin.cancel(id: id);
      } catch (e) {
        debugPrint('Error cancelando alerta $id: $e');
      }
    }
  }

  /// Programa notificaciones anticipadas para una MaintenanceVisit (-7, -3, -2, -1 días)
  Future<void> programarAlertasVisita(
    MaintenanceVisit visit, {
    String? planTitle,
    String? clientName,
    bool notificationsEnabled = true,
    int notificationHour = 9,
  }) async {
    if (kIsWeb || !_isInitialized) return;

    // 1. Cancelar cualquier alerta previa de esta visita
    await cancelarAlertasVisita(visit.id);

    // 2. Si no está en estado programado o están desactivadas, no programar nada
    if (!visit.isScheduled || !notificationsEnabled) return;

    // 3. Computar notificaciones válidas futuras
    final scheduledList = NotificationScheduleEngine.computeNotifications(
      visit: visit,
      now: DateTime.now(),
      planTitle: planTitle,
      clientName: clientName,
      notificationsEnabled: notificationsEnabled,
      notificationHour: notificationHour,
    );

    // 4. Programar cada notificación zonificada
    for (final item in scheduledList) {
      await _programarNotificacionZonificada(
        id: item.id,
        titulo: item.title,
        cuerpo: item.body,
        fechaProgramada: item.scheduledAt,
        payload: item.visitId,
      );
    }
  }

  /// Reprograma las alertas de una visita (cancela previas y programa nuevas)
  Future<void> reprogramarAlertasVisita(
    MaintenanceVisit visit, {
    String? planTitle,
    String? clientName,
    bool notificationsEnabled = true,
    int notificationHour = 9,
  }) async {
    await programarAlertasVisita(
      visit,
      planTitle: planTitle,
      clientName: clientName,
      notificationsEnabled: notificationsEnabled,
      notificationHour: notificationHour,
    );
  }

  Future<void> _programarNotificacionZonificada({
    required int id,
    required String titulo,
    required String cuerpo,
    required DateTime fechaProgramada,
    String? payload,
  }) async {
    try {
      final tzDateTime = tz.TZDateTime.from(fechaProgramada, tz.local);

      const AndroidNotificationDetails
      androidDetails = AndroidNotificationDetails(
        'mantenimiento_alertas_channel',
        'Alertas de Mantenimiento',
        channelDescription:
            'Recordatorios anticipados de 7, 3, 2 y 1 días para mantenimientos de clientes',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: titulo,
        body: cuerpo,
        scheduledDate: tzDateTime,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error programando alerta zonificada: $e');
    }
  }

  /// Muestra una notificación inmediata
  Future<void> mostrarNotificacionInmediata({
    required String titulo,
    required String cuerpo,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'mantenimiento_directo_channel',
          'Avisos Inmediatos',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: titulo,
      body: cuerpo,
      notificationDetails: details,
    );
  }

  // --- COMPATIBILIDAD V1 ---

  Future<void> programarAlertasMantenimiento(Mantenimiento m) async {
    if (kIsWeb || !_isInitialized) return;
    await cancelarAlertasMantenimiento(m.id);
    if (!m.activo || m.completado) return;

    final dummyVisit = MaintenanceVisit(
      id: m.id,
      planId: m.id,
      scheduledDate: m.fechaProximo,
      status: VisitStatus.scheduled,
    );

    await programarAlertasVisita(
      dummyVisit,
      planTitle: m.titulo,
      clientName: m.clienteNombre,
    );
  }

  Future<void> cancelarAlertasMantenimiento(String mantenimientoId) async {
    await cancelarAlertasVisita(mantenimientoId);
  }
}
