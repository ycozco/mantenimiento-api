# T-06 — Resultado de Implementación: Tools y ToolAssignments

**Fecha:** 2026-10-04  
**Estado:** `T-06 CLOSED`  
**Commit Asociado:** `feat(tools): implement T-06 tool assignment and return lifecycle`  

---

## 1. Resumen Ejecutivo

En el hito T-06 se implementó la gestión integral de activos fijos, maquinaria y herramientas manuales/eléctricas (`Tools`), desacoplándolos definitivamente del inventario consumible (`InventoryItems`).

Se diseñó e implementó el ciclo de vida de custodia y asignaciones (`ToolAssignments`), garantizando el principio de unicidad de custodia activa (una herramienta en estado `assigned` no puede asignarse simultáneamente a otro destino).

---

## 2. Modelo de Dominio y Schema Drift

Se utilizaron las tablas `Tools` y `ToolAssignments` definidas en Drift (`lib/core/database/database.dart`) sin romper compatibilidad y agregando la capa de dominio en `lib/core/models/`:

### 2.1 `Tool` (`lib/core/models/tool.dart`)
- **Identificadores y multi-tenant:** `id` (UUID), `workspaceId`.
- **Datos descriptivos:** `code` (ej. `HERR-001`, `MOT-002`), `name`, `category` (`manual`, `power`, `machinery`, `safety`, `measuring`, `other`).
- **Estados operativos (`status`):**
  - `available`: Lista en almacén para ser asignada.
  - `assigned`: En custodia activa de un trabajador, obra o visita de mantenimiento.
  - `maintenance`: En reparación, servicio técnico o calibración. No asignable.
  - `retired`: Dada de baja o desincorporada por obsolescencia/pérdida. No asignable.
- **Condición física (`condition`):** `new_`, `good`, `fair`, `damaged`.
- **Auditoría sincronizable:** `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `version`, `deletedAt`.

### 2.2 `ToolAssignment` (`lib/core/models/tool_assignment.dart`)
- **Identificadores:** `id` (UUID), `workspaceId`, `toolId`.
- **Destinos polimórficos de custodia (FKs explícitas):**
  - `workerId`: Trabajador responsable de la custodia personal.
  - `projectId`: Obra donde se encuentra la herramienta/maquinaria.
  - `maintenanceVisitId`: Visita de mantenimiento específica a la que fue asignada.
  *Al menos uno debe estar presente.*
- **Trazabilidad temporal:** `checkoutAt` (fecha de entrega/salida), `expectedReturnAt` (fecha estimada de retorno), `returnedAt` (fecha efectiva de devolución).
- **Observaciones:** `notes` (para consignar estado de entrega, combustible, accesorios, etc.).
- **Auditoría sincronizable:** `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `version`, `deletedAt`.

---

## 3. Repositorio y Reglas de Negocio (`ToolRepository`)

Ubicado en `lib/core/repositories/tool_repository.dart`, centraliza la lógica transaccional:

1. **Invariante de Custodia Única (`assignTool`):**
   - Verifica el estado actual de la herramienta en la base de datos.
   - Si la herramienta está `retired` o `maintenance`, arroja excepción impidiendo la asignación.
   - Si ya cuenta con una asignación activa (`returnedAt IS NULL`), arroja excepción.
   - Dentro de una transacción atómica Drift:
     - Inserta el nuevo registro en `ToolAssignments`.
     - Actualiza el estado de la herramienta a `assigned` incrementando su versión y fecha de actualización.
2. **Devolución Controlada (`returnTool`):**
   - Requiere un `ToolAssignment` activo.
   - Sella `returnedAt` con timestamp real.
   - Opcionalmente permite actualizar la condición física de la herramienta (`good`, `damaged`, etc.) y notas de recepción.
   - Si la condición resultante es `damaged`, la herramienta pasa a estado `maintenance`; en caso contrario, vuelve a `available`.
3. **Cambio de Estado de Herramienta (`updateToolStatus`):**
   - No permite cambiar manualmente a `available` si existe una asignación activa sin devolver.
