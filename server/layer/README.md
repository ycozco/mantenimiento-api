# Servidor de Decolumax

Estado: base de API y PostgreSQL creadas; dominio completo y autenticación siguen pendientes.

Esta carpeta será la raíz de la API de sincronización y de sus recursos de despliegue. El usuario confirmó que necesita la API de Decolumax. No hay un proveedor externo de webhooks definido.

El cliente permanece en `apps/client`. El contrato compartido permanece en `packages/sync-contract`. `server/layer` es la ubicación oficial del servidor para evitar dos APIs paralelas.

La API expone `GET /api/v1/health` y `GET /api/v1/health/ready`. Desarrollo local: `npm install`, `npm run build` y `npm run start:dev` desde esta carpeta. Compose local: `docker compose -f deploy/compose.local.yml up --build`; con `RUN_MIGRATIONS=true` ejecuta las migraciones SQL incluidas.

El primer workspace y su administrador se crean fuera de HTTP con `npm run bootstrap:admin`, usando `DATABASE_URL`, `WORKSPACE_SLUG`, `WORKSPACE_NAME`, `ADMIN_EMAIL`, `ADMIN_NAME` y `ADMIN_PASSWORD` en el entorno.

La imagen de producción de la API usa `node:22-alpine`; la compatibilidad de `argon2`, migraciones y readiness fue verificada en Docker. La alternativa distroless queda documentada, pero no es la imagen operativa inicial.

Plan de trabajo, correcciones previas y criterios de cierre: [PLAN.md](PLAN.md).
