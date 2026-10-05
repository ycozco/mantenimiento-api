import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/company_settings.dart';
import 'package:mantenimiento_app/core/models/device_preferences.dart';
import 'package:mantenimiento_app/core/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settingsRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    settingsRepo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    '1. Defaults: Retorna configuración por defecto cuando la base está vacía',
    () async {
      final settings = await settingsRepo.getSettings();

      expect(settings.companyName, equals('Decolumax EIRL'));
      expect(settings.currency, equals('PEN'));
      expect(settings.timezone, equals('America/Lima'));
      expect(settings.allowNegativeStock, isFalse);
      expect(settings.defaultWorkDayHours, equals(8.0));
      expect(settings.defaultNotificationHour, equals(9));
      expect(settings.workspaceId, equals('default'));
    },
  );

  test('2. Company name: Identidad inicial de Decolumax EIRL', () async {
    final defaults = CompanySettings.defaults();
    expect(defaults.companyName, equals('Decolumax EIRL'));
    expect(defaults.workspaceId, equals('default'));
  });

  test('3. Moneda oficial es PEN (Soles)', () async {
    final settings = await settingsRepo.getSettings();
    expect(settings.currency, equals('PEN'));
  });

  test('4. Zona horaria oficial es America/Lima', () async {
    final settings = await settingsRepo.getSettings();
    expect(settings.timezone, equals('America/Lima'));
  });

  test('5. Cambio de setting: Modificación de campos empresariales', () async {
    final current = await settingsRepo.getSettings();
    final updated = current.copyWith(
      legalName: 'Decolumax Servicios Integrales S.A.C.',
      ruc: '20601234567',
      phone: '+51 987654321',
      email: 'operaciones@decolumax.pe',
      address: 'Av. Industrial 456, Lima',
    );

    await settingsRepo.updateSettings(updated);

    final retrieved = await settingsRepo.getSettings();
    expect(retrieved.companyName, equals('Decolumax EIRL'));
    expect(
      retrieved.legalName,
      equals('Decolumax Servicios Integrales S.A.C.'),
    );
    expect(retrieved.ruc, equals('20601234567'));
    expect(retrieved.phone, equals('+51 987654321'));
    expect(retrieved.email, equals('operaciones@decolumax.pe'));
    expect(retrieved.address, equals('Av. Industrial 456, Lima'));
  });

  test('6. Persistencia: Valores guardados en tabla app_metadata', () async {
    final custom = CompanySettings(
      companyName: 'Decolumax Paisajismo',
      currency: 'PEN',
      timezone: 'America/Lima',
      ruc: '20111222333',
      updatedAt: DateTime.now(),
    );

    await settingsRepo.updateSettings(custom);

    // Inspeccionar SQLite directamente en la tabla app_metadata
    final rawRow = await (db.select(
      db.appMetadata,
    )..where((tbl) => tbl.key.equals('company_settings'))).getSingle();

    expect(rawRow.value, contains('Decolumax Paisajismo'));
    expect(rawRow.value, contains('20111222333'));
  });

  test(
    '7. allowNegativeStock: Activación y desactivación de inventario negativo',
    () async {
      expect((await settingsRepo.getSettings()).allowNegativeStock, isFalse);

      await settingsRepo.setAllowNegativeStock(true);
      expect((await settingsRepo.getSettings()).allowNegativeStock, isTrue);

      await settingsRepo.setAllowNegativeStock(false);
      expect((await settingsRepo.getSettings()).allowNegativeStock, isFalse);
    },
  );

  test(
    '8. Preferencia local: DevicePreferences almacena configuraciones visuales del dispositivo',
    () async {
      const prefs = DevicePreferences(
        themeMode: 'dark',
        notificationsEnabled: true,
        compactView: true,
        lastScreen: 'dashboard',
      );

      final map = prefs.toJson();
      final reconstructed = DevicePreferences.fromJson(map);

      expect(reconstructed.themeMode, equals('dark'));
      expect(reconstructed.notificationsEnabled, isTrue);
      expect(reconstructed.compactView, isTrue);
      expect(reconstructed.lastScreen, equals('dashboard'));
    },
  );

  test(
    '9. Separación Empresa / Dispositivo: Las preferencias locales no contaminan la configuración empresarial',
    () async {
      // 1. Configuramos empresa
      await settingsRepo.updateSettings(
        CompanySettings.defaults().copyWith(companyName: 'Empresa Aislada'),
      );

      // 2. Modificamos preferencias del dispositivo en SharedPreferences
      final sp = await SharedPreferences.getInstance();
      await sp.setString('device_theme_mode', 'light');
      await sp.setBool('device_notifications_enabled', false);

      // 3. Verificamos que la configuración de la empresa en DB permanece intacta
      final company = await settingsRepo.getSettings();
      expect(company.companyName, equals('Empresa Aislada'));
      expect(company.currency, equals('PEN'));

      // 4. Verificamos que en la tabla app_metadata no existen claves visuales del dispositivo
      final metadataRows = await db.select(db.appMetadata).get();
      final keys = metadataRows.map((r) => r.key).toList();
      expect(keys, isNot(contains('device_theme_mode')));
      expect(keys, isNot(contains('device_notifications_enabled')));
    },
  );

  test(
    '10. No pérdida después de restart simulado: Nueva instancia de SettingsRepository conserva datos',
    () async {
      final initial = CompanySettings.defaults().copyWith(
        companyName: 'Decolumax Persistente',
        phone: '999888777',
        allowNegativeStock: true,
      );
      await settingsRepo.updateSettings(initial);

      // Simular reinicio creando nueva instancia de SettingsRepository sobre la misma DB
      final freshRepo = SettingsRepository(db);
      final loaded = await freshRepo.getSettings();

      expect(loaded.companyName, equals('Decolumax Persistente'));
      expect(loaded.phone, equals('999888777'));
      expect(loaded.allowNegativeStock, isTrue);
      expect(loaded.currency, equals('PEN'));
      expect(loaded.timezone, equals('America/Lima'));
    },
  );
}
