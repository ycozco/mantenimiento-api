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
import 'package:mantenimiento_app/core/models/work_log.dart' as model;
import 'package:mantenimiento_app/core/models/worker.dart' as model;
import 'package:mantenimiento_app/core/repositories/collection_repository.dart';
import 'package:mantenimiento_app/core/repositories/inventory_repository.dart';
import 'package:mantenimiento_app/core/repositories/labor_payment_repository.dart';
import 'package:mantenimiento_app/core/repositories/partner_repository.dart';
import 'package:mantenimiento_app/core/repositories/work_log_repository.dart';
import 'package:mantenimiento_app/core/repositories/worker_repository.dart';
import 'package:mantenimiento_app/core/services/project_financial_service.dart';

void main() {
  late AppDatabase db;
  late ProjectFinancialService financialService;
  late InventoryRepository inventoryRepo;
  late WorkerRepository workerRepo;
  late WorkLogRepository workLogRepo;
  late LaborPaymentRepository laborPaymentRepo;
  late CollectionRepository collectionRepo;
  late PartnerRepository partnerRepo;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    financialService = ProjectFinancialService(db);
    inventoryRepo = InventoryRepository(db);
    workerRepo = WorkerRepository(db);
    workLogRepo = WorkLogRepository(db);
    laborPaymentRepo = LaborPaymentRepository(db);
    collectionRepo = CollectionRepository(db);
    partnerRepo = PartnerRepository(db);

    // Setup base entities required for FKs
    await db
        .into(db.clients)
        .insert(
          ClientsCompanion.insert(
            id: 'client-1',
            name: 'Inmobiliaria El Bosque',
          ),
        );

    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-1',
            clientId: const Value('client-1'),
            name: 'Jardines de Rinconada',
            budgetAmountCents: const Value(1000000), // S/ 10,000
            startDate: DateTime.now(),
          ),
        );

    await db
        .into(db.partners)
        .insert(PartnersCompanion.insert(id: 'partner-1', name: 'Carlos Ruiz'));

    await workerRepo.createWorker(
      model.Worker(
        id: 'worker-1',
        name: 'Juan Perez',
        defaultPaymentType: AppConstants.paymentTypeDaily,
        defaultRateCents: 10000,
      ),
    );

    await inventoryRepo.createItem(
      model.InventoryItem.create(
        id: 'item-1',
        name: 'Tierra Preparada 50kg',
        category: 'sustratos',
        unit: 'bolsa',
        defaultCostCents: 2000, // S/ 20
      ),
    );

    // Entrada inicial a almacén: 1,000 bolsas a S/ 20
    await inventoryRepo.recordMovement(
      model.StockMovement.create(
        id: 'initial-stock-1',
        itemId: 'item-1',
        movementType: 'purchase',
        quantity: 1000.0,
        unitCostCents: 2000,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'T-10 Escenario Integrado: Obra S/ 10,000, Mat S/ 2,000, MO S/ 1,500, Gastos S/ 500',
    () async {
      // Obra pactada: S/ 10,000 (1,000,000 cents)
      const revenueCents = 1000000;

      // 1. Materiales de Almacén: S/ 2,000 (100 bolsas @ S/ 20)
      await inventoryRepo.recordMovement(
        model.StockMovement.create(
          id: 'mov-1',
          itemId: 'item-1',
          movementType: 'consumption',
          quantity: 100.0,
          unitCostCents: 2000,
          projectId: 'proj-1',
        ),
      );

      // 2. Mano de Obra: S/ 1,500 (15 jornadas @ S/ 100)
      for (int i = 0; i < 15; i++) {
        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log-$i',
            workerId: 'worker-1',
            projectId: 'proj-1',
            date: DateTime.now(),
            paymentType: AppConstants.paymentTypeDaily,
            quantity: 1.0,
            rateCents: 10000,
            amountCents: 10000,
          ),
        );
      }

      // 3. Gastos Directos (Caja Chica): S/ 500
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'expense-1',
              concept: 'Herramientas menores y flete urgente',
              amountCents: const Value(50000), // S/ 500
              date: DateTime.now(),
              paidByPartnerId: 'partner-1',
              projectId: const Value('proj-1'),
            ),
          );

      // 4. Cobros al Cliente: S/ 7,000 (Cobro 1: S/ 4,000, Cobro 2: S/ 3,000)
      await collectionRepo.recordCollection(
        model.Collection.create(
          id: 'col-1',
          clientId: 'client-1',
          projectId: 'proj-1',
          amountCents: 400000,
          date: DateTime.now(),
          paymentMethod: 'transfer',
        ),
      );
      await collectionRepo.recordCollection(
        model.Collection.create(
          id: 'col-2',
          clientId: 'client-1',
          projectId: 'proj-1',
          amountCents: 300000,
          date: DateTime.now(),
          paymentMethod: 'yape',
        ),
      );

      // Obtener resumen financiero consolidado
      final summary = await financialService.getProjectFinancialSummary(
        'proj-1',
        revenueCents,
      );

      // Verificaciones exactas
      expect(summary.revenueCents, equals(1000000));
      expect(summary.revenue, equals(10000.0));

      expect(summary.materialCostCents, equals(200000));
      expect(summary.materialCost, equals(2000.0));

      expect(summary.laborCostCents, equals(150000));
      expect(summary.laborCost, equals(1500.0));

      expect(summary.expensesCostCents, equals(50000));
      expect(summary.expensesCost, equals(500.0));

      expect(summary.totalCostCents, equals(400000));
      expect(summary.totalCost, equals(4000.0));

      expect(summary.grossMarginCents, equals(600000));
      expect(summary.grossMargin, equals(6000.0));
      expect(summary.grossMarginPercent, closeTo(60.0, 0.01));
      expect(summary.isProfitable, isTrue);

      expect(summary.collectedCents, equals(700000));
      expect(summary.collected, equals(7000.0));

      expect(summary.receivableCents, equals(300000));
      expect(summary.receivable, equals(3000.0));
      expect(summary.isOverpaid, isFalse);
    },
  );

  test('T-10 Escenario: Obra sin cobros', () async {
    const revenueCents = 1000000; // S/ 10,000

    // Gasto de S/ 1,000
    await db
        .into(db.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'exp-only',
            concept: 'Plantas iniciales',
            amountCents: const Value(100000),
            date: DateTime.now(),
            paidByPartnerId: 'partner-1',
            projectId: const Value('proj-1'),
          ),
        );

    final summary = await financialService.getProjectFinancialSummary(
      'proj-1',
      revenueCents,
    );

    expect(summary.collectedCents, equals(0));
    expect(summary.receivableCents, equals(1000000));
    expect(summary.grossMarginCents, equals(900000));
    expect(summary.grossMarginPercent, closeTo(90.0, 0.01));
  });

  test('T-10 Escenario: Obra completamente cobrada', () async {
    const revenueCents = 1000000;

    await collectionRepo.recordCollection(
      model.Collection.create(
        id: 'col-full',
        clientId: 'client-1',
        projectId: 'proj-1',
        amountCents: 1000000,
        date: DateTime.now(),
        paymentMethod: 'transfer',
      ),
    );

    final summary = await financialService.getProjectFinancialSummary(
      'proj-1',
      revenueCents,
    );

    expect(summary.collectedCents, equals(1000000));
    expect(summary.receivableCents, equals(0));
    expect(summary.isOverpaid, isFalse);
    expect(summary.overpaidAmountCents, equals(0));
  });

  test(
    'T-10 Escenario: Sobrepago (Cliente paga más del presupuesto)',
    () async {
      const revenueCents = 1000000; // S/ 10,000

      // Cliente paga S/ 12,000
      await collectionRepo.recordCollection(
        model.Collection.create(
          id: 'col-over',
          clientId: 'client-1',
          projectId: 'proj-1',
          amountCents: 1200000,
          date: DateTime.now(),
          paymentMethod: 'transfer',
        ),
      );

      final summary = await financialService.getProjectFinancialSummary(
        'proj-1',
        revenueCents,
      );

      expect(summary.collectedCents, equals(1200000));
      expect(summary.receivableCents, equals(0));
      expect(summary.isOverpaid, isTrue);
      expect(summary.overpaidAmountCents, equals(200000));
      expect(summary.overpaidAmount, equals(2000.0));
    },
  );

  test('T-10 Escenario: Obra sin costos (Margen 100%)', () async {
    const revenueCents = 500000; // S/ 5,000

    final summary = await financialService.getProjectFinancialSummary(
      'proj-1',
      revenueCents,
    );

    expect(summary.totalCostCents, equals(0));
    expect(summary.grossMarginCents, equals(500000));
    expect(summary.grossMarginPercent, closeTo(100.0, 0.01));
    expect(summary.isProfitable, isTrue);
  });

  test('T-10 Escenario: Obra con pérdida (Costo > Venta)', () async {
    const revenueCents = 1000000; // S/ 10,000

    // Materiales por S/ 12,000
    await inventoryRepo.recordMovement(
      model.StockMovement.create(
        id: 'mov-loss',
        itemId: 'item-1',
        movementType: 'consumption',
        quantity: 600.0,
        unitCostCents: 2000,
        projectId: 'proj-1',
      ),
    );

    final summary = await financialService.getProjectFinancialSummary(
      'proj-1',
      revenueCents,
    );

    expect(summary.totalCostCents, equals(1200000));
    expect(summary.grossMarginCents, equals(-200000));
    expect(summary.grossMargin, equals(-2000.0));
    expect(summary.grossMarginPercent, closeTo(-20.0, 0.01));
    expect(summary.isProfitable, isFalse);
  });

  test(
    'T-10 Regla: WorkLog pagado no altera ni duplica el costo de la obra',
    () async {
      // 1 jornada de S/ 100
      final log = model.WorkLog(
        id: 'log-paid-test',
        workerId: 'worker-1',
        projectId: 'proj-1',
        date: DateTime.now(),
        paymentType: AppConstants.paymentTypeDaily,
        quantity: 1.0,
        rateCents: 10000,
        amountCents: 10000,
      );
      await workLogRepo.createWorkLog(log);

      final beforePayment = await financialService.getProjectFinancialSummary(
        'proj-1',
        1000000,
      );
      expect(beforePayment.laborCostCents, equals(10000));

      // Crear un pago laboral que liquida al trabajador
      await laborPaymentRepo.createPayment(
        model.LaborPayment(
          id: 'pay-1',
          workerId: 'worker-1',
          amountCents: 10000,
          paymentMethod: 'cash',
          paidByPartnerId: 'partner-1',
        ),
      );

      final afterPayment = await financialService.getProjectFinancialSummary(
        'proj-1',
        1000000,
      );
      // El costo laboral de la obra sigue siendo exactamente S/ 100
      expect(afterPayment.laborCostCents, equals(10000));
      expect(afterPayment.totalCostCents, equals(10000));
    },
  );

  test(
    'T-10 Regla: Aporte o movimiento de socio no altera revenue ni projectCost',
    () async {
      // Socio aporta S/ 5,000 para financiar el proyecto
      await partnerRepo.recordCapitalMovement(
        model.CapitalMovement.create(
          id: 'cap-1',
          partnerId: 'partner-1',
          projectId: 'proj-1',
          type: 'contribution',
          amountCents: 500000,
          date: DateTime.now(),
        ),
      );

      // Socio registra gasto personal
      await partnerRepo.recordCapitalMovement(
        model.CapitalMovement.create(
          id: 'cap-2',
          partnerId: 'partner-1',
          projectId: 'proj-1',
          type: 'partnerExpense',
          amountCents: 30000,
          date: DateTime.now(),
        ),
      );

      final summary = await financialService.getProjectFinancialSummary(
        'proj-1',
        1000000,
      );

      // Revenue y costo operacional no se contaminan con el capital de socios
      expect(summary.revenueCents, equals(1000000));
      expect(summary.totalCostCents, equals(0));
      expect(summary.grossMarginCents, equals(1000000));
    },
  );

  test(
    'T-10 Reactividad: Anulación de movimientos actualiza los derivados reactivamente',
    () async {
      const revenueCents = 1000000;

      // Registrar consumo de material S/ 500
      await inventoryRepo.recordMovement(
        model.StockMovement.create(
          id: 'mov-to-delete',
          itemId: 'item-1',
          movementType: 'consumption',
          quantity: 25.0,
          unitCostCents: 2000,
          projectId: 'proj-1',
        ),
      );

      // Registrar cobro S/ 3,000
      await collectionRepo.recordCollection(
        model.Collection.create(
          id: 'col-to-delete',
          clientId: 'client-1',
          projectId: 'proj-1',
          amountCents: 300000,
          date: DateTime.now(),
          paymentMethod: 'cash',
        ),
      );

      var summary = await financialService.getProjectFinancialSummary(
        'proj-1',
        revenueCents,
      );
      expect(summary.materialCostCents, equals(50000));
      expect(summary.collectedCents, equals(300000));

      // Anular consumo de material
      await inventoryRepo.deleteMovement('mov-to-delete');
      // Anular cobro
      await collectionRepo.deleteCollection('col-to-delete');

      // Derivados deben actualizarse
      summary = await financialService.getProjectFinancialSummary(
        'proj-1',
        revenueCents,
      );
      expect(summary.materialCostCents, equals(0));
      expect(summary.collectedCents, equals(0));
      expect(summary.totalCostCents, equals(0));
      expect(summary.receivableCents, equals(1000000));
    },
  );

  test(
    'T-10 Mantenimiento: Costo derivado de visita y costo histórico de plan',
    () async {
      // Crear plan de mantenimiento y visita
      await db
          .into(db.maintenancePlans)
          .insert(
            MaintenancePlansCompanion.insert(
              id: 'plan-1',
              clientId: 'client-1',
              title: 'Mantenimiento Mensual Jardines',
              estimatedCostCents: const Value(80000), // S/ 800 estimado
            ),
          );

      await db
          .into(db.maintenanceVisits)
          .insert(
            MaintenanceVisitsCompanion.insert(
              id: 'visit-1',
              planId: 'plan-1',
              scheduledDate: DateTime.now(),
              status: const Value('completed'),
            ),
          );

      // Imputar jornada de S/ 100 a la visita
      await workLogRepo.createWorkLog(
        model.WorkLog(
          id: 'log-visit-1',
          workerId: 'worker-1',
          maintenanceVisitId: 'visit-1',
          date: DateTime.now(),
          paymentType: AppConstants.paymentTypeDaily,
          quantity: 1.0,
          rateCents: 10000,
          amountCents: 10000,
        ),
      );

      // Imputar consumo de abono S/ 60 a la visita
      await inventoryRepo.recordMovement(
        model.StockMovement.create(
          id: 'mov-visit-1',
          itemId: 'item-1',
          movementType: 'consumption',
          quantity: 3.0,
          unitCostCents: 2000,
          visitId: 'visit-1',
        ),
      );

      // Imputar gasto directo S/ 40 a la visita
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-visit-1',
              concept: 'Gasolina para cortacésped',
              amountCents: const Value(4000), // S/ 40
              date: DateTime.now(),
              paidByPartnerId: 'partner-1',
              visitId: const Value('visit-1'),
            ),
          );

      // Costo derivado de la visita = 100 + 60 + 40 = S/ 200 (20,000 cents)
      final visitCostCents = await financialService
          .watchMaintenanceVisitTotalCostCents('visit-1')
          .first;
      expect(visitCostCents, equals(20000));

      // Costo acumulado histórico del plan = S/ 200 (20,000 cents)
      final planCostCents = await financialService
          .watchPlanHistoricalCostCents('plan-1')
          .first;
      expect(planCostCents, equals(20000));
    },
  );
}
