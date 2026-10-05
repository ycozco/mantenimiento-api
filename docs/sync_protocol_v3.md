# 📡 Protocolo de Sincronización V3 — Decolumax Connected
## Especificación Maestra de Contrato Cliente-Servidor (T-21)

---

## 1. Principios de Diseño del Protocolo (T-21.1)

El protocolo de sincronización V3 de Decolumax está gobernado por los siguientes principios rectores:

1. **Local-First & Offline-First**: La base de datos local SQLite (mediante Drift en `apps/client`) es la fuente primaria e inmediata de verdad para la interfaz de usuario. Cualquier creación, edición o anulación se realiza localmente en milisegundos sin requerir conexión a internet.
2. **Server-Mediated**: La nube no es un mero repositorio pasivo de archivos, sino la autoridad central de serialización, validación de reglas de negocio, asignación de secuencias monotónicas y control de concurrencia.
3. **Multi-Device & Multi-Partner**: Múltiples técnicos y socios operan en cuadrillas independientes con dispositivos móviles o terminales web, convergiendo de manera consistente.
4. **Workspace Isolated (Multi-Tenant)**: Todos los registros pertenecen estrictamente a un `workspaceId`. El aislamiento es vertical y absoluto; no es posible consultar ni modificar entidades entre diferentes espacios de trabajo.
5. **Idempotent**: El protocolo tolera caídas de red, reintentos agresivos, desconexiones intermedias y duplicación de paquetes sin corromper el estado ni duplicar movimientos financieros.
6. **Incremental**: Los dispositivos intercambian únicamente diferenciales de cambio (*deltas*) desde el último punto de control sincronizado, optimizando ancho de banda y batería en redes móviles precarias.
7. **Versioned & Auditable**: Cada mutación conserva marcas temporales del cliente (`clientUpdatedAt`), marcas del servidor (`serverReceivedAt`), versión de entidad (`version`), identificador del dispositivo emisor (`deviceId`) y actor (`userId`).

### Flujo Bidireccional de Datos

```text
[ Cliente Móvil / Flutter SQLite ]
       │
       ▼ (Mutación local en transacción)
  [ Outbox / sync_queue ]
       │
       ▼ (Worker asíncrono con backoff)
  POST /api/v1/sync/push
       │
       ▼ (Validación auth, schema, dependencias, idempotencia)
  [ Backend NestJS / API Server ]
       │
       ▼ (Asignación de secuencia monotónica server_seq y version++)
  [ PostgreSQL Master Database ]
       │
       ▲ (Solicitud incremental con cursor server_seq)
   GET /api/v1/sync/pull?cursor=...
       │
       ▲ (Retorno de changes[], nextCursor, hasMore)
[ Ingestion Engine en Cliente ] ──► (Transacción ACID local SQLite)
```

---

## 2. Modelo de Identidad Distribuida (T-21.2)

En un entorno local-first distribuido, **ningún identificador autoincremental de base de datos puede actuar como clave foránea o identidad de red**.

| Identificador | Formato | Ámbito | Propósito |
| :--- | :--- | :--- | :--- |
| `workspaceId` | UUIDv4 (o slug empresarial) | Global | Identifica la empresa o tenant titular de la información. |
| `userId` | UUIDv4 | Global / Auth | Identifica al usuario autenticado (socio, técnico, administrador). |
| `deviceId` | UUIDv4 | Dispositivo | Identificador persistente del terminal físico emitido durante el registro. |
| `entityId` | UUIDv4 | Entidad | Clave primaria inmutable de toda entidad de negocio (`clients`, `projects`, etc.). |
| `operationId` | UUIDv4 | Mutación | Identificador criptográfico único de cada acción encolada en el Outbox. |

> **Nota:** La columna `sync_queue.id` local en SQLite puede permanecer como `INTEGER PRIMARY KEY AUTOINCREMENT` por eficiencia de ordenamiento FIFO local, pero **en el cable y en PostgreSQL la identidad de la operación es estrictamente `operationId` (UUID)**.

---

## 3. Contrato de Subida: PUSH (T-21.3)

