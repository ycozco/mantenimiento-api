import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/database/local_storage_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar formateo de fechas en español
  await initializeDateFormatting('es', null);

  // Inicializar servicio de notificaciones locales
  final notificationService = NotificationService();
  await notificationService.init();

  // Inicializar base de datos local y cargar datos
  final localStorage = LocalStorageService();
  await localStorage.init();

  // Programar alertas iniciales para mantenimientos activos
  for (final m in localStorage.mantenimientos) {
    await notificationService.programarAlertasMantenimiento(m);
  }

  runApp(MantenimientoApp(storage: localStorage));
}

class MantenimientoApp extends StatelessWidget {
  final LocalStorageService storage;

  const MantenimientoApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mantenimiento & Gastos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(storage: storage),
    );
  }
}
