import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/socio.dart';
import '../models/cliente.dart';
import '../models/mantenimiento.dart';
import '../models/obra.dart';
import '../models/gasto.dart';
import '../constants/app_constants.dart';
import '../notifications/notification_service.dart';
import 'app_database.dart';
import 'data_migration_service.dart';
import '../repositories/worker_repository.dart';
import '../repositories/work_log_repository.dart';
import '../repositories/labor_payment_repository.dart';
import '../repositories/maintenance_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/tool_repository.dart';
import '../repositories/purchase_repository.dart';
import '../repositories/partner_repository.dart';
import '../repositories/collection_repository.dart';
import '../repositories/attachment_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/project_financial_service.dart';
import '../services/maintenance_financial_service.dart';
import '../services/dashboard_service.dart';
import '../services/calendar_service.dart';
import '../services/device_preferences_service.dart';
import '../services/backup_restore_service.dart';

class LocalStorageService extends ChangeNotifier {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService({AppDatabase? database}) {
    if (database != null) {
      _instance._db = database;
      _instance._workerRepository = WorkerRepository(database);
      _instance._workLogRepository = WorkLogRepository(database);
      _instance._laborPaymentRepository = LaborPaymentRepository(database);
      _instance._maintenanceRepository = MaintenanceRepository(database);
      _instance._inventoryRepository = InventoryRepository(database);
      _instance._toolRepository = ToolRepository(database);
      _instance._purchaseRepository = PurchaseRepository(database);
      _instance._partnerRepository = PartnerRepository(database);
      _instance._collectionRepository = CollectionRepository(database);
      _instance._projectFinancialService = ProjectFinancialService(database);
      _instance._maintenanceFinancialService = MaintenanceFinancialService(
        database,
      );
    }
    return _instance;
  }
  LocalStorageService._internal();

  AppDatabase? _db;
  AppDatabase get db => _db ??= AppDatabase();

  WorkerRepository? _workerRepository;
  WorkerRepository get workerRepository =>
      _workerRepository ??= WorkerRepository(db);

  WorkLogRepository? _workLogRepository;
  WorkLogRepository get workLogRepository =>
      _workLogRepository ??= WorkLogRepository(db);

  LaborPaymentRepository? _laborPaymentRepository;
  LaborPaymentRepository get laborPaymentRepository =>
      _laborPaymentRepository ??= LaborPaymentRepository(db);

  MaintenanceRepository? _maintenanceRepository;
  MaintenanceRepository get maintenanceRepository =>
      _maintenanceRepository ??= MaintenanceRepository(db);

  InventoryRepository? _inventoryRepository;
  InventoryRepository get inventoryRepository =>
      _inventoryRepository ??= InventoryRepository(db);

  ToolRepository? _toolRepository;
  ToolRepository get toolRepository => _toolRepository ??= ToolRepository(db);

  PurchaseRepository? _purchaseRepository;
  PurchaseRepository get purchaseRepository =>
      _purchaseRepository ??= PurchaseRepository(db);

  PartnerRepository? _partnerRepository;
  PartnerRepository get partnerRepository =>
      _partnerRepository ??= PartnerRepository(db);

  CollectionRepository? _collectionRepository;
  CollectionRepository get collectionRepository =>
      _collectionRepository ??= CollectionRepository(db);

  AttachmentRepository? _attachmentRepository;
  AttachmentRepository get attachmentRepository =>
      _attachmentRepository ??= AttachmentRepository(db);

  ProjectFinancialService? _projectFinancialService;
  ProjectFinancialService get projectFinancialService =>
      _projectFinancialService ??= ProjectFinancialService(db);

  MaintenanceFinancialService? _maintenanceFinancialService;
  MaintenanceFinancialService get maintenanceFinancialService =>
      _maintenanceFinancialService ??= MaintenanceFinancialService(db);

  DashboardService? _dashboardService;
  DashboardService get dashboardService =>
      _dashboardService ??= DashboardService(db, projectFinancialService);

  CalendarService? _calendarService;
  CalendarService get calendarService =>
      _calendarService ??= CalendarService(db);

