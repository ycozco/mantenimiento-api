# Corrección local y planificación de Decolumax Connected

Fecha: 2026-10-05. Estado: plan pendiente de ejecución.

## Progreso registrado

- `edba4cb` — documentación inicial de corrección y despliegue.
- `2d062e7` — workspace explícito, integridad de visitas y altas sin REPLACE destructivo; corrección de SQL financiero.
- `73b5c8a` — respaldos filtrados y validados por workspace.
- `192047b` — Drift schema 5 y migración del Outbox histórico.
- `3f382fd` — Outbox integrado en creación y finalización de mantenimientos.
- `e6c8cae` — `LocalStorageService` delega el ciclo de mantenimiento en un único repository.
- `893a79d` — base NestJS ejecutable, health check, configuración, Dockerfile y Compose local.
- `052a24e` — pool PostgreSQL, migraciones SQL, readiness y tablas fundacionales de identidad/sync.

Quedan por conectar las mutaciones restantes de repositories, el envío HTTP y la API en `server/layer`.

La base del servidor compila y `GET /api/v1/health` responde. `npm audit --omit=dev` no reporta vulnerabilidades; el conjunto de desarrollo todavía requiere revisar sus alertas transitivas antes de un release.
La migración SQL y Compose están validados por compilación/configuración; falta ejecutar una instancia PostgreSQL real porque Docker Engine no está disponible en este entorno.

## Objetivo y alcance

Dos socios trabajan desde instalaciones independientes, incluso sin conexión, y sus datos convergen mediante una API central. Flutter/Drift conserva la respuesta local inmediata. PostgreSQL valida y conserva el estado compartido. `server/layer` será la raíz del servicio y de su despliegue.

La revisión realizada es estática. No certifica ejecución visual, compilación actual, rendimiento medido ni la cantidad de pruebas aprobadas. Hay cambios locales previos en navegación, dependencias y documentación que deben conservarse.

La secuencia acordada es: corregir integridad local, refactorizar las escrituras que lo necesiten, cerrar el contrato y ejecutar después el plan del servidor. Crear esta carpeta y el plan no significa que esos hitos estén implementados.

## Hallazgos comprobados en el código

| Prioridad | Evidencia | Consecuencia y acción |
|---|---|---|
| Alta | `apps/client/lib/core/database/tables/tables.dart`: valores por defecto de workspace `default`; modelos como `maintenance_visit.dart`: UUID fijo diferente | Unificar el contexto de workspace y migrar datos existentes con un informe previo. No reemplazar todos los valores sin identificar su origen. |
| Alta | `MaintenanceRepository.createPlan` construye la primera visita sin pasar el workspace del plan | El hijo puede pertenecer a otro workspace según su valor por defecto. Revisar también compra/detalles/movimientos y herramienta/asignación. |
| Alta | `local_storage_service.dart`: IDs con `_loc_main`, `_visit_active` y sufijos de tiempo | No cumplen el contrato UUID del servidor. Mantener un mapa estable de IDs antiguos a nuevos para migrar todas las referencias, incluidas las guardadas en JSON. |
| Alta | `LocalStorageService` y `MaintenanceRepository` escriben planes y visitas | Dos implementaciones pueden aplicar reglas distintas. La ruta antigua de completar mantenimiento crea la siguiente visita sin fijar `agreedPriceCents`. Consolidar creación, edición, finalización y cancelación. |
| Alta | `local_storage_service.dart`: `InsertMode.insertOrReplace` en entidades relacionadas | Ante un ID repetido, REPLACE elimina la fila previa. Sustituir por inserción estricta o actualización explícita según la intención y verificar conservación de hijos. |
| Alta para V3 | `backup_restore_service.dart`: el parámetro `workspaceId` etiqueta el backup, pero las consultas extraen todas las filas | Un backup podría mezclar workspaces si la base los contiene. Definir alcance, filtrar y validar coherencia. |
| Media | `local_storage_service.dart`: `_reloadAllFromDb` después de múltiples mutaciones | Recarga amplia y notificación global. Migrar gradualmente a consultas reactivas específicas. |
| Media | `dashboard_service.dart`: una consulta de stock dentro del bucle de artículos; `collection_repository.dart`: consultas de nombres por cobro | El número de consultas crece con las filas. Usar agregaciones y joins manteniendo los resultados financieros. |
| Media | `inventory_screen.dart`: stream de stock por artículo | Revisar una consulta reactiva que entregue artículo y saldo; medir antes/después. |
| Media | `main.dart`: inicialización y programación de alertas antes de `runApp` | Agregar estado visible de inicio, recuperación de errores y separar trabajo diferible. Medir el arranque. |
| Pendiente funcional | `exportarRespaldo`: rama Web registra tamaño y retorna | Implementar descarga real y mensajes de éxito/error verificables en Web. |

