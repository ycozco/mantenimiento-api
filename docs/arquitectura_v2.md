# 🏛️ Documento de Arquitectura del Sistema (V2)
## Decolumax / Field Operations & CMMS Core

> **Estado del Ciclo de Vida del Proyecto**:
> - **V1 (JSON Monolítico)**: Histórico (Línea base original concluida).
> - **V2 Local (Drift SQLite / Full FSM / CMMS)**: **Cerrada y congelada con tag de seguridad `v2-local-ready`** (Commit `ba2695e1d5184923aa8840a7d7ccac0dde99b320`).
> - **V3 Connected (Monorepo / Schema 4 / Multi-Workspace / Sync Protocol)**: **Fase actual en desarrollo activo** (Iniciada en T-20 en rama `feature/v3-foundation`).

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

---

## 10. Arquitectura Objetivo V2 → V3 Conectada

Este apartado establece formalmente el contrato arquitectónico para que la base de código actual (V2 local con Drift/SQLite) evolucione limpiamente hacia una plataforma multiusuario conectada (V3) sin reescrituras estructurales.

### 10.1 Fuentes de Verdad y Filosofía Local-First
- **Fase V2 (Offline / Sin Servidor)**: Drift/SQLite en el dispositivo es la única fuente de verdad operacional.
- **Fase V3 (Conectada / Multiusuario)**:
  - **SQLite Local**: Fuente de verdad local inmediata para lectura y escritura offline con latencia cero ($O(1)$). Permite trabajar sin conexión en obra o campo.
  - **PostgreSQL Remoto**: Fuente de verdad centralizada, consolidada y autoritativa para el negocio.
  - **Invariante**: La adopción de PostgreSQL **NUNCA** reemplaza ni elimina Drift del cliente; SQLite se mantiene permanentemente como motor de persistencia offline-first en los clientes.

### 10.2 Contrato Mínimo de Entidad Sincronizable
Toda entidad de negocio sincronizable debe implementar el siguiente contrato de campos:
1. `id` (UUID v4 generado en el cliente al crear el registro).
2. `workspace_id` (UUID del espacio de trabajo compartido; por defecto `00000000-0000-0000-0000-000000000001` para Decolumax).
3. `created_at` (Timestamp UTC de creación).
4. `updated_at` (Timestamp UTC de última modificación).
5. `version` (Entero incremental optimista; inicia en 1 y se incrementa en cada mutación).
6. `deleted_at` (Timestamp UTC para soft delete / tombstone; `null` si está activa).
7. `created_by` / `updated_by` (UUIDs de auditoría para trazabilidad de usuario cuando aplique).

**Regla de Oro de Infraestructura**:
Las entidades de negocio **NO** deben contener banderas como `isSynced`, `synced` o `uploaded`. El estado de sincronización es una responsabilidad estricta de la capa de infraestructura representada por la tabla `sync_queue` (Outbox).

### 10.3 Regla Transaccional Local (Invariante Outbox)
Toda mutación de datos de negocio debe ejecutarse atómicamente junto con su registro en la cola de sincronización:
```sql
BEGIN TRANSACTION;
  -- 1. Modificar entidad localmente en SQLite
  INSERT/UPDATE/DELETE INTO entidad (...);
  -- 2. Registrar evento Outbox en la cola
  INSERT INTO sync_queue (workspace_id, entity_table, entity_id, operation, payload_json, queued_at)
  VALUES (...);
COMMIT;
```
*Prohibición*: Nunca persistir una entidad en SQLite y posteriormente, fuera de la transacción, intentar encolar la operación. Si la cola falla, el cambio local debe abortarse (rollback) para garantizar consistencia.

### 10.4 Protocolo de Sincronización (Push / Pull)
- **Push (`POST /sync/push`)**:
  - El cliente envía periódicamente (o al recuperar conexión) el lote de operaciones pendientes de `sync_queue`.
  - Estructura conceptual del ítem:
    ```json
    {
      "workspaceId": "00000000-0000-0000-0000-000000000001",
      "entityType": "work_logs",
      "entityId": "e3b0c442-98fc-1c14-9afb-4c7b6c501192",
      "operation": "UPSERT",
      "version": 1,
      "data": { ... }
    }
    ```
  - Al recibir confirmación HTTP 200/204 con los IDs procesados, el cliente purga los registros correspondientes de `sync_queue`.
