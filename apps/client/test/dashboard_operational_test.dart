import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/constants/app_constants.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/capital_movement.dart' as model;
import 'package:mantenimiento_app/core/models/collection.dart' as model;
import 'package:mantenimiento_app/core/models/inventory_item.dart' as model;
import 'package:mantenimiento_app/core/models/labor_payment.dart' as model;
import 'package:mantenimiento_app/core/models/stock_movement.dart' as model;
import 'package:mantenimiento_app/core/models/tool.dart' as model;
import 'package:mantenimiento_app/core/models/tool_assignment.dart' as model;
import 'package:mantenimiento_app/core/models/work_log.dart' as model;
import 'package:mantenimiento_app/core/models/worker.dart' as model;
import 'package:mantenimiento_app/core/repositories/collection_repository.dart';
import 'package:mantenimiento_app/core/repositories/inventory_repository.dart';
import 'package:mantenimiento_app/core/repositories/labor_payment_repository.dart';
import 'package:mantenimiento_app/core/repositories/partner_repository.dart';
import 'package:mantenimiento_app/core/repositories/tool_repository.dart';
import 'package:mantenimiento_app/core/repositories/work_log_repository.dart';
import 'package:mantenimiento_app/core/repositories/worker_repository.dart';
import 'package:mantenimiento_app/core/services/dashboard_service.dart';
import 'package:mantenimiento_app/core/services/project_financial_service.dart';

