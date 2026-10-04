# 📝 Bitácora Técnica de Implementación: Tarea T-01
## Decolumax / Checkpoint V1 Funcional sobre Drift (SQLite)

---

## 1. Resumen Ejecutivo de la Tarea T-01
- **Objetivo**: Transición transparente del motor de persistencia desde el archivo JSON monolítico (`mantenimiento_data.json`) hacia **Drift (SQLite)** con soporte relacional, transaccional e integridad de tipos, **sin modificar la experiencia de usuario ni introducir funcionalidades V2 todavía**.
- **Resultado**: **100% COMPLETADO Y VALIDADO CON PRUEBAS AUTOMATIZADAS**.
- **Estado del Checkpoint**: `T-01 CLOSED` (Listo para tag `v1-drift-migrated`).

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
| [`lib/core/database/tables/tables.dart`](file:///e:/mantenimiento/lib/core/database/tables/tables.dart) | **Creado** | Definición de las 21 tablas relacionales del modelo aprobado con claves primarias UUID, foreign keys estrictas (`customConstraint`), tabla `app_metadata` e importes en céntimos enteros. |
| [`lib/core/database/app_database.dart`](file:///e:/mantenimiento/lib/core/database/app_database.dart) | **Creado** | Clase `AppDatabase` que configura la conexión nativa con `drift_flutter`, ejecución de `PRAGMA foreign_keys = ON;` y constructor de pruebas en memoria. |
| [`lib/core/database/app_database.g.dart`](file:///e:/mantenimiento/lib/core/database/app_database.g.dart) | **Generado** | Código tipado generado por `drift_dev` para consultas reactivas y DAOs. |
| [`lib/core/database/data_migration_service.dart`](file:///e:/mantenimiento/lib/core/database/data_migration_service.dart) | **Creado** | Servicio de migración atómica e idempotente desde JSON V1 a SQLite con respaldo previo `mantenimiento_data.v1_backup.json`, control de errores y señal explícita en `app_metadata`. |
| [`lib/core/database/local_storage_service.dart`](file:///e:/mantenimiento/lib/core/database/local_storage_service.dart) | **Refactorizado** | Implementación de `LocalStorageService` como fachada sobre Drift SQLite manteniendo su API pública 100% compatible para las pantallas existentes. |
| [`lib/core/notifications/notification_service.dart`](file:///e:/mantenimiento/lib/core/notifications/notification_service.dart) | Modificado | Protección con bandera `_isInitialized` para evitar excepciones en entornos de prueba unitaria sin canal de plataforma nativo. |
| [`lib/features/gastos/gasto_form_dialog.dart`](file:///e:/mantenimiento/lib/features/gastos/gasto_form_dialog.dart) | Modificado | Corrección de formato de llaves en bloques de control de flujo. |
| [`lib/features/obras/obra_form_dialog.dart`](file:///e:/mantenimiento/lib/features/obras/obra_form_dialog.dart) | Modificado | Corrección de formato de llaves en bloques de control de flujo. |
| [`test/drift_migration_test.dart`](file:///e:/mantenimiento/test/drift_migration_test.dart) | **Creado** | Suite completa de pruebas unitarias e integración de Drift, migración, señal explícita de idempotencia, dinero exacto, fechas, foreign keys, import/export y CRUD. |

---

## 4. Verificaciones Realizadas

### A. Migración Idempotente y Robusta
- **Detección Confiable**: En lugar de consultar si una tabla particular contiene filas, la finalización de la migración se registra dentro de la misma transacción atómica en la tabla `app_metadata` (`key='v1_migration_status'`, `value='completed'`).
- Si una migración se interrumpe a la mitad, SQLite revierte la transacción íntegramente (rollback) y la señal en `app_metadata` no se graba, obligando al sistema a reintentar limpiamente sin dejar estados corruptos.
- El archivo JSON original nunca se elimina ni se sobreescribe destructivamente, y se genera un respaldo fehaciente `mantenimiento_data.v1_backup.json`.

### B. Integridad de las 21 Tablas y Foreign Keys
- Las 21 tablas relacionales aprobadas están definidas en SQLite con foreign keys estrictas mediante `customConstraint('NOT NULL REFERENCES ...')` y `PRAGMA foreign_keys = ON;`.
- No obligan a crear entidades V2 para operar los flujos V1 (los campos V2 son opcionales o tienen valores predeterminados seguros).
- Inserciones con claves foráneas inexistentes son rechazadas automáticamente por el motor SQLite.

### C. Precisión Monetaria
- Todos los importes monetarios se convierten a enteros en céntimos:
  $$\text{Centimos} = (\text{monto} \times 100).\text{round}()$$
  $$\text{Monto} = \text{cents} / 100.0$$
- Validado con montos críticos: `S/ 0.01`, `S/ 0.10`, `S/ 10.99`, `S/ 999999.99`, garantizando exactitud sin pérdida de decimales.

### D. Preservación de Fechas
- Fechas de negocio (`fechaProximo`, `fechaUltimo`, `fechaInicio`, `fechaGasto`) preservan el día exacto de negocio a través de `toIso8601String()` y parseo local sin desfases por zona horaria.

### E. Flujo Exportación / Importación
- Verificado el ciclo completo SQLite → Exportar JSON → Importar JSON → SQLite, comprobando que IDs, relaciones, montos, fechas, notas y estados permanecen idénticos.

---

## 5. Resultados de Verificación de Calidad

- **`dart format .`**: 25 archivos analizados (**0 issues de formato**).
- **`flutter analyze`**: **No issues found!** (0 advertencias, 0 errores).
- **`flutter test`**: **15/15 pruebas pasadas al 100%**:
  - `balance_calculator_test.dart` (3 tests: cálculo de ciclos de mantenimiento, reparto 50/50, reparto porcentual).
  - `drift_migration_test.dart` (12 tests: migración normal, señal explícita de completado, idempotencia, datos semilla, JSON corrupto, precisión de céntimos, cambio de mes/año, foreign keys, carga inicial, CRUD socios, CRUD gastos, completar mantenimiento, flujo exportación/importación).

---

## 6. Estado de Deuda Técnica y Limitaciones

- **Deuda Técnica**: Sin deuda técnica bloqueante identificada en T-01.
- **Limitaciones Registradas**:
  1. *Alcance de UI en T-01*: Las 21 tablas relacionales y sus foreign keys ya residen en SQLite, pero la UI actual de V1 opera a través de la fachada `LocalStorageService` que mapea las entidades activas de V1 (Socios, Clientes, Obras, Mantenimientos, Gastos).
  2. *Entidades V2*: Las tablas de trabajadores (`workers`), partes de trabajo (`work_logs`), herramientas (`tools`), inventario (`inventory_items`) y compras (`purchases`) no son pobladas ni mostradas en la interfaz actual, a la espera de sus tareas dedicadas (iniciando con T-02).
- **Siguiente Paso Recomendado**: Crear el Tag Git `v1-drift-migrated` y proceder a la definición del alcance de **`T-02: Workers + WorkLogs`**.
e Mantenimientos (Planes vs. Visitas Históricas)`**.
