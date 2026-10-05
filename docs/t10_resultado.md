# Hito T-10: Costos y Rentabilidad Consolidada

## 1. Resumen Ejecutivo

El hito **T-10** unifica de manera reactiva, consistente y sin duplicidad contable toda la información financiera y operativa construida a lo largo de los hitos T-01 hasta T-09:
- **Costos Laborales:** Imputación reactiva de `WorkLogs` (`work_logs`).
- **Costos de Materiales:** Consumos de almacén imputados de `StockMovements` (`stock_movements`).
- **Gastos Directos:** Caja chica y compras directas imputadas de `Expenses` (`expenses`).
- **Otros Costos:** Costos adicionales explícitos imputados al proyecto.
- **Ingresos Comerciales:** Presupuesto pactado (`revenueCents` / `agreedRevenueCents`).
- **Cobros Reales:** Registro y liquidación reactiva de `Collections` (`collections`).

Toda la rentabilidad se deriva en tiempo de consulta reactivo desde los ledgers existentes mediante `ProjectFinancialService` y el modelo desacoplado `ProjectFinancialSummary`, garantizando que **no existan campos mutables derivados almacenados** (`projectCost`, `collectedTotal`, `receivable`, `margin`), previniendo desincronizaciones y datos obsoletos.

---

## 2. Fórmulas Financieras Implementadas

### A. Obra (Proyectos)
$$\text{LaborCost} = \sum_{\text{deletedAt IS NULL}} \text{work\_logs.amount\_cents}$$

$$\text{MaterialCost} = \sum_{\substack{\text{deletedAt IS NULL} \\ \text{movement\_type} = \text{'consumption'}}} \text{stock\_movements.total\_cost\_cents}$$

$$\text{ExpensesCost} = \sum_{\text{deletedAt IS NULL}} \text{expenses.amount\_cents}$$

$$\text{TotalCost} = \text{LaborCost} + \text{MaterialCost} + \text{ExpensesCost} + \text{OtherCosts}$$

$$\text{Revenue} = \text{Presupuesto pactado / Valor de venta acordado (cents)}$$

$$\text{GrossMargin} = \text{Revenue} - \text{TotalCost}$$

$$\text{GrossMarginPercent} = \begin{cases} \left( \frac{\text{GrossMargin}}{\text{Revenue}} \right) \times 100 & \text{si Revenue} > 0 \\ -100\% & \text{si Revenue} \le 0 \text{ y TotalCost} > 0 \\ 0\% & \text{si Revenue} = 0 \text{ y TotalCost} = 0 \end{cases}$$

$$\text{Collected} = \sum_{\text{deletedAt IS NULL}} \text{collections.amount\_cents}$$

$$\text{Receivable} = \max(0, \text{Revenue} - \text{Collected})$$

$$\text{OverpaidAmount} = \max(0, \text{Collected} - \text{Revenue})$$

### B. Mantenimiento
$$\text{VisitCost} = \text{LaborCost}(\text{visit}) + \text{MaterialCost}(\text{visit}) + \text{ExpensesCost}(\text{visit})$$

$$\text{PlanHistoricalCost} = \sum_{\text{visitas del plan}} \text{VisitCost}$$

> **Nota de Arquitectura:** No se inventan ingresos ficticios de visitas de mantenimiento si no están contractualmente pactados en un plan recurrente.

### C. Finanzas de Socios y Cero Duplicidad
- Los aportes de socios (`CapitalMovement.contribution`) y gastos personales de socios (`CapitalMovement.partnerExpense`) registran el origen de los fondos o el pasivo a favor del socio, pero **no alteran ni duplican** el costo operacional directo de la obra.
- La liquidación de jornadas de trabajadores (`LaborPayment`) salda la cuenta por pagar con el obrero, pero no altera el costo laboral de la obra, el cual ya fue devengado en el `WorkLog`.

---

## 3. Componentes Implementados

### 1. Modelo de Dominio (`lib/core/models/project_financial_summary.dart`)
- `ProjectFinancialSummary`: Estructura inmutable con montos en centavos (`revenueCents`, `laborCostCents`, `materialCostCents`, `expensesCostCents`, `otherCostsCents`, `collectedCents`) y getters convertidos a Soles con precisión decimal.
- Getters de estado: `isProfitable`, `isOverpaid`, `percentCollected`.

### 2. Servicio de Cálculo (`lib/core/services/project_financial_service.dart`)
- `watchProjectFinancialSummary(projectId, revenueCents)`: Stream reactivo multidominio que escucha cambios simultáneos en `work_logs`, `stock_movements`, `expenses` y `collections`.
- `getProjectFinancialSummary(projectId, revenueCents)`: Consulta atómica bajo demanda.
- `watchMaintenanceVisitTotalCostCents(visitId)`: Costo total de visita de mantenimiento.
- `watchPlanHistoricalCostCents(planId)`: Costo histórico acumulado del plan.

### 3. Rediseño de UI (`lib/features/obras/obra_detail_screen.dart`)
- Resumen ejecutivo jerárquico con KPIs clave:
  - **Presupuesto / Valor**
  - **Costo Ejecutado** (alerta visual si supera presupuesto)
  - **Margen Bruto** (con % y color dinámico verde/rojo)
  - **Cobrado**
  - **Por Cobrar / Saldo a favor (Sobrepago)**
- Barras de progreso de ejecución y cobranza.
- Desglose detallado del costo ejecutado (Materiales de Almacén, Mano de Obra, Gastos Directos).
- Integración completa con el registro y anulación de cobros (`collections`).

---

## 4. Pruebas Automatizadas (`test/project_financial_summary_test.dart`)

Se implementaron 10 pruebas automatizadas que cubren exhaustivamente todos los escenarios requeridos:

1. **Escenario Integrado Estándar:** Obra vendida S/ 10,000, Materiales S/ 2,000, Mano de Obra S/ 1,500, Gastos S/ 500 $\rightarrow$ Costo S/ 4,000, Margen S/ 6,000 (60.0%), Cobrado S/ 7,000, Por cobrar S/ 3,000.
2. **Obra sin cobros:** Cobrado S/ 0, Por cobrar S/ 10,000, Margen S/ 9,000 intacto.
3. **Obra completamente cobrada:** Cobrado S/ 10,000, Por cobrar S/ 0.
4. **Sobrepago:** Cobrado S/ 12,000 $\rightarrow$ Por cobrar S/ 0, `isOverpaid = true`, `overpaidAmount = S/ 2,000`.
5. **Obra sin costos:** Costo S/ 0, Margen S/ 5,000, Margen 100%.
6. **Obra con pérdida:** Venta S/ 10,000, Costo S/ 12,000 $\rightarrow$ Margen -S/ 2,000, `isProfitable = false`, Margen -20.0%.
7. **Regla de Cero Duplicidad Laboral:** Pago laboral de trabajador liquida deuda laboral pero no altera el costo de la obra.
8. **Regla de Cero Duplicidad de Socios:** Aportes y gastos de socios no alteran revenue ni costo del proyecto.
9. **Reactividad ante anulación:** Anular un consumo de material o un cobro actualiza instantáneamente todos los derivados.
10. **Mantenimiento:** Costo derivado de visita y costo acumulado de visitas de un plan.

---

## 5. Estado de la Suite

- `flutter test`: **106/106 tests pasando (100%)**.
- `flutter analyze`: **0 issues**.
- Working tree: Listo para commit de cierre.
