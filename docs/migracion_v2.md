# 🚀 Plan Maestro de Migración y Roadmap (V2 / V2.5 / V3)
## Decolumax / Field Operations & CMMS Core

---

## 1. Checkpoint Obligatorio de Seguridad y No Regresión

Para evitar riesgos de estabilidad o introducir bugs en la aplicación funcional existente, el proceso de desarrollo se divide en dos grandes etapas:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       CHECKPOINT OBLIGATORIO DE MIGRACIÓN                   │
│                                                                             │
│   [ ESTADO ACTUAL V1 ]                                                      │
│     • Almacenamiento JSON (`mantenimiento_data.json` + `SharedPreferences`) │
│     • Vistas actuales de Mantenimientos, Obras, Gastos, Socios, Ajustes.    │
│                            │                                                │
│                            ▼                                                │
│   [ FASE 1: DRIFT DROP-IN & MIGRACIÓN TRANSPARENTE ]                        │
│     • Configurar SQLite y Drift con el nuevo esquema.                       │
│     • Ejecutar migración atómica de datos JSON existentes.                  │
│     • Adaptar repositorios para que la UI ACTUAL corra 100% sobre Drift.    │
│     • Validar con `flutter analyze` y `flutter test`.                       │
│     • 🛑 CHECKPOINT OBLIGATORIO: Crear Tag Git `v1-drift-migrated`.         │
│                            │                                                │
│                            ▼                                                │
│   [ FASE 2: INCORPORACIÓN INCREMENTAL DE NUEVOS MÓDULOS V2 ]                │
│     • Desacoplar MaintenancePlan vs Visits (Historial completo).            │
│     • Módulo de Trabajadores y Jornadas (WorkLogs).                         │
│     • Módulo de Inventario con Ledger (StockMovements).                     │
│     • Módulo de Custodia de Herramientas (Tools).                           │
│     • Costeo de Obra en Vivo y BalanceCalculator V2.                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Estrategia de Migración de Datos: JSON → Drift (SQLite)

### Reglas de Transformación Atómica
1. **Detección Automática**: Al iniciar la aplicación, `DataMigrationService` comprueba si existe `mantenimiento_data.json` y si la base de datos SQLite está vacía.
2. **Respaldo Inmutable**: Se copia `mantenimiento_data.json` como `mantenimiento_data.v1_backup.json`.
3. **Transacción ACID**:
   - Se insertan los socios en `partners` (mismos IDs `s1`, `s2`).
   - Se insertan los clientes en `clients` y su dirección en `client_locations`.
   - Se insertan las obras en `projects`.
   - Se insertan los mantenimientos en `maintenance_plans` y se crea la visita pendiente en `maintenance_visits`.
   - Se insertan los gastos en `expenses`.
4. **Verificación**: Si el conteo de registros coincide, se marca el flag `v1_migration_done=true`. Si algo falla, se ejecuta `ROLLBACK` y la app continúa leyendo el JSON original sin alteración.

---

## 3. Roadmap de Tareas Estándar

### FASE 1: Migración Base de Persistencia (P0)

#### `T-01` • Implementación de Base de Datos Drift & DAOs Tipados
- **Módulo**: `core/database`
- **Descripción**: Configurar `drift`, `drift_flutter`, `sqlite3_flutter_libs` y `path`. Definir las tablas relacionales y DAOs en Dart.
- **Dependencias**: Ninguna.
- **Prioridad**: **P0** (Imprescindible).
- **Complejidad**: **L** (Large).
- **Riesgo**: Bajo.
- **Archivos Probables**:
  - `lib/core/database/app_database.dart`
  - `lib/core/database/tables/`
  - `lib/core/database/daos/`
- **Criterio de Aceptación**: Compilación limpia con `build_runner` y paso de pruebas unitarias de inserción en memoria.

#### `T-02` • Migrador JSON → Drift y Repositorio de Compatibilidad V1
- **Módulo**: `core/database/migration`
- **Descripción**: Crear `DataMigrationService` que ejecute la carga de `mantenimiento_data.json` a Drift y adaptar `LocalStorageService` / Repositorios para que la UI actual funcione 100% sobre SQLite sin cambios visuales.
- **Dependencias**: `T-01`.
- **Prioridad**: **P0**.
- **Complejidad**: **M** (Medium).
- **Riesgo**: Medio.
- **Archivos Probables**:
  - `lib/core/database/data_migration_service.dart`
  - `lib/core/database/local_storage_service.dart`
  - `test/data_migration_test.dart`
