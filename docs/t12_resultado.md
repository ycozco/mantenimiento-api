# Hito T-12: Calendario / Agenda Operacional

## 1. Resumen Ejecutivo
El hito **T-12** implementa la agenda y calendario operacional unificado para Decolumax EIRL, integrando en una sola vista cronológica todas las fuentes de eventos temporales del sistema sin duplicar entidades ni persistir tablas redundantes de eventos:
- **Visitas de Mantenimiento (`MaintenanceVisits`):** Programadas, en curso, completadas y vencidas.
- **Obras / Proyectos (`Projects`):** Fechas de inicio e hitos de finalización estimada.
- **Retornos de Herramientas (`ToolAssignments`):** Fechas esperadas de devolución con control de vencimiento.

Se creó la capa de servicio [`CalendarService`](file:///e:/mantenimiento/lib/core/services/calendar_service.dart) y el modelo de presentación inmutable [`CalendarEvent`](file:///e:/mantenimiento/lib/core/models/calendar_event.dart), garantizando cero duplicación de datos y reactividad pura.

---

## 2. Componentes Implementados

### A. Modelo de Presentación (`lib/core/models/calendar_event.dart`)
- `CalendarEvent`: View model con `id`, `sourceType` (`maintenanceVisit`, `project`, `toolReturn`), `sourceId`, `title`, `subtitle`, `startDate`, `endDate`, `status` (`pending`, `in_progress`, `completed`, `cancelled`, `overdue`), `priority` (`normal`, `high`, `urgent`) y `metadata`.
- Getters de estado: `isOverdue`, `sourceTypeLabel`, `statusLabel`.

### B. Servicio Central (`lib/core/services/calendar_service.dart`)
- `watchEvents({filterType, fromDate, toDate})`: Stream reactivo que escucha cambios en las tablas de Drift (`maintenanceVisits`, `maintenancePlans`, `clients`, `projects`, `toolAssignments`, `tools`).
- `getEvents({filterType, fromDate, toDate})`: Consulta y agregación polimórfica en memoria con orden cronológico estricto (`startDate` ascendente).
- Cero duplicación: cualquier cambio en la tabla origen (reprogramación de visita, cambio de fecha de obra, devolución de herramienta) se refleja al instante.

### C. UI de Calendario (`lib/features/calendar/calendar_screen.dart`)
- Filtros rápidos por chip: `Todos`, `Mantenimientos`, `Obras`, `Herramientas`.
- Selector y filtro por fecha específica.
- Tarjetas de eventos con badges de estado y prioridad visual (verde completado, naranja programado, rojo urgente/vencido).
- Navegación al pulsar: dirige al detalle de la obra (`ObraDetailScreen`), herramienta (`ToolDetailScreen`) o visita correspondiente.
- Acceso directo integrado en `DashboardScreen`.

---

## 3. Pruebas Automatizadas (`test/calendar_service_test.dart`)

Se implementaron 10 pruebas automatizadas completas:
1. Visita programada aparece con su cliente, plan y fecha.
2. Visita cancelada se representa con su estado correspondiente.
3. Visita completada histórica se visualiza adecuadamente.
4. Devolución de herramienta con `expectedReturnAt` se refleja como evento.
5. Obra con fecha de inicio y fin estimada se integra correctamente.
6. Filtros por tipo de origen (`maintenanceVisit`, `project`, `toolReturn`) funcionan selectivamente.
7. Orden cronológico estricto de eventos por `startDate` ascendente.
8. Eventos del mismo día conservan unicidad y orden por hora.
9. Navegación: `sourceId` e `id` válidos en todos los orígenes.
10. Cero duplicación: una reprogramación en la tabla origen actualiza inmediatamente el evento en el calendario.

---

## 4. Estado de la Suite
- Total tests: **128/128 passing (100%)**.
- `flutter analyze`: **0 issues**.
- Cierre: **T-12 CLOSED**.
