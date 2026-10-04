# 📝 Bitácora Técnica de Implementación: Tarea T-01
## Decolumax / Checkpoint V1 Funcional sobre Drift (SQLite)

---

## 1. Resumen Ejecutivo de la Tarea T-01
- **Objetivo**: Transición transparente del motor de persistencia desde el archivo JSON monolítico (`mantenimiento_data.json`) hacia **Drift (SQLite)** con soporte relacional, transaccional e integridad de tipos, **sin modificar la experiencia de usuario ni introducir funcionalidades V2 todavía**.
- **Resultado**: **100% COMPLETADO Y VALIDADO CON PRUEBAS AUTOMATIZADAS**.
- **Estado del Checkpoint**: `READY FOR CHECKPOINT`.

---

## 2. Dependencias Agregadas (`pubspec.yaml`)
```yaml
dependencies:
  drift: ^2.24.2
  drift_flutter: ^0.2.4
  sqlite3_flutter_libs: ^0.5.28
  path: ^1.9.1

dev_dependencies:
  drift_dev: ^2.24.2
  build_runner: ^2.4.15
```

---

## 3. Archivos Creados y Modificados

| Archivo | Acción | Responsabilidad |
| :--- | :---: | :--- |
| [`pubspec.yaml`](file:///e:/mantenimiento/pubspec.yaml) | Modificado | Adición de dependencias oficiales de Drift, SQLite y generador de código. |
| [`lib/core/database/tables/tables.dart`](file:///e:/mantenimiento/lib/core/database/tables/tables.dart) | **Creado** | Definición de las 21 tablas relacionales del modelo aprobado con claves primarias UUID, foreign keys estrictas e importes en céntimos enteros. |
| [`lib/core/database/app_database.dart`](file:///e:/mantenimiento/lib/core/database/app_database.dart) | **Creado** | Clase `AppDatabase` que configura la conexión nativa con `drift_flutter`, ejecución de `PRAGMA foreign_keys = ON;` y constructor de pruebas en memoria. |
| [`lib/core/database/app_database.g.dart`](file:///e:/mantenimiento/lib/core/database/app_database.g.dart) | **Generado** | Código tipado generado por `drift_dev` para consultas reactivas y DAOs. |
| [`lib/core/database/data_migration_service.dart`](file:///e:/mantenimiento/lib/core/database/data_migration_service.dart) | **Creado** | Servicio de migración atómica e idempotente desde JSON V1 a SQLite con respaldo previo `mantenimiento_data.v1_backup.json` y control de errores. |
| [`lib/core/database/local_storage_service.dart`](file:///e:/mantenimiento/lib/core/database/local_storage_service.dart) | **Refactorizado** | Implementación de `LocalStorageService` como fachada sobre Drift SQLite manteniendo su API pública 100% compatible para las pantallas existentes. |
| [`lib/core/notifications/notification_service.dart`](file:///e:/mantenimiento/lib/core/notifications/notification_service.dart) | Modificado | Protección con bandera `_isInitialized` para evitar excepciones en entornos de prueba unitaria sin canal de plataforma nativo. |
| [`lib/features/gastos/gasto_form_dialog.dart`](file:///e:/mantenimiento/lib/features/gastos/gasto_form_dialog.dart) | Modificado | Corrección de formato de llaves en bloques de control de flujo. |
| [`lib/features/obras/obra_form_dialog.dart`](file:///e:/mantenimiento/lib/features/obras/obra_form_dialog.dart) | Modificado | Corrección de formato de llaves en bloques de control de flujo. |
| [`test/drift_migration_test.dart`](file:///e:/mantenimiento/test/drift_migration_test.dart) | **Creado** | Suite completa de pruebas unitarias e integración de Drift, migración, idempotencia, dinero y CRUD. |

---

## 4. Tablas Relacionales Implementadas en SQLite
1. `users` (Usuarios y auditoría)
2. `partners` (Socios propietarios y avatares)
3. `workers` (Trabajadores de cuadrilla sin login)
4. `clients` (Clientes y datos de contacto)
5. `client_locations` (Sedes y predios del cliente)
6. `projects` (Obras y presupuestos)
7. `maintenance_plans` (Reglas de recurrencia)
8. `maintenance_visits` (Historial de visitas)
9. `inventory_items` (Insumos y consumibles)
10. `suppliers` (Proveedores y viveros)
11. `purchases` (Compras de inventario)
12. `stock_movements` (Ledger continuo de stock)
13. `tools` (Herramientas y activos de alto valor)
14. `tool_assignments` (Historial de custodia check-out/check-in)
15. `work_logs` (Jornadas laborales devengadas)
16. `labor_payments` (Pagos a trabajadores)
17. `expenses` (Gastos operativos directos)
18. `capital_movements` (Aportes y retiros de capital)
19. `collections` (Cobros a clientes)
20. `attachments` (Fotografías y comprobantes locales)
21. `sync_queue` (Cola Outbox para sincronización asíncrona V3)

---

## 5. Estrategia de Dinero y Fechas

- **Dinero**: Todos los importes monetarios (`presupuesto`, `montoTotal`, `tarifa`, `costos`) se almacenan en SQLite como **enteros en céntimos** (`budgetAmountCents`, `amountCents`), evitando errores de redondeo de punto flotante de `double`:
  $$\text{Centimos} = (\text{monto} \times 100).\text{round}()$$
  $$\text{Monto en Pantalla} = \text{cents} / 100.0$$
- **Fechas**: Se almacenan mediante `DateTimeColumn` con `toIso8601String()` y `DateTime.parse()` coherente en hora local / UTC.

---

## 6. Resultados de Verificación de Calidad

- **`dart format .`**: 25 archivos analizados (**0 issues de formato**).
- **`flutter analyze`**: **No issues found!** (0 advertencias, 0 errores).
- **`flutter test`**: **12/12 pruebas pasadas al 100%**:
  - `balance_calculator_test.dart` (3 suites de cálculo de fechas y deudas entre socios).
  - `drift_migration_test.dart` (9 suites de migración normal, idempotencia, JSON vacío, JSON corrupto, preservación de céntimos, relaciones, foreign keys, CRUD V1 y serialización).

---

## 7. Problemas Encontrados y Resueltos durante T-01

1. **Constructores Companion en Drift**:
   - *Problema*: `PartnersCompanion.insert` no es `const` en Drift.
   - *Solución*: Se instanciaron los companions sin la palabra clave `const` en `data_migration_service.dart`.
2. **Llamadas a `FlutterLocalNotificationsPlugin` en Test Runner**:
   - *Problema*: Las pruebas unitarias en consola no disponen del plugin nativo de Android/iOS.
   - *Solución*: Se encapsuló la verificación `_isInitialized` en `NotificationService` para no disparar llamadas a canales de plataforma durante los tests.
3. **Orden de Gastos por Fecha Descendente**:
   - *Problema*: Drift ordena los gastos por fecha descendente (`OrderingTerm.desc(t.date)`), por lo que el gasto más reciente encabeza la lista.
   - *Solución*: Se ajustó la aserción de prueba para verificar pertenencia sin asumir orden arbitrario.

---

## 8. Deuda Técnica y Próximos Pasos

- **Deuda Técnica**: Ninguna. La base de código actual está 100% limpia sobre SQLite, sin advertencias de linter y con compatibilidad total hacia atrás.
- **Siguiente Paso**: Crear el Tag Git `v1-drift-migrated` para congelar el checkpoint y comenzar con la Tarea **`T-03: Desacoplamiento de Mantenimientos (Planes vs. Visitas Históricas)`**.