4. **Consultas Reactivas y Filtros:**
   - Flujos continuos por workspace y por estado (`watchTools`).
   - Consultas de asignación activa por herramienta (`watchActiveAssignment`).
   - Consultas de herramientas activas en obra (`watchActiveAssignmentsByProject`) y en visita de mantenimiento (`watchActiveAssignmentsByMaintenanceVisit`).
   - Historial completo e inmutable de asignaciones por herramienta (`watchAssignmentsForTool`).

---

## 4. Interfaz de Usuario (UI)

Se construyeron e integraron las siguientes vistas y diálogos modulares:

1. **Gestión de Herramientas (`ToolsScreen`):**
   - Ubicada en `lib/features/tools/tools_screen.dart`.
   - Accesible desde la barra lateral / pantalla de Ajustes (`LOGÍSTICA Y CONTROL OPERATIVO`).
   - Tabs con contadores en tiempo real: *Todas*, *Disponibles*, *Asignadas*, *Mantenimiento*, *Retiradas*.
   - Barra de búsqueda por código o nombre de equipo.
   - Diálogo de creación rápida `ToolFormDialog`.
2. **Ficha y Trazabilidad del Equipo (`ToolDetailScreen`):**
   - Ubicada en `lib/features/tools/tool_detail_screen.dart`.
   - Badge visual de estado y condición física.
   - Tarjeta de Custodia Actual: muestra responsable (trabajador), destino (obra o visita de mantenimiento), fecha de salida y fecha prevista de retorno.
   - Botón directo de **Devolución de Herramienta** (`ToolReturnDialog`).
   - Botón de **Asignar Herramienta** (`ToolAssignmentDialog`).
   - Acciones de mantenimiento preventivo/correctivo y baja de equipo.
   - Historial cronológico completo de asignaciones previas.
3. **Integración en Obra (`ObraDetailScreen`):**
   - Pestaña de Control de Obra / Equipos: sección *Herramientas y Maquinaria en Obra*.
   - Lista en tiempo real de equipos asignados a la obra con nombre del trabajador custodio.
   - Acción directa para devolver equipo al almacén central desde la misma obra.
4. **Integración en Visita de Mantenimiento (`MaintenanceVisitDetailScreen`):**
   - Sección *Herramientas Asignadas a la Visita*.
   - Permite despachar equipos para la cuadrilla de la visita y confirmar su retorno al completar el servicio.

---

## 5. Batería de Pruebas Automatizadas

Se implementaron 9 tests exhaustivos en `test/tools_assignment_test.dart`:

1. `Crear herramienta y verificar estado inicial available`
2. `Asignar herramienta cambia estado a assigned`
3. `Rechazar segunda asignacion activa simultanea (invariante principal)`
4. `Devolver herramienta restaura estado a available e historial permanece`
5. `Devolver herramienta en condicion damaged pasa a estado maintenance`
6. `No permitir asignar herramienta en mantenimiento o retirada`
7. `Asignar a Worker, Project y MaintenanceVisit correctamente`
8. `Obtener asignaciones activas por Project y por MaintenanceVisit`
9. `Retirar herramienta y verificar que no es asignable`

Todos los tests ejecutados con éxito: **68/68 tests passing** en la suite global.

---

## 6. Verificación de Criterios de Aceptación

| Criterio | Estado | Observación |
| :--- | :---: | :--- |
| Separación clara entre consumibles y activos/herramientas |  | Modelos y tablas 100% independientes |
| Estados de herramienta: available, assigned, maintenance, retired |  | Implementados con chips visuales y validaciones |
| Prohibición estricta de doble asignación activa |  | Garantizado a nivel transaccional en `ToolRepository` |
| Asignación polimórfica a Worker, Project o MaintenanceVisit |  | FKs explícitas con validación XOR |
| Ciclo de devolución y actualización de condición |  | `ToolReturnDialog` operativo |
| Historial cronológico inmutable de custodia |  | Preservado en `ToolAssignments` |
| Visualización de equipos en Obra y Visita de Mantenimiento |  | Integrado en `ObraDetailScreen` y `MaintenanceVisitDetailScreen` |
| Cobertura de tests unitarios e integrados |  | 9 nuevos tests unitarios (suite total en 68) |
| `flutter analyze` |  | 0 issues |
