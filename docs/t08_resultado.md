# T-08 — Resultado de Implementación: Partner Capital Movements & Balances

**Fecha:** 2026-10-04  
**Estado:** `T-08 CLOSED`  
**Commit Asociado:** `feat(partners): implement T-08 partner capital movements and balances`  

---

## 1. Resumen Ejecutivo

En el hito T-08 se desacoplaron rigurosamente las dimensiones financieras de los socios propietarios/inversionistas (`Partners`):
$$\text{Porcentaje de Propiedad (\%)} \neq \text{Capital Aportado} \neq \text{Gasto Pagado Personalmente} \neq \text{Retiros} \neq \text{Utilidad Distribuida}$$

Se implementó el libro mayor (`CapitalMovements` ledger) y el cálculo reactivo de saldos individuales por socio. Se garantizó la regla de **no duplicación de costos**: un gasto personal pagado por un socio para una obra explica quién financió el costo en el patrimonio, pero **no** vuelve a sumar al costo operativo del proyecto.

---

## 2. Modelo de Dominio y Schema Drift

### 2.1 `CapitalMovement` (`lib/core/models/capital_movement.dart`)
- **Identificadores:** `id` (UUID), `workspaceId`, `partnerId` (FK CASCADE).
- **Asociación opcional:** `projectId` (FK SET NULL, opcional para vincular desembolsos personales a una obra específica).
- **Tipos de Movimiento (`type`):**
  - `contribution`: Aporte de capital a la empresa (+ saldo a favor del socio).
  - `partnerExpense`: Gasto operativo/obra pagado personalmente (+ saldo a favor del socio como pasivo a reembolsar).
  - `withdrawal`: Retiro de capital del socio (- saldo a favor del socio).
  - `profitDistribution`: Reparto de utilidades percibido (- saldo a favor del socio).
  - `adjustment`: Ajuste contable manual (± saldo).
- **Importes:** `amountCents` estrictamente positivo (`> 0`). El efecto contable lo determina exclusivamente el `type`.
- **Auditoría:** `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `version`, `deletedAt`.

### 2.2 `PartnerBalanceSummary`
Estructura de derivación pura desde el historial de movimientos activos:
$$\text{Saldo Neto} = (\text{Aportes} + \text{Gastos Personales}) - (\text{Retiros} + \text{Utilidades}) + \text{Ajustes}$$
No se almacena ningún saldo mutable en `partners.balance`.

---

## 3. Repositorio y Reglas de Negocio (`PartnerRepository`)

Ubicado en `lib/core/repositories/partner_repository.dart`:
- `recordCapitalMovement(CapitalMovement movement)`
- `deleteCapitalMovement(String movementId)` (Soft-delete que actualiza inmediatamente el saldo derivado).
- `watchPartnerMovements(String partnerId, {String? type, String? projectId})` (Filtros reactivos para vistas y trazabilidad).
- `watchPartnerBalance(String partnerId)` y `getPartnerBalance(String partnerId)`.

---

## 4. Interfaz de Usuario (UI)

- **`PartnerDetailScreen` (`lib/features/socios_clientes/partner_detail_screen.dart`):**
  - Tarjeta destacada de **Saldo Neto en Empresa** con estado visual (verde a favor, rojo en contra).
  - Desglose en cuatro cuadrantes: Aportes, Gastos Personales, Retiros y Utilidades.
  - Filtro interactivo por tipo de movimiento.
  - Lista histórica de movimientos con indicación de signos (+ / -), obra relacionada, fecha y notas.
  - Acción para anular movimiento con confirmación.
  - Botón flotante "Registrar Movimiento".
- **`CapitalMovementFormDialog` (`lib/features/socios_clientes/capital_movement_form_dialog.dart`):**
  - Selector de tipo con explicativo de signo (+/-).
  - Entrada de monto en Soles (convertido a centavos).
  - Selector de fecha.
  - Selector opcional de obra asociada.
- **Integración:**
  - Navegación directa a la ficha financiera del socio al pulsar su tarjeta en `SociosClientesScreen`.

---

## 5. Batería de Pruebas Automatizadas

Se añadieron 10 pruebas unitarias e integradas en `test/partner_capital_test.dart`:
1. `Aporte simple: incrementa aportes y saldo neto a favor del socio`
2. `Múltiples aportes acumulan el saldo a favor`
3. `Retiro de capital: disminuye el saldo a favor del socio`
4. `Gasto personal para la empresa/obra: reconocido como pasivo a favor del socio`
5. `Distribución de utilidades: resta del saldo neto del socio`
6. `Dos socios con aportes y saldos independientes`
7. `projectId opcional en movimientos`
8. `Anulación (Soft Delete) de movimiento revierte el saldo inmediatamente`
9. `Invariante Crítica: CapitalMovement no incrementa ni duplica costo de Obra`
10. `amountCents positivo y rechazo de montos <= 0`

**Métricas:**
- **Total tests suite:** 87/87 passing
- **flutter analyze:** 0 issues
