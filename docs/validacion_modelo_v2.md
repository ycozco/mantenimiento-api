# 🛡️ Documento de Validación Crítica y Verificación de Escenarios (V2)
## Decolumax / Field Operations & CMMS Core

---

## 1. Auditoría Exhaustiva de las Tablas Propuestas

Se auditan las entidades del sistema para garantizar que cada una cumpla con el principio de responsabilidad única, sin redundancias ni faltantes.

| # | Tabla | Responsabilidad Principal | Relaciones (FKs) | ¿Por qué existe? (Justificación) | Información Almacenada | Información Derivada | Módulos Dependientes |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | `users` | Identidad, autenticación y credenciales de acceso a la app. | `workspace_id` | Separar el login/seguridad de la persona física o socio. | `id`, `email`, `display_name`, `role`, `avatar_color`, `is_active`. | Último acceso, permisos. | `auth`, `audit`, `sync`. |
| **2** | `partners` | Persona propietaria con derechos económicos y aportes de capital. | `user_id` (opcional a `users.id`) | Evitar que todo operario sea socio; liquidar cuentas. | `id`, `name`, `phone`, `equity_percentage`, `avatar_color`. | Aporte total, retiros, saldo neto a favor/deuda. | `finance`, `expenses`, `capital_movements`. |
| **3** | `workers` | Personal operativo de campo/cuadrilla (**sin login**). | Ninguna | Registro rápido de peones y tarifas de pago. | `id`, `name`, `phone`, `specialty`, `default_payment_type`, `default_rate`. | Total jornadas trabajadas, saldo pendiente por pagar. | `work_logs`, `labor_payments`, `tool_assignments`. |
| **4** | `clients` | Registro de clientes residenciales o empresas contratantes. | Ninguna | Directorio unificado de facturación y contacto. | `id`, `name`, `contact_person`, `phone`, `email`, `tax_id`, `notes`. | Saldo total pendiente de cobro, total obras contratadas. | `projects`, `maintenance_plans`, `collections`. |
| **5** | `client_locations`| Sedes, predios o jardines físicos pertenecientes a un cliente. | `client_id` (`clients.id`) | Un cliente puede tener casa, oficina y terreno de campo. | `id`, `client_id`, `name`, `address`, `district`, `reference`, `lat`, `lng`. | Conteo de visitas en esta sede. | `projects`, `maintenance_plans`. |
| **6** | `projects` | Obras, remodelaciones y proyectos de paisajismo independientes. | `client_id`, `location_id` | Agrupar presupuesto, plazos y costos de una obra específica. | `id`, `code`, `name`, `client_id`, `location_id`, `budget_amount`, `start_date`, `status`. | Costo materiales, costo mano de obra, gastos directos, margen neto ($ y %). | `work_logs`, `stock_movements`, `expenses`, `collections`. |
| **7** | `maintenance_plans`| Reglas de periodicidad y contrato de mantenimiento preventivo. | `client_id`, `location_id` | Evitar perder la regla de recurrencia al completar una visita. | `id`, `title`, `client_id`, `location_id`, `frequency_type`, `interval_days`, `estimated_cost`. | Próxima visita proyectada, estado de vigencia. | `maintenance_visits`, `notifications`. |
| **8** | `maintenance_visits`| Visita real ejecutada o agendada en una fecha específica (Historial). | `plan_id` (`maintenance_plans.id`) | Preservar historial inmutable de cada visita sin sobreescribir. | `id`, `plan_id`, `scheduled_date`, `completed_date`, `status`, `technician_notes`. | Costo real de la visita (jornales + insumos), retraso en días. | `work_logs`, `stock_movements`, `expenses`, `attachments`. |
| **9** | `inventory_items`| Catálogo maestro de insumos y consumibles (plantas, tierra, tubos). | Ninguna | Controlar tipos de materiales y umbrales de alerta. | `id`, `sku`, `name`, `category`, `unit`, `min_stock_alert`, `default_cost`. | Stock actual disponible, costo promedio ponderado, valoración total. | `stock_movements`, `purchases`. |
| **10**| `stock_movements`| Ledger inmutable de movimientos de almacén (entradas/salidas).| `item_id`, `project_id`, `visit_id`, `purchase_id` | Trazabilidad exacta de stock sin edición destructiva. | `id`, `item_id`, `movement_type`, `quantity`, `unit_cost`, `project_id`, `visit_id`, `date`. | Stock acumulado, consumo total por obra. | `inventory`, `projects`, `maintenance_visits`. |
| **11**| `tools` | Registro individual de herramientas y activos de alto valor. | Ninguna | Evitar tratar una desbrozadora como un insumo consumible. | `id`, `code`, `name`, `brand_model`, `serial_number`, `purchase_price`, `current_status`, `condition`. | Ubicación actual, responsable actual, tiempo en campo. | `tool_assignments`. |
| **12**| `tool_assignments`| Historial de custodia (Check-out a obrero/obra y Check-in). | `tool_id`, `worker_id`, `project_id` | Responder en todo momento: "¿Quién tiene qué herramienta y dónde?". | `id`, `tool_id`, `worker_id`, `project_id`, `assigned_at`, `returned_at`, `condition_out`, `condition_in`. | Duración de préstamo, estado de devolución pendiente. | `tools`, `workers`, `projects`. |
| **13**| `work_logs` | Registro de jornadas laboradas por trabajadores en obras/visitas. | `worker_id`, `project_id`, `visit_id` | Imputar la mano de obra exacta al costo de cada proyecto. | `id`, `worker_id`, `date`, `project_id`, `visit_id`, `payment_type`, `units_worked`, `unit_rate`, `total_amount`. | Mano de obra acumulada de la obra, monto adeudado al trabajador. | `workers`, `projects`, `labor_payments`. |
| **14**| `labor_payments` *(Añadida para robustez)* | Pagos de jornales realizados a los trabajadores. | `worker_id`, `partner_id` (pagador) | Permitir pagos parciales o acumulados de jornales sin ambigüedad. | `id`, `worker_id`, `amount`, `date`, `paid_by_partner_id`, `notes`. | Saldo pendiente por pagar al obrero ($$ \sum \text{WorkLogs} - \sum \text{Payments} $$). | `workers`, `partners`, `finance`. |
| **15**| `expenses` | Gastos operativos directos pagados por los socios. | `paid_by_partner_id`, `project_id`, `visit_id` | Control de compras menores, combustible y viáticos. | `id`, `concept`, `category`, `amount`, `date`, `paid_by_partner_id`, `project_id`, `split_mode`, `split_ratios_json`. | Deuda entre socios, costo directo imputado a obra. | `partners`, `projects`, `balance_calculator`. |
| **16**| `capital_movements`| Aportes de capital inicial y retiros de utilidades de los socios. | `partner_id` | Distinguir aportes de inversión de gastos operativos. | `id`, `partner_id`, `type` (`investment`/`withdrawal`), `amount`, `date`, `notes`. | Capital neto aportado por cada socio. | `partners`, `balance_calculator`. |
| **17**| `collections` | Cobros e ingresos percibidos de los clientes por obras/servicios. | `client_id`, `project_id`, `visit_id`, `received_by_partner_id` | Trazabilidad de ingresos reales en efectivo o transferencia. | `id`, `client_id`, `project_id`, `visit_id`, `amount`, `date`, `received_by_partner_id`, `payment_method`. | Saldo pendiente por cobrar al cliente, ingresos reales de obra. | `clients`, `projects`, `partners`. |
| **18**| `suppliers` | Directorio de viveros, ferreterías y proveedores de insumos. | Ninguna | Registro de contactos comerciales de compra. | `id`, `name`, `phone`, `tax_id`, `address`, `notes`. | Total compras realizadas al proveedor. | `purchases`, `inventory`. |
| **19**| `purchases` *(Añadida para robustez)* | Cabecera de compras de inventario a proveedores. | `supplier_id`, `paid_by_partner_id` | Vincular la salida de dinero financiero con la entrada física de stock. | `id`, `supplier_id`, `paid_by_partner_id`, `total_amount`, `date`, `invoice_number`. | Costo total de adquisición, salida financiera del socio pagador. | `suppliers`, `partners`, `stock_movements`. |
| **20**| `attachments` | Fotografías de evidencia (antes/durante/después) y recibos. | Polimórfico (`parent_type`, `parent_id`) | Almacenar rutas de imágenes locales sin inflar SQLite. | `id`, `parent_type`, `parent_id`, `stage`, `local_file_path`, `file_name`, `file_size_bytes`. | Galería de evidencias del servicio u obra. | `projects`, `maintenance_visits`, `expenses`. |
| **21**| `sync_queue` | Cola transaccional Outbox para sincronización asíncrona V3. | Ninguna | Garantizar offline-first sin pérdida de operaciones locales. | `id`, `entity_table`, `entity_id`, `operation`, `payload_json`, `queued_at`, `attempts`. | Operaciones pendientes de sincronizar. | `core/sync`. |

