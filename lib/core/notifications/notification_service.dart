import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/mantenimiento.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
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

    const InitializationSettings initializationSettings = InitializationSettings(
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
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  int _generarNotificationId(String mantenimientoId, int diasAntes) {
    return (mantenimientoId.hashCode ^ diasAntes.hashCode).abs() % 100000000;
  }

  Future<void> programarAlertasMantenimiento(Mantenimiento m) async {
    if (kIsWeb) return;

    await cancelarAlertasMantenimiento(m.id);

    if (!m.activo || m.completado) return;

    final targetDate = m.fechaProximo;
    final now = DateTime.now();

    const diasAlerta = [7, 3, 2, 1];

    for (final diasAntes in diasAlerta) {
      final fechaAlerta = targetDate.subtract(Duration(days: diasAntes));
      final fechaAlertaAjustada = DateTime(
        fechaAlerta.year,
        fechaAlerta.month,
        fechaAlerta.day,
        9, // 9:00 AM
        0,
      );

      if (fechaAlertaAjustada.isAfter(now)) {
        final notifId = _generarNotificationId(m.id, diasAntes);
        String mensajeTiempo = diasAntes == 7
            ? 'en 1 semana'
            : diasAntes == 1
                ? '¡MAÑANA!'
                : 'en $diasAntes días';

        await _programarNotificacionZonificada(
          id: notifId,
          titulo: 'Mantenimiento $mensajeTiempo: ${m.clienteNombre}',
          cuerpo: '${m.titulo} programado para el ${targetDate.day}/${targetDate.month}/${targetDate.year}.',
          fechaProgramada: fechaAlertaAjustada,
          payload: m.id,
        );
      }
    }
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

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'mantenimiento_alertas_channel',
        'Alertas de Mantenimiento',
        channelDescription: 'Recordatorios anticipados de 7, 3, 2 y 1 días para mantenimientos de clientes',
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

  Future<void> cancelarAlertasMantenimiento(String mantenimientoId) async {
    if (kIsWeb) return;
    const diasAlerta = [7, 3, 2, 1];
    for (final diasAntes in diasAlerta) {
      final notifId = _generarNotificationId(mantenimientoId, diasAntes);
      await _notificationsPlugin.cancel(id: notifId);
    }
  }

  Future<void> mostrarNotificacionInmediata({
    required String titulo,
    required String cuerpo,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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
}
