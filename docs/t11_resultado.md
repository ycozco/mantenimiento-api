# Hito T-11: Dashboard Operacional

## 1. Resumen Ejecutivo
El hito **T-11** implementa la pantalla de inicio operacional para Decolumax EIRL, proporcionando una vista consolidada en tiempo real de operaciones, finanzas de obras, mantenimientos, herramientas e inventario. 

Se diseñó la capa de servicio [`DashboardService`](file:///e:/mantenimiento/lib/core/services/dashboard_service.dart) y el modelo desacoplado [`DashboardSummary`](file:///e:/mantenimiento/lib/core/models/dashboard_summary.dart), reutilizando de manera estricta [`ProjectFinancialService`](file:///e:/mantenimiento/lib/core/services/project_financial_service.dart) para el cálculo de costos y márgenes de proyectos sin duplicar lógica financiera.

---

## 2. Componentes Implementados

### A. Modelo de Dominio (`lib/core/models/dashboard_summary.dart`)
- **Operaciones:** `activeProjectsCount`, `activeWorkersCount`, `assignedToolsCount`, `toolsInMaintenanceCount`, `overdueToolReturnsCount`.
- **Mantenimientos:** `visitsTodayCount`, `visitsUpcoming7DaysCount`, `visitsOverdueCount`.
- **Finanzas Consolidadas de Obras:** `activeProjectsAgreedRevenueCents`, `activeProjectsTotalCostCents`, `activeProjectsGrossMarginCents`, `activeProjectsGrossMarginPercent`, `activeProjectsCollectedCents`, `activeProjectsReceivableCents`.
- **Pasivos Laborales:** `totalPendingLaborDebtCents` (jornadas devengadas no liquidadas).
- **Inventario Kardex:** `lowStockItemsCount`, `outOfStockItemsCount`, `stockAlerts` (`LowStockAlert`).

### B. Servicio Central (`lib/core/services/dashboard_service.dart`)
- `watchDashboardSummary()`: Stream reactivo que observa simultáneamente las 11 tablas operativas y financieras de Drift (`projects`, `maintenanceVisits`, `workers`, `tools`, `toolAssignments`, `inventoryItems`, `stockMovements`, `workLogs`, `expenses`, `collections`, `laborPayments`).
- `getDashboardSummary()`: Agregación atómica sin almacenar valores derivados mutables.

### C. UI Operacional (`lib/features/dashboard/dashboard_screen.dart` y `home_screen.dart`)
- Tab **Inicio** en la barra de navegación principal.
- Banner de alerta visual prioritaria si existen visitas vencidas, retornos de herramientas vencidos o insumos agotados.
- Métricas accionables con navegación directa a sus respectivos módulos (Servicios, Obras, Almacén, Herramientas, Personal).

---

## 3. Pruebas Automatizadas (`test/dashboard_operational_test.dart`)

Se implementaron 12 pruebas automatizadas completas:
1. Dashboard vacío: todos los contadores en 0 sin errores ni divisiones por cero.
2. Obra activa: conteo correcto y exclusión de obras completadas/canceladas.
3. Agregación de costos: suma exacta de mano de obra, insumos de almacén y gastos directos.
4. Total por cobrar: suma reactiva de saldos por cobrar a clientes.
5. Regla contable: aportes de socios no alteran el revenue ni costos de obras.
6. Stock bajo: detección de insumos con stock $\le$ stock mínimo de alerta.
7. Stock agotado: detección de insumos con stock $\le 0$.
8. Mantenimiento próximo: conteo de visitas para hoy y próximos 7 días.
9. Mantenimiento vencido: detección de visitas pasadas pendientes.
10. Herramientas: conteo de asignadas, en taller y retornos vencidos con alerta.
11. Saldo laboral pendiente: cálculo exacto de jornadas devengadas menos pagos a obreros.
12. Exclusión estricta de registros soft-deleted (`deletedAt IS NOT NULL`).

---

## 4. Estado de la Suite
- Total tests: **118/118 passing (100%)**.
- `flutter analyze`: **0 issues**.
- Cierre: **T-11 CLOSED**.