- **Pull (`GET /sync/pull?cursor=...`)**:
  - El cliente solicita los cambios remotos ocurridos desde su último cursor confirmado (`cursor` = timestamp UTC o token secuencial).
  - El servidor responde: `{ "changes": [...], "nextCursor": "2026-10-04T21:00:00Z" }`.
  - El cliente aplica las mutaciones entrantes dentro de una transacción local SQLite y actualiza su cursor local.

### 10.5 Estrategia de Resolución de Conflictos
Se descarta el uso de CRDTs por complejidad innecesaria. La resolución se basa en:
1. **Entidades Editables (Catálogos y Datos Maestros)**:
   - Clientes, Proveedores, Nombres, Teléfonos, Notas, Ubicaciones.
   - Aplica *Last Write Wins* (LWW) condicionado por `version` y `updated_at`. Si la versión remota es superior, la actualización remota prevalece.
2. **Eventos Financieros y Operacionales Críticos (Inmutabilidad de Ledger)**:
   - `work_logs`, `labor_payments`, `stock_movements`, `capital_movements`, `collections`.
   - **Regla Estricta**: **Nunca se sobrescribe silenciosamente la historia financiera**.
   - Los registros de ledger no se editan destructivamente. Cualquier corrección se modela como un nuevo evento explícito (anulación mediante `deleted_at` + nuevo registro compensatorio/corrector) preservando la trazabilidad de auditoría.

### 10.6 Estrategia de Archivos: PDFs, Imágenes y Adjuntos
- **No Sobrecargar la Base de Datos**: Ni SQLite ni PostgreSQL deben almacenar binarios (BLOBs) ni strings base64 pesados. Solo almacenan tipos primitivos, URLs y metadatos.
- **Imágenes (Evidencias de Obra, Visitas, Perfiles)**:
  - Se utilizan URLs externas públicas o privadas (ImgBB, Google Drive u otros hostings HTTPS compatibles).
  - La base de datos almacena exclusivamente `url`, `mime_type`, `file_name` y `file_size_bytes`.
  - El cliente Flutter descarga y renderiza mediante caché de imágenes HTTP.
- **Documentos PDF (Comprobantes, Informes, Planos, Actas)**:
  - Los PDFs se almacenan en el sistema de archivos del servidor (volumen persistente en VPS o almacenamiento S3-compatible).
  - PostgreSQL y SQLite almacenan únicamente la metadata: `storage_key` (ej. `workspace/docs/informe_01.pdf`), tamaño en bytes y checksum.
  - Se accede al documento mediante endpoints autenticados o URLs firmadas temporales generadas por la API.
- **Modelo Unificado de `attachments`**:
  - La tabla `attachments` soporta ambos mundos:
    - *Imágenes*: `kind = 'image'`, `provider = 'external_url'`, `url = 'https://...'`, `storage_key = null`.
    - *PDFs de Servidor*: `kind = 'pdf'`, `provider = 'server'`, `url = null`, `storage_key = 'decolumax/2026/acta.pdf'`.

### 10.7 Arquitectura Futura del Repositorio (Monorepo)
En una etapa posterior de infraestructura se estructurará el repositorio como monorepo sin alterar la historia Git:
```text
mantenimiento/
  apps/
    client/          <-- Proyecto Flutter actual (Mobile & Web)
    api/             <-- Backend futuro (NestJS / FastAPI / etc.)
  infrastructure/
    docker/          <-- Dockerfiles para API y servicios
    reverse-proxy/   <-- Configuración Nginx o Caddy (SSL automático)
    postgres/        <-- Scripts de inicialización y migraciones SQL
    backup/          <-- Scripts cron de backup y rotación diaria
  docs/              <-- Documentación maestra del sistema
  docker-compose.yml <-- Orquestador de servicios en VPS
  .env.example       <-- Plantilla de variables de entorno requeridas
  README.md
```
*Aclaración*: Por el momento no se mueven carpetas; el proyecto Flutter permanece en la raíz del workspace hasta la tarea específica de reestructuración monorepo.

