import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/capital_movement.dart' as model;
import 'package:mantenimiento_app/core/repositories/inventory_repository.dart';
import 'package:mantenimiento_app/core/repositories/partner_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late PartnerRepository partnerRepo;
  late InventoryRepository inventoryRepo;

  late String partnerAId;
  late String partnerBId;
  late String projectId;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    partnerRepo = PartnerRepository(db);
    inventoryRepo = InventoryRepository(db);

    partnerAId = const Uuid().v4();
    partnerBId = const Uuid().v4();
    projectId = const Uuid().v4();

    // Crear dos socios en la base de datos
    await db
        .into(db.partners)
        .insert(
          PartnersCompanion.insert(
            id: partnerAId,
            name: 'Socio A (Carlos)',
            equityPercentage: const Value(50.0),
          ),
        );
    await db
        .into(db.partners)
        .insert(
          PartnersCompanion.insert(
            id: partnerBId,
            name: 'Socio B (Eduardo)',
            equityPercentage: const Value(50.0),
          ),
        );

    // Crear cliente y obra
    final clientId = const Uuid().v4();
    await db
        .into(db.clients)
        .insert(
          ClientsCompanion.insert(
            id: clientId,
            name: 'Cliente Residencial Los Pinos',
          ),
        );
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: projectId,
            clientId: Value(clientId),
            name: 'Obra Los Pinos Fachada',
            startDate: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('T-08: Pruebas de Finanzas de Socios y CapitalMovements Ledger', () {
    test(
      '1. Aporte simple: incrementa aportes y saldo neto a favor del socio',
      () async {
        final aporte = model.CapitalMovement.create(
          partnerId: partnerAId,
          type: 'contribution',
          amountCents: 500000, // S/ 5,000.00
          date: DateTime.now(),
          notes: 'Aporte de capital inicial en efectivo',
        );
        await partnerRepo.recordCapitalMovement(aporte);

        final balance = await partnerRepo.getPartnerBalance(partnerAId);
        expect(balance.contributionsCents, 500000);
        expect(balance.withdrawalsCents, 0);
        expect(balance.netBalanceCents, 500000);
        expect(balance.netBalance, 5000.0);
      },
    );

    test('2. Múltiples aportes acumulan el saldo a favor', () async {
      await partnerRepo.recordCapitalMovement(
        model.CapitalMovement.create(
          partnerId: partnerAId,
          type: 'contribution',
          amountCents: 500000, // S/ 5,000
          date: DateTime.now(),
        ),
      );
      await partnerRepo.recordCapitalMovement(
        model.CapitalMovement.create(
          partnerId: partnerAId,
          type: 'contribution',
          amountCents: 300000, // S/ 3,000
          date: DateTime.now(),
        ),
      );

      final balance = await partnerRepo.getPartnerBalance(partnerAId);
      expect(balance.contributionsCents, 800000);
      expect(balance.netBalanceCents, 800000);
      expect(balance.netBalance, 8000.0);
    });

    test(
      '3. Retiro de capital: disminuye el saldo a favor del socio',
      () async {
        // Aporte de S/ 8,000
        await partnerRepo.recordCapitalMovement(
          model.CapitalMovement.create(
            partnerId: partnerAId,
            type: 'contribution',
            amountCents: 800000,
            date: DateTime.now(),
          ),
        );

        // Retiro de S/ 2,000
        await partnerRepo.recordCapitalMovement(
          model.CapitalMovement.create(
            partnerId: partnerAId,
            type: 'withdrawal',
            amountCents: 200000,
            date: DateTime.now(),
            notes: 'Retiro parcial de capital',
          ),
        );

        final balance = await partnerRepo.getPartnerBalance(partnerAId);
        expect(balance.contributionsCents, 800000);
        expect(balance.withdrawalsCents, 200000);
        expect(balance.netBalanceCents, 600000); // 8000 - 2000 = 6000
        expect(balance.netBalance, 6000.0);
      },
    );

    test(
      '4. Gasto personal para la empresa/obra: reconocido como pasivo a favor del socio',
      () async {
        // Socio paga S/ 800 de su bolsillo para comprar materiales
        await partnerRepo.recordCapitalMovement(
          model.CapitalMovement.create(
            partnerId: partnerAId,
            projectId: projectId,
            type: 'partnerExpense',
            amountCents: 80000, // S/ 800
            date: DateTime.now(),
            notes: 'Pago de flete y herramientas menores de bolsillo',
          ),
        );

        final balance = await partnerRepo.getPartnerBalance(partnerAId);
        expect(balance.partnerExpensesCents, 80000);
        expect(balance.netBalanceCents, 80000);
        expect(balance.netBalance, 800.0);
      },
    );

    test(
      '5. Distribución de utilidades: resta del saldo neto del socio',
      () async {
        // Aporte S/ 5,000
        await partnerRepo.recordCapitalMovement(
          model.CapitalMovement.create(
            partnerId: partnerAId,
            type: 'contribution',
            amountCents: 500000,
            date: DateTime.now(),
          ),
        );

        // Reparto de utilidades S/ 1,500
        await partnerRepo.recordCapitalMovement(
          model.CapitalMovement.create(
            partnerId: partnerAId,
            type: 'profitDistribution',
            amountCents: 150000,
            date: DateTime.now(),
            notes: 'Reparto de dividendos mes Mayo',
          ),
        );

        final balance = await partnerRepo.getPartnerBalance(partnerAId);
        expect(balance.contributionsCents, 500000);
        expect(balance.profitDistributionsCents, 150000);
        expect(balance.netBalanceCents, 350000); // 5000 - 1500 = S/ 3500
        expect(balance.netBalance, 3500.0);
      },
    );

    test('6. Dos socios con aportes y saldos independientes', () async {
      // Socio A aporta S/ 10,000
      await partnerRepo.recordCapitalMovement(
        model.CapitalMovement.create(
          partnerId: partnerAId,
          type: 'contribution',
          amountCents: 1000000,
          date: DateTime.now(),
        ),
      );

      // Socio B aporta S/ 3,000
      await partnerRepo.recordCapitalMovement(
        model.CapitalMovement.create(
          partnerId: partnerBId,
          type: 'contribution',
          amountCents: 300000,
          date: DateTime.now(),
        ),
      );

      // Socio B retira S/ 500
      await partnerRepo.recordCapitalMovement(
        model.CapitalMovement.create(
          partnerId: partnerBId,
          type: 'withdrawal',
          amountCents: 50000,
          date: DateTime.now(),
        ),
      );

      final balA = await partnerRepo.getPartnerBalance(partnerAId);
      final balB = await partnerRepo.getPartnerBalance(partnerBId);

      expect(balA.netBalanceCents, 1000000);
      expect(balB.netBalanceCents, 250000); // 3000 - 500 = 2500
    });

    test('7. projectId opcional en movimientos', () async {
      final movGeneral = model.CapitalMovement.create(
        partnerId: partnerAId,
        type: 'contribution',
        amountCents: 200000,
        date: DateTime.now(),
      );
      expect(movGeneral.projectId, isNull);
      await partnerRepo.recordCapitalMovement(movGeneral);

      final movObra = model.CapitalMovement.create(
        partnerId: partnerAId,
        projectId: projectId,
        type: 'partnerExpense',
        amountCents: 35000,
        date: DateTime.now(),
      );
      expect(movObra.projectId, equals(projectId));
      await partnerRepo.recordCapitalMovement(movObra);

      final listObra = await partnerRepo
          .watchPartnerMovements(partnerAId, projectId: projectId)
          .first;
      expect(listObra.length, 1);
      expect(listObra.first.amountCents, 35000);
    });

    test(
      '8. Anulación (Soft Delete) de movimiento revierte el saldo inmediatamente',
      () async {
        final aporte = model.CapitalMovement.create(
          partnerId: partnerAId,
          type: 'contribution',
          amountCents: 400000, // S/ 4,000
          date: DateTime.now(),
        );
        await partnerRepo.recordCapitalMovement(aporte);
        expect(
          (await partnerRepo.getPartnerBalance(partnerAId)).netBalanceCents,
          400000,
        );

        // Anular aporte
        await partnerRepo.deleteCapitalMovement(aporte.id);

        // Saldo vuelve a 0
        final balance = await partnerRepo.getPartnerBalance(partnerAId);
        expect(balance.netBalanceCents, 0);
      },
    );

    test(
      '9. Invariante Crítica: CapitalMovement no incrementa ni duplica costo de Obra',
      () async {
        // Registrar un gasto personal de socio para la obra
        await partnerRepo.recordCapitalMovement(
          model.CapitalMovement.create(
            partnerId: partnerAId,
            projectId: projectId,
            type: 'partnerExpense',
            amountCents: 90000, // S/ 900
            date: DateTime.now(),
          ),
        );

        // El costo de materiales de la obra sigue siendo 0 (no se altera por financiamiento de socios)
        final materialCost = await inventoryRepo
            .watchProjectMaterialCostCents(projectId)
            .first;
        expect(materialCost, 0);
      },
    );

    test('10. amountCents positivo y rechazo de montos <= 0', () async {
      expect(
        () => model.CapitalMovement.create(
          partnerId: partnerAId,
          type: 'contribution',
          amountCents: 0,
          date: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => model.CapitalMovement.create(
          partnerId: partnerAId,
          type: 'contribution',
          amountCents: -5000,
          date: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
