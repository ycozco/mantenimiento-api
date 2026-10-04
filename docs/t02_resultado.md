# 📝 Bitácora Técnica de Implementación: Tarea T-02
## Módulo Workers (Trabajadores de Cuadrilla) + WorkLogs (Jornadas Laboradas)

---

## 1. Resumen Ejecutivo de la Tarea T-02
- **Objetivo**: Implementar el soporte relacional, de dominio, repositorios reactivos y UI operativa para la gestión de trabajadores de campo (`Worker`) y el registro histórico e inmutable de jornadas laboradas (`WorkLog`), integrando la mano de obra devengada en el cálculo del costo real de las obras (`Project`).
- **Resultado**: **100% COMPLETADO Y VALIDADO CON PRUEBAS AUTOMATIZADAS**.
- **Estado del Checkpoint**: `T-02 CLOSED`.

---

## 2. Decisiones de Diseño y Correcciones Arquitectónicas

1. **Separación Estricta de Actores**:
   - `Worker` representa exclusivamente a peones, operarios y maestros de obra de campo sin credenciales de inicio de sesión (`sin login`). Está totalmente desacoplado de `Users` (cuentas con login) y `Partners` (socios con capital y reparto).
2. **Tarifa Predeterminada vs. Histórico Inmutable**:
   - `Worker.defaultRateCents` y `Worker.defaultPaymentType` son solo plantillas de conveniencia.
   - Al registrar un `WorkLog`, los valores se copian a `WorkLog.rateCents` y `WorkLog.paymentType` (o se sobreescriben manualmente si se acordó una tarifa especial).
   - Las modificaciones posteriores a la tarifa del `Worker` no alteran ni recalculan jamás las jornadas pasadas.
3. **Representación de Cantidad (`quantity`) y Precisión Monetaria**:
   - Se evaluó el balance entre precisión y UX: `amountCents` y `rateCents` son enteros estrictos en céntimos (cero error de punto flotante en cálculos contables y `SUM`).
   - `quantity` se representa como un decimal controlado en el dominio (con redondeo a 2 decimales para soportar fracciones naturales como 0.5 días o 6.5 horas) almacenado en `RealColumn`.
   - El cálculo de `amountCents` se ejecuta al momento de la inserción/edición:
     - `daily`: $(\text{quantity} \times \text{rateCents}).\text{round}()$
     - `hourly`: $(\text{quantity} \times \text{rateCents}).\text{round}()$
     - `fixed`: $\text{rateCents}$
4. **Restricción de Contexto Operacional (XOR)**:
   - Se implementó a nivel de DDL SQLite el constraint:
     `CHECK ((project_id IS NOT NULL AND maintenance_visit_id IS NULL) OR (project_id IS NULL AND maintenance_visit_id IS NOT NULL))`
   - Una jornada pertenece exactamente a una Obra o a una Visita de Mantenimiento, nunca a ambas y nunca a ninguna.
5. **Centralización de Workspace**:
   - Se introdujo `AppConstants.defaultWorkspaceId = 'default'` para evitar cadenas mágicas dispersas.
6. **Soft Delete y Desactivación de Trabajadores**:
   - Para proteger la integridad referencial y contable, un trabajador con historial no se elimina físicamente; se desactiva (`isActive = false`) o se marca con `deletedAt`. Su historial de jornadas y costos de obras pasadas permanece 100% intacto.

---

## 3. Archivos Creados y Modificados

