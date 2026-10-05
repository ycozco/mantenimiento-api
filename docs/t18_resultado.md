# Resultado Hito T-18 — Modelo Económico y Facturación de Mantenimientos

**Estado:** CLOSED  
**Fecha:** 2026-10-04  
**SchemaVersion Drift:** 3  
**Suite de Tests Totales:** 189 tests passing (0 failed)  
**Analyze:** 0 issues  

---

## 1. Problema Resuelto y Objetivos Cumplidos

Antes de T-18, el módulo de mantenimiento rastreaba de forma determinística los costos operacionales de cada visita:
- Mano de obra devengada en `work_logs` (`laborCostCents`).
- Materiales e insumos consumidos en `stock_movements` (`materialCostCents`).
- Gastos operativos menores en `expenses` (`expensesCents`).

Sin embargo, no existía representación de los **ingresos reales**, la **modalidad de facturación acordada con el cliente**, los **cobros registrados**, los **saldos por cobrar** ni el **margen bruto**.

En T-18 se ha completado el modelo económico para mantenimientos cumpliendo estrictamente con las reglas de negocio e invariantes de Decolumax EIRL.

---

## 2. Decisiones Arquitectónicas y Reglas de Negocio

### A. Modalidades de Facturación en `MaintenancePlans`
Se incorporaron dos columnas clave en `maintenance_plans`:
- `billing_type` (`TEXT NOT NULL DEFAULT 'perVisit'`):
  - `'perVisit'`: cobro por cada visita ejecutada (ej. S/ 350 por visita).
  - `'monthly'`: tarifa plana mensual (ej. S/ 800 mensual sin importar cuántas visitas se realicen en el mes).
  - `'custom'`: tarifa personalizada/eventual por cotización puntual.
- `agreed_amount_cents` (`INTEGER NOT NULL DEFAULT 0`): valor acordado en céntimos enteros.

### B. Invariante de Snapshot Histórico en `MaintenanceVisits`
- Se agregó `agreed_price_cents` (`INTEGER NULL`) en `maintenance_visits`.
- **Regla Inmutable:** Cuando la tarifa del plan se modifica en el futuro (ej. sube de S/ 350 a S/ 400), las visitas históricas ya programadas o ejecutadas **no mutan su snapshot de precio**. Solo las nuevas visitas adoptan la nueva tarifa.

### C. No Duplicación de Ingresos en Tarifa Mensual (`monthly`)
- En modalidad `monthly`, si se programan múltiples visitas dentro del mismo mes calendario (ej. 2 visitas en mayo), el sistema **no multiplica la tarifa mensual** (no hace S/ 800 × 2).
- `MaintenanceFinancialService` agrupa las visitas por mes calendario (`year * 12 + month`), garantizando que la facturación mensual represente exactamente el costo contratado por periodo.

### D. Asociación de Cobros (`Collections`)
- Se extendió la tabla `collections` con la columna `plan_id` (`REFERENCES maintenance_plans(id)`).
- La regla XOR impide vincular un cobro a una obra (`project_id`) y a un mantenimiento (`visit_id` / `plan_id`) simultáneamente.
- Se soportan pagos parciales, liquidación completa y sobrepagos (registrando saldos a favor con advertencia).

### E. Invariantes Financieras Preservadas
1. `LaborPayment` no altera ni duplica el `laborCost` de la visita (liquidar jornales pendientes afecta el pasivo laboral, no el costo de la visita).
2. `CapitalMovement` es financiamiento de socios, jamás ingreso por ventas o mantenimiento.
3. Las compras de insumos (`purchases`) no son costo directo de visita; el costo se reconoce al consumirse en Kardex (`stock_movements`).

---

## 3. Servicio Centralizado: `MaintenanceFinancialService`

Se creó el servicio `MaintenanceFinancialService` que deriva de forma reactiva y no redundante el resumen financiero `MaintenanceFinancialSummary`:
- `revenueCents`: ingresos reconocidos según modalidad.
- `collectedCents`: total cobrado a la visita o al plan.
- `receivableCents`: saldo pendiente por cobrar (mínimo 0).
- `laborCostCents`: mano de obra acumulada en la visita/plan.
- `materialCostCents`: insumos consumidos.
- `expensesCents`: gastos directos.
- `totalCostCents`: costo operativo total.
- `grossMarginCents`: margen bruto (`revenueCents - totalCostCents`).
- `grossMarginPercent`: rentabilidad porcentual sobre ingresos.
- `isOverpaid` y `overpaidCents`: detección de pagos en exceso.

---

## 4. Migración de Base de Datos y SchemaVersion 3

- Se incrementó `schemaVersion` en Drift de 2 a 3.
- `MigrationStrategy.onUpgrade` implementa la migración incremental:
  ```dart
  if (from < 3) {
    await m.addColumn(maintenancePlans, maintenancePlans.billingType);
    await m.addColumn(maintenancePlans, maintenancePlans.agreedAmountCents);
    await m.addColumn(maintenanceVisits, maintenanceVisits.agreedPriceCents);
    await m.addColumn(collections, collections.planId);
  }
  ```
- `BackupRestoreService` actualizó su versión de schema a 3 y serializa/deserializa estos campos en respaldos JSON V2 respetando el orden transaccional y las llaves foráneas.

---

## 5. Actualización de Interfaz de Usuario (UI)

1. **`MaintenancePlanDetailScreen`:**
   - Tarjeta de Resumen Económico: modalidad (`perVisit`, `monthly`, `custom`), tarifa base, facturación proyectada/ejecutada, costos operativos, margen bruto con porcentaje, total cobrado y saldo por cobrar.
   - Botón directo "Registrar Cobro al Plan".
2. **`MaintenanceVisitDetailScreen`:**
   - Tarjeta de Economía de la Visita con desglose de snapshot de tarifa, mano de obra, insumos consumidos, gastos operativos, costo total, margen y saldos.
   - Botón "Registrar Cobro de Visita".
   - Historial en vivo de cobros aplicados a la visita con opción de anulación.
3. **`CollectionFormDialog`:**
   - Soporte para cobros de visitas (`visitId`) y planes (`planId`).
   - Panel de saldos con monto acordado, cobrado previo y saldo pendiente.
4. **`MantenimientoFormDialog`:**
   - Selector de modalidad de cobro y campo de tarifa acordada (S/) al crear o editar planes.
5. **`DashboardScreen`:**
   - Inclusión separada de "Por Cobrar (Mantenimiento)" junto a "Por Cobrar (Obras)".

---

## 6. Verificación Automatizada

- **Test Suite:** `test/maintenance_financial_test.dart` (7 escenarios exhaustivos).
- **Cobertura total:** 189 tests passing, 0 failed.
- **Flutter Analyze:** 0 issues.