### Endpoint
`POST /api/v1/sync/push`

### Headers Requeridos
- `Authorization`: `Bearer <jwt_access_token>`
- `Content-Type`: `application/json`
- `X-Client-Schema-Version`: `4`
- `X-Client-App-Version`: `3.0.0`

### Payload de Solicitud (Request Body)
```json
{
  "workspaceId": "550e8400-e29b-41d4-a716-446655440000",
  "deviceId": "b1b72a6b-95bb-41cf-8e7c-b166299ad001",
  "clientSchemaVersion": 4,
  "operations": [
    {
      "operationId": "c3d9a184-7cf6-4df1-bc44-59e20cb6b110",
      "entityType": "work_log",
      "entityId": "a904128f-7d1a-4f51-b841-f67a216e53c4",
      "operation": "UPSERT",
      "baseVersion": 2,
      "clientUpdatedAt": "2026-10-05T14:30:00.000Z",
      "payload": {
        "id": "a904128f-7d1a-4f51-b841-f67a216e53c4",
        "workspaceId": "550e8400-e29b-41d4-a716-446655440000",
        "workerId": "f103982e-839e-4a67-8c29-37f093bb291a",
        "projectId": "729cf329-8731-4c12-9c1a-28173491ba38",
        "maintenanceVisitId": null,
        "date": "2026-10-05",
        "hoursWorked": 8.0,
        "daysWorked": 1.0,
        "paymentMode": "daily",
        "calculatedCost": 80.00,
        "notes": "Instalación de grass sintético bloque A",
        "isSynced": true,
        "version": 3,
        "createdAt": "2026-10-05T14:30:00.000Z",
        "updatedAt": "2026-10-05T14:30:00.000Z",
        "deletedAt": null
      }
    }
  ]
}
```

### Respuesta del Servidor (Response Body) — HTTP 200 OK
```json
{
  "serverCursor": "104928",
  "processedAt": "2026-10-05T14:30:01.120Z",
  "accepted": [
    {
      "operationId": "c3d9a184-7cf6-4df1-bc44-59e20cb6b110",
      "entityType": "work_log",
      "entityId": "a904128f-7d1a-4f51-b841-f67a216e53c4",
      "assignedVersion": 3,
      "serverSeq": 104928
    }
  ],
  "conflicts": [],
  "rejected": []
}
```

---

## 4. Contrato de Descarga: PULL (T-21.4 & T-21.13)

### Endpoint
`GET /api/v1/sync/pull?cursor=104900&limit=500`

### Query Parameters
- `cursor` (opcional, default `0`): Secuencia monotónica entera del servidor (`server_seq`). Si es omitido o `0`, inicia sincronización completa (*initial sync*).
- `limit` (opcional, default `500`, máx `1000`): Tamaño del lote para paginación transaccional.

### Respuesta del Servidor (Response Body) — HTTP 200 OK
```json
{
  "changes": [
    {
      "serverSeq": 104901,
      "entityType": "client",
      "entityId": "8b37e2a1-6387-432d-9657-6e974e64db2a",
      "operation": "UPSERT",
      "version": 4,
      "updatedAt": "2026-10-05T12:00:00.000Z",
      "payload": {
        "id": "8b37e2a1-6387-432d-9657-6e974e64db2a",
        "workspaceId": "550e8400-e29b-41d4-a716-446655440000",
        "name": "Condominio Las Praderas",
        "phone": "+51999888777",
        "email": "administracion@laspraderas.pe",
        "documentType": "RUC",
        "documentNumber": "20601234567",
        "address": "Av. Primavera 123",
        "notes": "Cliente corporativo A1",
        "version": 4,
        "createdAt": "2026-09-01T08:00:00.000Z",
        "updatedAt": "2026-10-05T12:00:00.000Z",
        "deletedAt": null
      }
    }
  ],
  "nextCursor": "104901",
  "hasMore": false,
  "serverTime": "2026-10-05T14:30:05.000Z"
}
```

