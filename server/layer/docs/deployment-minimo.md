# Despliegue mínimo de sincronización

La primera versión de la API de sincronización de Decolumax se despliega como un monolito modular en una sola VPS. La API contiene autenticación, salud y sincronización; no se crea un proceso separado para el webhook porque el webhook es la propia API de sincronización acordada.

## Servicios permanentes

| Servicio | Imagen | Función |
| --- | --- | --- |
| `api` | `decolumax-sync-api:0.1.0`, construido desde `server/layer/deploy/Dockerfile` y basado en `node:22-alpine` | Auth, endpoints de sync, validación y reglas de negocio |
| `postgres` | `postgres:17-alpine` | Workspaces, usuarios, sesiones, cambios e idempotencia |

La base de datos solo está en la red interna de Compose. La API publica el puerto `3000` únicamente en `127.0.0.1`; Nginx instalado en el sistema termina HTTPS y reenvía a ese puerto. Let's Encrypt no añade una cuota mensual.

El respaldo se ejecuta con un timer/cron del sistema: `pg_dump` diario, retención corta local y copia periódica a almacenamiento externo. Es una tarea programada, no un tercer servicio permanente. Un backup dentro de la misma VPS no protege contra la pérdida de la VPS.

## Servicios que se posponen

No se despliegan Redis, un worker de sincronización, MinIO/S3, balanceador, Kubernetes, Prometheus/Grafana ni una base administrada. El primer flujo usa la API y PostgreSQL; se añaden cuando una medición de carga o un requisito funcional lo justifique.

## Recursos y costo objetivo

Para producción inicial: 2 vCPU, 4 GB de RAM y 40 GB NVMe. 2 GB puede servir para una prueba, pero deja poco margen para PostgreSQL, migraciones, logs y el proceso Node.

El Compose fija un presupuesto inicial de `0,75` vCPU y `512 MB` para la API, y `1` vCPU y `1 GB` para PostgreSQL. La suma deja CPU y memoria para el sistema operativo, Docker, Nginx y los respaldos. El volumen de PostgreSQL no tiene una cuota propia: su crecimiento está limitado por el disco de la VPS, por lo que se debe vigilar el tamaño y rotar logs/backups.

Como referencia de bajo costo, el plan Hetzner CX23 publica 2 vCPU, 4 GB y 40 GB por EUR 5,49/mes antes de IVA e IPv4; sus precios pueden variar por región y fecha. DigitalOcean publica el plan básico de 4 GB y 2 vCPU por USD 24/mes. Por eso la estimación objetivo es aproximadamente EUR 6–12/mes más dominio y almacenamiento externo de backups; el precio final depende de impuestos, IP y proveedor elegido.

## Primer arranque

```bash
cp server/layer/deploy/.env.production.example server/layer/deploy/.env.production
# editar .env.production y sustituir los secretos
docker compose --env-file server/layer/deploy/.env.production \
  -f server/layer/deploy/compose.production.yml up -d --build
docker compose --env-file server/layer/deploy/.env.production \
  -f server/layer/deploy/compose.production.yml ps
```

El comando de producción debe ejecutarse desde la raíz del repositorio. `RUN_MIGRATIONS=true` es adecuado mientras exista una sola réplica de la API; antes de escalar se debe separar la ejecución de migraciones del arranque.