### 10.8 Estrategia Git y Ciclo de Vida de Ramas
- No existirán ramas de backend separadas de forma permanente.
- Se utiliza un flujo *Trunk-based development*:
  - Rama principal: `master` (o `main`).
  - Ramas de características cortas: `feature/t03-labor-payments`, `feature/sync-gateway`, etc.
  - Al completar y validar las pruebas de cada feature, se hace merge a la rama principal. El backend vivirá en `apps/api` dentro del mismo árbol.

### 10.9 Despliegue en VPS Linux con Docker Compose
- **Entorno de Producción**: Servidor VPS Linux económico (2 vCPU, 4GB RAM) ejecutando Docker Compose.
- **Servicios Orquestados**:
  1. `reverse-proxy`: Caddy o Nginx con HTTPS automático (Let's Encrypt).
  2. `api`: Contenedor stateless del backend.
  3. `postgres`: PostgreSQL 16 sobre volumen Docker nombrado y persistente.
  4. `backup`: Contenedor ligero que ejecuta `pg_dump` programado (cron) con compresión y rotación hacia almacenamiento persistente desacoplado.
- **Regla de Persistencia**: Los contenedores deben ser 100% efímeros y descartables. Cero almacenamiento crítico dentro de la capa de escritura del contenedor.
- **Prudencia Operacional**: Se descarta Kubernetes, microservicios, Redis inicial y RabbitMQ inicial para evitar sobreingeniería innecesaria.

### 10.10 Configuración y Seguridad
- Todas las variables sensibles se cargan mediante variables de entorno (`.env` local en servidor, jamás versionado en Git).
- Plantilla obligatoria `.env.example`:
  ```bash
  APP_ENV=production
  API_PORT=3000
  DATABASE_HOST=postgres
  DATABASE_PORT=5432
  DATABASE_NAME=mantenimiento_db
  DATABASE_USER=decolumax_user
  DATABASE_PASSWORD=CHANGE_THIS_IN_PRODUCTION
  JWT_SECRET=CHANGE_THIS_IN_PRODUCTION_SUPER_SECRET
  PDF_STORAGE_PATH=/data/pdfs
  MAX_PDF_SIZE_MB=15
  BACKUP_PATH=/data/backups
  ```

### 10.11 Modelo de Autenticación Futura
- **Separación de Conceptos**:
  - `User`: Identidad con credenciales (email/contraseña, hash, JWT, rol administrativo o de campo).
  - `Worker`: Personal operativo de cuadrilla (no necesariamente tiene usuario ni acceso al sistema).
  - `Partner`: Socio capitalista/gestor; puede asociarse biunívocamente a un `User` si utiliza la app.
- **Estructura Inicial**:
  - Workspace: `Decolumax`
  - Usuarios: `Socio A` y `Socio B`
- **Tokens**:
  - Autenticación mediante `accessToken` (corta duración) y `refreshToken` (larga duración con rotación).
  - En Flutter Mobile los tokens se guardan exclusivamente en almacenamiento seguro nativo (`flutter_secure_storage` / KeyStore / Keychain).

### 10.12 Plataformas: Flutter Mobile vs. Flutter Web
- **Código Compartido**: Ambas plataformas comparten el 100% del dominio, DAOs de Drift, modelos, lógica de negocio y repositorios.
- **Especialización de Interfaz**:
  - **Mobile (Android / iOS)**: Diseñado para ergonomía táctil en campo, ingreso rápido de jornales, registro de visitas offline, captura fotográfica y consulta rápida de saldos.
  - **Web**: Diseñado para administración en escritorio, reportes consolidados, exportaciones contables, configuración de tarifas y visión global de obras.

---

## 11. Servicios y Módulos Operacionales V2 (T-11 a T-16)

### 11.1 Dashboard Operacional (`DashboardService` / T-11)
Servicio central de agregación en tiempo real que recopila indicadores accionables de obras activas, presupuestos, cobros, margen bruto, saldo laboral pendiente, productos bajo stock mínimo/agotados, visitas programadas/vencidas y herramientas asignadas sin duplicar cálculos de `ProjectFinancialService`.

### 11.2 Calendario y Agenda Unificada (`CalendarService` / T-12)
Modelo derivado en memoria (`CalendarEvent`) que consolida cronológicamente eventos desde tres fuentes operativas (Visitas de Mantenimiento, Hitos/Fechas de Obras y Devoluciones de Herramientas) con filtrado y navegación directa al detalle.

### 11.3 Gestión de Adjuntos (`AttachmentRepository` / T-13)
Almacenamiento de evidencias y documentación respetando la regla de **cero BLOBs / cero Base64 en SQLite**. Admite URLs externas con validación estricta de esquemas HTTPS y referencias a PDFs locales con verificación segura de existencia física en el dispositivo (`isLocalFileAvailable`).

### 11.4 Separación Empresa vs. Dispositivo (`SettingsRepository` & `DevicePreferencesService` / T-14)
- **Configuración de Empresa/Workspace (`CompanySettings`)**: Persistida en SQLite (`app_metadata`), sincronizable y respaldable (Nombre comercial, RUC, moneda PEN, zona horaria Lima, switch de stock negativo).
- **Preferencias del Dispositivo (`DevicePreferences`)**: Almacenadas en `SharedPreferences` locales, no sincronizables ni exportadas al backup de negocio (tema visual, notificaciones locales).

### 11.5 Notificaciones Locales V2 (`NotificationScheduleEngine` / T-15)
Motor puro de cálculo que programa alertas anticipadas para visitas de mantenimiento (`MaintenanceVisit.scheduledDate`) a los -7, -3, -2 y -1 días a las 09:00 AM, empleando IDs determinísticos de 32 bits para cancelación exacta en reprogramaciones o completados.

### 11.6 Respaldo y Restauración Integral V2 (`BackupRestoreService` / T-16)
Exportación e importación transaccional (`backupFormatVersion: 2`, `schemaVersion: 3`) que cubre las 21 tablas de negocio en Drift respetando el orden estricto de Foreign Keys, garantizando reversión atómica (ROLLBACK) ante cualquier inconsistencia, y excluyendo infraestructura efímera (`sync_queue`).

### 11.7 Navegación y Adaptabilidad Multiplataforma (`AppResponsive` / T-17)
- **Breakpoints Centralizados**: Definición unificada de tres anchos clave (`compact` < 600px, `medium` 600-840px, `expanded` >= 840px) en `AppResponsive`.
- **Navegación Adaptativa**: `HomeScreen` conmuta automáticamente entre `NavigationBar` en pantallas compactas/móviles y `NavigationRail` en tabletas/escritorio/web.
- **Jerarquía Simplificada**: 5 destinos principales (Inicio/Dashboard, Obras, Mantenimientos, Finanzas, Más) con acceso directo a sub-módulos y vistas especializadas (Inventario, Herramientas, Personal, Socios, Clientes, Calendario, Ajustes).
- **Vistas de Estado Estandarizadas**: Componentes reactivos reutilizables (`LoadingStateView`, `EmptyStateView`, `ErrorStateView`) para garantizar retroalimentación visual en toda la app sin pantallas en blanco ni overflows.

### 11.8 Modelo Económico de Mantenimientos (`MaintenanceFinancialService` / T-18)
- **Modalidades de Cobro**:
  - `perVisit`: Tarifa pactada cobrada por visita individual.
  - `monthly`: Tarifa mensual fija para el plan de mantenimiento. Las visitas dentro del mismo mes se agrupan cronológicamente (`year * 12 + month`) para no multiplicar falsamente los ingresos.
  - `custom`: Importe presupuestado ad-hoc o variable.
- **Snapshot Histórico Inmutable**: Toda visita (`MaintenanceVisit`) almacena su `agreedPriceCents` congelado al momento de su creación/ejecución. Modificaciones posteriores a la tarifa del plan padre no alteran el precio acordado de visitas históricas.
- **Asociación de Cobros**: `Collection` soporta imputación directa a `projectId`, `visitId` o `planId` bajo regla estricta XOR.
- **Métricas Financieras Derivadas Puras**: `MaintenanceFinancialService` calcula en tiempo real `revenueCents`, `collectedCents`, `receivableCents`, `laborCostCents`, `materialCostCents`, `expensesCents`, `totalCostCents`, `grossMarginCents` y `grossMarginPercent` sin almacenar valores calculados en SQLite.


