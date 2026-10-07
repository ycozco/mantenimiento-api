import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/database/local_storage_service.dart';
import 'package:mantenimiento_app/core/repositories/sync_queue_repository.dart';
import 'package:mantenimiento_app/core/services/device_identity_service.dart';
import 'package:mantenimiento_app/core/theme/app_theme.dart';
import 'package:mantenimiento_app/features/sync/sync_center_screen.dart';
import 'package:mantenimiento_app/features/sync/sync_transport_probe.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('device identity stays stable across app launches', () async {
    SharedPreferences.setMockInitialValues({});
    final service = DeviceIdentityService();

    final first = await service.getOrCreateDeviceId();
    final second = await service.getOrCreateDeviceId();

    expect(first, isNotEmpty);
    expect(first, second);
  });

  testWidgets(
    'sync center reports local queue, TLS probe and pending modules',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final storage = LocalStorageService(database: db);
      final queue = SyncQueueRepository(db);
      await queue.enqueue(
        workspaceId: 'default',
        entityTable: 'workers',
        entityId: 'worker-local',
        operation: 'UPSERT',
        baseVersion: 1,
        payload: const {'name': 'Local'},
        queuedAt: DateTime.utc(2026, 10, 6),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: SyncCenterScreen(
            storage: storage,
            deviceIdLoader: () async => 'device-test-001',
            probe: () async => const SyncTransportProbeResult(
              supported: true,
              connected: true,
              message: 'TLS de prueba confirmado; sin autenticación NATS.',
              elapsed: Duration(milliseconds: 42),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Servicio NATS'), findsOneWidget);
      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.text('Comprobar canal TLS'));
      await tester.pumpAndSettle();
      expect(find.text('TLS disponible'), findsOneWidget);
      expect(find.textContaining('sin autenticación NATS'), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('API de sincronización'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);

      await tester.tap(find.text('Organización'));
      await tester.pumpAndSettle();
      expect(find.text('Identidad de organización'), findsOneWidget);
      expect(find.text('Invitaciones todavía no disponibles'), findsOneWidget);

      await tester.tap(find.text('Dispositivos'));
      await tester.pumpAndSettle();
      expect(find.text('device-test-001'), findsOneWidget);
      expect(find.text('Aún no vinculado'), findsOneWidget);

      await tester.tap(find.text('Conflictos'));
      await tester.pumpAndSettle();
      expect(find.text('El inbox aún no está implementado'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    },
  );
}
