import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/inventory_item.dart' as model;
import 'package:mantenimiento_app/core/models/stock_movement.dart' as model;
import 'package:mantenimiento_app/core/repositories/inventory_repository.dart';

void main() {
  late AppDatabase db;
  late InventoryRepository repo;
  const testWorkspace = 'test-workspace';

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    repo = InventoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('T-05: Pruebas de Inventario y Kardex (StockMovements)', () {
    test(
      '1. Flujo completo: Compra +500, Obra -120, Mantenimiento -20, Pérdida -5 -> Stock = 355',
      () async {
        // Crear Item: Mioporo
        final mioporo = model.InventoryItem.create(
          workspaceId: testWorkspace,
          name: 'Mioporo',
          category: 'plants',
          unit: 'unit',
          minStockAlert: 50,
          defaultCostCents: 250, // S/ 2.50
        );
        await repo.createItem(mioporo);

        // Setup Project and Maintenance Plan/Visit for FK integrity
        final clientRow = await db
            .into(db.clients)
            .insertReturning(
              ClientsCompanion.insert(
                id: const Uuid().v4(),
                name: 'Cliente Jardín',
              ),
            );
        final projectRow = await db
            .into(db.projects)
            .insertReturning(
              ProjectsCompanion.insert(
                id: const Uuid().v4(),
                clientId: Value(clientRow.id),
                name: 'Obra Cayma',
                startDate: DateTime.now(),
              ),
            );
        final planRow = await db
            .into(db.maintenancePlans)
            .insertReturning(
              MaintenancePlansCompanion.insert(
                id: const Uuid().v4(),
                clientId: clientRow.id,
                title: 'Mantenimiento Residencial',
                nextDate: Value(DateTime.now()),
              ),
            );
        final visitRow = await db
            .into(db.maintenanceVisits)
            .insertReturning(
              MaintenanceVisitsCompanion.insert(
                id: const Uuid().v4(),
                planId: planRow.id,
                scheduledDate: DateTime.now(),
              ),
            );

        // Movimiento 1: Compra +500
        final compra = model.StockMovement.create(
          workspaceId: testWorkspace,
          itemId: mioporo.id,
          movementType: 'purchase',
          quantity: 500,
          unitCostCents: 200, // S/ 2.00
        );
        await repo.recordMovement(compra);

        var stock = await repo.getItemStock(mioporo.id);
        expect(stock, 500.0);

        // Movimiento 2: Consumo en Obra -120
        final consumoObra = model.StockMovement.create(
          workspaceId: testWorkspace,
          itemId: mioporo.id,
          movementType: 'consumption',
          quantity: 120,
          unitCostCents: 200,
          projectId: projectRow.id,
        );
        await repo.recordMovement(consumoObra);

        stock = await repo.getItemStock(mioporo.id);
        expect(stock, 380.0);

        // Movimiento 3: Consumo en Mantenimiento -20
        final consumoMantenimiento = model.StockMovement.create(
          workspaceId: testWorkspace,
          itemId: mioporo.id,
          movementType: 'consumption',
          quantity: 20,
          unitCostCents: 200,
          visitId: visitRow.id,
        );
        await repo.recordMovement(consumoMantenimiento);

        stock = await repo.getItemStock(mioporo.id);
        expect(stock, 360.0);

        // Movimiento 4: Pérdida / Merma -5
        final perdida = model.StockMovement.create(
          workspaceId: testWorkspace,
          itemId: mioporo.id,
          movementType: 'loss',
          quantity: 5,
          unitCostCents: 200,
          notes: 'Plantas dañadas durante descarga',
        );
        await repo.recordMovement(perdida);

        // Stock final esperado: exacto 355
        stock = await repo.getItemStock(mioporo.id);
        expect(stock, 355.0);
      },
    );

    test('2. Stock negativo rechazado por defecto', () async {
      final grass = model.InventoryItem.create(
        workspaceId: testWorkspace,
        name: 'Grass Americano',
        unit: 'm2',
      );
      await repo.createItem(grass);

      // Stock inicial es 0
      expect(await repo.getItemStock(grass.id), 0.0);

      // Intentar retirar 10 unidades sin stock previo debe arrojar StateError
      final consumoExcesivo = model.StockMovement.create(
        workspaceId: testWorkspace,
        itemId: grass.id,
        movementType: 'consumption',
        quantity: 10,
      );

      expect(
        () async => await repo.recordMovement(consumoExcesivo),
        throwsA(isA<StateError>()),
      );

      // El stock sigue siendo 0 intacto
      expect(await repo.getItemStock(grass.id), 0.0);
    });

    test(
      '3. Costo histórico snapshot preservado: cambiar costo futuro del item no altera consumos pasados',
      () async {
        final abono = model.InventoryItem.create(
          workspaceId: testWorkspace,
          name: 'Abono Orgánico',
          unit: 'kg',
          defaultCostCents: 1000, // S/ 10.00
        );
        await repo.createItem(abono);

        // Ingreso de 100 kg
        await repo.recordMovement(
          model.StockMovement.create(
            itemId: abono.id,
            movementType: 'purchase',
            quantity: 100,
            unitCostCents: 1000,
          ),
        );

        // Consumo de 15 kg con costo histórico de S/ 10.00 (total S/ 150.00)
        final consumoHistorico = model.StockMovement.create(
          itemId: abono.id,
          movementType: 'consumption',
          quantity: 15,
          unitCostCents: 1000,
        );
        await repo.recordMovement(consumoHistorico);

        // Se actualiza el item en el maestro a un precio más alto: S/ 18.00
        final abonoSubioPrecio = abono.copyWith(defaultCostCents: 1800);
        await repo.updateItem(abonoSubioPrecio);

        // Verificar que el movimiento anterior conserva su snapshot de S/ 10 y total S/ 150
        final movimientos = await repo.watchItemMovements(abono.id).first;
        final consumoRegistrado = movimientos.firstWhere(
          (m) => m.id == consumoHistorico.id,
        );
        expect(consumoRegistrado.unitCostCents, 1000);
        expect(
          consumoRegistrado.totalCostCents,
          15000,
        ); // 15 * 1000 = 15000 cents (S/ 150.00)
      },
    );

    test(
      '4. Derivación reactiva de Costo de Obra (projectMaterialCost)',
      () async {
        final clientRow = await db
            .into(db.clients)
            .insertReturning(
              ClientsCompanion.insert(
                id: const Uuid().v4(),
                name: 'Cliente Arequipa',
              ),
            );
        final obraA = await db
            .into(db.projects)
            .insertReturning(
              ProjectsCompanion.insert(
                id: const Uuid().v4(),
                clientId: Value(clientRow.id),
                name: 'Obra Yanahuara',
                startDate: DateTime.now(),
              ),
            );
        final obraB = await db
            .into(db.projects)
            .insertReturning(
              ProjectsCompanion.insert(
                id: const Uuid().v4(),
                clientId: Value(clientRow.id),
                name: 'Obra Selva Alegre',
                startDate: DateTime.now(),
              ),
            );

        final tubo = model.InventoryItem.create(
          name: 'Tubo PVC 1/2',
          unit: 'm',
        );
        await repo.createItem(tubo);
        await repo.recordMovement(
          model.StockMovement.create(
            itemId: tubo.id,
            movementType: 'purchase',
            quantity: 200,
            unitCostCents: 500, // S/ 5.00
          ),
        );

        // Consumo en Obra A: 20m a S/ 5.00 = S/ 100.00 (10000 cents)
        await repo.recordConsumption(
          itemId: tubo.id,
          quantity: 20,
          unitCostCents: 500,
          projectId: obraA.id,
        );

        // Consumo en Obra A: 10m a S/ 5.00 = S/ 50.00 (5000 cents)
        await repo.recordConsumption(
          itemId: tubo.id,
          quantity: 10,
          unitCostCents: 500,
          projectId: obraA.id,
        );

        // Consumo en Obra B (ajena): 30m a S/ 5.00 = S/ 150.00 (15000 cents)
        await repo.recordConsumption(
          itemId: tubo.id,
          quantity: 30,
          unitCostCents: 500,
          projectId: obraB.id,
        );

        // Costo de Obra A debe ser exactamente 15000 cents (S/ 150.00)
        final costoObraA = await repo
            .watchProjectMaterialCostCents(obraA.id)
            .first;
        expect(costoObraA, 15000);

        // Costo de Obra B debe ser 15000 cents
        final costoObraB = await repo
            .watchProjectMaterialCostCents(obraB.id)
            .first;
        expect(costoObraB, 15000);
      },
    );

    test(
      '5. Derivación reactiva de Costo de Visita de Mantenimiento',
      () async {
        final clientRow = await db
            .into(db.clients)
            .insertReturning(
              ClientsCompanion.insert(
                id: const Uuid().v4(),
                name: 'Cliente Club',
              ),
            );
        final plan = await db
            .into(db.maintenancePlans)
            .insertReturning(
              MaintenancePlansCompanion.insert(
                id: const Uuid().v4(),
                clientId: clientRow.id,
                title: 'Mantenimiento Semanal',
                nextDate: Value(DateTime.now()),
              ),
            );
        final visit = await db
            .into(db.maintenanceVisits)
            .insertReturning(
              MaintenanceVisitsCompanion.insert(
                id: const Uuid().v4(),
                planId: plan.id,
                scheduledDate: DateTime.now(),
              ),
            );

        final fertilizante = model.InventoryItem.create(
          name: 'Fertilizante Foliar',
          unit: 'kg',
        );
        await repo.createItem(fertilizante);
        await repo.recordMovement(
          model.StockMovement.create(
            itemId: fertilizante.id,
            movementType: 'purchase',
            quantity: 50,
            unitCostCents: 1200, // S/ 12.00/kg
          ),
        );

        // Consumo en Visita: 2.5 kg a S/ 12.00 = S/ 30.00 (3000 cents)
        await repo.recordConsumption(
          itemId: fertilizante.id,
          quantity: 2.5,
          unitCostCents: 1200,
          visitId: visit.id,
        );

        final visitMatCost = await repo
            .watchVisitMaterialCostCents(visit.id)
            .first;
        expect(visitMatCost, 3000);
      },
    );

    test(
      '6. Anulación (Soft Delete) de movimiento revierte stock y costos',
      () async {
        final planta = model.InventoryItem.create(name: 'Geranio');
        await repo.createItem(planta);

        await repo.recordMovement(
          model.StockMovement.create(
            itemId: planta.id,
            movementType: 'purchase',
            quantity: 20,
            unitCostCents: 400,
          ),
        );
        expect(await repo.getItemStock(planta.id), 20.0);

        final consumo = model.StockMovement.create(
          itemId: planta.id,
          movementType: 'consumption',
          quantity: 5,
          unitCostCents: 400,
        );
        await repo.recordMovement(consumo);
        expect(await repo.getItemStock(planta.id), 15.0);

        // Anular el consumo
        await repo.deleteMovement(consumo.id);

        // Stock recupera las 20 unidades
        expect(await repo.getItemStock(planta.id), 20.0);
      },
    );

    test(
      '7. Integridad XOR: Movimiento no puede pertenecer simultáneamente a Obra y Visita',
      () async {
        final arena = model.InventoryItem.create(name: 'Arena Fina');
        await repo.createItem(arena);

        expect(
          () => model.StockMovement.create(
            itemId: arena.id,
            movementType: 'consumption',
            quantity: 2,
            projectId: 'project-123',
            visitId: 'visit-456',
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      '8. FK de SQLite: Movimiento con itemId inexistente es rechazado',
      () async {
        final movimientoInvalido = model.StockMovement.create(
          itemId: 'item-fantasma-inexistente',
          movementType: 'purchase',
          quantity: 10,
          unitCostCents: 100,
        );

        expect(
          () async => await repo.recordMovement(movimientoInvalido),
          throwsA(anything),
        );
      },
    );

    test(
      '9. Precisión de cantidades fraccionarias y cálculo exacto en centavos',
      () async {
        final tierra = model.InventoryItem.create(
          name: 'Tierra Preparada',
          unit: 'm3',
        );
        await repo.createItem(tierra);

        // Compra de 7.25 m3 a S/ 85.50 el m3 (8550 cents)
        final compraFrac = model.StockMovement.create(
          itemId: tierra.id,
          movementType: 'purchase',
          quantity: 7.25,
          unitCostCents: 8550,
        );
        await repo.recordMovement(compraFrac);

        // Total esperado: 7.25 * 8550 = 61987.5 -> round() = 61988 cents (S/ 619.88)
        expect(compraFrac.totalCostCents, 61988);

        final stock = await repo.getItemStock(tierra.id);
        expect(stock, 7.25);
      },
    );
  });
}
