import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/models/collection.dart' as model;
import 'package:mantenimiento_app/core/repositories/collection_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late CollectionRepository collectionRepo;

  late String clientId;
  late String projectId;
  late String partnerId;

  const agreedBudgetCents = 1500000; // S/ 15,000.00

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    collectionRepo = CollectionRepository(db);

    clientId = const Uuid().v4();
    projectId = const Uuid().v4();
    partnerId = const Uuid().v4();

    // Insertar cliente
    await db
        .into(db.clients)
        .insert(
          ClientsCompanion.insert(
            id: clientId,
            name: 'Inmobiliaria Los Sauces',
          ),
        );

    // Insertar socio
    await db
        .into(db.partners)
        .insert(
          PartnersCompanion.insert(id: partnerId, name: 'Socio Administrador'),
        );

    // Insertar obra con presupuesto S/ 15,000
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: projectId,
            clientId: Value(clientId),
            name: 'Paisajismo Condominio Los Sauces',
            budgetAmountCents: const Value(agreedBudgetCents),
            startDate: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('T-09: Pruebas de Cobros de Clientes y Cuentas por Cobrar', () {
    test('1. Cobro parcial: reduce cuenta por cobrar correctamente', () async {
      final cobro1 = model.Collection.create(
        clientId: clientId,
        projectId: projectId,
        amountCents: 500000, // S/ 5,000.00
        date: DateTime.now(),
        paymentMethod: 'transfer',
        reference: 'Op. 123456',
        receivedByPartnerId: partnerId,
      );
      await collectionRepo.recordCollection(cobro1);

      final summary = await collectionRepo.getProjectBillingSummary(
        projectId,
        agreedBudgetCents,
      );

      expect(summary.agreedAmountCents, 1500000);
      expect(summary.collectedCents, 500000);
      expect(summary.receivableCents, 1000000); // 15,000 - 5,000 = S/ 10,000
      expect(summary.collected, 5000.0);
      expect(summary.receivable, 10000.0);
      expect(summary.isOverpaid, isFalse);
    });

    test('2. Múltiples cobros parciales acumulan el total recaudado', () async {
      // Cobro 1: S/ 5,000
      await collectionRepo.recordCollection(
        model.Collection.create(
          clientId: clientId,
          projectId: projectId,
          amountCents: 500000,
          date: DateTime.now(),
          paymentMethod: 'transfer',
        ),
      );

      // Cobro 2: S/ 3,000
      await collectionRepo.recordCollection(
        model.Collection.create(
          clientId: clientId,
          projectId: projectId,
          amountCents: 300000,
          date: DateTime.now(),
          paymentMethod: 'yape',
          reference: 'Yape 958112233',
        ),
      );

      final summary = await collectionRepo.getProjectBillingSummary(
        projectId,
        agreedBudgetCents,
      );

      expect(summary.collectedCents, 800000); // S/ 8,000
      expect(summary.receivableCents, 700000); // S/ 7,000
      expect(summary.isOverpaid, isFalse);

      final collections = await collectionRepo
          .watchProjectCollections(projectId)
          .first;
      expect(collections.length, 2);
    });

    test(
      '3. Cobro completo: saldo pendiente queda exactamente en 0 (100% cobrado)',
      () async {
        // Cobro 1: S/ 8,000
        await collectionRepo.recordCollection(
          model.Collection.create(
            clientId: clientId,
            projectId: projectId,
            amountCents: 800000,
            date: DateTime.now(),
          ),
        );

        // Cobro 2: S/ 7,000 (completa los S/ 15,000)
        await collectionRepo.recordCollection(
          model.Collection.create(
            clientId: clientId,
            projectId: projectId,
            amountCents: 700000,
            date: DateTime.now(),
          ),
        );

        final summary = await collectionRepo.getProjectBillingSummary(
          projectId,
          agreedBudgetCents,
        );

        expect(summary.collectedCents, 1500000);
        expect(summary.receivableCents, 0);
        expect(summary.percentCollected, 100.0);
        expect(summary.isOverpaid, isFalse);
      },
    );

    test(
      '4. Sobrepago: detecta saldo a favor del cliente sin bloquear',
      () async {
        // Cobro de S/ 17,000 sobre un presupuesto de S/ 15,000
        await collectionRepo.recordCollection(
          model.Collection.create(
            clientId: clientId,
            projectId: projectId,
            amountCents: 1700000,
            date: DateTime.now(),
            notes: 'Cliente pagó adelanto de adicionales no presupuestados aún',
          ),
        );

        final summary = await collectionRepo.getProjectBillingSummary(
          projectId,
          agreedBudgetCents,
        );

        expect(summary.collectedCents, 1700000);
        expect(summary.receivableCents, 0);
        expect(summary.isOverpaid, isTrue);
        expect(summary.overpaidAmountCents, 200000); // S/ 2,000 de sobrepago
        expect(summary.overpaidAmount, 2000.0);
      },
    );

    test(
      '5. Anulación (Soft Delete): cobro anulado se descuenta del total cobrado',
      () async {
        final cobro = model.Collection.create(
          clientId: clientId,
          projectId: projectId,
          amountCents: 600000,
          date: DateTime.now(),
        );
        await collectionRepo.recordCollection(cobro);

        var summary = await collectionRepo.getProjectBillingSummary(
          projectId,
          agreedBudgetCents,
        );
        expect(summary.collectedCents, 600000);

        // Anular cobro
        await collectionRepo.deleteCollection(cobro.id);

        summary = await collectionRepo.getProjectBillingSummary(
          projectId,
          agreedBudgetCents,
        );
        expect(summary.collectedCents, 0);
        expect(summary.receivableCents, agreedBudgetCents);
      },
    );

    test('6. Métodos de pago permitidos y formateo de etiquetas', () async {
      final methods = ['cash', 'yape', 'plin', 'transfer', 'other'];
      for (final m in methods) {
        final c = model.Collection.create(
          clientId: clientId,
          amountCents: 10000,
          date: DateTime.now(),
          paymentMethod: m,
        );
        expect(c.paymentMethodLabel.isNotEmpty, isTrue);
      }

      // Método no válido arrojado
      expect(
        () => model.Collection.create(
          clientId: clientId,
          amountCents: 10000,
          date: DateTime.now(),
          paymentMethod: 'crypto_invalido',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      '7. Integridad de Foreign Keys: Cobro con clientId inexistente es rechazado',
      () async {
        expect(
          () async => await collectionRepo.recordCollection(
            model.Collection.create(
              clientId: 'cliente-fantasma-inexistente',
              amountCents: 50000,
              date: DateTime.now(),
            ),
          ),
          throwsA(anything),
        );
      },
    );

    test(
      '8. Validación de montos: amountCents <= 0 es rechazado con ArgumentError',
      () async {
        expect(
          () => model.Collection.create(
            clientId: clientId,
            amountCents: 0,
            date: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => model.Collection.create(
            clientId: clientId,
            amountCents: -1500,
            date: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('9. Precisión en centavos sin redondeo erróneo de doubles', () async {
      // Cobro con centavos fraccionarios: S/ 1,234.56 = 123456 cents
      final cobroCentavos = model.Collection.create(
        clientId: clientId,
        projectId: projectId,
        amountCents: 123456,
        date: DateTime.now(),
      );
      await collectionRepo.recordCollection(cobroCentavos);

      final summary = await collectionRepo.getProjectBillingSummary(
        projectId,
        agreedBudgetCents,
      );
      expect(summary.collectedCents, 123456);
      expect(summary.receivableCents, agreedBudgetCents - 123456);
      expect(summary.collected, 1234.56);
    });
  });
}
