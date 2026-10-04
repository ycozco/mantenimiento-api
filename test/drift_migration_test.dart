import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/database/data_migration_service.dart';
import 'package:mantenimiento_app/core/database/local_storage_service.dart';
import 'package:mantenimiento_app/core/models/gasto.dart';
import 'package:mantenimiento_app/core/models/socio.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // Base de datos SQLite en memoria para tests aislados
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Pruebas de Migración JSON -> Drift SQLite', () {
    const sampleV1Json = '''
    {
      "version": 1,
      "updatedAt": "2026-10-04T12:00:00.000",
      "socios": [
        {"id": "s1", "nombre": "Socio 1 (Tú)", "telefono": "999111222", "colorValue": 4294348299},
        {"id": "s2", "nombre": "Socio 2", "telefono": "999333444", "colorValue": 4279351681}
      ],
      "clientes": [
        {
          "id": "c1",
          "nombre": "Residencial Los Álamos",
          "telefono": "555-0192",
          "direccion": "Av. Principal #450, Cayma",
          "notas": "Revisión bombas"
        },
        {
          "id": "c2",
          "nombre": "Clínica San Marcos",
          "telefono": "555-8821",
          "direccion": "Calle Médicos 12",
          "notas": "Generador eléctrico"
        }
      ],
      "mantenimientos": [
        {
          "id": "m1",
          "clienteId": "c1",
          "clienteNombre": "Residencial Los Álamos",
          "titulo": "Mantenimiento Bombas",
          "tipoFrecuencia": "unMesYMedio",
          "diasPersonalizados": 45,
          "fechaProximo": "2026-10-07T09:00:00.000",
          "fechaUltimo": "2026-08-23T09:00:00.000",
          "responsablesIds": ["s1", "s2"],
          "activo": true,
          "completado": false
        }
      ],
      "obras": [
        {
          "id": "o1",
          "nombre": "Red Hidráulica Torre B",
          "clienteId": "c1",
          "clienteNombre": "Residencial Los Álamos",
          "presupuesto": 45000.50,
          "fechaInicio": "2026-09-24T08:00:00.000",
          "estado": "enProgreso",
          "sociosAsignados": ["s1", "s2"]
        }
      ],
      "gastos": [
        {
          "id": "g1",
          "concepto": "Gasolina camioneta",
          "categoria": "gasolina",
          "montoTotal": 850.75,
          "fecha": "2026-10-02T14:30:00.000",
          "pagadoPorSocioId": "s1",
          "tipoReparto": "equitativo",
          "participaciones": {"s1": 1.0, "s2": 1.0},
          "nota": "Traslado Cayma"
        }
      ]
    }
    ''';

    test(
      'Migración normal importa todos los registros con exactitud monetaria y fechas',
      () async {
        final migrationService = DataMigrationService(db);
        final result = await migrationService.migrateIfNeeded(
          overrideJsonStr: sampleV1Json,
        );

        expect(result.success, isTrue);
        expect(result.alreadyMigrated, isFalse);
        expect(result.partnersCount, 2);
        expect(result.clientsCount, 2);
        expect(result.projectsCount, 1);
        expect(result.maintenancePlansCount, 1);
        expect(result.expensesCount, 1);

        // Verificar preservación monetaria en céntimos
        final projects = await db.select(db.projects).get();
        expect(projects.length, 1);
        expect(
          projects.first.budgetAmountCents,
          4500050,
        ); // S/ 45,000.50 -> 4500050 céntimos exactos

        final expenses = await db.select(db.expenses).get();
        expect(expenses.length, 1);
        expect(
          expenses.first.amountCents,
          85075,
        ); // S/ 850.75 -> 85075 céntimos

        // Verificar Foreign Keys e integridad referencial
        final locations = await db.select(db.clientLocations).get();
        expect(locations.length, 2);
        expect(locations.first.clientId, 'c1');
        expect(locations.first.address, 'Av. Principal #450, Cayma');

        final visits = await db.select(db.maintenanceVisits).get();
        expect(visits.length, 1);
        expect(visits.first.planId, 'm1');
        expect(
          visits.first.scheduledDate,
          DateTime.parse('2026-10-07T09:00:00.000'),
        );
      },
    );

    test('Migración repetida es idempotente y no duplica datos', () async {
      final migrationService = DataMigrationService(db);

      // Primera ejecución
      final res1 = await migrationService.migrateIfNeeded(
        overrideJsonStr: sampleV1Json,
      );
      expect(res1.success, isTrue);
      expect(res1.alreadyMigrated, isFalse);

      // Segunda ejecución
      final res2 = await migrationService.migrateIfNeeded(
        overrideJsonStr: sampleV1Json,
      );
      expect(res2.success, isTrue);
      expect(res2.alreadyMigrated, isTrue);

      final partners = await db.select(db.partners).get();
      expect(partners.length, 2); // No duplicó socios
    });

    test('JSON vacío genera datos semilla por defecto', () async {
      final migrationService = DataMigrationService(db);
      final result = await migrationService.migrateIfNeeded(
        overrideJsonStr: '',
      );

      expect(result.success, isTrue);
      final partners = await db.select(db.partners).get();
      expect(partners.length, 2);
      expect(partners.map((p) => p.id), containsAll(['s1', 's2']));
    });

    test(
      'JSON corrupto retorna error seguro sin crashear la base de datos',
      () async {
        final migrationService = DataMigrationService(db);
        final result = await migrationService.executeMigrationFromJson(
          '{ invalid json syntax ',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('JSON corrupto'));
      },
    );
  });

  group('Pruebas de CRUD V1 con LocalStorageService sobre Drift SQLite', () {
    late LocalStorageService storage;

    setUp(() async {
      storage = LocalStorageService(database: db);
      // Inicializar con datos semilla en memoria
      final migrationService = DataMigrationService(db);
      await migrationService.seedDefaultData();
      await storage.init();
    });

    test('Carga inicial expone entidades de negocio esperadas', () {
      expect(storage.socios.length, 2);
      expect(storage.clientes.length, 2);
      expect(storage.obras.length, 1);
      expect(storage.mantenimientos.length, 2);
      expect(storage.gastos.length, 2);

      expect(storage.obras.first.presupuesto, 45000.0);
      expect(
        storage.gastos.map((g) => g.montoTotal),
        containsAll([850.0, 3400.0]),
      );
    });

    test('Agregar, editar y eliminar socio persiste en Drift', () async {
      const nuevoSocio = Socio(
        id: 's3',
        nombre: 'Carlos Maestro',
        telefono: '999888777',
        colorValue: 0xFF3B82F6,
      );

      await storage.agregarSocio(nuevoSocio);
      expect(storage.socios.length, 3);
      expect(storage.socios.any((s) => s.id == 's3'), isTrue);

      // Editar
      final editado = nuevoSocio.copyWith(nombre: 'Carlos Maestro Albañil');
      await storage.editarSocio(editado);
      expect(
        storage.socios.firstWhere((s) => s.id == 's3').nombre,
        'Carlos Maestro Albañil',
      );

      // Eliminar (soft delete)
      await storage.eliminarSocio('s3');
      expect(storage.socios.length, 2);
      expect(storage.socios.any((s) => s.id == 's3'), isFalse);
    });

    test('Agregar y editar gasto con céntimos preserva precisión', () async {
      final nuevoGasto = Gasto(
        id: 'g_test_1',
        concepto: 'Compra de 10 brocas para concreto',
        categoria: CategoriaGasto.herramientas,
        montoTotal: 125.40,
        fecha: DateTime.now(),
        pagadoPorSocioId: 's1',
        participaciones: {'s1': 1.0, 's2': 1.0},
        nota: 'Ferretería central',
      );

      await storage.agregarGasto(nuevoGasto);
      expect(storage.gastos.any((g) => g.id == 'g_test_1'), isTrue);
      final guardado = storage.gastos.firstWhere((g) => g.id == 'g_test_1');
      expect(guardado.montoTotal, 125.40);

      // Verificar en la tabla SQLite que se guardó en céntimos enteros
      final rows = await (db.select(
        db.expenses,
      )..where((t) => t.id.equals('g_test_1'))).get();
      expect(rows.first.amountCents, 12540);
    });

    test('Completar mantenimiento actualiza la fecha en Drift', () async {
      final m1 = storage.mantenimientos.firstWhere((m) => m.id == 'm1');
      final fechaInicial = m1.fechaProximo;

      await storage.completarMantenimiento('m1');
      final m1Actualizado = storage.mantenimientos.firstWhere(
        (m) => m.id == 'm1',
      );

      expect(m1Actualizado.fechaProximo.isAfter(fechaInicial), isTrue);
      expect(m1Actualizado.fechaUltimo, isNotNull);
    });

    test(
      'Exportar e importar respaldo JSON recrea los datos en SQLite',
      () async {
        final jsonExportado = storage.serializeToJson();
        expect(jsonExportado, contains('"socios"'));
        expect(jsonExportado, contains('"obras"'));

        final exitoImport = await storage.importarRespaldoJson(jsonExportado);
        expect(exitoImport, isTrue);
        expect(storage.socios.length, 2);
        expect(storage.obras.length, 1);
      },
    );
  });
}
