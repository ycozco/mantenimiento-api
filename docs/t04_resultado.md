# T-04 — Resultado de Implementación: MaintenancePlan + MaintenanceVisit

## 1. Resumen Ejecutivo
Se completó exitosamente el hito **T-04**, separando definitivamente el concepto de contrato recurrente (**MaintenancePlan**) de cada una de sus ejecuciones reales históricas (**MaintenanceVisit**).

Con este cambio:
- Se elimina el defecto de V1 donde completar un mantenimiento simplemente sobreescribía la fecha siguiente destruyendo el registro de lo que ocurrió.
- Cada visita es inmutable una vez completada y conserva sus jornadas laborales (`WorkLog`) y notas.
- Se implementó la vinculación de `WorkLog` a `maintenanceVisitId` respetando estrictamente la regla XOR (`projectId` XOR `maintenanceVisitId`).
- Al completar una visita, se calcula automáticamente el siguiente ciclo (`plan.calculateNextCycle(completedDate)`), se actualiza el plan y se programa la siguiente visita inmutable con estado `scheduled`.

---

## 2. Entidades y Esquema Drift

### MaintenancePlan
- `id` (UUID v4)
- `workspaceId`
- `clienteId`, `clienteNombre`
- `tipo` (nombre/servicio)
- `frecuenciaDias`
- `proximaFecha`
- `estado` (`activo`, `pausado`, `cancelado`)
- `montoCobroSoles`
- `notas`
- Auditoría syncable: `createdAt`, `updatedAt`, `version`, `deletedAt`

### MaintenanceVisit
- `id` (UUID v4)
- `workspaceId`
- `maintenancePlanId`
- `scheduledDate` (fecha planificada)
- `executedDate` (fecha real de ejecución)
- `status` (`scheduled`, `inProgress`, `completed`, `cancelled`)
- `notes`
- Auditoría syncable: `createdAt`, `updatedAt`, `version`, `deletedAt`

### WorkLog (activación en visitas)
- Respeto del constraint XOR:
  - `projectId != null && maintenanceVisitId == null` (Obra)
  - `projectId == null && maintenanceVisitId != null` (Mantenimiento)
- Cálculo reactivo de costo laboral de visita:
  `maintenanceLaborCost = SUM(active WorkLogs.amountCents)`

---

## 3. Repositorio e Integración UI

- **MaintenanceRepository**:
  - `watchActivePlans()`, `watchPlan(id)`
  - `createPlan(plan)` (crea plan y genera automáticamente la primera visita programada)
  - `watchPlanVisits(planId)`, `watchVisit(visitId)`
  - `startVisit(visitId)` -> estado `inProgress`
  - `completeVisit(visitId, completedDate, notes)` -> completa visita, recalcula `nextDate`, actualiza plan y programa visita siguiente.
  - `cancelVisit(visitId, reason)` -> estado `cancelled`
  - `watchVisitLaborCostCents(visitId)` -> suma reactiva de WorkLogs
  - `watchVisitWorkLogs(visitId)` -> stream de jornadas
- **UI**:
  - `MaintenancePlanDetailScreen`: Detalle del plan, frecuencia, cliente, estado, próxima fecha e historial cronológico de todas las visitas pasadas y programadas.
  - `MaintenanceVisitDetailScreen`: Detalle de visita, selector de estado (`Iniciar`, `Completar`, `Cancelar`), registro directo de jornadas laborales vinculadas vía `WorkLogFormDialog` y desglose de costo laboral.
  - `MantenimientosScreen`: Al tocar una tarjeta de mantenimiento se navega a la pantalla completa de detalle y visitas del plan.

---

## 4. Pruebas Automatizadas

Se crearon 9 tests unitarios e integrados en `test/maintenance_plans_visits_test.dart`:
1. `Crear plan: programa automáticamente la primera visita`
2. `Iniciar visita: cambia estado a inProgress sin mutar plan`
3. `Completar visita: conserva historial inmutable y programa siguiente ciclo`
4. `Múltiples visitas completadas conservan historial cronológico íntegro`
5. `Jornadas laborales (WorkLog) asociadas a MaintenanceVisit`
6. `Costo laboral de visita suma reactivamente WorkLogs activos`
7. `XOR constraint: WorkLog no puede asociarse simultáneamente a Obra y Visita`
8. `Visita cancelada no modifica la próxima fecha programada del plan`
9. `Cambio de frecuencia en plan no altera visitas históricas ya ejecutadas`

Suite completa: **50/50 tests passing**, **flutter analyze: 0 issues**.

---

## 5. Criterio de Aceptación
- [x] Historial conservado al completar visita.
- [x] Siguiente ciclo programado automáticamente.
- [x] WorkLog asociado a MaintenanceVisit con costo derivado.
- [x] XOR Project / Visit respetado.
- [x] 0 errores de análisis y 100% tests pasando.
- [x] **T-04 CLOSED**.
