# Resultado de Implementación: T-15 — Notificaciones Locales V2 para Visitas de Mantenimiento

## 1. Resumen Ejecutivo
Se migró y reconectó el subsistema de notificaciones locales al modelo formal de **`MaintenanceVisit`**, desvinculándolo completamente del antiguo modelo mutable V1. La programación es reactiva a la fecha planificada (`scheduledDate`) y cuenta con generación de IDs determinísticos de 32 bits, cancelación fiable y compatibilidad con las preferencias del dispositivo.

- **Estado:** `T-15 CLOSED`
- **Tests totales acumulados:** 156 passing (10 tests específicos en `test/notifications_v2_test.dart`)
- **Análisis estático:** `flutter analyze`: 0 issues
- **Commit:** `feat(notifications): implement T-15 maintenance visit local notifications`

---

## 2. Arquitectura de Notificaciones V2

### 2.1 Motor de Cálculo Puro (`NotificationScheduleEngine`)
Para desacoplar la lógica de fechas y los IDs de los plugins nativos (permitiendo pruebas unitarias herméticas sin emulador ni mocks frágiles), se implementó:
- `lib/core/notifications/notification_schedule_engine.dart`

**Reglas de anticipación soportadas:**
- `7 días antes` (Aviso temprano para cotizar o pedir insumos)
- `3 días antes` (Confirmación con el cliente)
- `2 días antes` (Revisión y alistamiento de herramientas y materiales)
- `1 día antes` ("¡MAÑANA!" - Asignación final de cuadrilla de operarios)
- **Hora fija:** `09:00 AM` local

### 2.2 Estrategia de IDs Determinísticos
Para cancelar exactamente las notificaciones pendientes de una visita cuando se completa, cancela o reprograma sin guardar listas de IDs efímeros:
$$\text{Notification ID} = (|\text{hashCode}(\text{visitId})| \pmod{10^7}) \times 10 + (\text{díasAntes} \pmod{10})$$
- Garantiza identificadores enteros de 32 bits positivos compatibles con Android/iOS.
- Estabilidad total a través de reinicios de la aplicación o reimportación de datos.

### 2.3 Filtro de Fechas Pasadas / Vencidas
El motor compara cada fecha calculada (`alertDateTime`) contra el instante actual (`now`). Si una visita se programa para dentro de 2 días, las alertas de 7 y 3 días se omiten automáticamente, impidiendo notificaciones extemporáneas absurdas.

---

## 3. Integración del Ciclo de Vida

- **Creación / Programación:** Se computan y registran las alertas futuras en el canal `mantenimiento_alertas_channel`.
- **Reprogramación:** Se cancelan las notificaciones asociadas a la fecha anterior y se calculan las nuevas en base a la nueva fecha de ejecución.
- **Completado:** Al completar la visita, se cancelan las notificaciones restantes para esa visita.
- **Cancelación:** La anulación o cancelación de una visita limpia sus alertas pendientes.
- **Siguiente Visita Recurrente:** Al completarse un ciclo de un `MaintenancePlan`, la nueva `MaintenanceVisit` generada programa su propio paquete de notificaciones independientes.

---

## 4. Gestión de Permisos

- Solicitud no intrusiva mediante `flutter_local_notifications`.
- Si el usuario rechaza los permisos o las notificaciones están desactivadas en los Ajustes del terminal (`device.notificationsEnabled == false`), el sistema funciona con total normalidad sin excepciones ni cierres inesperados.
- Switch de control manual en la pantalla de Ajustes.

---

## 5. Pruebas Automatizadas

En `test/notifications_v2_test.dart` (10 tests passing):
1. **Cálculo de reglas de anticipación:** -7, -3, -2 y -1 días a las 09:00 AM.
2. **Programación completa:** Visita futura a 15 días genera las 4 alertas con títulos descriptivos y nombre del cliente.
3. **Descarte de alertas vencidas:** Fechas pasadas no generan notificaciones.
4. **ID determinístico y estable:** Mismo `visitId` y offset siempre generan el mismo ID; distintos offsets/visitas generan IDs disjuntos.
5. **Cancelación determinística:** Generación de lista exacta de IDs a cancelar para una visita.
6. **Reprogramación:** Nueva fecha genera alertas en sus fechas correctas.
7. **Visita completada:** No genera alertas pendientes.
8. **Visita cancelada:** No genera alertas pendientes.
9. **Siguiente ciclo:** Plan recurrente genera nueva visita con sus propias alertas.
10. **Preferencia de dispositivo:** Si las notificaciones están desactivadas, no se emite ninguna alerta.
