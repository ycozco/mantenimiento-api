import 'dart:convert';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/company_settings.dart';

class SettingsRepository {
  final AppDatabase _db;
  static const String _settingsMetadataKey = 'company_settings';

  SettingsRepository(this._db);

  /// Obtiene la configuración de empresa/workspace actual o retorna los defaults
  Future<CompanySettings> getSettings() async {
    final row = await (_db.select(
      _db.appMetadata,
    )..where((tbl) => tbl.key.equals(_settingsMetadataKey))).getSingleOrNull();

    if (row == null || row.value.trim().isEmpty) {
      return CompanySettings.defaults();
    }

    try {
      final json = jsonDecode(row.value) as Map<String, dynamic>;
      return CompanySettings.fromJson(json);
    } catch (_) {
      return CompanySettings.defaults();
    }
  }

  /// Observa reactivamente los cambios en la configuración empresarial
  Stream<CompanySettings> watchSettings() {
    return (_db.select(_db.appMetadata)
          ..where((tbl) => tbl.key.equals(_settingsMetadataKey)))
        .watchSingleOrNull()
        .map((row) {
          if (row == null || row.value.trim().isEmpty) {
            return CompanySettings.defaults();
          }
          try {
            final json = jsonDecode(row.value) as Map<String, dynamic>;
            return CompanySettings.fromJson(json);
          } catch (_) {
            return CompanySettings.defaults();
          }
        });
  }

  /// Guarda o actualiza la configuración empresarial de forma transaccional
  Future<void> updateSettings(CompanySettings settings) async {
    final now = DateTime.now();
    final updated = settings.copyWith(updatedAt: now);
    final jsonString = jsonEncode(updated.toJson());

    await _db
        .into(_db.appMetadata)
        .insertOnConflictUpdate(
          AppMetadataCompanion(
            key: const Value(_settingsMetadataKey),
            value: Value(jsonString),
            updatedAt: Value(now),
          ),
        );
  }

  /// Atajo para alternar la regla de permitir stock negativo
  Future<void> setAllowNegativeStock(bool allow) async {
    final current = await getSettings();
    await updateSettings(current.copyWith(allowNegativeStock: allow));
  }
}
