# Servidor de Decolumax

Estado: base de API y PostgreSQL creadas; dominio completo y autenticación siguen pendientes.

Esta carpeta será la raíz de la API de sincronización y de sus recursos de despliegue. El usuario confirmó que necesita la API de Decolumax. No hay un proveedor externo de webhooks definido.

El cliente permanece en `apps/client`. El contrato compartido permanece en `packages/sync-contract`. La estructura anterior que proponía `apps/api` debe actualizarse al implementar el servidor para evitar dos ubicaciones oficiales.

La API expone `GET /api/v1/health` y `GET /api/v1/health/ready`. Desarrollo local: `npm install`, `npm run build` y `npm run start:dev` desde esta carpeta. Compose local: `docker compose -f deploy/compose.local.yml up --build`; con `RUN_MIGRATIONS=true` ejecuta las migraciones SQL incluidas.

Plan de trabajo, correcciones previas y criterios de cierre: [PLAN.md](PLAN.md).