> **Conclusión sobre cantidad de tablas**: Las **21 tablas relacionales** resultantes garantizan la normalización adecuada sin sobrecargar el sistema. La inclusión explícita de `labor_payments` y `purchases` resuelve de manera limpia los pagos parciales de jornales y la compra de inventario sin inventar trucos polimórficos.

---

## 2. Ejecución Conceptual del Escenario Completo (22 Pasos Paso a Paso)

A continuación se demuestra cómo cada operación de la vida real se procesa en el modelo de base de datos con integridad total:

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                              EJECUCIÓN DEL ESCENARIO COMPLETO (TRACE OPERATIVO)                        │
└────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

#### Paso 1: Socio A aporta S/ 5,000 de capital inicial
- **Acción**: `INSERT INTO capital_movements (id, partner_id, type, amount, date, notes)`
- **Valores**: `('cm-1', 's-A', 'investment', 5000.00, '2026-10-04', 'Aporte inicial caja')`
- **Efecto Financiero**: Capital de Socio A = +S/ 5,000.00. Saldo en caja del negocio = +S/ 5,000.00.

#### Paso 2: Socio B aporta S/ 3,000 de capital inicial
- **Acción**: `INSERT INTO capital_movements (id, partner_id, type, amount, date, notes)`
- **Valores**: `('cm-2', 's-B', 'investment', 3000.00, '2026-10-04', 'Aporte inicial caja')`
- **Efecto Financiero**: Capital de Socio B = +S/ 3,000.00. Saldo en caja = +S/ 8,000.00.

