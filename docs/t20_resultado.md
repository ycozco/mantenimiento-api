# Informe de Cierre T-20: Transición V2 Local → V3 Connected

**Proyecto:** Decolumax / Field Operations & CMMS Core  
**Fecha:** 2026-10-05  
**Rama:** `feature/v3-foundation`  
**Estado:** COMPLETADO CON ÉXITO  

---

## 1. Estado Inicial de Partida

- **Commit Base:** `ba2695e1d5184923aa8840a7d7ccac0dde99b320`
- **Tag de Seguridad Verificado:** `v2-local-ready` (anotado en `HEAD` de master)
- **Working Tree Inicial:** Limpio, 0 issues en `flutter analyze`, 197 tests pasando, Drift `schemaVersion: 3`.

---

## 2. Correcciones P1 Implementadas

### 2.1 Identificadores Estables de Notificaciones (FNV-1a 32-bit)
- **Problema en V2:** `NotificationScheduleEngine` utilizaba `visitId.hashCode`, dependiente de la implementación interna de Dart VM, no determinista entre compilaciones ni reinicios de proceso.
- **Solución V3:** Se implementó el algoritmo estándar **FNV-1a de 32 bits** con offset `0x811C9DC5` y prime `0x01000193`, proyectado a un entero positivo de 31 bits (`& 0x7FFFFFFF`) plenamente compatible con el `id` (int32) de Android `NotificationManager`.
- **Fórmula:** `fnv1a32("$visitId:$daysBefore") & 0x7FFFFFFF`.
- **Vectores de Prueba Congelados:**
  - `fnv1a32("test-visit-123:7")` = `1236087532`
  - `fnv1a32("fixed-test-visit-id:7")` = `1056253811`
  - Se verificó que mismo UUID + mismo offset genera idéntico valor; offsets diferentes generan IDs diferenciables; y valores congelados no varían.
- **Estrategia de Transición:** V2 fue una versión interna local en pre-lanzamiento. Al actualizar a V3, las notificaciones huérfanas pendientes pueden purgarse mediante `flutter_local_notifications.cancelAll()` y ser reprogramadas limpiamente con el nuevo motor determinista.

### 2.2 Invariante de Contexto Único en Cobranzas (`Collections`)
- **Problema en V2:** Auditoría detectó que una cobranza podía asociarse accidentalmente a más de una entidad operacional o quedar huérfana de contexto.
- **Solución V3:** Se estableció la regla de negocio estricta: **Exactamente uno** de los siguientes contextos debe existir: `project_id`, `visit_id` o `plan_id`.
- **Capa DB:** Se aplicó constraint `CHECK` en SQLite:
  ```sql
  CHECK (((project_id IS NOT NULL) + (visit_id IS NOT NULL) + (plan_id IS NOT NULL)) = 1)
  ```
- **Capa Modelo/Repositorio:** `Collection.validateContext()` y `CollectionRepository.createCollection()` validan la regla antes de emitir la sentencia SQL, manteniendo la base de datos como última línea de defensa infalible.

---

## 3. Regularización Multi-Workspace & Schema 4

### 3.1 Normalización de `workspace_id`
Las 4 tablas baseline heredadas de V1 que carecían de aislamiento multi-tenant fueron regularizadas con:
```sql
workspace_id TEXT NOT NULL DEFAULT 'default'
```
- Tablas actualizadas: `partners`, `clients`, `client_locations`, `projects`.
- Se generaron índices compuestos optimizados:
  - `partners_workspace_idx` ON `partners (workspace_id)`
  - `clients_workspace_idx` ON `clients (workspace_id)`
  - `client_locations_client_workspace_idx` ON `client_locations (client_id, workspace_id)`
  - `projects_workspace_idx` ON `projects (workspace_id)`

### 3.2 Migración Drift Schema 3 → Schema 4
- **`schemaVersion` final:** `4`.
- **Estrategia de migración:**
  1. Activación de `PRAGMA foreign_keys = OFF`.
  2. Adición de columna `workspace_id TEXT NOT NULL DEFAULT 'default'` mediante `addColumn` en `partners`, `clients`, `client_locations` y `projects`.
  3. Recreación atómica de la tabla `collections` para introducir el `CHECK` constraint:
     - Creación de `collections_temp` con el nuevo schema y `CHECK`.
     - Inserción de todos los registros preexistentes: `INSERT INTO collections_temp SELECT ... FROM collections`.
     - Eliminación de la tabla original: `DROP TABLE collections`.
     - Renombrado: `ALTER TABLE collections_temp RENAME TO collections`.
     - Recreación de índices `collections_workspace_idx`, `collections_client_idx`, `collections_project_idx`, etc.
  4. Reactivación de `PRAGMA foreign_keys = ON`.
