# 🏛️ Documento de Arquitectura del Sistema (V2)
## Decolumax / Field Operations & CMMS Core

---

## 1. Executive Summary

El proyecto **Mantenimiento & Finanzas** (Decolumax) nació como una solución móvil Flutter 100% offline-first, orientada a dos socios operadores dedicados a servicios de jardinería, paisajismo, mantenimiento técnico y ejecución de obras. Su valor central radica en la inmediatez operativa en campo (sin login engorroso ni dependencia de conectividad celular), el control de vencimientos de servicios y la resolución matemática de cuentas compartidas (*"¿Quién debe a quién y cuánto?"*).

La **Versión 2 (V2)** evoluciona este núcleo sin sacrificar su agilidad ni convertirlo en un ERP burocrático. El objetivo es estructurar un sistema modular de **Operaciones de Campo (FSM) + CMMS Preventivo + Proyectos/Obras + Inventario Continuo (Ledger) + Gestión de Herramientas/Activos + Jornadas/Personal + Finanzas Operativas**.

La arquitectura V2 migra el motor de persistencia desde un archivo monolítico JSON hacia **Drift (SQLite)** con soporte reactivo tipado, introduce separación estricta entre actores (**User**, **Partner**, **Worker**), desacopla los planes de mantenimiento de sus ejecuciones reales (**MaintenancePlan** vs. **MaintenanceVisit**), adopta el patrón contable de doble entrada para inventario (**StockMovement ledger**), y deja la base de datos completamente preparada con campos de auditoría, versionado y *tombstones* para una sincronización bidireccional asíncrona mediante el patrón **Outbox / Sync Queue**.

---

## 2. Auditoría del Sistema Actual (V1)

### 2.1 Resultados de Verificación de Salud
- **`flutter analyze`**: Ejecutado exitosamente (**0 issues found**, análisis limpio).
- **`flutter test`**: 3 suites de pruebas unitarias ejecutadas exitosamente (**3/3 passed** en `test/balance_calculator_test.dart`).

