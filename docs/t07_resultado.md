# T-07 — Resultado de Implementación: Suppliers + Purchases

**Fecha:** 2026-10-04  
**Estado:** `T-07 CLOSED`  
**Commit Asociado:** `feat(purchases): implement T-07 suppliers and inventory purchases`  

---

## 1. Resumen Ejecutivo

En el hito T-07 se implementó el circuito completo de adquisición de suministros e insumos:
$$\text{Proveedor} \longrightarrow \text{Compra} \longrightarrow \text{Ítems de Compra} \longrightarrow \text{Entrada a Kardex (StockMovements)} \longrightarrow \text{Actualización de Stock}$$

Se garantizó la atomicidad transaccional: una compra con múltiples líneas persiste en SQLite tanto la cabecera `Purchase`, como el detalle `PurchaseItems`, como las entradas positivas en `StockMovements`. La anulación de compras revierte el stock del Kardex y bloquea la operación si causaría stock negativo.

---

## 2. Modelo de Dominio y Schema Drift

Se actualizó la base de datos a `schemaVersion = 2` con migración `onUpgrade` retrocompatible y soporte de Foreign Keys:

### 2.1 `Supplier` (`lib/core/models/supplier.dart`)
- **Identificadores:** `id` (UUID), `workspaceId`.
- **Datos comerciales:** `name` (Razón social o nombre), `contactName` (opcional), `phone`, `email`, `taxId` (RUC / DNI opcional, permitiendo proveedores informales/personas naturales), `address`, `notes`, `isActive`.
- **Auditoría sincronizable:** `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `version`, `deletedAt`.

### 2.2 `Purchase` (`lib/core/models/purchase.dart`)
- **Identificadores:** `id` (UUID), `workspaceId`, `supplierId` (nullable, permite compras directas sin proveedor registrado), `paidByPartnerId` (nullable, socio que pagó la compra o caja).
- **Comprobante y montos:** `totalAmountCents` (entero en centavos), `date`, `documentType` (`invoice`, `receipt`, `ticket`, `none`, `other`), `invoiceNumber` (número de serie/correlativo), `notes`.
- **Auditoría:** `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `version`, `deletedAt`.

### 2.3 `PurchaseItem` (`lib/core/models/purchase_item.dart` y tabla `PurchaseItems`)
- **Relaciones:** `purchaseId` (FK CASCADE), `itemId` (FK `inventory_items(id)`).
- **Snapshots de costo:** `quantity` (decimal), `unitCostCents` (entero), `totalCostCents` (entero).
- Modificaciones futuras del precio de referencia en inventario **no** alteran los snapshots de costo de compras históricas.

---

## 3. Repositorio y Transacciones Atómicas (`PurchaseRepository`)

Ubicado en `lib/core/repositories/purchase_repository.dart`:

1. **Registro Atómico (`recordPurchase`):**
   - Ejecutado dentro de una transacción `_db.transaction(...)`.
   - Inserta cabecera `Purchases`.
   - Inserta cada línea en `PurchaseItems`.
   - Inserta para cada línea un `StockMovement` con `movementType: 'purchase'` e incremento positivo de existencias.
   - Actualiza el `defaultCostCents` en `InventoryItems` como referencia para futuras valorizaciones.
2. **Anulación y Reversión Segura (`cancelPurchase`):**
   - Verifica que el stock comprado no haya sido ya consumido en su totalidad (bloquea la anulación con `StateError` si causaría stock negativo).
   - Soft-delete simultáneo de `Purchase`, `PurchaseItems` y `StockMovements`.

---

## 4. Interfaz de Usuario (UI)

- **`SuppliersScreen` (`lib/features/suppliers/suppliers_screen.dart`):** Directorio de proveedores con búsqueda por nombre, RUC o contacto, y botón para crear nuevo proveedor.
- **`SupplierDetailScreen` (`lib/features/suppliers/supplier_detail_screen.dart`):** Ficha del proveedor, edición rápida y eliminación lógica.
- **`PurchaseFormDialog` (`lib/features/purchases/purchase_form_dialog.dart`):** Formulario modal multi-producto para registrar compras con selector de proveedor, socio pagador, tipo de comprobante, cálculo dinámico de subtotales y gran total.
- **`PurchaseDetailScreen` (`lib/features/purchases/purchase_detail_screen.dart`):** Visualización de comprobante, lista de insumos y acción para anular compra con reversión de Kardex.
- **Integraciones:**
  - `InventoryScreen`: Botón de acceso directo "Registrar Compra" en AppBar.
  - `AjustesScreen`: Entrada a "Proveedores de Insumos" bajo el bloque de Logística.

---

## 5. Batería de Pruebas Automatizadas

Se añadieron 9 pruebas en `test/suppliers_purchases_test.dart`:
1. `Crear proveedor con y sin RUC/DNI`
2. `Compra de un ítem: inserción atómica de Purchase, Item y Kardex`
3. `Compra multi-ítem: 10 bolsas tierra, 50 mioporos, 2 fertilizantes`
4. `Transacción atómica: falla en una línea aborta toda la operación`
5. `Snapshots de costo históricos preservados en PurchaseItems y Kardex`
6. `Integridad de Foreign Keys: Compra con supplierId inexistente es rechazada`
7. `Anulación de compra: revierte movimientos de stock en Kardex`
8. `Rechazo de anulación si el stock comprado ya fue consumido`
9. `Precisión en centavos y redondeo de cantidades fraccionarias`

**Métricas:**
- **Total tests suite:** 77/77 passing
- **flutter analyze:** 0 issues