void main() {
  late AppDatabase db;
  late DashboardService dashboardService;
  late ProjectFinancialService financialService;
  late InventoryRepository inventoryRepo;
  late WorkerRepository workerRepo;
  late WorkLogRepository workLogRepo;
  late LaborPaymentRepository laborPaymentRepo;
  late CollectionRepository collectionRepo;
  late PartnerRepository partnerRepo;
  late ToolRepository toolRepo;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    financialService = ProjectFinancialService(db);
    dashboardService = DashboardService(db, financialService);
    inventoryRepo = InventoryRepository(db);
    workerRepo = WorkerRepository(db);
    workLogRepo = WorkLogRepository(db);
    laborPaymentRepo = LaborPaymentRepository(db);
    collectionRepo = CollectionRepository(db);
    partnerRepo = PartnerRepository(db);
    toolRepo = ToolRepository(db);

    // Semilla básica de cliente y socio para llaves foráneas
    await db
        .into(db.clients)
        .insert(ClientsCompanion.insert(id: 'client-1', name: 'Cliente Base'));

    await db
        .into(db.partners)
        .insert(
          PartnersCompanion.insert(id: 'partner-1', name: 'Socio Principal'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('1. Dashboard vacío: todos los contadores en 0 sin errores', () async {
    final summary = await dashboardService.getDashboardSummary();

    expect(summary.activeProjectsCount, equals(0));
    expect(summary.activeWorkersCount, equals(0));
    expect(summary.assignedToolsCount, equals(0));
    expect(summary.toolsInMaintenanceCount, equals(0));
    expect(summary.overdueToolReturnsCount, equals(0));
    expect(summary.visitsTodayCount, equals(0));
    expect(summary.visitsUpcoming7DaysCount, equals(0));
    expect(summary.visitsOverdueCount, equals(0));
    expect(summary.activeProjectsAgreedRevenueCents, equals(0));
    expect(summary.activeProjectsTotalCostCents, equals(0));
    expect(summary.activeProjectsGrossMarginCents, equals(0));
    expect(summary.activeProjectsGrossMarginPercent, equals(0.0));
    expect(summary.activeProjectsCollectedCents, equals(0));
    expect(summary.activeProjectsReceivableCents, equals(0));
    expect(summary.totalPendingLaborDebtCents, equals(0));
    expect(summary.lowStockItemsCount, equals(0));
    expect(summary.outOfStockItemsCount, equals(0));
    expect(summary.stockAlerts, isEmpty);
    expect(summary.hasUrgentAlerts, isFalse);
  });

  test('2. Obra activa: conteo correcto y estado de ejecución', () async {
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-activa',
            clientId: const Value('client-1'),
            name: 'Obra Los Álamos',
            budgetAmountCents: const Value(500000), // S/ 5,000
            status: const Value('in_progress'),
            startDate: DateTime.now(),
          ),
        );

    // Obra completada no debe contar como activa
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-terminada',
            clientId: const Value('client-1'),
            name: 'Obra Antigua',
            budgetAmountCents: const Value(300000),
            status: const Value('completed'),
            startDate: DateTime.now().subtract(const Duration(days: 60)),
          ),
        );

    final summary = await dashboardService.getDashboardSummary();
    expect(summary.activeProjectsCount, equals(1));
    expect(summary.activeProjectsAgreedRevenueCents, equals(500000));
    expect(summary.activeProjectsAgreedRevenue, equals(5000.0));
  });

  test(
    '3. Agregación de costos en obras activas (Mano de obra, materiales y gastos)',
    () async {
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'p1',
              clientId: const Value('client-1'),
              name: 'Obra 1',
              budgetAmountCents: const Value(1000000), // S/ 10,000
              status: const Value('in_progress'),
              startDate: DateTime.now(),
            ),
          );

      await workerRepo.createWorker(
        model.Worker(
          id: 'w1',
          name: 'Carlos',
          defaultPaymentType: AppConstants.paymentTypeDaily,
          defaultRateCents: 10000,
        ),
      );

      // Jornada laboral S/ 100
      await workLogRepo.createWorkLog(
        model.WorkLog(
          id: 'log-1',
          workerId: 'w1',
          projectId: 'p1',
          date: DateTime.now(),
          paymentType: AppConstants.paymentTypeDaily,
          quantity: 1.0,
          rateCents: 10000,
          amountCents: 10000,
        ),
      );

      // Insumo y consumo S/ 200
      await inventoryRepo.createItem(
        model.InventoryItem.create(
          id: 'i1',
          name: 'Cemento',
          category: 'materiales',
          unit: 'bolsa',
          defaultCostCents: 2500,
        ),
      );
      // Compra inicial para permitir consumo
      await inventoryRepo.recordMovement(
        model.StockMovement.create(
          id: 'stock-in',
          itemId: 'i1',
          movementType: 'purchase',
          quantity: 50.0,
          unitCostCents: 2500,
        ),
      );
      // Consumo de 8 bolsas = S/ 200
      await inventoryRepo.recordMovement(
        model.StockMovement.create(
          id: 'stock-cons',
          itemId: 'i1',
          movementType: 'consumption',
          quantity: 8.0,
          unitCostCents: 2500,
          projectId: 'p1',
        ),
      );

      // Gasto directo S/ 150
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-1',
              concept: 'Herramientas menores',
              amountCents: const Value(15000),
              date: DateTime.now(),
              paidByPartnerId: 'partner-1',
              projectId: const Value('p1'),
            ),
          );

      final summary = await dashboardService.getDashboardSummary();
      // Costo total = 100 + 200 + 150 = S/ 450 (45,000 cents)
      expect(summary.activeProjectsTotalCostCents, equals(45000));
      expect(summary.activeProjectsTotalCost, equals(450.0));
      // Margen bruto = 10,000 - 450 = S/ 9,550
      expect(summary.activeProjectsGrossMarginCents, equals(955000));
      expect(summary.activeProjectsGrossMarginPercent, closeTo(95.5, 0.01));
    },
  );

  test('4. Total por cobrar: suma de saldos pendientes de clientes', () async {
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'p-cobro',
            clientId: const Value('client-1'),
            name: 'Obra Cobros',
            budgetAmountCents: const Value(1000000), // S/ 10,000
            status: const Value('in_progress'),
            startDate: DateTime.now(),
          ),
        );

    // Cobro parcial S/ 6,000
    await collectionRepo.recordCollection(
      model.Collection.create(
        id: 'c1',
        clientId: 'client-1',
        projectId: 'p-cobro',
        amountCents: 600000,
        date: DateTime.now(),
        paymentMethod: 'transfer',
      ),
    );

    final summary = await dashboardService.getDashboardSummary();
    expect(summary.activeProjectsCollectedCents, equals(600000));
    expect(summary.activeProjectsReceivableCents, equals(400000));
    expect(summary.activeProjectsReceivable, equals(4000.0));
  });

  test(
    '5. Aportes de socio no alteran el revenue ni costo de obras en dashboard',
    () async {
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'p-cap',
              clientId: const Value('client-1'),
              name: 'Obra Capital',
              budgetAmountCents: const Value(800000), // S/ 8,000
              status: const Value('in_progress'),
              startDate: DateTime.now(),
            ),
          );

      // Aporte de capital de S/ 5,000
      await partnerRepo.recordCapitalMovement(
        model.CapitalMovement.create(
          id: 'cap-mov-1',
          partnerId: 'partner-1',
          projectId: 'p-cap',
          type: 'contribution',
          amountCents: 500000,
          date: DateTime.now(),
        ),
      );

      final summary = await dashboardService.getDashboardSummary();
      expect(summary.activeProjectsAgreedRevenueCents, equals(800000));
      expect(summary.activeProjectsTotalCostCents, equals(0));
    },
  );

  test(
    '6. Stock bajo: detecta ítems con stock menor o igual al mínimo de alerta',
    () async {
      await inventoryRepo.createItem(
        model.InventoryItem.create(
          id: 'item-low',
          name: 'Mioporos',
          category: 'plantas',
          unit: 'unidad',
          minStockAlert: 20.0,
        ),
      );

      // Compra de 15 unidades (menor al mínimo de 20)
      await inventoryRepo.recordMovement(
        model.StockMovement.create(
          id: 'm-in-1',
          itemId: 'item-low',
          movementType: 'purchase',
          quantity: 15.0,
          unitCostCents: 200,
        ),
      );

      final summary = await dashboardService.getDashboardSummary();
      expect(summary.lowStockItemsCount, equals(1));
      expect(summary.outOfStockItemsCount, equals(0));
      expect(summary.stockAlerts.first.isOutOfStock, isFalse);
      expect(summary.stockAlerts.first.currentStock, equals(15.0));
    },
  );

  test('7. Stock agotado: detecta ítems con stock cero o negativo', () async {
    await inventoryRepo.createItem(
      model.InventoryItem.create(
        id: 'item-out',
        name: 'Fertilizante NPK',
        category: 'quimicos',
        unit: 'bolsa',
        minStockAlert: 5.0,
      ),
    );

    // Sin movimientos de entrada -> stock 0
    final summary = await dashboardService.getDashboardSummary();
    expect(summary.outOfStockItemsCount, equals(1));
    expect(summary.stockAlerts.first.isOutOfStock, isTrue);
    expect(summary.hasUrgentAlerts, isTrue);
  });

  test(
    '8. Mantenimiento próximo: detecta visitas en los próximos 7 días y hoy',
    () async {
      await db
          .into(db.maintenancePlans)
          .insert(
            MaintenancePlansCompanion.insert(
              id: 'plan-1',
              clientId: 'client-1',
              title: 'Plan Residencial',
            ),
          );

      final now = DateTime.now();

      // Visita para hoy
      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'visit-today',
              planId: 'plan-1',
              scheduledDate: now,
              status: const Value('pending'),
            ),
          );

      // Visita para dentro de 3 días
      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'visit-future',
              planId: 'plan-1',
              scheduledDate: now.add(const Duration(days: 3)),
              status: const Value('pending'),
            ),
          );

      final summary = await dashboardService.getDashboardSummary();
      expect(summary.visitsTodayCount, equals(1));
      expect(summary.visitsUpcoming7DaysCount, equals(1));
      expect(summary.visitsOverdueCount, equals(0));
    },
  );

  test(
    '9. Mantenimiento vencido: detecta visitas programadas antes de hoy no completadas',
    () async {
      await db
          .into(db.maintenancePlans)
          .insert(
            MaintenancePlansCompanion.insert(
              id: 'plan-vencido',
              clientId: 'client-1',
              title: 'Plan Corporativo',
            ),
          );

      // Visita de hace 2 días en estado pending
      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'visit-old',
              planId: 'plan-vencido',
              scheduledDate: DateTime.now().subtract(const Duration(days: 2)),
              status: const Value('pending'),
            ),
          );

      final summary = await dashboardService.getDashboardSummary();
      expect(summary.visitsOverdueCount, equals(1));
      expect(summary.hasUrgentAlerts, isTrue);
    },
  );

  test('10. Herramientas asignadas, en taller y retornos vencidos', () async {
    final t1 = model.Tool.create(
      id: 'tool-1',
      code: 'DES-01',
      name: 'Desbrozadora Honda',
      category: 'maquinaria',
    );
    final t2 = model.Tool.create(
      id: 'tool-2',
      code: 'MOT-01',
      name: 'Motosierra Stihl',
      category: 'maquinaria',
    );
    await toolRepo.createTool(t1);
    await toolRepo.createTool(t2);

    // Poner t2 en taller de mantenimiento
    await toolRepo.updateTool(t2.copyWith(currentStatus: 'maintenance'));

    await workerRepo.createWorker(
      model.Worker(
        id: 'w-tools',
        name: 'Operador Herramientas',
        defaultRateCents: 6000,
      ),
    );

    // Asignar t1 con fecha de retorno en el pasado (vencida)
    await toolRepo.assignTool(
      model.ToolAssignment.create(
        id: 'asg-overdue',
        toolId: t1.id,
        workerId: 'w-tools',
        expectedReturnAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );

    final summary = await dashboardService.getDashboardSummary();
    expect(summary.assignedToolsCount, equals(1));
    expect(summary.toolsInMaintenanceCount, equals(1));
    expect(summary.overdueToolReturnsCount, equals(1));
    expect(summary.hasUrgentAlerts, isTrue);
  });

  test(
    '11. Saldo laboral pendiente: jornadas devengadas menos pagos laborales',
    () async {
      // Obra para asociar jornadas
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'proj-labor',
              clientId: const Value('client-1'),
              name: 'Obra Labor',
              startDate: DateTime.now(),
            ),
          );

      await workerRepo.createWorker(
        model.Worker(
          id: 'w-pedro',
          name: 'Pedro Obrero',
          defaultPaymentType: AppConstants.paymentTypeDaily,
          defaultRateCents: 8000,
        ),
      );

      // 2 jornadas a S/ 80 = S/ 160 devengado
      await workLogRepo.createWorkLog(
        model.WorkLog(
          id: 'wl-1',
          workerId: 'w-pedro',
          projectId: 'proj-labor',
          date: DateTime.now(),
          paymentType: AppConstants.paymentTypeDaily,
          quantity: 1.0,
          rateCents: 8000,
          amountCents: 8000,
        ),
      );
      await workLogRepo.createWorkLog(
        model.WorkLog(
          id: 'wl-2',
          workerId: 'w-pedro',
          projectId: 'proj-labor',
          date: DateTime.now(),
          paymentType: AppConstants.paymentTypeDaily,
          quantity: 1.0,
          rateCents: 8000,
          amountCents: 8000,
        ),
      );

      // Pago parcial de S/ 60
      await laborPaymentRepo.createPayment(
        model.LaborPayment(
          id: 'pay-part',
          workerId: 'w-pedro',
          amountCents: 6000,
          paymentMethod: 'cash',
          paidByPartnerId: 'partner-1',
        ),
      );

      final summary = await dashboardService.getDashboardSummary();
      // Pendiente = 160 - 60 = S/ 100 (10,000 cents)
      expect(summary.totalPendingLaborDebtCents, equals(10000));
      expect(summary.totalPendingLaborDebt, equals(100.0));
    },
  );

  test(
    '12. Registros soft-deleted son excluidos de todas las métricas',
    () async {
      // Obra activa pero soft-deleted
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'proj-del',
              clientId: const Value('client-1'),
              name: 'Obra Eliminada',
              budgetAmountCents: const Value(500000),
              status: const Value('in_progress'),
              startDate: DateTime.now(),
              deletedAt: Value(DateTime.now()),
            ),
          );

      // Visita vencida pero soft-deleted
      await db
          .into(db.maintenancePlans)
          .insert(
            MaintenancePlansCompanion.insert(
              id: 'plan-del',
              clientId: 'client-1',
              title: 'Plan Test',
            ),
          );
      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'visit-del',
              planId: 'plan-del',
              scheduledDate: DateTime.now().subtract(const Duration(days: 3)),
              deletedAt: Value(DateTime.now()),
            ),
          );

      // Jornada soft-deleted
      await workerRepo.createWorker(
        model.Worker(
          id: 'w-del',
          name: 'Trabajador Test',
          defaultRateCents: 5000,
        ),
      );
      final log = model.WorkLog(
        id: 'wl-del',
        workerId: 'w-del',
        projectId: 'proj-del',
        date: DateTime.now(),
        paymentType: AppConstants.paymentTypeDaily,
        quantity: 1.0,
        rateCents: 5000,
        amountCents: 5000,
      );
      await workLogRepo.createWorkLog(log);
      await workLogRepo.voidWorkLog(log.id);

      final summary = await dashboardService.getDashboardSummary();
      expect(summary.activeProjectsCount, equals(0));
      expect(summary.visitsOverdueCount, equals(0));
      expect(summary.totalPendingLaborDebtCents, equals(0));
    },
  );
}