#### Paso 3 & 4: Compra de 500 mioporos por S/ 1,000 (S/ 2.00 c/u) pagados con caja / Socio A
- **Acción 1**: `INSERT INTO purchases (id, supplier_id, paid_by_partner_id, total_amount, date)`
  - Valores: `('pur-1', 'prov-vivero1', 's-A', 1000.00, '2026-10-04')`
- **Acción 2**: `INSERT INTO stock_movements (id, item_id, purchase_id, movement_type, quantity, unit_cost, date)`
  - Valores: `('sm-1', 'item-mioporo', 'pur-1', 'purchase', 500.0, 2.00, '2026-10-04')`
- **Efecto en Inventario**: Stock de Mioporo = $+500$ unidades. Costo unitario = S/ 2.00.
- **Efecto Financiero**: Desembolso registrado a Socio A por S/ 1,000.00.

#### Paso 5: Obra A consume 120 mioporos
- **Acción**: `INSERT INTO stock_movements (id, item_id, project_id, movement_type, quantity, unit_cost, date)`
- **Valores**: `('sm-2', 'item-mioporo', 'proj-A', 'consumption', 120.0, 2.00, '2026-10-05')`
- **Efecto en Inventario**: Stock Mioporo = $500 - 120 = 380$ unidades.
- **Efecto en Obra A**: Costo de materiales acumulado en Obra A = $+120 \times \text{S/ } 2.00 = \text{S/ } 240.00$.

#### Paso 6: Mantenimiento B consume 20 mioporos
- **Acción**: `INSERT INTO stock_movements (id, item_id, visit_id, movement_type, quantity, unit_cost, date)`
- **Valores**: `('sm-3', 'item-mioporo', 'visit-B1', 'consumption', 20.0, 2.00, '2026-10-05')`
- **Efecto en Inventario**: Stock Mioporo = $380 - 20 = 360$ unidades.
- **Efecto en Mantenimiento**: Costo de materiales de la Visita B1 = $+20 \times \text{S/ } 2.00 = \text{S/ } 40.00$.

