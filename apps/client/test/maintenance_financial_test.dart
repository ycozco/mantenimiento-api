import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mantenimiento_app/core/database/app_database.dart'
    hide
        MaintenancePlan,
        MaintenanceVisit,
        WorkLog,
        Collection,
        StockMovement,
        Worker,
        LaborPayment;
import 'package:mantenimiento_app/core/models/maintenance_plan.dart';
import 'package:mantenimiento_app/core/models/maintenance_visit.dart';
import 'package:mantenimiento_app/core/models/collection.dart';
import 'package:mantenimiento_app/core/models/work_log.dart';
import 'package:mantenimiento_app/core/models/stock_movement.dart';
import 'package:mantenimiento_app/core/models/labor_payment.dart';
import 'package:mantenimiento_app/core/repositories/maintenance_repository.dart';
import 'package:mantenimiento_app/core/repositories/collection_repository.dart';
import 'package:mantenimiento_app/core/repositories/work_log_repository.dart';
import 'package:mantenimiento_app/core/repositories/labor_payment_repository.dart';
import 'package:mantenimiento_app/core/repositories/inventory_repository.dart';
import 'package:mantenimiento_app/core/services/maintenance_financial_service.dart';
import 'package:mantenimiento_app/core/services/backup_restore_service.dart';