Matiz de la revisión anterior: una FK con CASCADE no actúa al cambiar `deleted_at`. Su presencia no demuestra pérdida de datos durante un borrado lógico. El riesgo concreto está en borrados físicos, REPLACE y futuros procesos de purga; hay que revisar cada uso, no retirar todas las cascadas automáticamente.

## Fase R: correcciones y refactorización previa

Todas las tareas están pendientes. Ejecutarlas en cambios pequeños y revisables.

### R0. Fijar la línea base

- Inventariar rutas de escritura, tablas, relaciones y cálculos financieros.
- Conservar un respaldo de una base representativa y sus totales: stock, costos, pagos, cobros, capital y saldos.
- Ejecutar análisis y pruebas existentes antes de tocar lógica; registrar resultados actuales, sin reutilizar como evidencia los informes antiguos.
- Cierre: línea base reproducible y cambios previos del usuario identificados.

### R1. Corregir integridad de mantenimiento y escrituras

- Propagar workspace del padre a todas las entidades creadas en una operación.
- Compartir reglas de visitas y precio acordado entre las pantallas que hoy usan caminos distintos.
- Sustituir REPLACE en altas de negocio. Un alta duplicada debe fallar o resolverse según una regla explícita; una edición no debe recrear el registro.
- Verificar que borrados lógicos, cancelaciones y anulaciones conservan historial y actualizan metadatos consistentemente.
- Cierre: pruebas dirigidas de workspace no predeterminado, repetición de alta sin pérdida de hijos, precio de la siguiente visita e historial conservado.

### R2. Unificar acceso y contexto local

- Extraer clientes, obras y gastos a repositorios; convertir `LocalStorageService` gradualmente en fachada de compatibilidad.
- Mantener servicios para cálculos y operaciones que coordinan varias tablas. Evitar SQL y lógica financiera en widgets.
- Inyectar base de datos y contexto de workspace. Toda consulta y mutación de negocio debe declarar su alcance.
- Establecer una sola base por sesión/workspace o aislamiento explícito en una base compartida. Resolver cierre de sesión y acceso offline a datos previamente autorizados.
- Cierre: cada acción de negocio tiene un único camino de escritura y no se consultan datos de otro workspace.

### R3. Normalizar identidades y representación de datos

- Inventariar IDs que no sean UUID y valores de workspace existentes. Diseñar la migración antes de cambiar el schema.
- Generar y persistir un mapa de traducción único; actualizar PK, FK y referencias JSON en una operación controlada. Evitar generar mapas independientes para dos copias de la misma base histórica.
- Separar revisión local y versión aceptada por el servidor; no usar incrementos offline como si fueran versiones confirmadas.
- Definir DTO con importes en centavos, fechas de negocio sin zona cuando corresponda e instantes de auditoría en UTC. Definir precisión de cantidades de inventario.
- Cierre: migración repetible, referencias válidas y mismos totales antes/después. La aplicación no exige reinstalar para actualizar.

### R4. Backup, rendimiento y experiencia de uso

- Exportar un snapshot coherente dentro de una transacción, validar workspace al restaurar y resolver descarga Web.
- Para V3, no restaurar un JSON encima de una sesión sincronizada sin protocolo de reimportación. La exclusión actual de Outbox exige una decisión explícita antes de conectar datos.
- Reducir consultas por fila del Dashboard, inventario y cobros; añadir índices según consultas reales y planes de ejecución.
- Reemplazar recargas completas por suscripciones de alcance acotado, paginar listas largas y controlar el ciclo de vida de streams.
- Consolidar tokens de tipografía, espaciado, color y estados comunes. Revisar móvil estrecho, tablet y escritorio, texto grande, teclado, foco, confirmaciones y errores.
- Cierre: cálculos equivalentes, backup/restore completos y medición documentada con volumen representativo. No es necesario rediseñar todas las vistas para empezar el backend.

## Fase C: cerrar el contrato antes del servidor