| Archivo | Acción | Responsabilidad |
| :--- | :---: | :--- |
| [`lib/core/constants/app_constants.dart`](file:///e:/mantenimiento/lib/core/constants/app_constants.dart) | **Creado** | Centralización de `workspaceId` y tipos de pago (`daily`, `hourly`, `fixed`). |
| [`lib/core/models/worker.dart`](file:///e:/mantenimiento/lib/core/models/worker.dart) | **Creado** | Modelo de dominio Worker con getters monetarios y serialización JSON. |
| [`lib/core/models/work_log.dart`](file:///e:/mantenimiento/lib/core/models/work_log.dart) | **Creado** | Modelo de dominio WorkLog con cálculo exacto de devengado y formato UX. |
| [`lib/core/database/tables/tables.dart`](file:///e:/mantenimiento/lib/core/database/tables/tables.dart) | Modificado | Inclusión de `workspaceId`, `createdBy`, `updatedBy`, `customConstraints` (XOR y validación de importes no negativos). |
| [`lib/core/database/app_database.g.dart`](file:///e:/mantenimiento/lib/core/database/app_database.g.dart) | **Regenerado** | Actualización de código Drift generado para Workers y WorkLogs. |
| [`lib/core/repositories/worker_repository.dart`](file:///e:/mantenimiento/lib/core/repositories/worker_repository.dart) | **Creado** | Repositorio tipado y reactivo para operaciones CRUD y filtrado de cuadrilla. |
| [`lib/core/repositories/work_log_repository.dart`](file:///e:/mantenimiento/lib/core/repositories/work_log_repository.dart) | **Creado** | Repositorio reactivo para registro, edición, anulación y agregación (`SUM`) de costo laboral. |
| [`lib/core/database/local_storage_service.dart`](file:///e:/mantenimiento/lib/core/database/local_storage_service.dart) | Modificado | Exposición de `workerRepository` y `workLogRepository` como fachada unificada. |
| [`lib/features/workers/worker_form_dialog.dart`](file:///e:/mantenimiento/lib/features/workers/worker_form_dialog.dart) | **Creado** | Diálogo minimalista de registro y edición rápida de trabajadores. |
| [`lib/features/workers/worker_detail_screen.dart`](file:///e:/mantenimiento/lib/features/workers/worker_detail_screen.dart) | **Creado** | Pantalla de perfil de trabajador con KPIs (jornadas, total devengado) e historial reactivo. |
| [`lib/features/work_logs/work_log_form_dialog.dart`](file:///e:/mantenimiento/lib/features/work_logs/work_log_form_dialog.dart) | **Creado** | Diálogo de alta rápida de jornada con precarga de tarifas, override y previsualización en vivo. |
| [`lib/features/obras/obras_screen.dart`](file:///e:/mantenimiento/lib/features/obras/obras_screen.dart) | Modificado | Integración de costo laboral en vivo en las tarjetas de obra, acción `+ Jornada` y acceso a detalle. |
| [`lib/features/obras/obra_detail_screen.dart`](file:///e:/mantenimiento/lib/features/obras/obra_detail_screen.dart) | **Creado** | Detalle financiero de obra con desglose materiales vs. mano de obra y listado de jornadas. |
| [`lib/features/socios_clientes/socios_clientes_screen.dart`](file:///e:/mantenimiento/lib/features/socios_clientes/socios_clientes_screen.dart) | Modificado | Incorporación de la pestaña "Personal (Cuadrilla)" con búsqueda y filtro de inactivos. |
| [`test/workers_work_logs_test.dart`](file:///e:/mantenimiento/test/workers_work_logs_test.dart) | **Creado** | Suite completa de 14 pruebas unitarias para Worker, WorkLog, precisión, XOR y foreign keys. |
| [`docs/modelo_datos_v2.md`](file:///e:/mantenimiento/docs/modelo_datos_v2.md) | Modificado | Actualización de especificaciones de las tablas `workers` y `work_logs`. |

---

## 4. Resultados de Verificación de Calidad

- **`dart format .`**: 35 archivos analizados (**0 issues de formato**).
- **`flutter analyze`**: **No issues found!** (0 advertencias, 0 errores en 2.3s).
- **`flutter test`**: **29/29 tests pasados al 100%**:
  - `balance_calculator_test.dart` (3 tests V1 sin regresiones).
  - `drift_migration_test.dart` (12 tests V1 sin regresiones).
  - `workers_work_logs_test.dart` (14 tests específicos de T-02):
    1. Crear trabajador con valores mínimos y `defaultRateCents`.
    2. Editar trabajador actualizando especialidad y tarifa.
    3. Desactivar trabajador: no aparece en selector activo y permanece en listado general.
    4. Trabajador inactivo conserva su historial completo.
    5. WorkLog daily ($1 \times 7000 = 7000$ céntimos).
    6. WorkLog hourly ($6.5 \times 1200 = 7800$ céntimos).
    7. WorkLog fixed ($15000$ céntimos fijos).
    8. Snapshot histórico: cambio de tarifa de trabajador no afecta jornadas previas.
    9. Override: registrar jornada a tarifa acordada diferente sin alterar la tarifa base del trabajador.
    10. Costo de obra acumulado: derivación exacta por suma de jornadas de múltiples trabajadores.
    11. Restricción XOR de contexto: rechaza `projectId + maintenanceVisitId` simultáneos.
    12. Restricción XOR de contexto: rechaza jornada sin contexto.
    13. Foreign Key: rechaza inserción con trabajador inexistente.
    14. Soft Delete: anulación de jornada descuenta automáticamente el costo derivado de la obra.


---

## 5. Deuda Técnica y Limitaciones Registradas

- **Deuda Técnica**: Sin deuda técnica bloqueante identificada en T-02.
- **Limitaciones Registradas**:
  1. *Liquidación de Pagos (`labor_payments`)*: El sistema registra con exactitud el total devengado por cada trabajador y por cada obra, pero la pantalla de registro de abonos/liquidaciones a peones se implementará en la tarea posterior (T-03).
  2. *Asociación con Visitas de Mantenimiento*: El schema de `WorkLogs` cuenta con la columna `maintenanceVisitId` y el constraint XOR activo; sin embargo, en esta tarea la interfaz de usuario se concentró en la asociación con Obras (`Project`), a la espera del desacoplamiento de Visitas de Mantenimiento.