### Justificación de Cursor Monotónico vs. Timestamp
**Queda terminantemente prohibido utilizar `updatedAt` como cursor de pull.**
- **Problema de timestamps:** Relojes de servidores distribuidos sufren de *clock skew* (deriva NTP). Transacciones concurrentes que duran 200ms pueden comprometerse con un timestamp anterior a lecturas ya ejecutadas, provocando que el cliente omita registros silenciosamente (*lost updates*).
- **Decisión V3:** El cursor es un entero de 64 bits (`BIGINT`) emitido por una secuencia PostgreSQL (`server_seq BIGSERIAL`). Es estrictamente creciente, monotónico y continuo por workspace.

---

## 5. Garantía de Idempotencia (T-21.5)

Cada mutación local genera un `operationId` (UUIDv4) antes de ser insertada en la `sync_queue`.

En PostgreSQL, el backend mantiene una tabla de auditoría de idempotencia:
```sql
CREATE TABLE sync_idempotency_log (
  workspace_id UUID NOT NULL,
  operation_id UUID NOT NULL,
  device_id UUID NOT NULL,
  entity_type VARCHAR(64) NOT NULL,
  entity_id UUID NOT NULL,
  status VARCHAR(32) NOT NULL, -- 'ACCEPTED', 'CONFLICT', 'REJECTED'
  server_seq BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  response_payload JSONB NOT NULL,
  PRIMARY KEY (workspace_id, operation_id)
);
```

**Comportamiento ante reenvío por timeout de red:**
Si el cliente envía un lote conteniendo un `operationId` ya registrado:
1. El backend detecta la clave primaria duplicada `(workspace_id, operation_id)`.
2. **No ejecuta nuevamente la mutación** en la tabla de negocio.
3. Retorna en la lista `accepted` la respuesta cacheada original con su `assignedVersion` y `serverSeq`.
4. El cliente confirma la operación y purga la fila de su `sync_queue`.

---

## 6. Modelo de Versionado Optimista (T-21.6)

Toda entidad sincronizable posee una columna entera `version INT NOT NULL DEFAULT 1`.
- Al crear una entidad localmente, nace con `version = 1`.
- En el push, el cliente envía `baseVersion` (la versión que tenía la entidad cuando el cliente inició la mutación).
- El servidor compara `baseVersion` con la `version` actual en PostgreSQL:
  - **Coincidencia (`baseVersion == currentVersion`):** La mutación se acepta, se incrementa la versión a `currentVersion + 1`, se actualiza el registro y se registra en el log de cambios con un nuevo `server_seq`.
  - **Discrepancia (`baseVersion < currentVersion`):** La entidad fue modificada concurrentemente por otro terminal en el servidor. Se dispara el protocolo de resolución de conflictos.

---

## 7. Estrategia de Resolución de Conflictos por Categoría (T-21.7)