void main() {
  late AppDatabase db;
  late MaintenanceRepository maintenanceRepo;
  late CollectionRepository collectionRepo;
  late WorkLogRepository workLogRepo;
  late LaborPaymentRepository laborPaymentRepo;
  late InventoryRepository inventoryRepo;
  late MaintenanceFinancialService financialService;
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

    maintenanceRepo = MaintenanceRepository(db);
    collectionRepo = CollectionRepository(db);
    workLogRepo = WorkLogRepository(db);
    laborPaymentRepo = LaborPaymentRepository(db);
    inventoryRepo = InventoryRepository(db);
    financialService = MaintenanceFinancialService(db);
    backupService = BackupRestoreService(db);

    // Sembrar cliente y socio base para FKs
    await db
        .into(db.clients)
        .insert(
          ClientsCompanion.insert(
            id: 'client-1',
            name: 'Edificio Las Palmeras',
            phone: const Value('999111222'),
            createdAt: Value(DateTime(2026, 1, 1)),
            updatedAt: Value(DateTime(2026, 1, 1)),
          ),
        );

    await db
        .into(db.partners)
        .insert(
          PartnersCompanion.insert(
            id: 'p-1',
            name: 'Socio A',
            phone: const Value('999000000'),
            createdAt: Value(DateTime(2026, 1, 1)),
            updatedAt: Value(DateTime(2026, 1, 1)),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('T-18: Tarifa por Visita, Snapshot Histórico y Margen', () {
    test(
      '1. Tarifa por visita: snapshot en visita y preservación histórica al cambiar tarifa del plan',
      () async {
        // Plan inicial con tarifa de S/ 350 por visita (35000 cents)
        final plan = MaintenancePlan(
          id: 'plan-1',
          clientId: 'client-1',
          title: 'Mantenimiento Preventivo Ascensores',
          frequencyType: 'monthly',
          intervalDays: 30,
          nextDate: DateTime(2026, 1, 15),
          billingType: 'perVisit',
          agreedAmountCents: 35000,
        );
        await maintenanceRepo.createPlan(plan);

        // La visita inicial debe tener un snapshot de S/ 350
        final visitsEnero = await maintenanceRepo.getVisitsForPlan('plan-1');
        expect(visitsEnero.length, equals(1));
        final visitEnero = visitsEnero.first;
        expect(visitEnero.agreedPriceCents, equals(35000));
        expect(visitEnero.agreedPrice, equals(350.0));

        // Completamos la visita de enero
        await maintenanceRepo.completeVisit(
          visitEnero.id,
          executedDate: DateTime(2026, 1, 15),
        );

        // Ahora el cliente y Decolumax acuerdan subir la tarifa a S/ 400 por visita
        final planActualizado = plan.copyWith(agreedAmountCents: 40000);
        await maintenanceRepo.updatePlan(planActualizado);

        // Verificamos que la visita de enero CONSERVA su snapshot histórico de S/ 350
        final visitaEneroDespues = await maintenanceRepo.getVisitById(
          visitEnero.id,
        );
        expect(visitaEneroDespues!.agreedPriceCents, equals(35000));

        // Programamos una nueva visita de marzo: debe adoptar la nueva tarifa de S/ 400
        final visitMarzo = MaintenanceVisit(
          id: 'visit-marzo',
          planId: 'plan-1',
          scheduledDate: DateTime(2026, 3, 15),
          status: VisitStatus.scheduled,
        );
        await maintenanceRepo.createVisit(visitMarzo);

        final marzoGuardada = await maintenanceRepo.getVisitById('visit-marzo');
        expect(marzoGuardada!.agreedPriceCents, equals(40000));
      },
    );

    test('2. Costo operativo de visita y margen bruto derivado', () async {
      // Plan S/ 500 por visita
      final plan = MaintenancePlan(
        id: 'plan-costos',
        clientId: 'client-1',
        title: 'Mantenimiento Bombas',
        frequencyType: 'monthly',
        intervalDays: 30,
        nextDate: DateTime(2026, 2, 10),
        billingType: 'perVisit',
        agreedAmountCents: 50000,
      );
      await maintenanceRepo.createPlan(plan);
      final visits = await maintenanceRepo.getVisitsForPlan('plan-costos');
      final visitId = visits.first.id;

      // 1. Sembrar trabajador y WorkLog (Mano de obra: S/ 120)
      await db
          .into(db.workers)
          .insert(
            WorkersCompanion.insert(
              id: 'w-1',
              name: 'Juan Técnico',
              defaultRateCents: const Value(12000),
            ),
          );
      await workLogRepo.createWorkLog(
        WorkLog(
          id: 'log-1',
          workerId: 'w-1',
          maintenanceVisitId: visitId,
          date: DateTime(2026, 2, 10),
          quantity: 1.0,
          rateCents: 12000,
          amountCents: 12000,
        ),
      );

      // 2. Sembrar ítem de inventario y stock inicial (Material: S/ 80)
      await db
          .into(db.inventoryItems)
          .insert(
            InventoryItemsCompanion.insert(
              id: 'item-filtro',
              name: 'Filtro de Agua 10"',
              unit: const Value('UND'),
              defaultCostCents: const Value(8000),
            ),
          );
      await inventoryRepo.recordMovement(
        StockMovement.create(
          itemId: 'item-filtro',
          movementType: 'purchase',
          quantity: 5.0,
          unitCostCents: 8000,
          date: DateTime(2026, 2, 1),
        ),
      );
      await inventoryRepo.recordMovement(
        StockMovement.create(
          itemId: 'item-filtro',
          movementType: 'consumption',
          quantity: 1.0,
          unitCostCents: 8000,
          date: DateTime(2026, 2, 10),
          visitId: visitId,
        ),
      );

      // 3. Sembrar gasto operativo menor asignado a la visita (Gasto: S/ 25)
      await db
          .into(db.expenses)
          .insert(
            ExpensesCompanion.insert(
              id: 'exp-pasajes',
              concept: 'Transporte y pasajes',
              amountCents: const Value(2500),
              date: DateTime(2026, 2, 10),
              paidByPartnerId: 'p-1',
              visitId: Value(visitId),
              createdAt: Value(DateTime(2026, 2, 10)),
              updatedAt: Value(DateTime(2026, 2, 10)),
            ),
          );

      // Derivar resumen financiero de la visita
      final visitFin = await financialService.getVisitFinancialSummary(visitId);
      expect(visitFin.revenueCents, equals(50000)); // S/ 500.00
      expect(visitFin.laborCostCents, equals(12000)); // S/ 120.00
      expect(visitFin.materialCostCents, equals(8000)); // S/ 80.00
      expect(visitFin.expensesCents, equals(2500)); // S/ 25.00
      expect(visitFin.totalCostCents, equals(22500)); // S/ 225.00
      expect(visitFin.grossMarginCents, equals(27500)); // S/ 275.00
      expect(visitFin.grossMarginPercent, closeTo(55.0, 0.1)); // 55%

      // Regla de Invariante: LaborPayment NO altera el laborCost de la visita
      await laborPaymentRepo.createPayment(
        LaborPayment(
          id: 'pay-1',
          workerId: 'w-1',
          amountCents: 12000,
          paymentDate: DateTime(2026, 2, 15),
          paidByPartnerId: 'p-1',
        ),
      );
      final visitFinDespuesPago = await financialService
          .getVisitFinancialSummary(visitId);
      expect(visitFinDespuesPago.laborCostCents, equals(12000));
      expect(visitFinDespuesPago.totalCostCents, equals(22500));
    });
  });

  group('T-18: Cobros, Cobros Parciales, Sobrepago y Anulación', () {
    test(
      '3. Cobro parcial, cobro complementario y liquidación total',
      () async {
        final plan = MaintenancePlan(
          id: 'plan-cobros',
          clientId: 'client-1',
          title: 'Plan Cobros',
          frequencyType: 'monthly',
          intervalDays: 30,
          nextDate: DateTime(2026, 3, 1),
          billingType: 'perVisit',
          agreedAmountCents: 35000, // S/ 350.00
        );
        await maintenanceRepo.createPlan(plan);
        final visit = (await maintenanceRepo.getVisitsForPlan(
          'plan-cobros',
        )).first;

        // Estado inicial
        var summary = await financialService.getVisitFinancialSummary(visit.id);
        expect(summary.revenueCents, equals(35000));
        expect(summary.collectedCents, equals(0));
        expect(summary.receivableCents, equals(35000));

        // Cobro parcial: S/ 200 (20000 cents)
        final c1 = Collection.create(
          clientId: 'client-1',
          visitId: visit.id,
          amountCents: 20000,
          date: DateTime(2026, 3, 2),
        );
        await collectionRepo.recordCollection(c1);

        summary = await financialService.getVisitFinancialSummary(visit.id);
        expect(summary.collectedCents, equals(20000));
        expect(summary.receivableCents, equals(15000));

        // Segundo cobro: S/ 150 (15000 cents)
        final c2 = Collection.create(
          clientId: 'client-1',
          visitId: visit.id,
          amountCents: 15000,
          date: DateTime(2026, 3, 5),
        );
        await collectionRepo.recordCollection(c2);

        summary = await financialService.getVisitFinancialSummary(visit.id);
        expect(summary.collectedCents, equals(35000));
        expect(summary.receivableCents, equals(0));
      },
    );

    test('4. Sobrepago y anulación de cobro', () async {
      final plan = MaintenancePlan(
        id: 'plan-sobrepago',
        clientId: 'client-1',
        title: 'Plan Sobrepago',
        frequencyType: 'monthly',
        intervalDays: 30,
        nextDate: DateTime(2026, 4, 1),
        billingType: 'perVisit',
        agreedAmountCents: 30000, // S/ 300.00
      );
      await maintenanceRepo.createPlan(plan);
      final visit = (await maintenanceRepo.getVisitsForPlan(
        'plan-sobrepago',
      )).first;

      // Pago en exceso: S/ 350
      final c1 = Collection.create(
        clientId: 'client-1',
        visitId: visit.id,
        amountCents: 35000,
        date: DateTime(2026, 4, 2),
      );
      await collectionRepo.recordCollection(c1);

      var summary = await financialService.getVisitFinancialSummary(visit.id);
      expect(summary.collectedCents, equals(35000));
      expect(summary.isOverpaid, isTrue);
      expect(summary.overpaidCents, equals(5000));
      expect(summary.receivableCents, equals(0));

      // Anulación del cobro
      await collectionRepo.deleteCollection(c1.id);

      summary = await financialService.getVisitFinancialSummary(visit.id);
      expect(summary.collectedCents, equals(0));
      expect(summary.receivableCents, equals(30000));
    });
  });

  group('T-18: Tarifa Mensual y No Duplicación por Visitas', () {
    test(
      '5. Modalidad monthly: múltiples visitas en un mismo mes NO duplican facturación',
      () async {
        // Plan mensual de S/ 800 (80000 cents)
        final plan = MaintenancePlan(
          id: 'plan-mensual',
          clientId: 'client-1',
          title: 'Mantenimiento Mensual Integral',
          frequencyType: 'monthly',
          intervalDays: 15, // 2 visitas al mes
          nextDate: DateTime(2026, 5, 5),
          billingType: 'monthly',
          agreedAmountCents: 80000, // S/ 800 por mes
        );
        await maintenanceRepo.createPlan(plan);

        // Crear segunda visita en el mismo mes de mayo
        final visit2 = MaintenanceVisit(
          id: 'visit-mayo-2',
          planId: 'plan-mensual',
          scheduledDate: DateTime(2026, 5, 20),
          status: VisitStatus.scheduled,
        );
        await maintenanceRepo.createVisit(visit2);

        // Crear una tercera visita en el mes de junio
        final visit3 = MaintenanceVisit(
          id: 'visit-junio-1',
          planId: 'plan-mensual',
          scheduledDate: DateTime(2026, 6, 10),
          status: VisitStatus.scheduled,
        );
        await maintenanceRepo.createVisit(visit3);

        // En mayo hay 2 visitas y en junio 1 visita -> Total 2 meses calendario activos
        // Revenue total del plan debe ser 2 meses * S/ 800 = S/ 1,600 (NO 3 * 800 = 2,400)
        final planSummary = await financialService.getPlanFinancialSummary(
          'plan-mensual',
        );
        expect(planSummary.revenueCents, equals(160000)); // S/ 1,600.00

        // Cobro realizado al plan directamente: S/ 800
        final colPlan = Collection.create(
          clientId: 'client-1',
          planId: 'plan-mensual',
          amountCents: 80000,
          date: DateTime(2026, 5, 10),
        );
        await collectionRepo.recordCollection(colPlan);

        final planSummaryCobrado = await financialService
            .getPlanFinancialSummary('plan-mensual');
        expect(planSummaryCobrado.collectedCents, equals(80000));
        expect(planSummaryCobrado.receivableCents, equals(80000));
      },
    );

    test('6. Invariante: CapitalMovement no es ingreso operacional', () async {
      await db
          .into(db.capitalMovements)
          .insert(
            CapitalMovementsCompanion.insert(
              id: 'cap-1',
              partnerId: 'p-1',
              type: const Value('contribution'),
              amountCents: const Value(500000), // S/ 5,000 aporte de capital
              date: DateTime(2026, 5, 1),
              createdAt: Value(DateTime(2026, 5, 1)),
              updatedAt: Value(DateTime(2026, 5, 1)),
            ),
          );

      // Verificamos que el total por cobrar de mantenimiento no se altera
      final globalReceivable = await financialService
          .getTotalMaintenanceReceivableCents();
      expect(globalReceivable, equals(0));
    });
  });

  group('T-18: Backup / Restore V2 con Schema 3', () {
    test(
      '7. Export y Restore preservan billingType, agreedAmountCents, agreedPriceCents y planId',
      () async {
        // Plan y visita con billing
        final plan = MaintenancePlan(
          id: 'plan-backup',
          clientId: 'client-1',
          title: 'Plan para Respaldo',
          frequencyType: 'monthly',
          intervalDays: 30,
          nextDate: DateTime(2026, 7, 1),
          billingType: 'monthly',
          agreedAmountCents: 120000, // S/ 1,200.00
        );
        await maintenanceRepo.createPlan(plan);

        // Cobro vinculado al plan
        final col = Collection.create(
          clientId: 'client-1',
          planId: 'plan-backup',
          amountCents: 60000,
          date: DateTime(2026, 7, 2),
        );
        await collectionRepo.recordCollection(col);

        // Exportar a JSON
        final jsonStr = await backupService.exportBackupJson();
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        expect(map['schemaVersion'], equals(4));

        final plansJson = (map['data']['maintenancePlans'] as List);
        final planRestoredJson = plansJson.firstWhere(
          (p) => p['id'] == 'plan-backup',
        );
        expect(planRestoredJson['billingType'], equals('monthly'));
        expect(planRestoredJson['agreedAmountCents'], equals(120000));

        final collectionsJson = (map['data']['collections'] as List);
        final colRestoredJson = collectionsJson.firstWhere(
          (c) => c['id'] == col.id,
        );
        expect(colRestoredJson['planId'], equals('plan-backup'));

        // Restaurar en base de datos limpia
        final restoreResult = await backupService.restoreBackupJson(jsonStr);
        expect(restoreResult.success, isTrue);

        final planDb = await maintenanceRepo.getPlanById('plan-backup');
        expect(planDb, isNotNull);
        expect(planDb!.billingType, equals('monthly'));
        expect(planDb.agreedAmountCents, equals(120000));

        final planFinancials = await financialService.getPlanFinancialSummary(
          'plan-backup',
        );
        expect(planFinancials.collectedCents, equals(60000));
        expect(planFinancials.receivableCents, equals(60000));
      },
    );
  });
}