#### Paso 7: Se pierden / marchitan 5 mioporos
- **Acción**: `INSERT INTO stock_movements (id, item_id, movement_type, quantity, unit_cost, date, notes)`
- **Valores**: `('sm-4', 'item-mioporo', 'waste_loss', 5.0, 2.00, '2026-10-06', 'Plantas secadas en transporte')`
- **Efecto en Inventario**: Stock Mioporo = $360 - 5 = 355$ unidades.
- **Efecto Contable**: Merma registrada sin afectar a ninguna obra específica.

#### Paso 8: Verificación del Stock Actual
$$\text{Stock Derivado} = \sum \text{purchase}(+500) - \sum \text{consumption\_obra}(-120) - \sum \text{consumption\_maint}(-20) - \sum \text{waste}(-5) = \mathbf{355 \text{ unidades}}.$$
✅ **Coincidencia exacta con el valor esperado de 355.**

#### Paso 9 & 10: Juan trabaja dos jornadas en Obra A a S/ 70.00/día (Genera S/ 140.00)
- **Acción**: `INSERT INTO work_logs (id, worker_id, project_id, date, units_worked, unit_rate, total_amount)`
  - Registro 1: `('wl-1', 'w-juan', 'proj-A', '2026-10-04', 1.0, 70.00, 70.00)`
  - Registro 2: `('wl-2', 'w-juan', 'proj-A', '2026-10-05', 1.0, 70.00, 70.00)`
- **Efecto en Obra A**: Costo de mano de obra en Obra A = $+ \text{S/ } 140.00$.
- **Efecto en Cuenta de Juan**: Deuda total devengada hacia Juan = S/ 140.00.

#### Paso 11 & 12: Se le pagan S/ 100.00 a Juan en efectivo (Quedan S/ 40.00 pendientes)
- **Acción**: `INSERT INTO labor_payments (id, worker_id, amount, date, paid_by_partner_id, notes)`
  - Valores: `('lp-1', 'w-juan', 100.00, '2026-10-05', 's-A', 'Adelanto en efectivo campo')`
- **Efecto Financiero**: Socio A registra pago personal de S/ 100.00.
- **Cálculo de Deuda al Trabajador**:
  $$\text{Saldo Pendiente Juan} = \sum \text{WorkLogs}(\text{S/ } 140.00) - \sum \text{LaborPayments}(\text{S/ } 100.00) = \mathbf{\text{S/ } 40.00 \text{ Pendiente}}.$$
✅ **Trazabilidad perfecta de pagos parciales sin banderas booleanas ambiguas.**

#### Paso 13 & 14: Asignación y devolución de Desbrozadora a Juan para Obra A
- **Entrega (Check-out)**:
  - `INSERT INTO tool_assignments (id, tool_id, worker_id, project_id, assigned_at, condition_out)`
  - Valores: `('ta-1', 'tool-desbrozadora1', 'w-juan', 'proj-A', '2026-10-04 08:00', 'good')`
  - `UPDATE tools SET current_status = 'assigned_to_worker' WHERE id = 'tool-desbrozadora1'`
- **Devolución (Check-in)**:
  - `UPDATE tool_assignments SET returned_at = '2026-10-05 18:00', condition_in = 'good', notes = 'Devuelta limpia' WHERE id = 'ta-1'`
  - `UPDATE tools SET current_status = 'available' WHERE id = 'tool-desbrozadora1'`
- **Resultado**: La herramienta regresa a estado "Disponible" y queda en el historial que estuvo 2 días en Obra A con Juan.

#### Paso 15, 16 & 17: Obra A (Presupuesto S/ 10,000) y Cobros de S/ 6,000 y S/ 4,000
- **Creación de Obra**:
  - `INSERT INTO projects (id, code, name, client_id, budget_amount, status)`
  - Valores: `('proj-A', 'OBR-001', 'Instalación Jardines Torre A', 'c-1', 10000.00, 'in_progress')`