Decolumax rechaza la estrategia ingenua de *Last-Write-Wins (LWW)* global, pues provocaría corrupción destructiva en balances financieros y kardex. Las entidades se clasifican en tres grupos semánticos:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   CLASIFICACIÓN SEMÁNTICA DE CONFLICTOS                │
├─────────────────────────┬────────────────────────┬─────────────────────┤
│ GRUPO A: EVENTOS/LEDGER │ GRUPO B: MASTER DATA   │ GRUPO C: SETTINGS   │
├─────────────────────────┼────────────────────────┼─────────────────────┤
│ • stock_movements       │ • clients              │ • company_settings  │
│ • work_logs             │ • workers              │                     │
│ • labor_payments        │ • suppliers            │                     │
│ • expenses (gastos)     │ • tools                │                     │
│ • capital_movements     │ • projects (obras)     │                     │
│ • collections (cobros)  │ • maintenance_plans    │                     │
│ • purchases             │ • maintenance_visits   │                     │
├─────────────────────────┼────────────────────────┼─────────────────────┤
│ POLÍTICA: Append-Only / │ POLÍTICA: Optimistic   │ POLÍTICA: Workspace │
│ Event Sourcing / Void   │ Concurrency / Merge por│ Authority / Locked  │
│ No sobreescritura       │ campo / LWW no crítico │ Version             │
└─────────────────────────┴────────────────────────┴─────────────────────┘
```

### Grupo A — Eventos Financieros y Kardex (Ledger)
- **Principio:** Los registros contables y movimientos físicos son inmutables por naturaleza.
- **Inserción concurrente:** Si el Socio A registra un Gasto de S/ 50 y el Socio B registra un Gasto de S/ 100 simultáneamente en modo offline, **ambos se aceptan y se suman**. No hay colisión porque cada uno posee un `entityId` UUID único.
- **Edición / Anulación:** Si un socio intenta editar un gasto cuya versión ya cambió en el servidor, el servidor emite `VERSION_CONFLICT`. La anulación se gestiona preferentemente como transacción inversa (*contra-asiento* o soft delete explícito).

### Grupo B — Master Data (Entidades Operativas)
- Si ambos socios editan el mismo `Client` en offline (ej. Socio A actualiza el teléfono y Socio B actualiza la dirección):
  - El servidor aplica fusión a nivel de campo (*field-level merge*) si no hay campos en conflicto directo.
  - Si colisiona el mismo campo exacto, la versión del servidor prevalece y se reporta en `conflicts[]` para que el cliente actualice su vista local.

### Grupo C — Configuración de Empresa (Settings)
- `CompanySettings` es un registro único por workspace.
- Requiere `baseVersion` estricta. Si colisiona, se rechaza con `VERSION_CONFLICT` y se requiere confirmación manual del usuario.

---

## 8. Eliminación Lógica y Lápidas / Tombstones (T-21.8)

1. En el sistema distribuido V3, **está prohibido ejecutar `DELETE` físico** sobre tablas de negocio durante la operación habitual.
2. Toda eliminación es un borrado lógico:
   ```json
   {
     "operation": "UPSERT",
     "payload": {
       "id": "...",
       "deletedAt": "2026-10-05T14:40:00.000Z",
       "version": 5
     }
   }
   ```
3. El endpoint de PULL transporta registros con `deletedAt != null` (*tombstones*).
4. El cliente local ejecuta el soft delete en SQLite actualizando `deleted_at = ?`, garantizando que consultas normales excluyan el registro pero preservando la integridad referencial histórica.
5. El purgado físico (*hard delete / vacuum*) sólo se ejecuta tras un período de retención mínimo (ej. 90 días) mediante procedimientos de mantenimiento centralizados.

---

## 9. Ordenamiento y Resolución de Dependencias (T-21.9)

Las entidades poseen dependencias estrictas de clave foránea:
```text
Client ──► Project ──► WorkLog
Client ──► MaintenancePlan ──► MaintenanceVisit
InventoryItem ──► StockMovement
Supplier ──► Purchase ──► PurchaseItem
```

### Estrategia en el Servidor: Two-Pass Dependency Ordering
Cuando un lote de push contiene múltiples operaciones interdependientes (por ejemplo, creación offline de un Cliente y simultáneamente una Obra asociada):
1. **Fase 1 (Topological Sort):** El servidor ordena internamente las operaciones según el grafo de dependencias de negocio (Maestros primero, Transaccionales después).
2. **Fase 2 (Deferred FK Validation):** Si una operación referencia un padre que no viene en el lote y no existe en PostgreSQL, se responde con código de error `DEPENDENCY_MISSING`, reteniendo la operación hija en la cola local del cliente hasta que el padre sea aceptado.

---

## 10. Gestión de Archivos Adjuntos y Documentos PDF (T-21.10)

**Regla de Oro: Ningún byte binario de imagen o archivo PDF transita por `/sync/push`.**

1. **Fotos de Evidencia:**
   - La foto se captura en el dispositivo y se guarda en almacenamiento local privado.
   - El cliente solicita una URL de subida prefirmada (S3/Cloud Storage/MinIO):
     `POST /api/v1/attachments/upload-ticket`
   - El cliente sube el archivo binario directamente al almacenamiento de objetos.
   - Una vez confirmada la subida, se genera la entidad de metadatos `Attachment` (`id`, `remoteUrl`, `fileSize`, `mimeType`, `relatedEntityType`, `relatedEntityId`).
   - Los metadatos de `Attachment` se sincronizan mediante el flujo regular de `/sync/push`.
2. **Presupuestos y Reportes PDF:**
   - Se generan dinámicamente bajo demanda o se almacenan sus metadatos con enlace de descarga autenticado.

---

## 11. Autenticación y Autorización Multi-Tenant (T-21.11)

1. Todas las peticiones a la API requieren cabecera:
   `Authorization: Bearer <accessToken>`
2. El servidor valida la firma criptográfica del JWT y extrae las reclamaciones:
   - `sub`: Identificador de usuario (`userId`).
   - `workspaces`: Lista de identificadores de workspace a los que el usuario tiene acceso y sus roles (`ADMIN`, `OPERATOR`, `AUDITOR`).
3. **Validación Antifraude:** El servidor **no confía ciegamente en el `workspaceId` del payload JSON**. Si el `workspaceId` enviado no coincide con los permisos concedidos en el token de sesión, la petición es abortada inmediatamente con error `403 Forbidden` (`WORKSPACE_MISMATCH`).

---

## 12. Registro y Ciclo de Vida de Dispositivos (T-21.12)

Para auditar el acceso y detectar dispositivos obsoletos o robados:

### Tabla PostgreSQL: `devices`
```sql
CREATE TABLE devices (
  device_id UUID PRIMARY KEY,
  workspace_id UUID NOT NULL,
  user_id UUID NOT NULL,
  platform VARCHAR(32) NOT NULL, -- 'android', 'web', 'ios', 'windows'
  app_version VARCHAR(32) NOT NULL,
  client_schema_version INT NOT NULL,
  device_model VARCHAR(128),
  os_version VARCHAR(64),
  push_token VARCHAR(255),
  first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_revoked BOOLEAN NOT NULL DEFAULT FALSE
);
```

Si `is_revoked == true`, cualquier intento de PUSH o PULL desde ese `deviceId` es rechazado con error `401 Unauthorized` (`DEVICE_REVOKED`).

---

## 13. Paginación y Transaccionalidad de Lotes (T-21.13)

1. En el endpoint PULL, si el número de cambios pendientes supera `limit` (ej. 500):
   - El servidor retorna los primeros 500 registros.
   - Establece `hasMore: true` y entrega el `nextCursor` correspondiente al último registro de ese bloque.
2. **Garantía Transaccional en Cliente:** El cliente aplica cada bloque de 500 cambios dentro de una transacción exclusiva `appDatabase.transaction(() async { ... })`.
3. Sólo tras el éxito del commit en SQLite, el cliente persiste el nuevo `cursor` en sus preferencias y procede a solicitar la siguiente página. Si la app se cierra a mitad de proceso, no hay estado intermedio inconsistente.

---

## 14. Tratamiento de Relojes y Marcas de Tiempo (T-21.14)

1. Los relojes de los teléfonos inteligentes de los técnicos pueden estar atrasados, adelantados o alterados manualmente.
2. `clientUpdatedAt` se trata únicamente como **metadato testimonial de campo** ("según el teléfono, la obra se terminó a las 18:00").
3. El orden global del sistema, la prioridad de sincronización y las secuencias de cambio están gobernados exclusivamente por:
   - `serverReceivedAt`: Fecha y hora UTC inmutable registrada por el servidor PostgreSQL al recibir el paquete.
   - `serverSeq`: Entero monotónico secuencial emitido por la base central.

---

## 15. Modelo Canónico de Errores (T-21.15)

Toda respuesta de error sigue la estructura unificada RFC 7807 adaptada:

```json
{
  "errorCode": "VERSION_CONFLICT",
  "message": "La versión local de la entidad (baseVersion: 2) difiere de la versión actual en el servidor (version: 3).",
  "entityType": "client",
  "entityId": "8b37e2a1-6387-432d-9657-6e974e64db2a",
  "serverVersion": 3,
  "serverPayload": { ... },
  "retryable": false,
  "timestamp": "2026-10-05T14:45:00.000Z"
}
```

### Catálogo de Códigos de Error

| Código | HTTP | Semántica |
| :--- | :--- | :--- |
| `INVALID_PAYLOAD` | 400 | El cuerpo JSON no cumple con el esquema tipado o faltan campos obligatorios. |
| `UNAUTHORIZED` | 401 | Token JWT ausente, expirado, inválido o dispositivo revocado. |
| `WORKSPACE_MISMATCH` | 403 | El usuario no posee autorización sobre el `workspaceId` solicitado. |
| `ENTITY_NOT_FOUND` | 404 | Se intentó mutar o consultar una entidad inexistente en el espacio de trabajo. |
| `VERSION_CONFLICT` | 409 | Colisión concurrente en entidad master data o settings (`baseVersion < serverVersion`). |
| `DEPENDENCY_MISSING` | 422 | Clave foránea requerida aún no existe en el servidor. |
| `DUPLICATE_OPERATION` | 200/409 | `operationId` ya procesado previamente (idempotencia aplicada). |
| `SCHEMA_UNSUPPORTED` | 426 | La versión de schema del cliente es obsoleta y requiere actualización obligatoria. |

---

## 16. Compatibilidad y Negociación de Versiones (T-21.16)

Para gobernar el ciclo de vida sin romper clientes antiguos en campo:

1. Parámetros negociados en cabeceras:
   - `clientSchemaVersion: 4`
   - `apiVersion: 1` (`/api/v1/...`)
2. El servidor mantiene en configuración:
   - `MINIMUM_SUPPORTED_CLIENT_SCHEMA = 4`
   - `RECOMMENDED_APP_VERSION = 3.0.0`
3. Si un terminal con Drift Schema 3 intenta sincronizar contra la API V3:
   - El servidor rechaza la conexión con `HTTP 426 Upgrade Required` (`SCHEMA_UNSUPPORTED`).
   - El cliente presenta un diálogo no bloqueante sugiriendo actualizar la app o bloqueante si la brecha de datos es crítica.

---

## 17. Especificación Futura para el Outbox Local (`sync_queue`) (T-21.17)

En T-24 la base local avanza a `schemaVersion: 5`. La tabla `sync_queue` ya contiene la estructura canónica del Outbox, con migración Drift 4→5 que conserva las operaciones pendientes y genera un `operationId` para las filas históricas:

```sql
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  operation_id TEXT NOT NULL UNIQUE,       -- UUIDv4 de la operación para idempotencia
  workspace_id TEXT NOT NULL,              -- Aislamiento tenant
  entity_table TEXT NOT NULL,              -- 'clients', 'projects', 'work_logs', etc.
  entity_id TEXT NOT NULL,                 -- UUIDv4 de la entidad
  operation TEXT NOT NULL,                 -- 'UPSERT' o 'DELETE'
  base_version INTEGER NOT NULL DEFAULT 1, -- Versión sobre la cual se calculó el cambio
  payload_json TEXT NOT NULL,              -- Serialización JSON completa
  queued_at TEXT NOT NULL,                 -- Timestamp ISO-8601 local
  attempts INTEGER NOT NULL DEFAULT 0,     -- Contador de intentos de envío
  next_attempt_at TEXT NOT NULL,           -- Timestamp para backoff exponencial
  last_error TEXT,                         -- Detalle del último error reportado
  status TEXT NOT NULL DEFAULT 'PENDING'   -- 'PENDING', 'IN_FLIGHT', 'FAILED', 'COMPLETED'
);

