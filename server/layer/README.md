# Servidor de Decolumax

Estado: API de identidad y relay cifrado NATS implementados; aplicación de datos, invitaciones y aprobación de dispositivos siguen pendientes.

Esta carpeta será la raíz de la API de sincronización y de sus recursos de despliegue. El usuario confirmó que necesita la API de Decolumax. No hay un proveedor externo de webhooks definido.

El cliente permanece en `apps/client`. El contrato compartido permanece en `packages/sync-contract`. `server/layer` es la ubicación oficial del servidor para evitar dos APIs paralelas.

La API expone `GET /api/v1/health`, `GET /api/v1/health/ready`, autenticación en `/api/v1/auth` y relay JetStream en `POST /api/v1/sync/push` y `GET /api/v1/sync/pull`. El relay maneja sobres cifrados por workspace; no aplica cambios a las tablas de negocio. Desarrollo local: `npm install`, `npm run build` y `npm run start:dev` desde esta carpeta. Compose local: `docker compose -f deploy/compose.local.yml up --build`; con `RUN_MIGRATIONS=true` ejecuta las migraciones SQL incluidas.

El primer workspace y su administrador se crean fuera de HTTP con `npm run bootstrap:admin`, usando `DATABASE_URL`, `WORKSPACE_SLUG`, `WORKSPACE_NAME`, `ADMIN_EMAIL`, `ADMIN_NAME` y `ADMIN_PASSWORD` en el entorno.

La imagen de producción de la API usa `node:22-alpine`; la compatibilidad de `argon2`, migraciones y readiness fue verificada en Docker. La alternativa distroless queda documentada, pero no es la imagen operativa inicial.

Plan de trabajo, correcciones previas y criterios de cierre: [PLAN.md](PLAN.md).

La API requiere `NATS_URL`, `NATS_SYNC_USER`, `NATS_SYNC_PASSWORD` y `NATS_SYNC_STREAM`; las credenciales se configuran solo en el servidor. Flutter se compila con `--dart-define=SYNC_API_BASE_URL=https://<dominio-api>/api/v1`. Variables, rutas y límites: [docs/sync-api.md](docs/sync-api.md).

La arquitectura de buzón y migración está descrita en [docs/migracion-sync-cifrado.md](docs/migracion-sync-cifrado.md), junto con la [comparación de servicios, proyectos Flutter y recursos](docs/evaluacion-p2p-flutter.md).