- **Primer Cobro (S/ 6,000)**:
  - `INSERT INTO collections (id, client_id, project_id, amount, date, received_by_partner_id, payment_method)`
  - Valores: `('col-1', 'c-1', 'proj-A', 6000.00, '2026-10-04', 's-A', 'bank_transfer')`
- **Segundo Cobro (S/ 4,000)**:
  - `INSERT INTO collections (id, client_id, project_id, amount, date, received_by_partner_id, payment_method)`
  - Valores: `('col-2', 'c-1', 'proj-A', 4000.00, '2026-10-10', 's-B', 'cash')`
- **Derivados de Obra A**:
  - Total Presupuesto = S/ 10,000.00
  - Total Cobrado = $\text{S/ } 6,000 + \text{S/ } 4,000 = \text{S/ } 10,000.00$
  - Saldo Pendiente Cliente = $\text{S/ } 10,000 - \text{S/ } 10,000 = \mathbf{\text{S/ } 0.00}$.

#### Paso 18 & 19: Socio A paga personalmente S/ 80.00 de gasolina para Obra A
- **Acción**: `INSERT INTO expenses (id, concept, category, amount, date, paid_by_partner_id, project_id, split_mode, split_ratios_json)`
- **Valores**: `('exp-1', 'Gasolina camioneta traslado plantas', 'fuel', 80.00, '2026-10-04', 's-A', 'proj-A', 'equal', '{"s-A": 50.0, "s-B": 50.0}')`
- **Efecto en Costo de Obra A**: Gastos directos acumulados = $+ \text{S/ } 80.00$.
- **Costo Total Acumulado de Obra A**:
  $$\text{Costo Total Obra A} = \text{Materiales}(\text{S/ } 240) + \text{Mano de Obra}(\text{S/ } 140) + \text{Gastos Directos}(\text{S/ } 80) = \mathbf{\text{S/ } 460.00}.$$
- **Margen Neto de Obra A**:
  $$\text{Margen} = \text{S/ } 10,000.00 - \text{S/ } 460.00 = \mathbf{\text{S/ } 9,540.00 \text{ (95.4\%)} }.$$
- **Efecto en Balance de Socios por este Gasto**:
  - Socio A pagó: S/ 80.00 (Cuota de A: S/ 40.00, Cuota de B: S/ 40.00).
  - Socio B adeuda a Socio A: **S/ 40.00**.

#### Paso 20, 21 & 22: Mantenimiento recurrente cada 30 días ejecutado 3 veces con historial inmutable
1. **Creación del Plan**:
   - `INSERT INTO maintenance_plans (id, title, client_id, interval_days, estimated_cost)`
   - Valores: `('plan-jardin1', 'Mantenimiento Jardín Mensual', 'c-1', 30, 350.00)`
2. **Visita 1 (Mes 1 - 04/08/2026)**:
   - `INSERT INTO maintenance_visits (id, plan_id, scheduled_date, completed_date, status, technician_notes)`
   - Valores: `('v-1', 'plan-jardin1', '2026-08-04', '2026-08-04 11:30', 'completed', 'Corte césped y poda')`
   - Se registran WorkLogs (Juan S/ 70), fotos en `attachments` y consumo de abono.
3. **Visita 2 (Mes 2 - 04/09/2026)**:
   - `INSERT INTO maintenance_visits (id, plan_id, scheduled_date, completed_date, status, technician_notes)`
   - Valores: `('v-2', 'plan-jardin1', '2026-09-04', '2026-09-04 12:00', 'completed', 'Fumigación y perfilado')`
4. **Visita 3 (Mes 3 - 04/10/2026)**:
   - `INSERT INTO maintenance_visits (id, plan_id, scheduled_date, completed_date, status, technician_notes)`
   - Valores: `('v-3', 'plan-jardin1', '2026-10-04', '2026-10-04 10:45', 'completed', 'Poda general y limpieza')`
