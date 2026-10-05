import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/capital_movement.dart' as model;
import 'package:mantenimiento_app/core/models/collection.dart' as model;
import 'package:mantenimiento_app/core/models/company_settings.dart';
import 'package:mantenimiento_app/core/models/inventory_item.dart' as model;
import 'package:mantenimiento_app/core/models/labor_payment.dart' as model;
import 'package:mantenimiento_app/core/models/maintenance_plan.dart' as model;
import 'package:mantenimiento_app/core/models/maintenance_visit.dart' as model;
import 'package:mantenimiento_app/core/models/purchase.dart' as model;
import 'package:mantenimiento_app/core/models/stock_movement.dart' as model;
import 'package:mantenimiento_app/core/models/supplier.dart' as model;
import 'package:mantenimiento_app/core/models/tool.dart' as model;
import 'package:mantenimiento_app/core/models/tool_assignment.dart' as model;
import 'package:mantenimiento_app/core/models/work_log.dart' as model;
import 'package:mantenimiento_app/core/models/worker.dart' as model;
import 'package:mantenimiento_app/core/notifications/notification_schedule_engine.dart';
import 'package:mantenimiento_app/core/repositories/collection_repository.dart';
import 'package:mantenimiento_app/core/repositories/inventory_repository.dart';
import 'package:mantenimiento_app/core/repositories/labor_payment_repository.dart';
import 'package:mantenimiento_app/core/repositories/maintenance_repository.dart';
import 'package:mantenimiento_app/core/repositories/partner_repository.dart';
import 'package:mantenimiento_app/core/repositories/purchase_repository.dart';
import 'package:mantenimiento_app/core/repositories/settings_repository.dart';
import 'package:mantenimiento_app/core/repositories/tool_repository.dart';
import 'package:mantenimiento_app/core/repositories/work_log_repository.dart';
import 'package:mantenimiento_app/core/repositories/worker_repository.dart';
import 'package:mantenimiento_app/core/services/backup_restore_service.dart';
import 'package:mantenimiento_app/core/services/maintenance_financial_service.dart';
import 'package:mantenimiento_app/core/services/project_financial_service.dart';