1. **Orden de cambios:** `BIGSERIAL` por sí solo no garantiza orden de commit. Propuesta para el volumen inicial: contador por workspace actualizado bajo bloqueo de fila, dentro de la misma transacción que la mutación y su registro de cambio. Todos los escritores deben usar ese camino. Validar rollback y concurrencia. Los huecos no deben interpretarse como pérdida de datos.
2. **Idempotencia:** clave `(workspace_id, operation_id)`, hash del contenido y resultado persistido atómicamente con la mutación. Mismo ID con contenido diferente se rechaza. Un rechazo temporal por dependencia no debe quedar cacheado para siempre; definir estados finales y reintentables.
3. **Atomicidad de negocio:** una compra con detalles y movimientos de stock requiere una unidad atómica; el orden topológico no evita una compra aplicada a medias. Definir comandos/agregados y resultados por unidad antes de decidir el formato del lote.
4. **Ediciones offline encadenadas:** definir creación con base inexistente, cambios sucesivos sobre la misma entidad y edición durante un push. Un ACK no puede borrar una edición posterior. El pull debe preservar operaciones locales pendientes.
5. **Conflictos:** comenzar con OCC explícito para maestros. El merge por campo requiere snapshot base e historial, todavía no definidos. Para ledger, especificar inmutabilidad y anulaciones compensatorias por entidad.
6. **Pull:** aplicar página y cursor en la misma transacción SQLite, con supresión de generación de Outbox durante ingestión. Un cursor del push no sustituye al cursor de pull.
7. **Bootstrap:** snapshot consistente con cursor de corte, paginación sobre ese snapshot, reanudación y caducidad. Tras instalarlo, consumir cambios posteriores. Definir resnapshot cuando expire la retención.
8. **Contrato portable:** formalizar entidades y DTO, límites, códigos de error y versiones. Representar cursores BIGINT como cadenas en JSON; fijar rango seguro para dinero y su serialización en Web/Node. Quitar `isSynced` del payload de negocio.
9. **Adjuntos:** fotografías por URL externa y PDFs en volumen persistente del VPS, conforme a la decisión del usuario. Corregir la propuesta previa de tickets S3/MinIO.
10. **Autorización:** el workspace procede de la sesión validada; IDs de usuario, versión, permisos y campos controlados por servidor no son confiables por venir en un payload.

Cierre: contrato con ejemplos válidos y casos de concurrencia, interrupción, dependencias y migración; las tareas posteriores implementan estas decisiones.

## Arquitectura y estructura objetivo

Monolito modular NestJS con PostgreSQL. Mantener módulos por dominio y una capa de sincronización transversal. La elección del ORM/migrador queda en la tarea S1, contrastando restricciones compuestas, transacciones, bloqueos y SQL de migración. No crear repositorios genéricos que permitan escribir cualquier tabla desde el payload.

Estructura prevista (solo README y PLAN existen inicialmente):

```text
server/layer/
  src/
    main.ts
    app.module.ts
    config/
    database/
    modules/
      auth/
      workspaces/
      operations/
      inventory/
      finance/
      sync/
      attachments/
      health/
  migrations/
  scripts/
    bootstrap/
    backup/
    restore/
    deploy/
  test/
  deploy/
    Dockerfile
    compose.local.yml
    compose.production.yml
    nginx/
  .env.example
  .dockerignore
  package.json
  README.md
  PLAN.md
```

La configuración de despliegue se mantendrá aquí. Migrar los README actuales de `infrastructure/` a enlaces hacia esta ubicación o archivarlos al implementar S1; actualizar también el README raíz. `packages/sync-contract` sigue siendo compartido y debe incluirse explícitamente en el contexto de build si el servidor lo consume. Los volúmenes de datos, secretos y respaldos reales quedan fuera del código versionado.

## Fase S: implementación y despliegue

