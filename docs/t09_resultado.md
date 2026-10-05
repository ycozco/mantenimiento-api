# T-09 — Resultado de Implementación: Client Collections & Receivables

**Fecha:** 2026-10-04  
**Estado:** `T-09 CLOSED`  
**Commit Asociado:** `feat(collections): implement T-09 client collections and receivables`  

---

## 1. Resumen Ejecutivo

En el hito T-09 se implementó el módulo de gestión de cobros y cuentas por cobrar a clientes (`Collections`):
$$\text{Presupuesto / Venta Pactada} \neq \text{Costo Operativo Ejecutado} \neq \text{Cobrado Efectivo}$$

Se habilitó el registro de cobros parciales o totales vinculados a obras y clientes, derivando reactivamente el estado de cuentas por cobrar (`receivables`) y detectando de forma transparente eventuales sobrepagos a favor del cliente sin bloquear la operación.

---

## 2. Modelo de Dominio y Schema Drift

### 2.1 `Collection` (`lib/core/models/collection.dart`)
- **Identificadores:** `id` (UUID), `workspaceId`, `clientId` (FK CASCADE), `projectId` (FK SET NULL), `visitId` (FK SET NULL).
- **Importes y Fechas:** `amountCents` (> 0), `date`.
- **Datos de Cobro:** `receivedByPartnerId` (FK partners, socio receptor), `paymentMethod` (`cash`, `yape`, `plin`, `transfer`, `other`), `reference` (ej. número de operación bancaria), `notes`.
- **Auditoría:** `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `version`, `deletedAt`.

### 2.2 `ProjectBillingSummary`
Estructura de derivación calculada en tiempo real:
- $\text{Cobrado} = \sum (\text{Collections activas del proyecto})$
- $\text{Pendiente por Cobrar} = \max(0, \text{Presupuesto Pactado} - \text{Cobrado})$
- $\text{Sobrepago} = \max(0, \text{Cobrado} - \text{Presupuesto Pactado})$
- $\text{Porcentaje Cobrado} = (\text{Cobrado} / \text{Presupuesto}) \times 100\%$

No se almacenan valores mutables ni saldos redundantes en la tabla `projects`.

---

## 3. Repositorio y Reglas de Negocio (`CollectionRepository`)

Ubicado en `lib/core/repositories/collection_repository.dart`:
- `recordCollection(Collection collection)`
- `deleteCollection(String collectionId)` (Soft-delete que restaura el saldo por cobrar reactivamente).
- `watchProjectCollections(String projectId)` y `watchClientCollections(String clientId)`.
- `watchProjectBillingSummary(String projectId, int agreedAmountCents)` y `getProjectBillingSummary(String projectId, int agreedAmountCents)`.

---

## 4. Interfaz de Usuario (UI)

- **`CollectionFormDialog` (`lib/features/collections/collection_form_dialog.dart`):**
  - Diálogo modal con panel informativo en vivo que muestra el presupuesto pactado, lo recaudado hasta la fecha, el monto ingresado y el saldo resultante (o advertencia de sobrepago).
  - Campos de cliente, método de pago, socio receptor y referencia bancaria.
- **Integración en `ObraDetailScreen` (`lib/features/obras/obra_detail_screen.dart`):**
  - Tarjeta destacada **Cobros y Facturación al Cliente**:
    - Valor Presupuestado
    - Cobrado hasta la fecha con barra de progreso porcentual
    - Saldo pendiente por cobrar (o banner de sobrepago)
    - Botón "Registrar Cobro"
    - Historial de cobros con método, referencia y acción de anular con confirmación.

---

## 5. Batería de Pruebas Automatizadas

Se añadieron 9 pruebas unitarias e integradas en `test/collections_receivables_test.dart`:
1. `Cobro parcial: reduce cuenta por cobrar correctamente`
2. `Múltiples cobros parciales acumulan el total recaudado`
3. `Cobro completo: saldo pendiente queda exactamente en 0 (100% cobrado)`
4. `Sobrepago: detecta saldo a favor del cliente sin bloquear`
5. `Anulación (Soft Delete): cobro anulado se descuenta del total cobrado`
6. `Métodos de pago permitidos y formateo de etiquetas`
7. `Integridad de Foreign Keys: Cobro con clientId inexistente es rechazado`
8. `Validación de montos: amountCents <= 0 es rechazado con ArgumentError`
9. `Precisión en centavos sin redondeo erróneo de doubles`

**Métricas:**
- **Total tests suite:** 96/96 passing
- **flutter analyze:** 0 issues