void main() {
  late AppDatabase db;
  late ProjectFinancialService projectFinancialService;
  late MaintenanceFinancialService maintenanceFinancialService;
  late InventoryRepository inventoryRepo;
  late WorkerRepository workerRepo;
  late WorkLogRepository workLogRepo;
  late LaborPaymentRepository laborPaymentRepo;
  late CollectionRepository collectionRepo;
  late PartnerRepository partnerRepo;
  late PurchaseRepository purchaseRepo;
  late MaintenanceRepository maintenanceRepo;
  late ToolRepository toolRepo;
  late SettingsRepository settingsRepo;
  late BackupRestoreService backupService;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );

    projectFinancialService = ProjectFinancialService(db);
    maintenanceFinancialService = MaintenanceFinancialService(db);
    inventoryRepo = InventoryRepository(db);
    workerRepo = WorkerRepository(db);
    workLogRepo = WorkLogRepository(db);
    laborPaymentRepo = LaborPaymentRepository(db);
    collectionRepo = CollectionRepository(db);
    partnerRepo = PartnerRepository(db);
    purchaseRepo = PurchaseRepository(db);
    maintenanceRepo = MaintenanceRepository(db);
    toolRepo = ToolRepository(db);
    settingsRepo = SettingsRepository(db);
    backupService = BackupRestoreService(db);

    // Initial setup: Partners A and B
    await db
        .into(db.partners)
        .insert(
          PartnersCompanion.insert(
            id: 'partner-a',
            name: 'Carlos Socio A',
            phone: const Value('999111222'),
            equityPercentage: const Value(50.0),
            avatarColor: const Value(0xFF10B981),
          ),
        );
    await db
        .into(db.partners)
        .insert(
          PartnersCompanion.insert(
            id: 'partner-b',
            name: 'Manuel Socio B',
            phone: const Value('999333444'),
            equityPercentage: const Value(50.0),
            avatarColor: const Value(0xFF3B82F6),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('T-19: E2E Full Operational Workflows & Stabilization', () {
    test('1. Flujo E2E - Obra completa y rentabilidad pura sin duplicación', () async {
      // 1. Crear Cliente
      await db
          .into(db.clients)
          .insert(
            ClientsCompanion.insert(
              id: 'client-obra-1',
              name: 'Condominio Las Palmeras',
              phone: const Value('987654321'),
            ),
          );

      // 2. Crear Obra con presupuesto de S/ 5,000.00 (500,000 cents)
      const projectId = 'proj-obra-1';
      const revenueCents = 500000;
      await db
          .into(db.projects)
          .insert(
            ProjectsCompanion.insert(
              id: projectId,
              name: 'Paisajismo y Riego Automatizado',
              clientId: const Value('client-obra-1'),
              startDate: DateTime(2026, 3, 1),
              budgetAmountCents: const Value(500000),
            ),
          );

      // 3. Crear Proveedor y Compra de Insumos (20 bolsas de tierra abonada @ S/ 25 = S/ 500)
      final supplier = model.Supplier.create(
        name: 'Vivero Central SAC',
        taxId: '20123456789',
      );
      await purchaseRepo.createSupplier(supplier);

      final itemModel = model.InventoryItem.create(
        name: 'Tierra Preparada x50kg',
        category: 'Insumos',
        unit: 'bolsa',
        minStockAlert: 5,
        defaultCostCents: 2500,
      );
      await inventoryRepo.createItem(itemModel);

      final purchase = model.Purchase.create(
        supplierId: supplier.id,
        paidByPartnerId: 'partner-a',
        totalAmountCents: 50000,
        date: DateTime(2026, 3, 2),
        invoiceNumber: 'F001-0099',
      );

      await purchaseRepo.recordPurchase(
        purchase: purchase,
        items: [
          PurchaseItemDraft(
            itemId: itemModel.id,
            quantity: 20,
            unitCostCents: 2500, // S/ 25.00
          ),
        ],
      );

      // Verificar que el stock actual es 20
      var stock = await inventoryRepo.getItemStock(itemModel.id);
      expect(stock, 20.0);

      // 4. Consumo de 10 bolsas en la Obra (Costo material = 10 * 25 = S/ 250 = 25,000 cents)
      await inventoryRepo.recordMovement(
        model.StockMovement.create(
          itemId: itemModel.id,
          movementType: 'consumption',
          quantity: 10,
          unitCostCents: 2500,
          projectId: projectId,
          date: DateTime(2026, 3, 5),
          notes: 'Consumo para bancales principales',
        ),
      );

      stock = await inventoryRepo.getItemStock(itemModel.id);
      expect(stock, 10.0);

      // 5. Crear Trabajador y registrar 2 jornadas de trabajo en la Obra
      const workerId = 'worker-1';
      await workerRepo.createWorker(
        model.Worker(
          id: workerId,
          name: 'Roberto Gomez',
          specialty: 'Jardinero especialista',
          defaultPaymentType: 'daily',
          defaultRateCents: 8000, // S/ 80.00
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 2 días trabajados @ S/ 80 = S/ 160 = 16,000 cents
      await workLogRepo.createWorkLog(
        model.WorkLog(
          id: 'log-obra-1',
          workerId: workerId,
          date: DateTime(2026, 3, 6),
          paymentType: 'daily',
          quantity: 2.0,
          rateCents: 8000,
          amountCents: 16000,
          projectId: projectId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 6. Pago laboral al trabajador por Socio B (S/ 160.00)
      // REGLA CLAVE: LaborPayment NO debe sumar costo a la obra (WorkLog ya computa el costo)
      await laborPaymentRepo.createPayment(
        model.LaborPayment(
          id: 'pay-1',
          workerId: workerId,
          amountCents: 16000,
          paymentDate: DateTime(2026, 3, 7),
          paidByPartnerId: 'partner-b',
          notes: 'Pago de 2 jornadas obra Las Palmeras',
        ),
      );

      // 7. Herramienta creada y asignada a la Obra
      const toolId = 'tool-desbrozadora-1';
      await toolRepo.createTool(
        model.Tool(
          id: toolId,
          name: 'Desbrozadora Stihl FS250',
          brandModel: 'Stihl FS250',
          serialNumber: 'ST-99881',
          currentStatus: 'available',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      const assignmentId = 'assign-1';
      await toolRepo.assignTool(
        model.ToolAssignment(
          id: assignmentId,
          toolId: toolId,
          projectId: projectId,
          workerId: workerId,
          assignedAt: DateTime(2026, 3, 5),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 8. Gasto directo operativo en la Obra pagado por Socio A (Combustible S/ 90 = 9,000 cents)
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-obra-1',
              concept: 'Gasolina para desbrozadora en obra',
              category: const Value('combustible'),
              amountCents: const Value(9000),
              date: DateTime(2026, 3, 6),
              paidByPartnerId: 'partner-a',
              projectId: const Value(projectId),
            ),
          );

      // 9. Cobros: Cobro parcial 1 (S/ 3,000) y Cobro final 2 (S/ 2,000)
      await collectionRepo.recordCollection(
        model.Collection(
          id: 'col-obra-1',
          clientId: 'client-obra-1',
          projectId: projectId,
          amountCents: 300000, // S/ 3,000
          date: DateTime(2026, 3, 10),
          receivedByPartnerId: 'partner-a',
          paymentMethod: 'transfer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await collectionRepo.recordCollection(
        model.Collection(
          id: 'col-obra-2',
          clientId: 'client-obra-1',
          projectId: projectId,
          amountCents: 200000, // S/ 2,000
          date: DateTime(2026, 3, 20),
          receivedByPartnerId: 'partner-b',
          paymentMethod: 'check',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // 10. Verificación exhaustiva de Rentabilidad de la Obra
      final summary = await projectFinancialService.getProjectFinancialSummary(
        projectId,
        revenueCents,
      );

      expect(summary.revenueCents, 500000); // S/ 5,000.00
      expect(summary.collectedCents, 500000); // S/ 5,000.00
      expect(summary.receivableCents, 0); // S/ 0.00
      expect(summary.laborCostCents, 16000); // S/ 160.00
      expect(summary.materialCostCents, 25000); // S/ 250.00
      expect(summary.expensesCostCents, 9000); // S/ 90.00
      expect(summary.totalCostCents, 50000); // S/ 500.00 total
      expect(summary.grossMarginCents, 450000); // S/ 4,500.00
      expect(summary.grossMarginPercent, 90.0); // 90.0%

      // Devolver herramienta
      await toolRepo.returnTool(assignmentId: assignmentId);
      final tool = await toolRepo.getTool(toolId);
      expect(tool!.currentStatus, 'available');
    });

    test(
      '2. Flujo E2E - Mantenimiento completo, snapshot inmutable y rentabilidad',
      () async {
        // 1. Cliente y ubicación
        await db
            .into(db.clients)
            .insert(
              ClientsCompanion.insert(
                id: 'client-maint-1',
                name: 'Residencial Los Álamos',
                phone: const Value('955112233'),
              ),
            );

        // 2. Plan de Mantenimiento con tarifa acordada de S/ 350.00 por visita
        const planId = 'plan-maint-1';
        final scheduledDate = DateTime.now().add(const Duration(days: 7));

        await maintenanceRepo.createPlan(
          model.MaintenancePlan(
            id: planId,
            title: 'Mantenimiento Quincenal de Jardines',
            clientId: 'client-maint-1',
            frequencyType: 'quincenal',
            intervalDays: 15,
            nextDate: scheduledDate,
            billingType: 'perVisit',
            agreedAmountCents: 35000, // S/ 350.00
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // 3. Crear Visita programada para dentro de 7 días
        const visitId = 'visit-maint-1';
        final visitModel = model.MaintenanceVisit(
          id: visitId,
          planId: planId,
          scheduledDate: scheduledDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await maintenanceRepo.createVisit(visitModel);

        // Verificar que la visita congeló el snapshot de precio a S/ 350.00
        var visit = await maintenanceRepo.getVisitById(visitId);
        expect(visit!.agreedPriceCents, 35000);

        // 4. Notificaciones determinísticas
        final notifications = NotificationScheduleEngine.computeNotifications(
          visit: visitModel,
          now: DateTime.now(),
          planTitle: 'Mantenimiento Quincenal de Jardines',
          clientName: 'Residencial Los Álamos',
          notificationsEnabled: true,
        );
        expect(notifications.isNotEmpty, isTrue);

        // 5. Asignar jornada de trabajador a la visita
        const workerId = 'worker-podador-1';
        await workerRepo.createWorker(
          model.Worker(
            id: workerId,
            name: 'Esteban Podador',
            defaultPaymentType: 'daily',
            defaultRateCents: 7500, // S/ 75.00
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log-visit-1',
            workerId: workerId,
            date: scheduledDate,
            paymentType: 'daily',
            quantity: 1.0,
            rateCents: 7500,
            amountCents: 7500,
            maintenanceVisitId: visitId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // 6. Consumo de materiales en la visita
        final itemModel = model.InventoryItem.create(
          name: 'Abono Foliar Líquido 1L',
          category: 'Químicos',
          unit: 'litro',
          minStockAlert: 2,
          defaultCostCents: 3000,
        );
        await inventoryRepo.createItem(itemModel);

        // Se siembra stock inicial mediante purchase
        final sup = model.Supplier.create(name: 'Agroinsumos del Sur');
        await purchaseRepo.createSupplier(sup);
        await purchaseRepo.recordPurchase(
          purchase: model.Purchase.create(
            supplierId: sup.id,
            paidByPartnerId: 'partner-a',
            totalAmountCents: 15000,
            date: DateTime.now(),
          ),
          items: [
            PurchaseItemDraft(
              itemId: itemModel.id,
              quantity: 5,
              unitCostCents: 3000,
            ),
          ],
        );

        await inventoryRepo.recordMovement(
          model.StockMovement.create(
            itemId: itemModel.id,
            movementType: 'consumption',
            quantity: 2,
            unitCostCents: 3000, // S/ 60.00 total
            visitId: visitId,
            date: scheduledDate,
            notes: 'Fumigación y abono foliar de rosales',
          ),
        );

        // 7. Gasto directo en la visita (Bolsas de residuos S/ 25 = 2,500 cents)
        await db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'exp-visit-1',
                concept: 'Bolsas jumbo de poda y acarreo',
                category: const Value('residuos'),
                amountCents: const Value(2500),
                date: scheduledDate,
                paidByPartnerId: 'partner-b',
                visitId: const Value(visitId),
              ),
            );

        // 8. Completar la visita
        await maintenanceRepo.completeVisit(
          visitId,
          executedDate: DateTime.now(),
          notes: 'Poda de cercos y rosales culminada con éxito',
        );

        // 9. REGLA INMUTABLE: Modificar la tarifa del plan a S/ 450.00 para el futuro
        final currentPlan = await maintenanceRepo.getPlanById(planId);
        await maintenanceRepo.updatePlan(
          currentPlan!.copyWith(
            title: 'Mantenimiento Quincenal de Jardines (Tarifa 2026)',
            agreedAmountCents: 45000, // S/ 450.00
          ),
        );

        // Verificar que la visita ejecutada CONSERVA su snapshot de S/ 350.00
        visit = await maintenanceRepo.getVisitById(visitId);
        expect(visit!.agreedPriceCents, 35000);

        // 10. Cobros a la visita: Cobro parcial S/ 200 y Cobro final S/ 150
        await collectionRepo.recordCollection(
          model.Collection(
            id: 'col-visit-1',
            clientId: 'client-maint-1',
            visitId: visitId,
            amountCents: 20000, // S/ 200.00
            date: DateTime.now(),
            receivedByPartnerId: 'partner-a',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await collectionRepo.recordCollection(
          model.Collection(
            id: 'col-visit-2',
            clientId: 'client-maint-1',
            visitId: visitId,
            amountCents: 15000, // S/ 150.00
            date: DateTime.now(),
            receivedByPartnerId: 'partner-b',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // 11. Validar resumen financiero de la visita
        final finSummary = await maintenanceFinancialService
            .getVisitFinancialSummary(visitId);
        expect(finSummary.revenueCents, 35000); // S/ 350.00
        expect(finSummary.collectedCents, 35000); // S/ 350.00
        expect(finSummary.receivableCents, 0);
        expect(finSummary.laborCostCents, 7500); // S/ 75.00
        expect(finSummary.materialCostCents, 6000); // S/ 60.00
        expect(finSummary.expensesCents, 2500); // S/ 25.00
        expect(finSummary.totalCostCents, 16000); // S/ 160.00
        expect(finSummary.grossMarginCents, 19000); // S/ 190.00
        expect(finSummary.grossMarginPercent, closeTo(54.28, 0.05));
      },
    );

    test(
      '3. Flujo E2E - Socios, aportes de capital y retiros aislados de costos/revenue',
      () async {
        // 1. Socio A aporta S/ 10,000 de capital inicial
        await partnerRepo.recordCapitalMovement(
          model.CapitalMovement.create(
            partnerId: 'partner-a',
            type: 'contribution',
            amountCents: 1000000,
            date: DateTime(2026, 1, 1),
            notes: 'Aporte de capital para equipamiento',
          ),
        );

        // 2. Socio B aporta S/ 5,000 de capital
        await partnerRepo.recordCapitalMovement(
          model.CapitalMovement.create(
            partnerId: 'partner-b',
            type: 'contribution',
            amountCents: 500000,
            date: DateTime(2026, 1, 2),
            notes: 'Aporte de capital operativo',
          ),
        );

        // 3. Socio A retira S/ 1,000 de utilidades / retiro personal
        await partnerRepo.recordCapitalMovement(
          model.CapitalMovement.create(
            partnerId: 'partner-a',
            type: 'withdrawal',
            amountCents: 100000,
            date: DateTime(2026, 2, 1),
            notes: 'Retiro personal',
          ),
        );

        // 4. Verificar saldos netos de capital
        final balanceA = await partnerRepo.getPartnerBalance('partner-a');
        final balanceB = await partnerRepo.getPartnerBalance('partner-b');

        expect(balanceA.netBalanceCents, 900000); // S/ 9,000.00
        expect(balanceB.netBalanceCents, 500000); // S/ 5,000.00

        // REGLA: Ningún movimiento de capital debe registrarse como costo o ingreso en obras ni mantenimientos
        final totalLabor = await db
            .customSelect('SELECT COUNT(*) as c FROM work_logs')
            .getSingle();
        expect(totalLabor.read<int>('c'), 0);

        final totalCollections = await db
            .customSelect('SELECT COUNT(*) as c FROM collections')
            .getSingle();
        expect(totalCollections.read<int>('c'), 0);
      },
    );

    test(
      '4. Flujo E2E - Inventario: compra, consumo obra, consumo visita, pérdidas y setting de stock negativo',
      () async {
        final itemModel = model.InventoryItem.create(
          name: 'Tubería Riego 1/2 pulgada x 100m',
          category: 'Riego',
          unit: 'rollo',
          minStockAlert: 2,
          defaultCostCents: 12000,
        );
        await inventoryRepo.createItem(itemModel);

        final sup = model.Supplier.create(name: 'Riegos y Tubos SAC');
        await purchaseRepo.createSupplier(sup);

        // Compra de 10 rollos
        await purchaseRepo.recordPurchase(
          purchase: model.Purchase.create(
            supplierId: sup.id,
            paidByPartnerId: 'partner-a',
            totalAmountCents: 120000,
            date: DateTime.now(),
          ),
          items: [
            PurchaseItemDraft(
              itemId: itemModel.id,
              quantity: 10,
              unitCostCents: 12000,
            ),
          ],
        );

        var stock = await inventoryRepo.getItemStock(itemModel.id);
        expect(stock, 10.0);

        // Consumo obra: 4 rollos
        await inventoryRepo.recordMovement(
          model.StockMovement.create(
            itemId: itemModel.id,
            movementType: 'consumption',
            quantity: 4,
            unitCostCents: 12000,
            date: DateTime.now(),
            notes: 'Instalación obra sector norte',
          ),
        );

        // Consumo visita: 2 rollos
        await inventoryRepo.recordMovement(
          model.StockMovement.create(
            itemId: itemModel.id,
            movementType: 'consumption',
            quantity: 2,
            unitCostCents: 12000,
            date: DateTime.now(),
            notes: 'Reparación de línea en visita',
          ),
        );

        // Pérdida / Merma: 1 rollo dañado
        await inventoryRepo.recordMovement(
          model.StockMovement.create(
            itemId: itemModel.id,
            movementType: 'loss',
            quantity: 1,
            unitCostCents: 12000,
            date: DateTime.now(),
            notes: 'Rollo aplastado en transporte',
          ),
        );

        stock = await inventoryRepo.getItemStock(itemModel.id);
        expect(stock, 3.0); // 10 - 4 - 2 - 1 = 3 rollos

        // Intentar consumir 5 rollos cuando solo hay 3 y el setting por defecto NO permite stock negativo
        expect(
          () async => await inventoryRepo.recordMovement(
            model.StockMovement.create(
              itemId: itemModel.id,
              movementType: 'consumption',
              quantity: 5,
              unitCostCents: 12000,
              date: DateTime.now(),
            ),
          ),
          throwsA(isA<StateError>()),
        );

        // Activar setting allowNegativeStock = true
        await settingsRepo.updateSettings(
          CompanySettings(
            companyName: 'Decolumax EIRL',
            allowNegativeStock: true,
            updatedAt: DateTime.now(),
          ),
        );

        // Ahora el consumo de 5 rollos debe permitirse y dejar el stock en -2.0
        await inventoryRepo.recordMovement(
          model.StockMovement.create(
            itemId: itemModel.id,
            movementType: 'consumption',
            quantity: 5,
            unitCostCents: 12000,
            date: DateTime.now(),
          ),
          allowNegativeStock: true,
        );

        stock = await inventoryRepo.getItemStock(itemModel.id);
        expect(stock, -2.0);
      },
    );

    test(
      '5. Flujo E2E - Herramientas: ciclo de vida completo y bloqueo de doble asignación',
      () async {
        const toolId = 'tool-motosierra-1';
        await toolRepo.createTool(
          model.Tool(
            id: toolId,
            name: 'Motosierra Husqvarna 450',
            brandModel: 'Husqvarna 450 Rancher',
            serialNumber: 'HQ-77332',
            currentStatus: 'available',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        const worker1Id = 'worker-op-1';
        const worker2Id = 'worker-op-2';
        await workerRepo.createWorker(
          model.Worker(
            id: worker1Id,
            name: 'Operario 1',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await workerRepo.createWorker(
          model.Worker(
            id: worker2Id,
            name: 'Operario 2',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // 1. Asignar herramienta al Trabajador 1
        const assignmentId = 'assign-moto-1';
        await toolRepo.assignTool(
          model.ToolAssignment(
            id: assignmentId,
            toolId: toolId,
            workerId: worker1Id,
            conditionOut: 'good',
            notes: 'Entrega para desrame',
            assignedAt: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        var tool = await toolRepo.getTool(toolId);
        expect(tool!.currentStatus, 'assigned');

        // 2. Intentar asignar la misma herramienta al Trabajador 2 mientras está asignada -> debe fallar
        expect(
          () async => await toolRepo.assignTool(
            model.ToolAssignment(
              id: 'assign-moto-2',
              toolId: toolId,
              workerId: worker2Id,
              assignedAt: DateTime.now(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
          throwsA(isA<StateError>()),
        );

        // 3. Trabajador 1 devuelve la herramienta
        await toolRepo.returnTool(
          assignmentId: assignmentId,
          conditionIn: 'fair',
          notes: 'Devuelta con desgaste de cadena',
        );

        tool = await toolRepo.getTool(toolId);
        expect(tool!.currentStatus, 'available');
        expect(tool.condition, 'fair');

        // 4. Enviar herramienta a mantenimiento
        await toolRepo.sendToMaintenance(
          toolId,
          notes: 'Afilado y calibración de motor en taller',
        );
        tool = await toolRepo.getTool(toolId);
        expect(tool!.currentStatus, 'maintenance');

        // 5. Finalizar mantenimiento y retornar a disponible
        await toolRepo.updateTool(
          tool.copyWith(currentStatus: 'available', condition: 'good'),
        );
        tool = await toolRepo.getTool(toolId);
        expect(tool!.currentStatus, 'available');

        // 6. Retiro definitivo por baja de equipo
        await toolRepo.retireTool(
          toolId,
          reason: 'Baja del activo por reemplazo de maquinaria',
        );
        tool = await toolRepo.getTool(toolId);
        expect(tool!.currentStatus, 'retired');

        // Verificar que el historial de asignaciones se conserva intacto
        final history = await toolRepo.watchToolHistory(toolId).first;
        expect(history.length, 1);
        expect(history.first.returnedAt, isNotNull);
      },
    );

    test(
      '6. Flujo E2E - Backup / Restore Roundtrip Completo con preservación funcional',
      () async {
        // 1. Poblar la base con datos completos enlazados
        await db
            .into(db.clients)
            .insert(
              ClientsCompanion.insert(
                id: 'client-backup-1',
                name: 'Corporación Miraflores',
                phone: const Value('999888777'),
              ),
            );

        const planId = 'plan-backup-1';
        await maintenanceRepo.createPlan(
          model.MaintenancePlan(
            id: planId,
            title: 'Plan Integral Edificio Miraflores',
            clientId: 'client-backup-1',
            billingType: 'monthly',
            agreedAmountCents: 80000, // S/ 800.00
            nextDate: DateTime(2026, 4, 15),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        const visitId = 'visit-backup-1';
        await maintenanceRepo.createVisit(
          model.MaintenanceVisit(
            id: visitId,
            planId: planId,
            scheduledDate: DateTime(2026, 4, 15),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        const workerId = 'worker-backup-1';
        await workerRepo.createWorker(
          model.Worker(
            id: workerId,
            name: 'Luis Tecnico',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await workLogRepo.createWorkLog(
          model.WorkLog(
            id: 'log-backup-1',
            workerId: workerId,
            date: DateTime(2026, 4, 15),
            paymentType: 'daily',
            quantity: 1.0,
            rateCents: 9000,
            amountCents: 9000,
            maintenanceVisitId: visitId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await collectionRepo.recordCollection(
          model.Collection(
            id: 'col-backup-1',
            clientId: 'client-backup-1',
            planId: planId,
            amountCents: 80000,
            date: DateTime(2026, 4, 16),
            receivedByPartnerId: 'partner-a',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // 2. Exportar Backup V2
        final backupJson = await backupService.exportBackupJson();
        final decoded = jsonDecode(backupJson) as Map<String, dynamic>;
        expect(decoded['backupFormatVersion'], 2);
        expect(decoded['schemaVersion'], 3);

        // 3. Crear una segunda base de datos en blanco
        final db2 = AppDatabase(
          NativeDatabase.memory(
            setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
          ),
        );
        final backupService2 = BackupRestoreService(db2);
        final maintenanceFinancialService2 = MaintenanceFinancialService(db2);

        // 4. Restaurar el backup completo en la nueva base
        final report = await backupService2.restoreBackupJson(backupJson);
        expect(report.success, isTrue);

        // 5. Verificar equivalencia funcional y numérica
        final restoredClients = await db2.select(db2.clients).get();
        expect(restoredClients.length, 1);
        expect(restoredClients.first.id, 'client-backup-1');

        final restoredPlans = await db2.select(db2.maintenancePlans).get();
        expect(restoredPlans.length, 1);
        expect(restoredPlans.first.billingType, 'monthly');
        expect(restoredPlans.first.agreedAmountCents, 80000);

        final restoredCollections = await db2.select(db2.collections).get();
        expect(restoredCollections.length, 1);
        expect(restoredCollections.first.planId, planId);
        expect(restoredCollections.first.amountCents, 80000);

        // Recalcular rentabilidad en la nueva DB restaurada
        final summary = await maintenanceFinancialService2
            .getPlanFinancialSummary(planId);
        expect(summary.revenueCents, 80000);
        expect(summary.collectedCents, 80000);
        expect(summary.receivableCents, 0);
        expect(summary.laborCostCents, 9000);
        expect(summary.grossMarginCents, 71000);

        await db2.close();
      },
    );

    test(
      '7. Flujo E2E - Migración sin fricción desde backup histórico V1 JSON',
      () async {
        // Simular JSON V1 legacy con clientes, obras, mantenimientos, socios y gastos
        final legacyV1Json = jsonEncode({
          'socios': [
            {
              'id': 'v1-socio-1',
              'nombre': 'Socio Histórico 1',
              'telefono': '999111',
              'color': 4283215696,
            },
            {
              'id': 'v1-socio-2',
              'nombre': 'Socio Histórico 2',
              'telefono': '999222',
              'color': 4280191205,
            },
          ],
          'clientes': [
            {
              'id': 'v1-cliente-1',
              'nombre': 'Colegio San Jose',
              'telefono': '987000',
              'direccion': 'Av. Pardo 123',
            },
          ],
          'mantenimientos': [
            {
              'id': 'v1-maint-1',
              'titulo': 'Mantenimiento Canchas de Césped',
              'clienteId': 'v1-cliente-1',
              'frecuencia': 'mensual',
              'fechaProximo': '2026-05-01T00:00:00.000',
              'montoCents': 60000,
            },
          ],
          'obras': [
            {
              'id': 'v1-obra-1',
              'nombre': 'Construcción Jardinera Principal',
              'clienteId': 'v1-cliente-1',
              'presupuesto': 3500.0,
              'fechaInicio': '2026-02-01T00:00:00.000',
              'estado': 'en_progreso',
            },
          ],
          'gastos': [
            {
              'id': 'v1-gasto-1',
              'concepto': 'Compra de ladrillos y cemento',
              'montoTotal': 450.0,
              'pagadoPorSocioId': 'v1-socio-1',
              'obraId': 'v1-obra-1',
              'fecha': '2026-02-05T00:00:00.000',
            },
          ],
        });

        final report = await backupService.restoreBackupJson(legacyV1Json);
        expect(report.success, isTrue);

        // Verificar que se migraron las entidades a Drift
        final clients = await db.select(db.clients).get();
        expect(clients.any((c) => c.name == 'Colegio San Jose'), isTrue);

        final projects = await db.select(db.projects).get();
        expect(
          projects.any((p) => p.name == 'Construcción Jardinera Principal'),
          isTrue,
        );

        final plans = await db.select(db.maintenancePlans).get();
        expect(
          plans.any((p) => p.title == 'Mantenimiento Canchas de Césped'),
          isTrue,
        );
      },
    );

    test(
      '8. Flujo E2E - Simulación de reinicio de la app y persistencia de settings',
      () async {
        // 1. Guardar configuraciones de empresa personalizadas
        await settingsRepo.updateSettings(
          CompanySettings(
            companyName: 'Decolumax Servicios Generales SAC',
            ruc: '20601234567',
            currency: 'PEN',
            timezone: 'America/Lima',
            allowNegativeStock: false,
            updatedAt: DateTime.now(),
          ),
        );

        // 2. Simular reinicio creando nuevas instancias de repositorios sobre la misma base
        final newSettingsRepo = SettingsRepository(db);
        final persistedSettings = await newSettingsRepo.getSettings();

        expect(
          persistedSettings.companyName,
          'Decolumax Servicios Generales SAC',
        );
        expect(persistedSettings.ruc, '20601234567');
        expect(persistedSettings.currency, 'PEN');
        expect(persistedSettings.allowNegativeStock, isFalse);
      },
    );
  });
}
