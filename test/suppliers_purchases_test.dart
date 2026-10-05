import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/inventory_item.dart' as model;
import 'package:mantenimiento_app/core/models/stock_movement.dart' as model;
import 'package:mantenimiento_app/core/models/purchase.dart' as model;
import 'package:mantenimiento_app/core/models/supplier.dart' as model;
import 'package:mantenimiento_app/core/repositories/inventory_repository.dart';
import 'package:mantenimiento_app/core/repositories/purchase_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late InventoryRepository inventoryRepo;
  late PurchaseRepository purchaseRepo;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    inventoryRepo = InventoryRepository(db);
    purchaseRepo = PurchaseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('T-07: Pruebas de Proveedores y Compras de Insumos', () {
    test('1. Crear proveedor con y sin RUC/DNI', () async {
      final supConRuc = model.Supplier.create(
        name: 'Vivero Flores del Sur SAC',
        taxId: '20601234567',
        contactName: 'Carlos Fuentes',
        phone: '958112233',
      );
      await purchaseRepo.createSupplier(supConRuc);

      final supSinRuc = model.Supplier.create(
        name: 'Don José Productor Local',
        phone: '959001122',
        notes: 'Venta de abono por camionada',
      );
      await purchaseRepo.createSupplier(supSinRuc);

      final suppliers = await purchaseRepo.watchActiveSuppliers().first;
      expect(suppliers.length, 2);
      expect(suppliers.any((s) => s.taxId == '20601234567'), isTrue);
      expect(suppliers.any((s) => s.taxId == null), isTrue);
    });

    test(
      '2. Compra de un ítem: inserción atómica de Purchase, Item y Kardex',
      () async {
        final planta = model.InventoryItem.create(
          name: 'Ficus Benjamina',
          unit: 'unit',
        );
        await inventoryRepo.createItem(planta);
        expect(await inventoryRepo.getItemStock(planta.id), 0.0);

        final purchase = model.Purchase.create(
          totalAmountCents: 15000,
          date: DateTime.now(),
          documentType: 'invoice',
          invoiceNumber: 'F001-0042',
        );

        await purchaseRepo.recordPurchase(
          purchase: purchase,
          items: [
            PurchaseItemDraft(
              itemId: planta.id,
              quantity: 30,
              unitCostCents: 500, // S/ 5.00 c/u = 15000 cents
            ),
          ],
        );

        // Stock actualizado en Kardex
        final stock = await inventoryRepo.getItemStock(planta.id);
        expect(stock, 30.0);

        // Líneas de compra guardadas
        final items = await purchaseRepo.watchPurchaseItems(purchase.id).first;
        expect(items.length, 1);
        expect(items.first.quantity, 30.0);
        expect(items.first.unitCostCents, 500);
        expect(items.first.totalCostCents, 15000);
      },
    );

    test(
      '3. Compra multi-ítem: 10 bolsas tierra, 50 mioporos, 2 fertilizantes',
      () async {
        final tierra = model.InventoryItem.create(
          name: 'Tierra Preparada',
          unit: 'bolsa',
        );
        final mioporo = model.InventoryItem.create(
          name: 'Mioporo',
          unit: 'unit',
        );
        final fertilizante = model.InventoryItem.create(
          name: 'Fertilizante Triple 15',
          unit: 'kg',
        );

        await inventoryRepo.createItem(tierra);
        await inventoryRepo.createItem(mioporo);
        await inventoryRepo.createItem(fertilizante);

        // 10 tierra x S/ 15.00 (1500c) = 15000c
        // 50 mioporos x S/ 2.00 (200c) = 10000c
        // 2 fertilizantes x S/ 45.00 (4500c) = 9000c
        // Total esperado: 34000 cents (S/ 340.00)
        final purchase = model.Purchase.create(
          totalAmountCents: 34000,
          date: DateTime.now(),
          documentType: 'receipt',
          invoiceNumber: 'B002-1234',
        );

        await purchaseRepo.recordPurchase(
          purchase: purchase,
          items: [
            PurchaseItemDraft(
              itemId: tierra.id,
              quantity: 10,
              unitCostCents: 1500,
            ),
            PurchaseItemDraft(
              itemId: mioporo.id,
              quantity: 50,
              unitCostCents: 200,
            ),
            PurchaseItemDraft(
              itemId: fertilizante.id,
              quantity: 2,
              unitCostCents: 4500,
            ),
          ],
        );

        // Kardex stocks incrementados
        expect(await inventoryRepo.getItemStock(tierra.id), 10.0);
        expect(await inventoryRepo.getItemStock(mioporo.id), 50.0);
        expect(await inventoryRepo.getItemStock(fertilizante.id), 2.0);

        // Detalle de líneas
        final lines = await purchaseRepo.watchPurchaseItems(purchase.id).first;
        expect(lines.length, 3);

        final retrievedPurchase = await purchaseRepo.getPurchase(purchase.id);
        expect(retrievedPurchase?.totalAmountCents, 34000);
      },
    );

    test(
      '4. Transacción atómica: falla en una línea aborta toda la operación',
      () async {
        final planta = model.InventoryItem.create(name: 'Palmera Abanico');
        await inventoryRepo.createItem(planta);

        final purchase = model.Purchase.create(
          totalAmountCents: 10000,
          date: DateTime.now(),
        );

        // Línea 2 con itemId inexistente para forzar violación de foreign key de SQLite
        expect(
          () async => await purchaseRepo.recordPurchase(
            purchase: purchase,
            items: [
              PurchaseItemDraft(
                itemId: planta.id,
                quantity: 5,
                unitCostCents: 1000,
              ),
              PurchaseItemDraft(
                itemId: 'item-fantasma-inexistente',
                quantity: 2,
                unitCostCents: 2500,
              ),
            ],
          ),
          throwsA(anything),
        );

        // Verificar que NO se creó la compra ni el movimiento de la línea 1
        final purchases = await purchaseRepo.watchPurchases().first;
        expect(purchases.isEmpty, isTrue);

        final stock = await inventoryRepo.getItemStock(planta.id);
        expect(stock, 0.0);
      },
    );

    test(
      '5. Snapshots de costo históricos preservados en PurchaseItems y Kardex',
      () async {
        final abono = model.InventoryItem.create(
          name: 'Compost Orgánico',
          defaultCostCents: 800, // S/ 8.00
        );
        await inventoryRepo.createItem(abono);

        final purchase = model.Purchase.create(
          totalAmountCents: 10000,
          date: DateTime.now(),
        );

        await purchaseRepo.recordPurchase(
          purchase: purchase,
          items: [
            PurchaseItemDraft(
              itemId: abono.id,
              quantity: 10,
              unitCostCents: 1000,
            ), // S/ 10.00
          ],
        );

        // Ahora actualizamos el maestro de items con un nuevo costo
        await inventoryRepo.updateItem(abono.copyWith(defaultCostCents: 2500));

        final lines = await purchaseRepo.watchPurchaseItems(purchase.id).first;
        expect(lines.first.unitCostCents, 1000);
        expect(lines.first.totalCostCents, 10000);

        final movements = await inventoryRepo
            .watchItemMovements(abono.id)
            .first;
        expect(movements.first.unitCostCents, 1000);
      },
    );

    test(
      '6. Integridad de Foreign Keys: Compra con supplierId inexistente es rechazada',
      () async {
        final item = model.InventoryItem.create(name: 'Arena Gruesa');
        await inventoryRepo.createItem(item);

        final purchase = model.Purchase.create(
          supplierId: 'supplier-inexistente-123',
          totalAmountCents: 5000,
          date: DateTime.now(),
        );

        expect(
          () async => await purchaseRepo.recordPurchase(
            purchase: purchase,
            items: [
              PurchaseItemDraft(
                itemId: item.id,
                quantity: 10,
                unitCostCents: 500,
              ),
            ],
          ),
          throwsA(anything),
        );
      },
    );

    test(
      '7. Anulación de compra: revierte movimientos de stock en Kardex',
      () async {
        final tubo = model.InventoryItem.create(name: 'Tubo PVC 1/2 pulgada');
        await inventoryRepo.createItem(tubo);

        final purchase = model.Purchase.create(
          totalAmountCents: 8000,
          date: DateTime.now(),
          invoiceNumber: 'B001-50',
        );

        await purchaseRepo.recordPurchase(
          purchase: purchase,
          items: [
            PurchaseItemDraft(
              itemId: tubo.id,
              quantity: 20,
              unitCostCents: 400,
            ),
          ],
        );
        expect(await inventoryRepo.getItemStock(tubo.id), 20.0);

        // Anular compra
        await purchaseRepo.cancelPurchase(
          purchase.id,
          reason: 'Error en comprobante',
        );

        // Stock debe volver a 0
        final stockPostAnulacion = await inventoryRepo.getItemStock(tubo.id);
        expect(stockPostAnulacion, 0.0);

        // Compra queda con deletedAt y motivo
        final canceledPurchase = await purchaseRepo.getPurchase(purchase.id);
        expect(
          canceledPurchase,
          isNull,
        ); // getPurchase filtra deletedAt.isNull()
      },
    );

    test(
      '8. Rechazo de anulación si el stock comprado ya fue consumido',
      () async {
        final grass = model.InventoryItem.create(name: 'Grass en Tepe');
        await inventoryRepo.createItem(grass);

        final purchase = model.Purchase.create(
          totalAmountCents: 50000,
          date: DateTime.now(),
        );

        // Comprar 100 unidades
        await purchaseRepo.recordPurchase(
          purchase: purchase,
          items: [
            PurchaseItemDraft(
              itemId: grass.id,
              quantity: 100,
              unitCostCents: 500,
            ),
          ],
        );
        expect(await inventoryRepo.getItemStock(grass.id), 100.0);

        // Consumir 70 unidades
        await inventoryRepo.recordMovement(
          model.StockMovement.create(
            itemId: grass.id,
            movementType: 'consumption',
            quantity: 70,
            notes: 'Consumo directo en campo',
          ),
        );
        expect(await inventoryRepo.getItemStock(grass.id), 30.0);

        // Intentar anular la compra de 100 unidades (dejaría stock en 30 - 100 = -70)
        // Debe ser estrictamente rechazada
        expect(
          () async => await purchaseRepo.cancelPurchase(purchase.id),
          throwsA(isA<StateError>()),
        );

        // El stock sigue intacto en 30
        expect(await inventoryRepo.getItemStock(grass.id), 30.0);
      },
    );

    test(
      '9. Precisión en centavos y redondeo de cantidades fraccionarias',
      () async {
        final piedrilla = model.InventoryItem.create(
          name: 'Piedrilla Lavada',
          unit: 'm3',
        );
        await inventoryRepo.createItem(piedrilla);

        // 3.5 m3 a S/ 65.40 (6540c) = 3.5 * 6540 = 22890 cents (S/ 228.90)
        final draft = PurchaseItemDraft(
          itemId: piedrilla.id,
          quantity: 3.5,
          unitCostCents: 6540,
        );
        expect(draft.totalCostCents, 22890);

        final purchase = model.Purchase.create(
          totalAmountCents: draft.totalCostCents,
          date: DateTime.now(),
        );

        await purchaseRepo.recordPurchase(purchase: purchase, items: [draft]);

        final lines = await purchaseRepo.watchPurchaseItems(purchase.id).first;
        expect(lines.first.quantity, 3.5);
        expect(lines.first.unitCostCents, 6540);
        expect(lines.first.totalCostCents, 22890);
        expect(await inventoryRepo.getItemStock(piedrilla.id), 3.5);
      },
    );
  });
}
