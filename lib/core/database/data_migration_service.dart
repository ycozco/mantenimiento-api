import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';

class MigrationResult {
  final bool success;
  final bool alreadyMigrated;
  final int partnersCount;
  final int clientsCount;
  final int projectsCount;
  final int maintenancePlansCount;
  final int expensesCount;
  final String? error;

  const MigrationResult({
    required this.success,
    this.alreadyMigrated = false,
    this.partnersCount = 0,
    this.clientsCount = 0,
    this.projectsCount = 0,
    this.maintenancePlansCount = 0,
    this.expensesCount = 0,
    this.error,
  });
}

class DataMigrationService {
  final AppDatabase db;

  DataMigrationService(this.db);

  Future<File?> getLocalV1File() async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/mantenimiento_data.json');
    } catch (e) {
      debugPrint('Error obteniendo directorio local: $e');
      return null;
    }
  }

  Future<File?> createBackupFile(String jsonContent) async {
    if (kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupFile = File('${dir.path}/mantenimiento_data.v1_backup.json');
      await backupFile.writeAsString(jsonContent, flush: true);
      return backupFile;
    } catch (e) {
      debugPrint('Error creando backup V1: $e');
      return null;
    }
  }

  Future<String?> readV1JsonSource() async {
    try {
      final file = await getLocalV1File();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) return content;
      }

      final prefs = await SharedPreferences.getInstance();
      final prefContent = prefs.getString('mantenimiento_backup_key');
      if (prefContent != null && prefContent.trim().isNotEmpty) {
        return prefContent;
      }
    } catch (e) {
      debugPrint('Error leyendo fuente JSON V1: $e');
    }
    return null;
  }

  Future<MigrationResult> migrateIfNeeded({String? overrideJsonStr}) async {
    try {
      // 1. Verificar idempotencia: si la base de datos ya contiene socios o clientes, omitir
      final existingPartners = await db.select(db.partners).get();
      if (existingPartners.isNotEmpty) {
        return const MigrationResult(success: true, alreadyMigrated: true);
      }

      // 2. Obtener JSON fuente
      final jsonStr = overrideJsonStr ?? await readV1JsonSource();
      if (jsonStr == null || jsonStr.trim().isEmpty) {
        // Inicializar datos semilla por defecto si no hay JSON
        await seedDefaultData();
        return const MigrationResult(
          success: true,
          alreadyMigrated: false,
          partnersCount: 2,
          clientsCount: 2,
        );
      }

      // 3. Crear backup físico preventivo antes de la migración
      if (overrideJsonStr == null) {
        await createBackupFile(jsonStr);
      }

      // 4. Ejecutar migración atómica dentro de una transacción
      return await executeMigrationFromJson(jsonStr);
    } catch (e, stack) {
      debugPrint('Error general en migrateIfNeeded: $e\n$stack');
      return MigrationResult(success: false, error: e.toString());
    }
  }

  Future<MigrationResult> executeMigrationFromJson(String jsonStr) async {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        return const MigrationResult(
          success: false,
          error: 'Formato JSON inválido (no es un objeto Map)',
        );
      }
      data = decoded;
    } catch (e) {
      return MigrationResult(
        success: false,
        error: 'JSON corrupto o mal formado: $e',
      );
    }

    int partnersCount = 0;
    int clientsCount = 0;
    int projectsCount = 0;
    int plansCount = 0;
    int expensesCount = 0;

    try {
      await db.transaction(() async {
        // --- MIGRAR SOCIOS ---
        final sociosRaw = data['socios'];
        if (sociosRaw is List) {
          for (final s in sociosRaw) {
            if (s is Map<String, dynamic> &&
                s['id'] != null &&
                s['nombre'] != null) {
              await db
                  .into(db.partners)
                  .insert(
                    PartnersCompanion.insert(
                      id: s['id'].toString(),
                      name: s['nombre'].toString(),
                      phone: Value(s['telefono']?.toString()),
                      avatarColor: Value(s['colorValue'] as int? ?? 0xFFF59E0B),
                      equityPercentage: const Value(50.0),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              partnersCount++;
            }
          }
        }

        // Si no se migraron socios, insertar al menos s1 y s2 para consistencia
        if (partnersCount == 0) {
          await db
              .into(db.partners)
              .insert(
                PartnersCompanion.insert(
                  id: 's1',
                  name: 'Socio 1 (Tú)',
                  avatarColor: const Value(0xFFF59E0B),
                  equityPercentage: const Value(50.0),
                ),
              );
          await db
              .into(db.partners)
              .insert(
                PartnersCompanion.insert(
                  id: 's2',
                  name: 'Socio 2',
                  avatarColor: const Value(0xFF10B981),
                  equityPercentage: const Value(50.0),
                ),
              );
          partnersCount = 2;
        }

        // --- MIGRAR CLIENTES Y UBICACIONES ---
        final clientesRaw = data['clientes'];
        if (clientesRaw is List) {
          for (final c in clientesRaw) {
            if (c is Map<String, dynamic> &&
                c['id'] != null &&
                c['nombre'] != null) {
              final clientId = c['id'].toString();
              await db
                  .into(db.clients)
                  .insert(
                    ClientsCompanion.insert(
                      id: clientId,
                      name: c['nombre'].toString(),
                      phone: Value(c['telefono']?.toString()),
                      notes: Value(c['notas']?.toString()),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );

              final dirStr = c['direccion']?.toString();
              await db
                  .into(db.clientLocations)
                  .insert(
                    ClientLocationsCompanion.insert(
                      id: '${clientId}_loc_main',
                      clientId: clientId,
                      name: const Value('Principal'),
                      address: dirStr != null && dirStr.isNotEmpty
                          ? dirStr
                          : 'Dirección principal',
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              clientsCount++;
            }
          }
        }

        // --- MIGRAR OBRAS (PROJECTS) ---
        final obrasRaw = data['obras'];
        if (obrasRaw is List) {
          for (final o in obrasRaw) {
            if (o is Map<String, dynamic> &&
                o['id'] != null &&
                o['nombre'] != null) {
              final clientId = o['clienteId']?.toString();
              final presupuestoDouble =
                  (o['presupuesto'] as num?)?.toDouble() ?? 0.0;
              final presupuestoCents = (presupuestoDouble * 100).round();
              final startDate = o['fechaInicio'] != null
                  ? DateTime.parse(o['fechaInicio'].toString())
                  : DateTime.now();
              final endDate = o['fechaFin'] != null
                  ? DateTime.parse(o['fechaFin'].toString())
                  : null;
              final sociosList =
                  (o['sociosAsignados'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];

              await db
                  .into(db.projects)
                  .insert(
                    ProjectsCompanion.insert(
                      id: o['id'].toString(),
                      name: o['nombre'].toString(),
                      clientId: Value(clientId),
                      locationId: Value(
                        clientId != null ? '${clientId}_loc_main' : null,
                      ),
                      description: Value(o['descripcion']?.toString()),
                      budgetAmountCents: Value(presupuestoCents),
                      startDate: startDate,
                      actualEndDate: Value(endDate),
                      status: Value(o['estado']?.toString() ?? 'enProgreso'),
                      assignedPartnerIdsJson: Value(jsonEncode(sociosList)),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              projectsCount++;
            }
          }
        }

        // --- MIGRAR MANTENIMIENTOS (PLANS + VISITS) ---
        final mantenimientosRaw = data['mantenimientos'];
        if (mantenimientosRaw is List) {
          for (final m in mantenimientosRaw) {
            if (m is Map<String, dynamic> &&
                m['id'] != null &&
                m['titulo'] != null) {
              final planId = m['id'].toString();
              final clientId = m['clienteId']?.toString() ?? 'c1';
              final diasPers = m['diasPersonalizados'] as int? ?? 30;
              final tipoFreq = m['tipoFrecuencia']?.toString() ?? 'unMes';
              final fechaProximo = m['fechaProximo'] != null
                  ? DateTime.parse(m['fechaProximo'].toString())
                  : DateTime.now();
              final fechaUltimo = m['fechaUltimo'] != null
                  ? DateTime.parse(m['fechaUltimo'].toString())
                  : null;
              final responsList =
                  (m['responsablesIds'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];
              final activo = m['activo'] as bool? ?? true;
              final completado = m['completado'] as bool? ?? false;

              // 1. Plan recurrente
              await db
                  .into(db.maintenancePlans)
                  .insert(
                    MaintenancePlansCompanion.insert(
                      id: planId,
                      title: m['titulo'].toString(),
                      clientId: clientId,
                      locationId: Value('${clientId}_loc_main'),
                      description: Value(m['descripcion']?.toString()),
                      frequencyType: Value(tipoFreq),
                      intervalDays: Value(diasPers > 0 ? diasPers : 30),
                      assignedPartnerIdsJson: Value(jsonEncode(responsList)),
                      isActive: Value(activo),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );

              // 2. Visita activa/programada
              await db
                  .into(db.maintenanceVisits)
                  .insert(
                    MaintenanceVisitsCompanion.insert(
                      id: '${planId}_visit_active',
                      planId: planId,
                      scheduledDate: fechaProximo,
                      completedDate: Value(fechaUltimo),
                      status: Value(completado ? 'completed' : 'scheduled'),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );

              plansCount++;
            }
          }
        }

        // --- MIGRAR GASTOS ---
        final gastosRaw = data['gastos'];
        if (gastosRaw is List) {
          for (final g in gastosRaw) {
            if (g is Map<String, dynamic> &&
                g['id'] != null &&
                g['concepto'] != null) {
              final montoDouble = (g['montoTotal'] as num?)?.toDouble() ?? 0.0;
              final montoCents = (montoDouble * 100).round();
              final fecha = g['fecha'] != null
                  ? DateTime.parse(g['fecha'].toString())
                  : DateTime.now();
              final pagadoPor = g['pagadoPorSocioId']?.toString() ?? 's1';
              final participaciones = g['participaciones'] is Map
                  ? g['participaciones'] as Map
                  : {};
              final splitMap = participaciones.map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              );
              final obraId = g['obraId']?.toString();
              final maintId = g['mantenimientoId']?.toString();

              await db
                  .into(db.expenses)
                  .insert(
                    ExpensesCompanion.insert(
                      id: g['id'].toString(),
                      concept: g['concepto'].toString(),
                      category: Value(g['categoria']?.toString() ?? 'otro'),
                      amountCents: Value(montoCents),
                      date: fecha,
                      paidByPartnerId: pagadoPor,
                      projectId: Value(obraId),
                      visitId: Value(
                        maintId != null ? '${maintId}_visit_active' : null,
                      ),
                      splitMode: Value(
                        g['tipoReparto']?.toString() ?? 'equitativo',
                      ),
                      splitRatiosJson: Value(jsonEncode(splitMap)),
                      notes: Value(g['nota']?.toString()),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
              expensesCount++;
            }
          }
        }
      });

      return MigrationResult(
        success: true,
        alreadyMigrated: false,
        partnersCount: partnersCount,
        clientsCount: clientsCount,
        projectsCount: projectsCount,
        maintenancePlansCount: plansCount,
        expensesCount: expensesCount,
      );
    } catch (e, stack) {
      debugPrint('Error en transacción de migración: $e\n$stack');
      return MigrationResult(success: false, error: e.toString());
    }
  }

  Future<void> seedDefaultData() async {
    await db.transaction(() async {
      await db
          .into(db.partners)
          .insert(
            PartnersCompanion.insert(
              id: 's1',
              name: 'Socio 1 (Tú)',
              avatarColor: const Value(0xFFF59E0B),
              equityPercentage: const Value(50.0),
            ),
          );
      await db
          .into(db.partners)
          .insert(
            PartnersCompanion.insert(
              id: 's2',
              name: 'Socio 2',
              avatarColor: const Value(0xFF10B981),
              equityPercentage: const Value(50.0),
            ),
          );

      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(
              id: 'c1',
              name: 'Residencial Los Álamos',
              phone: const Value('555-0192'),
              notes: const Value('Revisión bombas de agua y tableros'),
            ),
          );
      await db
          .into(db.clientLocations)
          .insert(
            ClientLocationsCompanion.insert(
              id: 'c1_loc_main',
              clientId: 'c1',
              name: const Value('Principal'),
              address: 'Av. Principal #450',
            ),
          );

      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(
              id: 'c2',
              name: 'Clínica San Marcos',
              phone: const Value('555-8821'),
              notes: const Value('Aire acondicionado y generador'),
            ),
          );
      await db
          .into(db.clientLocations)
          .insert(
            ClientLocationsCompanion.insert(
              id: 'c2_loc_main',
              clientId: 'c2',
              name: const Value('Principal'),
              address: 'Calle Médicos 12',
            ),
          );

      final now = DateTime.now();

      await db
          .into(db.maintenancePlans)
          .insert(
            MaintenancePlansCompanion.insert(
              id: 'm1',
              title: 'Mantenimiento Preventivo Bombas',
              clientId: 'c1',
              locationId: const Value('c1_loc_main'),
              frequencyType: const Value('unMesYMedio'),
              intervalDays: const Value(45),
              assignedPartnerIdsJson: const Value('["s1","s2"]'),
            ),
          );
      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'm1_visit_active',
              planId: 'm1',
              scheduledDate: now.add(const Duration(days: 3)),
            ),
          );

      await db
          .into(db.maintenancePlans)
          .insert(
            MaintenancePlansCompanion.insert(
              id: 'm2',
              title: 'Inspección Eléctrica y Climas',
              clientId: 'c2',
              locationId: const Value('c2_loc_main'),
              frequencyType: const Value('unMes'),
              intervalDays: const Value(30),
              assignedPartnerIdsJson: const Value('["s1"]'),
            ),
          );
      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'm2_visit_active',
              planId: 'm2',
              scheduledDate: now.add(const Duration(days: 7)),
            ),
          );

      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'o1',
              name: 'Instalación Red Hidráulica Torre B',
              clientId: const Value('c1'),
              locationId: const Value('c1_loc_main'),
              budgetAmountCents: const Value(4500000), // S/ 45,000.00
              startDate: now.subtract(const Duration(days: 10)),
              status: const Value('enProgreso'),
              assignedPartnerIdsJson: const Value('["s1","s2"]'),
            ),
          );

      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'g1',
              concept: 'Gasolina para camioneta de trabajo',
              category: const Value('gasolina'),
              amountCents: const Value(85000), // S/ 850.00
              date: now.subtract(const Duration(days: 2)),
              paidByPartnerId: 's1',
              splitMode: const Value('equitativo'),
              splitRatiosJson: const Value('{"s1":1.0,"s2":1.0}'),
              notes: const Value('Traslado a Los Álamos'),
            ),
          );

      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'g2',
              concept: 'Materiales tubería PVC y selladores',
              category: const Value('materialesObra'),
              amountCents: const Value(340000), // S/ 3,400.00
              date: now.subtract(const Duration(days: 1)),
              paidByPartnerId: 's2',
              projectId: const Value('o1'),
              splitMode: const Value('equitativo'),
              splitRatiosJson: const Value('{"s1":1.0,"s2":1.0}'),
            ),
          );
    });
  }
}