- **Criterio de Aceptación**: La app actual arranca, lee y guarda datos en SQLite. `flutter test` pasa al 100%. Se crea el tag Git `v1-drift-migrated`.

---

### FASE 2: Nuevas Funcionalidades V2 (P0 / P1)

#### `T-03` • Desacoplamiento de Mantenimiento (Plan vs Visitas Históricas)
- **Módulo**: `features/mantenimientos`
- **Descripción**: Historial completo de visitas ejecutadas (`MaintenanceVisit`) y cálculo automático del siguiente ciclo sin mutar registros pasados.
- **Dependencias**: `T-02` (Checkpoint).
- **Prioridad**: **P0**.
- **Complejidad**: **M**.
- **Riesgo**: Bajo.
- **Criterio de Aceptación**: Completar un servicio genera la visita 4 conservando las visitas 1, 2 y 3 con sus notas y fotos.

#### `T-04` • Módulo de Trabajadores, Jornadas (WorkLogs) y Pagos
- **Módulo**: `features/workers`
- **Descripción**: Catálogo de peones/jardineros sin login, registro rápido de jornadas (`WorkLog`) y pagos de jornales (`LaborPayment`).
- **Dependencias**: `T-02`.
- **Prioridad**: **P0**.
- **Complejidad**: **M**.
- **Riesgo**: Bajo.
- **Criterio de Aceptación**: Registrar jornada de S/ 70 y pago parcial de S/ 50 mostrando saldo pendiente de S/ 20.

#### `T-05` • Módulo de Inventario Continuo con Ledger (StockMovements)
- **Módulo**: `features/inventory`
- **Descripción**: Insumos y plantas con ledger de movimientos (`purchase`, `consumption`, `waste_loss`).
- **Dependencias**: `T-02`.
- **Prioridad**: **P1**.
- **Complejidad**: **L**.
- **Riesgo**: Medio.
- **Criterio de Aceptación**: Stock derivado de movimientos sin campos editables directos.

#### `T-06` • Módulo de Custodia de Herramientas (Tools & ToolAssignments)
- **Módulo**: `features/tools`
- **Descripción**: Control de herramientas de alto valor con check-out a trabajador/obra y check-in a bodega.
- **Dependencias**: `T-02`.
- **Prioridad**: **P1**.
- **Complejidad**: **M**.
- **Riesgo**: Bajo.
- **Criterio de Aceptación**: Conocer en tiempo real quién tiene cada equipo y en qué obra.

#### `T-07` • Costeo Automático de Obras y BalanceCalculator V2
- **Módulo**: `features/obras` & `features/gastos`
- **Descripción**: Costeo derivado en tiempo real (Materiales + Mano de Obra + Gastos Directos) y resolución de balances entre socios con aportes y cobros.
- **Dependencias**: `T-04`, `T-05`.
- **Prioridad**: **P0**.
- **Complejidad**: **M**.
- **Riesgo**: Bajo.
- **Criterio de Aceptación**: Margen neto de obra y matriz de liquidación entre socios exacta.

---

### FASE 3: Multiplataforma y Preparación Sync V3 (P1 / P2)

#### `T-08` • Layout Adaptativo Web / Desktop (Master-Detail)
- **Módulo**: `features/home` / `core/theme`
- **Descripción**: Renderizado responsive para pantallas de escritorio con Sidebar y tablas de alta densidad.
- **Dependencias**: `T-03` a `T-07`.
- **Prioridad**: **P1**.
- **Complejidad**: **L**.
- **Riesgo**: Bajo.

#### `T-09` • Preparación Sync Gateway (PocketBase / Supabase / Custom API)
- **Módulo**: `core/sync`
- **Descripción**: Motor Outbox que procese la tabla `sync_queue` cuando se defina el backend definitivo en V3.
- **Dependencias**: `T-02`.
- **Prioridad**: **P2**.
- **Complejidad**: **XL**.
- **Riesgo**: Alto.
