import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart';
import 'package:mantenimiento_app/core/database/data_migration_service.dart';
import 'package:mantenimiento_app/core/database/local_storage_service.dart';
import 'package:mantenimiento_app/core/models/cliente.dart';
import 'package:mantenimiento_app/core/models/gasto.dart';
import 'package:mantenimiento_app/core/models/mantenimiento.dart';
import 'package:mantenimiento_app/core/models/obra.dart';
import 'package:mantenimiento_app/core/models/socio.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // Base de datos SQLite en memoria para tests aislados con foreign keys habilitadas
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
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
      'Migración normal importa todos los registros y marca señal explícita de éxito',
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

        // Verificar señal explícita de migración completada en AppMetadata
        final statusRecord = await (db.select(
          db.appMetadata,
        )..where((t) => t.key.equals('v1_migration_status'))).getSingleOrNull();
        expect(statusRecord, isNotNull);
        expect(statusRecord!.value, 'completed');

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

    test(
      'Migración repetida es estrictamente idempotente mediante AppMetadata',
      () async {
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
      },
    );

    test(
      'JSON vacío genera datos semilla por defecto con señal de completado',
      () async {
        final migrationService = DataMigrationService(db);
        final result = await migrationService.migrateIfNeeded(
          overrideJsonStr: '',
        );

        expect(result.success, isTrue);
        final partners = await db.select(db.partners).get();
        expect(partners.length, 2);
        expect(partners.map((p) => p.id), containsAll(['s1', 's2']));

        final statusRecord = await (db.select(
          db.appMetadata,
        )..where((t) => t.key.equals('v1_migration_status'))).getSingleOrNull();
        expect(statusRecord?.value, 'completed');
      },
    );

    test(
      'JSON corrupto retorna error seguro sin dejar la base de datos en estado completado',
      () async {
        final migrationService = DataMigrationService(db);
        final result = await migrationService.executeMigrationFromJson(
          '{ invalid json syntax ',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('JSON corrupto'));

        // Verificar que NO se marcó como completado
        final statusRecord = await (db.select(
          db.appMetadata,
        )..where((t) => t.key.equals('v1_migration_status'))).getSingleOrNull();
        expect(statusRecord, isNull);
      },
    );
  });

  group('Pruebas de Precisión Monetaria (Céntimos Exactos)', () {
    test(
      'Preserva montos críticos S/ 0.01, S/ 0.10, S/ 10.99, S/ 999999.99 sin pérdida de decimales',
      () {
        final montosTest = [0.01, 0.10, 10.99, 999999.99, 1250.45, 0.00];

        for (final montoOriginal in montosTest) {
          final cents = (montoOriginal * 100).round();
          final montoReconstruido = cents / 100.0;

          expect(montoReconstruido, closeTo(montoOriginal, 0.00001));
        }
      },
    );
  });

  group('Pruebas de Fechas y Límites de Calendario', () {
    test(
      'Calcula correctamente cambio de mes y de año sin desfasar el día de negocio',
      () {
        final planMensual = Mantenimiento(
          id: 'm_fecha_1',
          clienteId: 'c1',
          clienteNombre: 'Cliente Fecha',
          titulo: 'Revisión Fin de Año',
          tipoFrecuencia: TipoFrecuencia.unMes,
          diasPersonalizados: 30,
          fechaProximo: DateTime(2026, 12, 15, 9, 0),
        );

        // Siguiente ciclo en enero del año siguiente
        final proximoCiclo = planMensual.calcularProximoCiclo(
          DateTime(2026, 12, 15, 9, 0),
        );
        expect(proximoCiclo.year, 2027);
        expect(proximoCiclo.month, 1);
        expect(proximoCiclo.day, 14); // 30 días después
      },
    );
  });

  group('Pruebas de Foreign Keys y Restricciones en SQLite', () {
    test(
      'Rechaza inserción en clientLocations si no existe el cliente referenciado',
      () async {
        await db.customStatement('PRAGMA foreign_keys = ON;');
        expect(
          db
              .into(db.clientLocations)
              .insert(
                ClientLocationsCompanion.insert(
                  id: 'loc_invalida',
                  clientId: 'cliente_no_existente_999',
                  address: 'Calle Falsa 123',
                ),
              ),
          throwsException,
        );
      },
    );
  });

  group('Pruebas de CRUD V1 con LocalStorageService sobre Drift SQLite', () {
    late LocalStorageService storage;

    setUp(() async {
      storage = LocalStorageService(database: db);
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
      'Flujo completo SQLite -> Exportar JSON -> Importar JSON -> SQLite preserva todas las entidades',
      () async {
        // 1. Agregar datos personalizados
        await storage.agregarCliente(
          const Cliente(
            id: 'c_export_test',
            nombre: 'Edificio Las Torres',
            telefono: '987654321',
            direccion: 'Av. Las Torres 500',
            notas: 'Condominio 20 pisos',
          ),
        );

        await storage.agregarObra(
          Obra(
            id: 'o_export_test',
            nombre: 'Instalación Césped Sintético',
            clienteId: 'c_export_test',
            presupuesto: 18500.75,
            fechaInicio: DateTime(2026, 10, 1),
            estado: EstadoObra.enProgreso,
            sociosAsignados: ['s1'],
          ),
        );

        // 2. Exportar a JSON
        final jsonExportado = storage.serializeToJson();
        expect(jsonExportado, contains('c_export_test'));
        expect(jsonExportado, contains('Edificio Las Torres'));
        expect(jsonExportado, contains('o_export_test'));
        expect(jsonExportado, contains('18500.75'));

        // 3. Importar a base de datos
        final exitoImport = await storage.importarRespaldoJson(jsonExportado);
        expect(exitoImport, isTrue);

        // 4. Verificar preservación de todas las entidades en SQLite
        expect(storage.clientes.any((c) => c.id == 'c_export_test'), isTrue);
        expect(storage.obras.any((o) => o.id == 'o_export_test'), isTrue);
        final obraImportada = storage.obras.firstWhere(
          (o) => o.id == 'o_export_test',
        );
        expect(obraImportada.presupuesto, 18500.75);
        expect(obraImportada.nombre, 'Instalación Césped Sintético');
      },
    );
  });
}