  SettingsRepository? _settingsRepository;
  SettingsRepository get settingsRepository =>
      _settingsRepository ??= SettingsRepository(db);

  DevicePreferencesService? _devicePreferencesService;
  DevicePreferencesService get devicePreferencesService =>
      _devicePreferencesService ??= DevicePreferencesService();

  BackupRestoreService? _backupRestoreService;
  BackupRestoreService get backupRestoreService =>
      _backupRestoreService ??= BackupRestoreService(db);

  List<Socio> _socios = [];
  List<Cliente> _clientes = [];
  List<Mantenimiento> _mantenimientos = [];
  List<Obra> _obras = [];
  List<Gasto> _gastos = [];

  List<Socio> get socios => List.unmodifiable(_socios);
  List<Cliente> get clientes => List.unmodifiable(_clientes);
  List<Mantenimiento> get mantenimientos => List.unmodifiable(_mantenimientos);
  List<Obra> get obras => List.unmodifiable(_obras);
  List<Gasto> get gastos => List.unmodifiable(_gastos);

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    // 1. Ejecutar migración automática de JSON si es necesario
    final migrationService = DataMigrationService(db);
    await migrationService.migrateIfNeeded();

    // 2. Cargar datos desde SQLite
    await _reloadAllFromDb();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _reloadAllFromDb() async {
    try {
      // Socios (Partners)
      final partnerRows = await (db.select(
        db.partners,
      )..where((tbl) => tbl.deletedAt.isNull())).get();
      _socios = partnerRows
          .map(
            (p) => Socio(
              id: p.id,
              nombre: p.name,
              telefono: p.phone,
              colorValue: p.avatarColor,
            ),
          )
          .toList();

      // Clientes & Ubicaciones
      final clientRows = await (db.select(
        db.clients,
      )..where((tbl) => tbl.deletedAt.isNull())).get();
      final locationRows = await (db.select(
        db.clientLocations,
      )..where((tbl) => tbl.deletedAt.isNull())).get();
      final Map<String, String> locationMap = {
        for (var loc in locationRows) loc.clientId: loc.address,
      };

      _clientes = clientRows
          .map(
            (c) => Cliente(
              id: c.id,
              nombre: c.name,
              telefono: c.phone,
              direccion: locationMap[c.id] ?? '',
              notas: c.notes,
            ),
          )
          .toList();

      final clientsMap = {for (var c in _clientes) c.id: c.nombre};

      // Obras (Projects)
      final projectRows = await (db.select(
        db.projects,
      )..where((tbl) => tbl.deletedAt.isNull())).get();
      _obras = projectRows.map((p) {
        List<String> assigned = [];
        try {
          final decoded = jsonDecode(p.assignedPartnerIdsJson);
          if (decoded is List) {
            assigned = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}

        return Obra(
          id: p.id,
          nombre: p.name,
          clienteId: p.clientId,
          clienteNombre: p.clientId != null ? clientsMap[p.clientId!] : null,
          ubicacion: p.clientId != null ? locationMap[p.clientId!] : null,
          descripcion: p.description,
          presupuesto: p.budgetAmountCents / 100.0,
          fechaInicio: p.startDate,
          fechaFin: p.actualEndDate,
          estado: EstadoObraExt.fromString(p.status),
          sociosAsignados: assigned,
        );
      }).toList();

      // Mantenimientos (Plans + Visits)
      final planRows = await (db.select(
        db.maintenancePlans,
      )..where((tbl) => tbl.deletedAt.isNull())).get();
      final visitRows =
          await (db.select(db.maintenanceVisits)
                ..where((tbl) => tbl.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.asc(t.scheduledDate)]))
              .get();

      final Map<String, MaintenanceVisit> scheduledVisitMap = {};
      final Map<String, MaintenanceVisit> completedVisitMap = {};
      for (final v in visitRows) {
        if (v.status == 'completed' || v.completedDate != null) {
          completedVisitMap[v.planId] = v;
        } else if (v.status == 'scheduled' || v.status == 'inProgress') {
          scheduledVisitMap.putIfAbsent(v.planId, () => v);
        }
      }

      _mantenimientos = planRows.map((plan) {
        final nextVisit = scheduledVisitMap[plan.id];
        final lastVisit = completedVisitMap[plan.id];
        List<String> respons = [];
        try {
          final decoded = jsonDecode(plan.assignedPartnerIdsJson);
          if (decoded is List) {
            respons = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}

        final fechaProximo =
            plan.nextDate ??
            nextVisit?.scheduledDate ??
            DateTime.now().add(Duration(days: plan.intervalDays));

        return Mantenimiento(
          id: plan.id,
          clienteId: plan.clientId,
          clienteNombre: clientsMap[plan.clientId] ?? 'Cliente',
          titulo: plan.title,
          descripcion: plan.description,
          tipoFrecuencia: TipoFrecuenciaExt.fromString(plan.frequencyType),
          diasPersonalizados: plan.intervalDays,
          fechaProximo: fechaProximo,
          fechaUltimo: lastVisit?.completedDate ?? nextVisit?.completedDate,
          responsablesIds: respons,
          activo: plan.isActive,
          completado: nextVisit == null && lastVisit != null,
          billingType: plan.billingType,
          agreedAmountCents: plan.agreedAmountCents,
        );
      }).toList();

      // Gastos (Expenses)
      final expenseRows =
          await (db.select(db.expenses)
                ..where((tbl) => tbl.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.desc(t.date)]))
              .get();

      final obrasMap = {for (var o in _obras) o.id: o.nombre};

      _gastos = expenseRows.map((e) {
        Map<String, double> participaciones = {};
        try {
          final decoded = jsonDecode(e.splitRatiosJson);
          if (decoded is Map) {
            participaciones = decoded.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            );
          }
        } catch (_) {}

        return Gasto(
          id: e.id,
          concepto: e.concept,
          categoria: CategoriaGastoExt.fromString(e.category),
          montoTotal: e.amountCents / 100.0,
          fecha: e.date,
          pagadoPorSocioId: e.paidByPartnerId,
          obraId: e.projectId,
          obraNombre: e.projectId != null ? obrasMap[e.projectId!] : null,
          tipoReparto: TipoRepartoExt.fromString(e.splitMode),
          participaciones: participaciones,
          nota: e.notes,
        );
      }).toList();
    } catch (e, stack) {
      debugPrint('Error recargando datos de SQLite: $e\n$stack');
    }
  }

  // --- CRUD SOCIOS ---
  Future<void> agregarSocio(Socio socio) async {
    await db
        .into(db.partners)
        .insert(
          PartnersCompanion.insert(
            id: socio.id,
            workspaceId: const Value(AppConstants.defaultWorkspaceId),
            name: socio.nombre,
            phone: Value(socio.telefono),
            avatarColor: Value(socio.colorValue),
            equityPercentage: const Value(50.0),
          ),
        );
    await _reloadAllFromDb();
    notifyListeners();
  }

  Future<void> editarSocio(Socio socio) async {
    await (db.update(db.partners)..where((t) => t.id.equals(socio.id))).write(
      PartnersCompanion(
        name: Value(socio.nombre),
        phone: Value(socio.telefono),
        avatarColor: Value(socio.colorValue),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _reloadAllFromDb();
    notifyListeners();
  }

  Future<void> eliminarSocio(String socioId) async {
    if (_socios.length <= 1) return; // Mantener al menos 1
    await (db.update(db.partners)..where((t) => t.id.equals(socioId))).write(
      PartnersCompanion(deletedAt: Value(DateTime.now())),
    );
    await _reloadAllFromDb();
    notifyListeners();
  }

  // --- CRUD CLIENTES ---
  Future<void> agregarCliente(Cliente cliente) async {
    await db.transaction(() async {
      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(
              id: cliente.id,
              workspaceId: const Value(AppConstants.defaultWorkspaceId),
              name: cliente.nombre,
              phone: Value(cliente.telefono),
              notes: Value(cliente.notas),
            ),
          );

      await db
          .into(db.clientLocations)
          .insert(
            ClientLocationsCompanion.insert(
              id: '${cliente.id}_loc_main',
              workspaceId: const Value(AppConstants.defaultWorkspaceId),
              clientId: cliente.id,
              name: const Value('Principal'),
              address:
                  cliente.direccion != null && cliente.direccion!.isNotEmpty
                  ? cliente.direccion!
                  : 'Dirección principal',
            ),
          );
    });
    await _reloadAllFromDb();
    notifyListeners();
  }

  Future<void> editarCliente(Cliente cliente) async {
    await db.transaction(() async {
      await (db.update(
        db.clients,
      )..where((t) => t.id.equals(cliente.id))).write(
        ClientsCompanion(
          name: Value(cliente.nombre),
          phone: Value(cliente.telefono),
          notes: Value(cliente.notas),
          updatedAt: Value(DateTime.now()),
        ),
      );

      if (cliente.direccion != null) {
        await (db.update(
          db.clientLocations,
        )..where((t) => t.clientId.equals(cliente.id))).write(
          ClientLocationsCompanion(
            address: Value(cliente.direccion!),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
    await _reloadAllFromDb();
    notifyListeners();
  }

  Future<void> eliminarCliente(String clienteId) async {
    await (db.update(db.clients)..where((t) => t.id.equals(clienteId))).write(
      ClientsCompanion(deletedAt: Value(DateTime.now())),
    );
    await _reloadAllFromDb();
    notifyListeners();
  }

  // --- CRUD MANTENIMIENTOS ---
  Future<void> agregarMantenimiento(Mantenimiento m) async {
    await db.transaction(() async {
      await db
          .into(db.maintenancePlans)
          .insert(
            MaintenancePlansCompanion.insert(
              id: m.id,
              workspaceId: const Value(AppConstants.defaultWorkspaceId),
              title: m.titulo,
              clientId: m.clienteId,
              locationId: Value('${m.clienteId}_loc_main'),
              description: Value(m.descripcion),
              frequencyType: Value(m.tipoFrecuencia.name),
              intervalDays: Value(m.diasIntervalo),
              nextDate: Value(m.fechaProximo),
              assignedPartnerIdsJson: Value(jsonEncode(m.responsablesIds)),
              isActive: Value(m.activo),
              billingType: Value(m.billingType),
              agreedAmountCents: Value(m.agreedAmountCents),
            ),
          );

      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: '${m.id}_visit_active',
              workspaceId: const Value(AppConstants.defaultWorkspaceId),
              planId: m.id,
              scheduledDate: m.fechaProximo,
              completedDate: Value(m.fechaUltimo),
              status: Value(m.completado ? 'completed' : 'scheduled'),
              agreedPriceCents: Value(
                m.billingType == 'perVisit' ? m.agreedAmountCents : null,
              ),
            ),
          );
    });

    await _reloadAllFromDb();
    await NotificationService().programarAlertasMantenimiento(m);
    notifyListeners();
  }

  Future<void> editarMantenimiento(Mantenimiento m) async {
    await db.transaction(() async {
      await (db.update(
        db.maintenancePlans,
      )..where((t) => t.id.equals(m.id))).write(
        MaintenancePlansCompanion(
          title: Value(m.titulo),
          clientId: Value(m.clienteId),
          description: Value(m.descripcion),
          frequencyType: Value(m.tipoFrecuencia.name),
          intervalDays: Value(m.diasIntervalo),
          nextDate: Value(m.fechaProximo),
          assignedPartnerIdsJson: Value(jsonEncode(m.responsablesIds)),
          isActive: Value(m.activo),
          billingType: Value(m.billingType),
          agreedAmountCents: Value(m.agreedAmountCents),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final activeVisit =
          await (db.select(db.maintenanceVisits)
                ..where(
                  (t) =>
                      t.planId.equals(m.id) &
                      t.status.equals('scheduled') &
                      t.deletedAt.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.scheduledDate)])
                ..limit(1))
              .getSingleOrNull();

      if (activeVisit != null) {
        await (db.update(
          db.maintenanceVisits,
        )..where((t) => t.id.equals(activeVisit.id))).write(
          MaintenanceVisitsCompanion(
            scheduledDate: Value(m.fechaProximo),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });

    await _reloadAllFromDb();
    await NotificationService().programarAlertasMantenimiento(m);
    notifyListeners();
  }

  Future<void> completarMantenimiento(String id) async {
    final idx = _mantenimientos.indexWhere((item) => item.id == id);
    if (idx != -1) {
      final actual = _mantenimientos[idx];
      final proximaFecha = actual.calcularProximoCiclo(DateTime.now());

      await db.transaction(() async {
        // 1. Marcar visita activa como completada
        final activeVisit =
            await (db.select(db.maintenanceVisits)
                  ..where(
                    (t) =>
                        t.planId.equals(id) &
                        t.deletedAt.isNull() &
                        (t.status.equals('scheduled') |
                            t.status.equals('inProgress')),
                  )
                  ..orderBy([(t) => OrderingTerm.asc(t.scheduledDate)])
                  ..limit(1))
                .getSingleOrNull();

        if (activeVisit != null) {
          await (db.update(
            db.maintenanceVisits,
          )..where((t) => t.id.equals(activeVisit.id))).write(
            MaintenanceVisitsCompanion(
              completedDate: Value(DateTime.now()),
              status: const Value('completed'),
              updatedAt: Value(DateTime.now()),
            ),
          );
        } else {
          final visitId =
              '${id}_visit_${DateTime.now().millisecondsSinceEpoch}';
          await db
              .into(db.maintenanceVisits)
              .insert(
                MaintenanceVisitsCompanion.insert(
                  id: visitId,
                  workspaceId: const Value(AppConstants.defaultWorkspaceId),
                  planId: id,
                  scheduledDate: actual.fechaProximo,
                  completedDate: Value(DateTime.now()),
                  status: const Value('completed'),
                  agreedPriceCents: Value(
                    actual.billingType == 'perVisit'
                        ? actual.agreedAmountCents
                        : null,
                  ),
                ),
              );
        }

        // 2. Programar siguiente visita (invariable histórico)
        final nextVisitId =
            '${id}_visit_${DateTime.now().millisecondsSinceEpoch + 1}';
        await db
            .into(db.maintenanceVisits)
            .insert(
              MaintenanceVisitsCompanion.insert(
                id: nextVisitId,
                workspaceId: const Value(AppConstants.defaultWorkspaceId),
                planId: id,
                scheduledDate: proximaFecha,
                status: const Value('scheduled'),
                agreedPriceCents: Value(
                  actual.billingType == 'perVisit'
                      ? actual.agreedAmountCents
                      : null,
                ),
              ),
            );

        // 3. Actualizar el plan con la nueva próxima fecha
        await (db.update(
          db.maintenancePlans,
        )..where((t) => t.id.equals(id))).write(
          MaintenancePlansCompanion(
            nextDate: Value(proximaFecha),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

      await _reloadAllFromDb();
      final actualizado = _mantenimientos.firstWhere((m) => m.id == id);
      await NotificationService().programarAlertasMantenimiento(actualizado);
      notifyListeners();
    }
  }

  Future<void> eliminarMantenimiento(String id) async {
    await NotificationService().cancelarAlertasMantenimiento(id);
    await (db.update(db.maintenancePlans)..where((t) => t.id.equals(id))).write(
      MaintenancePlansCompanion(deletedAt: Value(DateTime.now())),
    );
    await _reloadAllFromDb();
    notifyListeners();
  }

  // --- CRUD OBRAS ---
  Future<void> agregarObra(Obra obra) async {
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: obra.id,
            workspaceId: const Value(AppConstants.defaultWorkspaceId),
            name: obra.nombre,
            clientId: Value(obra.clienteId),
            locationId: Value(
              obra.clienteId != null ? '${obra.clienteId}_loc_main' : null,
            ),
            description: Value(obra.descripcion),
            budgetAmountCents: Value((obra.presupuesto * 100).round()),
            startDate: obra.fechaInicio,
            actualEndDate: Value(obra.fechaFin),
            status: Value(obra.estado.name),
            assignedPartnerIdsJson: Value(jsonEncode(obra.sociosAsignados)),
          ),
        );
    await _reloadAllFromDb();
    notifyListeners();
  }

  Future<void> editarObra(Obra obra) async {
    await (db.update(db.projects)..where((t) => t.id.equals(obra.id))).write(
      ProjectsCompanion(
        name: Value(obra.nombre),
        clientId: Value(obra.clienteId),
        description: Value(obra.descripcion),
        budgetAmountCents: Value((obra.presupuesto * 100).round()),
        startDate: Value(obra.fechaInicio),
        actualEndDate: Value(obra.fechaFin),
        status: Value(obra.estado.name),
        assignedPartnerIdsJson: Value(jsonEncode(obra.sociosAsignados)),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _reloadAllFromDb();
    notifyListeners();
  }

  Future<void> eliminarObra(String obraId) async {
    await (db.update(db.projects)..where((t) => t.id.equals(obraId))).write(
      ProjectsCompanion(deletedAt: Value(DateTime.now())),
    );
    await _reloadAllFromDb();
    notifyListeners();
  }

  // --- CRUD GASTOS ---
  Future<void> agregarGasto(Gasto gasto) async {
    await db
        .into(db.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: gasto.id,
            workspaceId: const Value(AppConstants.defaultWorkspaceId),
            concept: gasto.concepto,
            category: Value(gasto.categoria.name),
            amountCents: Value((gasto.montoTotal * 100).round()),
            date: gasto.fecha,
            paidByPartnerId: gasto.pagadoPorSocioId,
            projectId: Value(gasto.obraId),
            splitMode: Value(gasto.tipoReparto.name),
            splitRatiosJson: Value(jsonEncode(gasto.participaciones)),
            notes: Value(gasto.nota),
          ),
        );
    await _reloadAllFromDb();
    notifyListeners();
  }

  Future<void> editarGasto(Gasto gasto) async {
    await (db.update(db.expenses)..where((t) => t.id.equals(gasto.id))).write(
      ExpensesCompanion(
        concept: Value(gasto.concepto),
        category: Value(gasto.categoria.name),
        amountCents: Value((gasto.montoTotal * 100).round()),
        date: Value(gasto.fecha),
        paidByPartnerId: Value(gasto.pagadoPorSocioId),
        projectId: Value(gasto.obraId),
        splitMode: Value(gasto.tipoReparto.name),
        splitRatiosJson: Value(jsonEncode(gasto.participaciones)),
        notes: Value(gasto.nota),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _reloadAllFromDb();
    notifyListeners();
  }

  Future<void> eliminarGasto(String gastoId) async {
    await (db.update(db.expenses)..where((t) => t.id.equals(gastoId))).write(
      ExpensesCompanion(deletedAt: Value(DateTime.now())),
    );
    await _reloadAllFromDb();
    notifyListeners();
  }

  // --- EXPORTAR / IMPORTAR RESPALDO JSON ---
  String serializeToJson() {
    final Map<String, dynamic> data = {
      'version': 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'socios': _socios.map((s) => s.toJson()).toList(),
      'clientes': _clientes.map((c) => c.toJson()).toList(),
      'mantenimientos': _mantenimientos.map((m) => m.toJson()).toList(),
      'obras': _obras.map((o) => o.toJson()).toList(),
      'gastos': _gastos.map((g) => g.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  Future<void> exportarRespaldo() async {
    final jsonContent = await backupRestoreService.exportBackupJson();
    if (kIsWeb) {
      debugPrint('Exportar en web: ${jsonContent.length} bytes');
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final backupFile = File(
        '${tempDir.path}/decolumax_respaldo_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await backupFile.writeAsString(jsonContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(backupFile.path)],
          subject: 'Copia de Respaldo Completa Decolumax (V2)',
          text: 'Copia local de seguridad generada desde la app de Decolumax.',
        ),
      );
    } catch (e) {
      debugPrint('Error exportando respaldo: $e');
    }
  }

  Future<bool> importarRespaldoJson(String jsonStr) async {
    try {
      final result = await backupRestoreService.restoreBackupJson(jsonStr);
      if (!result.success) {
        debugPrint('Fallo al restaurar backup: ${result.errorMessage}');
        return false;
      }

      await _reloadAllFromDb();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error al importar json: $e');
      return false;
    }
  }
}
