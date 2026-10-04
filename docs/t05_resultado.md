# T-05 — Resultado de Implementación: Inventory + Stock Movements

## 1. Resumen Ejecutivo
Se implementó exitosamente el hito **T-05**, introduciendo el sistema de inventario y kardex de insumos y consumibles (plantas, materiales, fertilizantes, tierra preparada, tuberías).

Principales características implementadas:
- **Ledger Inmutable**: El stock no se edita directamente en la tabla del ítem; se deriva estrictamente como `stock = SUM(StockMovements.quantity)`.
- **Integridad y Restricción de Stock Negativo**: Todo consumo o salida rechaza transacciones que produzcan stock menor a cero, alertando oportunamente al usuario.
- **Snapshot de Costo Histórico**: Cada movimiento de inventario conserva de forma inmutable el snapshot de costo unitario (`unitCostCents`) y costo total (`totalCostCents`) al momento de la operación; si el costo de referencia futuro del ítem varía, los consumos históricos no se ven alterados.
- **Derivación de Costos de Obra y Mantenimiento**:
  - `projectMaterialCost = SUM(consumos asociados al proyecto)`
  - `maintenanceMaterialCost = SUM(consumos asociados a la visita)`
- **Integridad XOR**: Ningún movimiento de stock puede estar vinculado simultáneamente a una Obra y a una Visita de Mantenimiento.

---

## 2. Modelos y Repositorio Drift

### InventoryItem
- `id` (UUID v4)
- `workspaceId`
- `sku` (código de barra o SKU único)
- `name` (nombre del insumo/planta)
- `category` (`plants`, `materials`, `supplies`, `pipes`, etc.)
- `unit` (`unit`, `m3`, `kg`, `m`, `bag`, `sack`)
- `minStockAlert` (alerta de stock bajo)
- `defaultCostCents` (costo de referencia en centavos enteros)
- `isActive`
- `notes`
- Auditoría syncable: `createdAt`, `updatedAt`, `version`, `deletedAt`

### StockMovement
- `id` (UUID v4)
- `workspaceId`
- `itemId` (FK a `inventory_items`)
- `movementType` (`purchase`, `consumption`, `adjustment`, `return`, `loss`, `transfer`)
- `quantity` (con signo controlado: positivo para entradas, negativo para consumos y pérdidas)
- `unitCostCents` (snapshot de costo unitario en centavos)
- `totalCostCents` (snapshot de costo total en centavos)
- `projectId` (nullable, FK a `projects`)
- `visitId` (nullable, FK a `maintenance_visits`)
- `purchaseId` (nullable, FK a `purchases`)
- `date`, `notes`
- Auditoría syncable: `createdAt`, `updatedAt`, `version`, `deletedAt`

### InventoryRepository
- `watchActiveItems()`, `getItem(id)`
- `createItem(item)`, `updateItem(item)`, `deleteItem(id)`
- `watchItemStock(itemId)`, `getItemStock(itemId)` -> `SUM(movements.quantity)`
- `recordMovement(movement, {allowNegativeStock})` -> validación de saldo positivo
- `recordConsumption({itemId, quantity, unitCostCents, projectId, visitId})`
- `watchProjectMaterialCostCents(projectId)` -> derivación de costo de materiales para Obra
- `watchVisitMaterialCostCents(visitId)` -> derivación de costo de materiales para Visita

---

## 3. Integración en UI

- **InventoryScreen**:
  - Búsqueda en tiempo real por nombre o SKU.
  - Filtro por categoría mediante chips interactivos.
  - Tarjetas de insumo con stock reactivo en vivo, alertas visuales (`AGOTADO`, `BAJO STOCK`, `EN STOCK`), unidad de medida y costo referencial.
  - Botón flotante para registro de nuevo ítem.
- **InventoryItemDetailScreen**:
  - Encabezado con estado del stock y tarjeta degradada adaptativa según nivel de alerta.
  - Botones de acción rápida: `Entrada / Compra (+)`, `Consumo / Salida (-)`, `Ajuste de Stock`.
  - Kardex histórico detallado con tipo de movimiento, cantidades con signo, snapshot de costo y tags de asignación.
- **StockMovementFormDialog**:
  - Cálculo instantáneo del stock actual y stock proyectado resultante antes de confirmar.
  - Bloqueo y advertencia en caso de stock insuficiente.
  - Selección de contexto Obra o Visita.
- **ObraDetailScreen**:
  - Botón de acción rápida `Registrar Consumo de Material (Almacén)`.
  - Desglose financiero actualizado: Gastos directos de caja chica + Materiales de almacén + Mano de obra de jornadas = Inversión total acumulada.
  - Sección inferior con lista reactiva de materiales consumidos de almacén.
- **MaintenanceVisitDetailScreen**:
  - Botón `Registrar Consumo`.
  - Tarjeta de costos de visita desglosada: Mano de Obra + Insumos/Materiales = Costo Total de Visita.
  - Lista de consumos con opción de anulación.
- **AjustesScreen**:
  - Nueva sección `LOGÍSTICA Y CONTROL OPERATIVO` con acceso directo al Inventario.

---

## 4. Pruebas Automatizadas (test/inventory_stock_test.dart)

Se implementaron 9 pruebas unitarias e integradas:
1. `Flujo completo: Compra +500, Obra -120, Mantenimiento -20, Pérdida -5 -> Stock = 355`
2. `Stock negativo rechazado por defecto`
3. `Costo histórico snapshot preservado: cambiar costo futuro del item no altera consumos pasados`
4. `Derivación reactiva de Costo de Obra (projectMaterialCost)`
5. `Derivación reactiva de Costo de Visita de Mantenimiento`
6. `Anulación (Soft Delete) de movimiento revierte stock y costos`
7. `Integridad XOR: Movimiento no puede pertenecer simultáneamente a Obra y Visita`
8. `FK de SQLite: Movimiento con itemId inexistente es rechazado`
9. `Precisión de cantidades fraccionarias y cálculo exacto en centavos`

Estado de la suite de pruebas: **59/59 tests passing**, **flutter analyze: 0 issues**.

---

## 5. Criterio de Aceptación
- [x] Separación de insumos consumibles vs herramientas.
- [x] Stock estrictamente calculado como `SUM(movimientos)`.
- [x] Rechazo de stock negativo garantizado.
- [x] Snapshot inmutable de costo histórico por movimiento.
- [x] Costos derivados para Obra y Visita de Mantenimiento sin duplicidad.
- [x] Integridad XOR Project / Visit.
- [x] 0 errores de análisis y 100% tests pasando.
- [x] **T-05 CLOSED**.