### 2.2 Inventario de Componentes Actuales
| Componente | Archivo Actual | Responsabilidad Actual |
| :--- | :--- | :--- |
| **Entrada Principal** | [`lib/main.dart`](file:///e:/mantenimiento/lib/main.dart) | Inicialización de bindings, locale `intl` español, `NotificationService` y `LocalStorageService`. |
| **Almacenamiento** | [`lib/core/database/local_storage_service.dart`](file:///e:/mantenimiento/lib/core/database/local_storage_service.dart) | Monolito `ChangeNotifier` que lee/escribe `mantenimiento_data.json` y `SharedPreferences`. |
| **Notificaciones** | [`lib/core/notifications/notification_service.dart`](file:///e:/mantenimiento/lib/core/notifications/notification_service.dart) | Programación de alarmas locales con `flutter_local_notifications` y `timezone` a 7, 3, 2 y 1 días. |
| **Tema Visual** | [`lib/core/theme/app_theme.dart`](file:///e:/mantenimiento/lib/core/theme/app_theme.dart) | Paleta Slate Dark (`#0F172A`), Amber Safety (`#F59E0B`), Emerald (`#10B981`) y Sky Blue (`#0EA5E9`). |
| **Modelos** | [`lib/core/models/`](file:///e:/mantenimiento/lib/core/models/) | `mantenimiento.dart`, `obra.dart`, `gasto.dart`, `socio.dart`, `cliente.dart`, `balance_calculator.dart`. |
| **Vistas** | [`lib/features/`](file:///e:/mantenimiento/lib/features/) | `home`, `mantenimientos`, `obras`, `gastos`, `socios_clientes`, `ajustes`. |

---

## 3. Problemas y Limitaciones Encontrados en V1

1. **Persistencia Monolítica JSON (`LocalStorageService`)**:
   - **Problema**: Toda la base de datos se reescribe completa en disco en cada inserción o edición (`jsonEncode` de todas las listas).
   - **Impacto**: Si la app llega a 500 gastos, 200 visitas y fotos/adjuntos, el I/O bloqueará el hilo principal de Flutter. No hay transaccionalidad ACID ni consultas indexadas.
2. **Pérdida de Historial en Mantenimientos**:
   - **Problema**: Al presionar *"Completar Mantenimiento"*, la entidad `Mantenimiento` muta su `fechaProximo` y sobreescribe `fechaUltimo`.
   - **Impacto**: Se pierde la trazabilidad de cuándo se realizaron las visitas previas, qué operarios asistieron, qué materiales se usaron o qué observaciones hubo en visitas pasadas.
3. **Confusión de Entidades de Personas (`Socio` como comodín)**:
   - **Problema**: El modelo `Socio` se usa tanto para el dueño inversionista, como para el técnico asignado a una obra y el usuario de la app.
   - **Impacto**: No se puede registrar a un peón o jardinero jornalero sin convertirlo en "socio" con avatar y participación de utilidades.
4. **Acoplamiento de Gastos sin Contexto Operativo**:
   - **Problema**: `Gasto` mezcla compras de activos (herramientas), insumos consumibles (gasolina, bolsas de tierra), jornales y comidas con un reparto hardcodeado.
   - **Impacto**: No se puede calcular la rentabilidad real de una obra porque los materiales no se descuentan de stock ni se diferencian de herramientas amortizables.
5. **Inexistencia de Módulo de Inventario y Herramientas**:
   - **Problema**: No existe control de stock ni seguimiento de activos de campo (desbrozadoras, motosierras, escaleras).
   - **Impacto**: Pérdidas de herramientas en obras y compras duplicadas de consumibles por desconocer el stock físico disponible.
6. **Imposibilidad de Sincronización Multi-dispositivo**:
   - **Problema**: La sincronización actual es manual (exportar/importar archivo JSON completo).
   - **Impacto**: Si ambos socios registran gastos en campo simultáneamente, al importar el JSON de uno se sobreescriben los datos del otro (pérdida de datos por colisión destructiva).

---

## 4. Requisitos Reales del Dominio

1. **Jardinería, Paisajismo y Obras Civiles Ligeras**:
   - Operación en cuadrillas pequeñas (1-2 socios + 2-6 peones/jardineros de apoyo).
   - Control de materiales vivos y consumibles (plantas, rollos de césped, tierra negra, abono, tuberías de riego).
   - Control estricto de custodia de herramientas de alto valor (desbrozadoras Stihl, cortasetos, motosierras, bombas de agua).
2. **Planes de Mantenimiento Recurrentes**:
   - Clientes residenciales y corporativos con visitas programadas (semanales, quincenales, mensuales, 45 días o bimensuales).
   - Checklist operativo de visita (corte de césped, perfilado, poda, fumigación, fertilización, revisión de aspersores, limpieza final, fotos de evidencia).
3. **Finanzas Transparentes y Ágiles**:
   - Inversiones iniciales de capital aportadas por cada socio.
   - Registro de jornales pagados a trabajadores (por día, por metro cuadrado o por tarea).
   - Costos reales directos de obra (materiales consumidos + jornales + gastos específicos) vs. presupuesto contratado para calcular el margen neto real.

---

## 5. Investigación de Productos y Proyectos de Referencia

Se analizaron repositorios de código abierto, documentación técnica oficial y arquitecturas de dominio consolidadas:

### 5.1 [OpenFieldService (clawnify/OpenFieldService)](https://github.com/clawnify/OpenFieldService)
- **Stack**: Preact, Hono, SQLite (D1/embedded).
- **Lección Clave**: Modelo simplificado de `Jobs` (Trabajos) vinculados a `Customer`, `Site Location`, `Assigned Techs` y `Material Consumption`. Despacho visual sin sobrecarga de formularios.
- **Qué Reutilizar**: El desacoplamiento entre el cliente y sus múltiples sedes/ubicaciones geográficas (`Location`), así como la asignación directa de cuadrilla a una orden.
- **Qué Descartar**: Su enfoque de servidor web centralizado sin almacenamiento local reactivo en cliente.

### 5.2 [Beveren FSM](https://github.com/phamos-eu/beveren-fsm) & [ERPNext Field Service](https://docs.frappe.io/)
- **Stack**: Python, Frappe Framework, MariaDB/PostgreSQL.
- **Lección Clave**: 
  - `Project` centraliza costos a través de `Timesheets` (mano de obra) y `Stock Entry` (consumo de materiales tipo *Material Issue*).
  - La rentabilidad de obra se deriva de: $$\text{Margen} = \text{Cobros Facturados} - (\sum \text{Timesheets} + \sum \text{Stock Issue} + \sum \text{Gastos Directos})$$.
- **Qué Reutilizar**: La fórmula de costos derivados mediante movimientos atómicos y no mediante números estáticos editados a mano.
- **Qué Descartar**: La pesadez burocrática del ciclo completo de compras (Requisición -> Cotización -> Orden -> Recepción -> Factura).

### 5.3 [Atlas CMMS / GraspJS CMMS](https://github.com/graspjs/grasp-cmms) & MaintainX
- **Stack**: Node.js, React, SQLite/PostgreSQL.
- **Lección Clave**:
  - `PreventiveMaintenancePlan`: Define la regla de recurrencia (intervalo en días o cron) y la plantilla de checklist.
  - `WorkOrder / Visit`: Instancia concreta ejecutada en una fecha específica, con estado (`Scheduled`, `InProgress`, `Completed`, `Overdue`), tiempo empleado, materiales consumidos y firma/fotos.
- **Qué Reutilizar**: Separación estricta entre la regla recurrente (`MaintenancePlan`) y las visitas ejecutadas (`MaintenanceVisit`).
- **Qué Descartar**: Métricas de confiabilidad industrial complejas (MTBF, MTTR) que no aplican a servicios de campo ligeros.

### 5.4 [Snipe-IT](https://github.com/snipe/snipe-it)
- **Stack**: PHP, Laravel, MySQL.
- **Lección Clave**:
  - Gestión de herramientas y activos (`Asset`) mediante historial de eventos `ActionLog` (`checkout` a persona/obra, `checkin` a bodega, condición física al entregar y recibir).
  - Estado del activo: `Disponible`, `En Obra / Asignada`, `En Mantenimiento / Taller`, `Dañada / Baja`.
- **Qué Reutilizar**: Modelo de custodia de herramientas: saber qué socio/trabajador tiene la herramienta, en qué obra se encuentra y desde qué fecha.
- **Qué Descartar**: Licencias de software y campos corporativos innecesarios.

### 5.5 [Grocy](https://github.com/grocy/grocy)
- **Stack**: PHP, SQLite.
- **Lección Clave**:
  - Inventario continuo basado en transacciones inmutables (`stock_log`): `PURCHASE`, `CONSUME`, `INVENTORY_CORRECTION`, `TRANSFER`.
  - El stock actual no es un campo arbitrario, sino la suma acumulada del ledger indexado.
- **Qué Reutilizar**: Trazabilidad mediante movimientos de inventario con costo unitario para calcular el costo promedio ponderado.
- **Qué Descartar**: Sistema de recetas culinarias y códigos de barras complejos en V2.

---

## 6. Matriz Comparativa

| Capacidad del Sistema | OpenFieldService | Atlas CMMS | ERPNext | Odoo FSM | Snipe-IT | Grocy | Decolumax V2 (Nuestra Decisión) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Control de Obras/Proyectos** | Básico | No | Completo | Completo | No | No | **Adopta ERPNext simplificado** (Presupuesto vs Costos Derivados). |
| **Mantenimiento Recurrente** | Intermedio | Avanzado | Intermedio | Avanzado | No | Chores | **Adopta Atlas CMMS** (`Plan` recurrente + `Visit` historial). |
| **Gestión de Trabajadores/Jornadas** | Asignación | Técnico | Timesheet | Timesheet | Usuario | No | **WorkLog ligero** (registro rápido de jornales sin login para peones). |
| **Consumibles (Ledger)** | Directo | Repuestos | Stock Entry | Stock Move | Consumables | Stock Log | **StockMovement Ledger** (Compra, Consumo en Obra/Servicio, Merma). |
| **Custodia de Herramientas** | No | Asset | Asset | Equipment | Checkout Log | No | **Tool + ToolAssignment** (Quién la tiene, en qué obra, estado). |
| **Finanzas entre Socios** | Invoices | No | Socios/Cuentas | Cuentas | No | No | **BalanceCalculator V2** (Aportes de Capital, Retiros, Deuda Neta). |
| **Offline-First Nativo** | No | No | No | No | No | No | **Drift (SQLite) + Outbox Queue** en Flutter local. |
| **UX Móvil de Campo** | Web | Web | Web app | App pesada | Web | Web/App | **Flutter Nativo** optimizado a 1 mano y modo oscuro. |

---

## 7. Patrones Seleccionados y Clasificación de Alcance

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            CLASIFICACIÓN DE ALCANCE                         │
├────────────────────────────────┬────────────────────────────────────────────┤
│  ADOPTAR AHORA (V2)            │  PREPARAR EN MODELO (V2 Backend/Schema)    │
│  - Drift / SQLite + DAOs       │  - workspaceId en todas las tablas         │
│  - User vs Partner vs Worker   │  - sync_status, version, tombstones        │
│  - MaintenancePlan + Visits    │  - Location multi-sede por cliente         │
│  - StockMovement Ledger        │  - Attachments (fotos antes/después)       │
│  - Tool Checkout/Custodia      │  - Purchases & LaborPayments explícitos    │
│  - WorkLogs de Jornales        │                                            │
│  - Costeo de Obra en Vivo      │                                            │
├────────────────────────────────┼────────────────────────────────────────────┤
│  FUTURO (V2.5 / V3)            │  DESCARTAR DEFINITIVAMENTE                 │
│  - Sync Gateway                │  - Contabilidad general de partida doble   │
│  - Flutter Web Admin Dashboard │  - Facturación electrónica SUNAT           │
│  - Cotizaciones / Presupuestos │  - Nómina legal compleja / contratos       │
│  - Rutas GPS en mapa           │  - CRDTs o Event Sourcing puro             │
└────────────────────────────────┴────────────────────────────────────────────┘
```

---

## 8. Arquitectura Objetivo y Persistencia Drift (SQLite)

### Comparativa Técnica: LocalStorage JSON vs. Drift SQLite
| Criterio | LocalStorage JSON Actual | Drift (SQLite) V2 |
| :--- | :--- | :--- |
| **Rendimiento I/O** | $O(N)$ - Serializa todo el archivo en cada cambio. | $O(1)$ - Inserciones y updates atómicos indexados. |
| **Integridad Referencial** | Manual en código (riesgo de IDs huérfanos). | Foreign Keys forzadas a nivel de motor SQLite. |
| **Reactividad UI** | `notifyListeners()` global (re-render de todo el árbol). | `Stream` específico por consulta / tabla observada. |
| **Transacciones** | Inexistentes (riesgo de archivo corrupto si se apaga el móvil). | Transacciones ACID (`db.transaction(...)`). |
| **Consultas Complejas** | Bucles en memoria `where(...)` iterativos. | SQL optimizado con `JOIN`, `GROUP BY`, `SUM` y filtros. |

---

## 9. Alternativas de Backend para Sincronización en V3 (Candidatos Abiertos)

La elección del backend para el Gateway se realizará formalmente en la etapa V3. Las cuatro alternativas evaluadas son:

1. **API Propia (FastAPI / NestJS) + PostgreSQL**: Máximo control sobre reglas de negocio y lógica de sincronización, requiere desarrollo y mantenimiento de endpoints.
2. **Supabase / PostgreSQL**: Backend-as-a-Service completo con Auth, PostgreSQL y Realtime listo para usar.
3. **PocketBase**: Solución ligera embebida en un solo binario en Go con SQLite/WAL y bajo consumo de RAM, idónea para VPS económicos.
4. **Appwrite**: Alternativa open-source completa con Auth, Bases de datos y Storage.