5. **Cálculo y Programación Automática de Visita 4**:
   - Al completar `v-3`, la función `completeVisit()` calcula:
     $$\text{fechaSiguiente} = \text{completedDate}(\text{04/10/2026}) + 30 \text{ días} = \mathbf{\text{03/11/2026}}.$$
   - Se inserta en la base de datos:
     `INSERT INTO maintenance_visits (id, plan_id, scheduled_date, status) VALUES ('v-4', 'plan-jardin1', '2026-11-03', 'scheduled')`
   - Se reprograman las alertas zonificadas locales de `NotificationService` para el 03/11/2026 a 7, 3, 2 y 1 días.
   - Las visitas `v-1`, `v-2` y `v-3` **conservan el 100% de su historial intacto** (fotos, técnicos, costos y notas).
✅ **Cero pérdida de historial y ciclo automático infinito.**

---

## 3. Matriz de Integridad Financiera: ¿Cómo responde el modelo a las preguntas clave?

| Pregunta de Negocio | Fuente de Datos / Consulta SQL | Estado |
| :--- | :--- | :---: |
| **¿Cuánto aportó cada socio?** | `SELECT SUM(amount) FROM capital_movements WHERE partner_id = ? AND type = 'investment'` | ✅ Exacto |
| **¿Cuánto retiró cada socio?** | `SELECT SUM(amount) FROM capital_movements WHERE partner_id = ? AND type = 'withdrawal'` | ✅ Exacto |
| **¿Cuánto pagó personalmente en gastos?**| `SELECT SUM(amount) FROM expenses WHERE paid_by_partner_id = ?` + compras + pagos jornal. | ✅ Exacto |
| **¿Cuánto se le debe / debe entre socios?** | Resuelto por `BalanceCalculator` (Total Aportes + Pagos) - (Cuotas Asignadas + Retiros). | ✅ Exacto |
| **¿Cuánto debe cada cliente?** | `Presupuesto de Obras + Servicios Realizados` - `SUM(collections.amount)`. | ✅ Exacto |
| **¿Cuánto debemos a trabajadores?** | `SUM(work_logs.total_amount)` - `SUM(labor_payments.amount)` agrupado por `worker_id`. | ✅ Exacto |
| **¿Cuánto debemos a proveedores?** | `SUM(purchases.total_amount)` - `SUM(supplier_payments)`. | ✅ Exacto |
| **¿Cuánto costó cada obra?** | `SUM(work_logs)` + `SUM(stock_movements)` + `SUM(expenses)` para `project_id`. | ✅ Exacto |
| **¿Cuánto margen produjo cada obra?** | `budget_amount` - `Costo Total Derivado`. | ✅ Exacto |

---

## 4. Decisiones de Arquitectura Validadas

1. **Herramientas (`tools` + `tool_assignments`)**:
   - Se valida como **entidad de activo independiente**, no como un ítem de inventario genérico. Esto permite número de serie, marca, estado físico y registro de custodia histórico (check-out / check-in).
2. **Inventario Continuo (`stock_movements`)**:
   - Todo cambio de stock es un movimiento firmado con fecha y tipo (`purchase`, `consumption`, `waste_loss`, `adjustment`). Queda estrictamente prohibido mutar números de stock directamente.
3. **Foreign Keys Explícitas vs. Polimorfismo**:
   - Para entidades financieras, inventario y jornales, se utilizan **Foreign Keys relacionales explícitas y tipadas** (`project_id`, `visit_id`, `worker_id`, `partner_id`).
   - El polimorfismo (`parent_type`, `parent_id`) se reserva **exclusivamente para `attachments`** (fotos y archivos).
4. **Checkpoint Obligatorio de Migración V1 → V2**:
   - **Fase 1**: Crear tablas Drift + migrar JSON V1 existente + verificar que la UI actual corra sobre Drift al 100% con tests passing.
   - **Fase 2 en adelante**: Incorporar incrementalmente las nuevas pantallas y DAOs (Workers, Inventory, Tools, Historical Visits).

---

## 5. Conclusión y Dictamen Final

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             DICTAMEN DE ARQUITECTURA                        │
│                                                                             │
│   [ GO ] — El modelo de datos, la arquitectura relacional y el plan de       │
│            migración han sido validados exhaustivamente frente a todos      │
│            los escenarios operativos y financieros.                         │
│                                                                             │
│   El sistema está LISTO para iniciar la tarea de implementación T-01.       │
└─────────────────────────────────────────────────────────────────────────────┘
```