- **Test de Migración Real:** Se escribió una suite dedicada ([`schema_v3_to_v4_migration_test.dart`](file:///e:/mantenimiento/apps/client/test/schema_v3_to_v4_migration_test.dart)) que crea una base de datos en Schema 3 cruda, inserta socios, clientes, proyectos y cobranzas válidas, ejecuta el upgrade a Schema 4 y valida la integridad de cada registro y la activación del nuevo `CHECK` constraint.

### 3.3 Compatibilidad de Respaldos (Backup Schema 4)
- `currentSchemaVersion` actualizado a `4` en `BackupRestoreService`.
- Formato empresarial preservado en `backupFormatVersion: 2`.
- Verificada compatibilidad de exportación e importación completa en limpio en Schema 4 sin tocar `sync_queue` ni `DevicePreferences`.

---

## 4. Reorganización a Monorepo

### 4.1 Estructura Anterior (Monolito Flutter en Raíz)
```text
mantenimiento/
├── android/
├── ios/
├── web/
├── windows/
├── macos/
├── linux/
├── lib/
├── test/
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
├── mantenimiento.md
└── docs/
```

### 4.2 Nueva Estructura Monorepo V3
```text
mantenimiento/
├── apps/
│   ├── client/                  # Flutter Client (Android, Web, Desktop)
│   └── (api/)                   # Reservado para backend NestJS/Node en T-22
├── packages/
│   └── sync-contract/           # Especificación y tipos compartidos de sync
├── infrastructure/
│   ├── docker/                  # Configuración contenedores
│   ├── nginx/                   # Reverse proxy y TLS
│   ├── postgres/                # Esquemas centrales PostgreSQL
│   ├── backup/                  # Backups del servidor
│   └── scripts/                 # Scripts operativos
├── docs/                        # Documentación técnica centralizada
├── .gitignore                   # Actualizado para monorepo
└── README.md                    # Guía raíz
```

### 4.3 Archivos y Carpetas Movidas
- Todo el cliente Flutter fue trasladado mediante `git mv` a `apps/client/`.
- `mantenimiento.md` fue consolidado en `docs/mantenimiento.md`.
- `docs/` y `.git/` se mantienen en la raíz del repositorio.

---

## 5. Pruebas y Validaciones Ejecutadas

Ejecutadas íntegramente desde `apps/client/`:
- `dart format --output=none --set-exit-if-changed .`: 116 archivos formateados, 0 modificados (100% limpio).
- `flutter analyze`: **0 issues found!**
- `flutter test`: **200 tests passing** (incluyendo suites E2E, migraciones 1→2→3→4, balance calculator, finanzas, inventario, herramientas, notificaciones FNV-1a y cobranzas).
- `flutter build web`: **OK** (`√ Built build\web` en 37.7s).
- `flutter build apk --debug`: **OK** (`√ Built build\app\outputs\flutter-apk\app-debug.apk` en 56.1s).

---

## 6. Historial de Commits T-20

1. `f813c00`: `fix(v3): harden local model for synchronization`
   - Stable FNV-1a notification IDs.
   - Collections single-context invariant + SQLite CHECK.
   - `workspace_id` en `partners`, `clients`, `client_locations`, `projects`.
   - Drift `schemaVersion: 4` con migración 3→4 y tests dedicados.
   - Backup format schema 4.
2. Siguiente commit: `chore(repo): reorganize Decolumax as V3 monorepo`

---

## 7. Problemas Encontrados y Soluciones

1. **`TableMigration` Experimental en Drift 2.31**:
   - *Problema:* El uso de la API experimental de Drift generaba advertencia en `flutter analyze`.
   - *Solución:* Se adoptó la técnica canónica y segura de SQLite con `customStatement` para recrear `collections` en 12 pasos dentro de una transacción sin advertencias estáticas.
2. **Dependencia de `package:sqlite3` en tests**:
   - *Problema:* El linter reportaba `depend_on_referenced_packages`.
   - *Solución:* Se reemplazó por `NativeDatabase.memory(setup: ...)` provisto directamente por `package:drift/native.dart`.
3. **Fixture de tests en `collections_receivables_test.dart`**:
   - *Problema:* Los tests de cobranza de V2 creaban cobros asociados solo a un cliente sin especificar obra ni mantenimiento.
   - *Solución:* Se adaptaron los fixtures de prueba para asignar formalmente un `projectId` válido, cumpliendo con la regla de contexto único.