| Hito | Depende de | Entregables | Criterio de cierre |
|---|---|---|---|
| S1 Base central (T-22) | R1–R3, C | NestJS, ORM elegido, PostgreSQL local, migraciones, índices, workspaces/miembros, tablas de negocio, log de cambios/idempotencia | Migraciones sobre base vacía y actualización; restricciones XOR y referencias del mismo workspace comprobadas |
| S2 Auth (T-23) | S1 | Bootstrap administrativo de workspace y dos usuarios; Argon2id, sesiones revocables, refresh rotatorio, roles, health, validación y logs | Login/refresh/logout, revocación y acceso cruzado denegado; límites de petición desde el inicio |
| S3 Cliente y Outbox (T-24/25) | S2, R2/R3 | HTTP separado de repositorios, login, deviceId, almacenamiento de sesión, migración Outbox, transacciones de negocio+cola | Si falla cola falla cambio; sesión offline definida; política Web explícita, sin asumir que el navegador ofrece la misma protección que Android |
| S4 Push (T-26) | S3 | Procesador por comandos/agregados, autorización, OCC, idempotencia, ACK y reintentos | Timeout y reenvío no duplican; compra no queda aplicada a medias; edición durante envío se conserva |
| S5 Pull y bootstrap (T-27/28) | S4 | Feed paginado, snapshot inicial, cursor persistente, ingestión y retención | Segunda instalación recupera datos; interrupción reanuda; ninguna página pisa ediciones locales pendientes |
| S6 Conflictos y automatización (T-29/30/31) | S5 | UI comprensible de conflictos, estados de sync, backoff y coordinación de workers | Cambios offline de ambos socios convergen; sin workers simultáneos que dupliquen procesamiento |
| S7 PDFs (T-32) | S2/S5 | Upload separado, límites, validación del archivo, permisos, metadata y descarga protegida | PDF disponible en ambos dispositivos; acceso de otro workspace denegado; volumen persistente |
| S8 Despliegue y recuperación (T-34–38) | S6/S7 | Imagen reproducible, Compose, Nginx/HTTPS, migraciones de despliegue, secretos, backup DB+PDF externo, restore y rollback documentados | Staging funciona desde Internet; restauración en instancia limpia; DB privada y reinicio sin pérdida |
| S9 Validación conectada (T-39–45) | S8, R4 | E2E A/B y Web/Android, auditoría de seguridad, métricas, volumen, retención y compatibilidad | Stock, jornadas, pagos, cobros, capital y margen idénticos tras reconexión; cliente obsoleto recibe respuesta definida |
| S10 Migración y release (T-46–50) | S9 | Firma Android, build Web, ensayo de importación canónica, conciliación, bootstrap del segundo socio y runbook | Conteos y finanzas iguales; recuperación ensayada; solo entonces tag y entrada de datos reales |

Docker/PostgreSQL local pueden usarse desde S1 para desarrollo reproducible. S8 añade el despliegue operativo completo. Seguridad y observabilidad comienzan en S1/S2; T-41/T-42 son revisiones de cierre, no el primer momento en que se implementan.

FCM/T-33 queda opcional después de la primera versión conectada. Un aviso push solo informa de cambios; el estado se obtiene mediante pull.

## Escenarios de aceptación obligatorios

- A crea un cliente y B lo recibe; B crea una obra y A la recibe.
- Ambos crean gastos distintos offline y se conservan ambos.
- Ambos editan el mismo cliente: se detecta conflicto y ninguna edición desaparece sin resolución.
- Cierre durante push, durante pull y durante bootstrap; recuperación sin duplicados ni cursor adelantado.
- Alta y varias ediciones offline de la misma entidad, incluyendo una mientras llega el ACK.
- Compra y sus movimientos: aplicación completa o rechazo completo.
- Dos transacciones servidor concurrentes con confirmación en orden adverso: ningún cambio se pierde en pull.
- Petición con IDs de otra empresa, incluso dentro de relaciones: rechazada sin revelar datos.
- Base histórica con IDs antiguos: importación única, segunda ejecución idempotente y segundo dispositivo por descarga.
- Base restaurada junto con PDFs: clientes recuperan una sesión/cursor válidos o se les exige bootstrap controlado. Definir una época del servidor para invalidar cursores después de una restauración que retroceda el historial.

## Primer paquete de implementación

R0 y R1 constituyen el siguiente trabajo de código: comprobar línea base, corregir herencia de workspace, unificar el ciclo de mantenimiento y retirar REPLACE de altas relacionadas. Después R2/R3 preparan el Outbox. Cada paquete entrega cambios, pruebas relevantes y evidencia de conservación financiera.

No conviene iniciar a la vez un rediseño general de pantallas, la API completa y la migración de datos: el criterio de avance es cerrar los riesgos de integridad antes de conectar dispositivos.

## Fuentes técnicas consultadas

- [SQLite: ON CONFLICT / REPLACE](https://www.sqlite.org/lang_conflict.html): REPLACE elimina la fila previa ante conflicto de clave. El riesgo con relaciones depende de las FK y de la operación concreta.
- [PostgreSQL: funciones de secuencia](https://www.postgresql.org/docs/current/functions-sequence.html): las secuencias pueden tener huecos y sus avances no se revierten como una mutación ordinaria. El ejemplo de commits fuera de orden y el contador transaccional son razonamiento y propuesta de diseño para este proyecto.