CREATE INDEX sync_queue_status_idx ON sync_queue (status, next_attempt_at);
```

---

## 18. Vectores de Prueba del Protocolo (T-21.18)

A continuación se detallan los 12 casos de prueba canónicos que certificarán el motor de sincronización.

---

### Caso 1: Crear Cliente en Modo Offline
- **Estado Inicial:** Dispositivo sin conectividad. Base local con 0 clientes.
- **Acción:** El usuario crea el cliente "Jardines del Golf" (`clientId: uuid-c1`).
- **Encolamiento:** Se guarda en SQLite local `clients` (`version: 1`) y en `sync_queue` (`operationId: op-1`, `operation: UPSERT`, `baseVersion: 0`).
- **Push:** Al reconectar, envía `POST /sync/push` con `op-1`.
- **Respuesta Servidor:** `accepted: [{ operationId: "op-1", assignedVersion: 1, serverSeq: 101 }]`.
- **Pull:** El cliente consulta con `cursor: 0`. Recibe `serverSeq: 101`.
- **Estado Final:** `sync_queue` vacía. Cliente marcado como sincronizado (`isSynced: true`).

---

### Caso 2: Registrar Jornal de Trabajo (`WorkLog`) Offline
- **Estado Inicial:** Proyecto `uuid-p1` y Trabajador `uuid-w1` ya sincronizados.
- **Acción:** En campo, el técnico registra jornada de 8 horas para Juan Pérez (costo S/ 80.00).
- **Encolamiento:** `work_logs` insertado con `id: uuid-wl1`, `version: 1`. Fila creada en `sync_queue` (`op-2`).
- **Push:** Envía `op-2`.
- **Respuesta Servidor:** El servidor valida existencia de `uuid-p1` y `uuid-w1`, acepta con `assignedVersion: 1`, `serverSeq: 102`.
- **Estado Final:** Costo laboral acumulado visible en la obra tanto en local como en backend.

---

### Caso 3: Mismo `operationId` Enviado Dos Veces (Reintento por Timeout)
- **Estado Inicial:** Operación `op-3` enviada por el cliente. El servidor la procesó y asignó `serverSeq: 103`, pero la red se cayó antes de que el cliente recibiera el HTTP 200.
- **Push (Reintento):** El cliente reintenta con `op-3` exacto.
- **Respuesta Servidor:** El servidor detecta `op-3` en `sync_idempotency_log`. No inserta duplicado. Responde `accepted` con la misma respuesta original (`serverSeq: 103`).
- **Estado Final:** Cero duplicidad en PostgreSQL. Cliente purga `op-3` de su cola.

---

### Caso 4: Edición Concurrente de Master Data (Socio A y Socio B editan mismo Cliente)
- **Estado Inicial:** Cliente "Hotel Plaza" en `version: 2`. Socio A y B están offline.
- **Acción Socio A:** Actualiza teléfono a `+51999111222` (`baseVersion: 2`).
- **Acción Socio B:** Actualiza teléfono a `+51999333444` (`baseVersion: 2`).
- **Push Socio A:** Conecta primero. Servidor acepta y promueve a `version: 3` (`serverSeq: 104`).
- **Push Socio B:** Conecta después. Envía `baseVersion: 2`.
- **Respuesta Servidor a B:** `conflicts: [{ operationId: "op-b", errorCode: "VERSION_CONFLICT", serverVersion: 3 }]`.
- **Pull Socio B:** Descarga cambio de Socio A. Su cliente presenta aviso o fusiona pacíficamente según política de campo.

---

### Caso 5: Creación Concurrente de Gastos Diferentes (Grupo A Ledger)
- **Estado Inicial:** Obra "Parque Central".
- **Acción Socio A:** Registra compra de 10 bolsas de abono (S/ 150) -> `uuid-gasto-a`.
- **Acción Socio B:** Registra pago de combustible (S/ 60) -> `uuid-gasto-b`.
- **Push:** Ambos envían sus lotes casi simultáneamente.
- **Respuesta Servidor:** Ambos gastos tienen UUIDs diferentes y pertenecen al Grupo A (Append-Only). El servidor acepta ambos sin conflicto (`assignedVersion: 1` para cada uno, `serverSeq: 105` y `106`).
- **Estado Final:** La obra totaliza S/ 210 de gasto en ambos teléfonos tras pull.

---

### Caso 6: Eliminación Lógica (Soft Delete / Tombstone)
- **Estado Inicial:** Proveedor "Vivero El Rosal" activo con `version: 3`.
- **Acción:** Usuario elimina al proveedor en la app.
- **Encolamiento:** En SQLite se marca `deleted_at = "2026-10-05T15:00:00.000Z"`, `version: 4`.
- **Push:** Se envía `UPSERT` con `deletedAt` poblado.
- **Respuesta Servidor:** Servidor actualiza `deleted_at` y asigna `serverSeq: 107`.
- **Pull por Terceros:** Otros terminales reciben el registro con `deletedAt` poblado y lo ocultan de la interfaz.

---

### Caso 7: Dispositivo Desconectado por 3 Días
- **Estado Inicial:** Teléfono del capataz en zona rural sin cobertura durante 72 horas. Se generaron 1,200 cambios en la nube por otros usuarios.
- **Reconexión:** Teléfono solicita `GET /sync/pull?cursor=800&limit=500`.
- **Respuesta Servidor:** 500 cambios (`serverSeq: 801..1300`), `hasMore: true`, `nextCursor: 1300`.
- **Proceso Local:** Cliente aplica el lote en transacción, actualiza cursor a `1300`, y solicita siguiente página (`cursor=1300&limit=500`).
- **Fin:** Con 3 ciclos HTTP el dispositivo queda 100% al día sin sobrecargar memoria RAM.

---

### Caso 8: Pull Paginado con Transacción Atómica
- **Escenario:** Lote de pull contiene 300 cambios que incluyen la creación de una Obra y 50 Jornales asociados.
- **Fallo:** La batería del teléfono se agota mientras SQLite procesaba el registro 180.
- **Recuperación:** Al reiniciar, como la transacción no hizo commit, SQLite revierte automáticamente al estado del cursor previo. Al reconectar, la app solicita de nuevo desde el cursor previo y aplica los 300 cambios limpiamente.

---

### Caso 9: Conflicto de Versión en Configuración (`CompanySettings`)
- **Estado Inicial:** Razón social "Decolumax S.A.C.", `version: 4`.
- **Acción Socio A:** Cambia RUC a `20609999991` (`baseVersion: 4`). Aceptado -> `version: 5`.
- **Acción Socio B:** Intentó cambiar RUC a `20608888882` con `baseVersion: 4`.
- **Respuesta Servidor:** `conflicts: [{ entityType: "company_settings", errorCode: "VERSION_CONFLICT" }]`.
- **Estado Final:** Socio B es notificado de que la configuración de la empresa cambió y se recarga el valor oficial del servidor.

---

### Caso 10: Foto de Evidencia con Subida Desacoplada
- **Acción:** Técnico toma foto del jardín podado (3.5 MB).
- **Paso 1:** App solicita ticket: `POST /attachments/upload-ticket` -> recibe `uploadUrl` y `publicUrl`.
- **Paso 2:** App sube el archivo binario mediante `PUT` directo a la nube.
- **Paso 3:** App registra en Drift el `Attachment` con `remoteUrl: publicUrl` y lo encola en `sync_queue`.
- **Paso 4:** `POST /sync/push` transporta sólo el registro JSON (400 bytes).

---

### Caso 11: Metadatos de Presupuesto PDF Sincronizable
- **Acción:** Se emite presupuesto formal para un cliente institucional.
- **Sincronización:** Se genera la entidad `Estimate` o `Document` con número correlativo, hash criptográfico SHA-256 del contenido, total monetario y URL de descarga.
- **Resultado:** Los socios en campo pueden consultar el PDF descargándolo bajo demanda mediante su URL autenticada sin saturar la base SQLite local.

---

### Caso 12: Dependencia Aún No Sincronizada (`DEPENDENCY_MISSING`)
- **Escenario Anómalo:** Por una falla de ordenamiento en la cola local, se intenta enviar un `StockMovement` que referencia a un `inventory_item_id` que aún no ha sido enviado al servidor.
- **Evaluación Servidor:** El backend comprueba la existencia de la FK en PostgreSQL. Al no encontrar el ítem, responde en `rejected`:
  ```json
  {
    "operationId": "op-sm-1",
    "errorCode": "DEPENDENCY_MISSING",
    "missingEntity": "inventory_item",
    "missingId": "uuid-item-99"
  }
  ```
- **Acción del Cliente:** El cliente no descarta la operación; la posterga hasta que el `InventoryItem` sea aceptado en el siguiente ciclo de sincronización.
