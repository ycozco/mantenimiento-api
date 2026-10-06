# Opciones de optimización de API y PostgreSQL

## Hallazgos del proyecto

- El contexto de build estaba incluyendo aproximadamente 2,4 GB de `apps` Flutter, aunque la imagen solo copia `server/layer`. `.dockerignore` corrige ese desperdicio.
- El árbol local de dependencias de desarrollo de la API ocupa aproximadamente 124 MB. La imagen final usa solo dependencias de producción.
- La variante Alpine fue construida y ejecutada con `argon2`, las migraciones y readiness correctos. La variante distroless también arrancó, pero requiere un health check sin shell y ofrece menos herramientas de diagnóstico.
- `DatabaseService` tenía un pool máximo de 10 conexiones. Para una sola API y dos usuarios iniciales se fija en 4, con timeout de conexión y de inactividad.
- La clave primaria `(workspace_id, server_seq)` ya cubre las consultas por workspace y secuencia. La migración 002 elimina el índice duplicado `sync_changes_pull_idx`.

## Cambios aplicados

1. `npm ci` en las etapas de build y runtime para usar el lockfile de forma determinista.
2. `.dockerignore` para no enviar Flutter, `.dart_tool`, builds, dependencias locales ni secretos al daemon.
3. Pool PostgreSQL configurable: 4 conexiones, 2 segundos de timeout de conexión y 10 segundos de timeout inactivo en producción.
4. PostgreSQL limitado a 32 conexiones, `shared_buffers=128MB`, `work_mem=2MB`, `maintenance_work_mem=32MB` y sin workers de consultas paralelas en el perfil inicial. Estos valores son conservadores para una VPS pequeña y deben revisarse con métricas.
5. Eliminación del índice redundante de `sync_changes` mediante migración, sin editar una migración ya ejecutada.

## Alternativas evaluadas

| Alternativa | Ahorro | Riesgo o límite | Decisión |
| --- | --- | --- | --- |
| Mantener una VPS de 4 GB con API y PostgreSQL juntos | Bajo costo y operación simple | Requiere vigilar el volumen y backups | Recomendada para el primer despliegue |
| Perfil económico, API 384 MB y PostgreSQL 512 MB | Menor presión de RAM | Puede terminar en OOM durante migraciones o cargas de sync; medir antes | Piloto después de una prueba de carga |
| API gratuita + PostgreSQL gratuito administrado | Puede costar USD 0 | Pausas, límites de tamaño, sin backups o expiración según proveedor | Solo staging/demostración |
| Separar API y base en dos servicios | Aislamiento | Normalmente aumenta el costo y añade red/latencia | Posponer |
| Fastify en lugar de Express | Más solicitudes por CPU en benchmarks de Nest | Cambio de adaptador y compatibilidad de middleware | Medir después de cerrar el contrato |
| PgBouncer o Redis | Útil al escalar instancias o colas | Otro proceso, memoria y operación | No justificado con una API única |
| `node:alpine` | Reduce disco de imagen | `argon2` es un módulo nativo; exige probar binarios y compatibilidad musl | Adoptar `node:22-alpine`, ya probado |
| Imagen distroless | Reduce aún más disco y superficie de ataque | No trae shell; exige health check y diagnóstico específicos | Mantener como alternativa |
| Particionar `sync_changes` desde el inicio | Puede ayudar a tablas muy grandes | Más complejidad y memoria de planificación | Posponer hasta que el tamaño lo justifique |

## Recomendación de recursos

Conservar la VPS de 4 GB durante el primer staging. Después de una prueba con datos representativos, se puede probar el perfil económico:

```text
API:        0,50 vCPU / 384 MB
PostgreSQL: 0,75 vCPU / 768 MB
Pool API:   4 conexiones
VPS:        2 GB como mínimo para piloto
```

No bajar a 2 GB solo porque el consumo en reposo sea bajo: PostgreSQL puede usar memoria por conexión y por operación. `work_mem` se aplica por operación y por sesión, de modo que el consumo total puede ser varias veces ese valor. `shared_buffers` tampoco es un límite total de PostgreSQL.

Node puede recibir un límite de heap explícito cuando se pruebe el perfil económico, por ejemplo `--max-old-space-size=256`, dejando margen para memoria nativa, módulos y el runtime. El límite de Docker debe quedar por encima del heap para evitar un OOM prematuro.

## Medición antes de reducir la VPS

## Prueba de imágenes (Docker Desktop, 2026-10-06)

Se construyeron las tres variantes con el mismo código y dependencias de producción. Los tamaños son los que muestra `docker system df -v` para las capas desplegadas localmente; el tamaño comprimido de descarga puede ser menor:

| Variante | Tamaño de imagen desplegada | Health | `argon2` | Readiness con PostgreSQL |
| --- | ---: | --- | --- | --- |
| `node:22-bookworm-slim` | 398 MB | OK | OK | No ejecutada en Compose |
| `node:22-alpine` | 310 MB | OK | OK | OK; migraciones 001 y 002 aplicadas |
| `gcr.io/distroless/nodejs22-debian13:nonroot` | 280 MB | OK directo | OK | No se adoptó por el health check sin shell |

Con Alpine, API y PostgreSQL continuaron saludables con límites temporales de 384 MB y 512 MB respectivamente. En reposo midieron aproximadamente 46 MiB y 34 MiB; son mediciones de un entorno local, no un compromiso de carga de producción.

```bash
docker stats --no-stream
docker system df -v
docker inspect decolumax-sync-api --format '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}'
```

En PostgreSQL:

```sql
SELECT pg_size_pretty(pg_database_size(current_database()));
SELECT count(*) AS conexiones FROM pg_stat_activity;
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
```

Las consultas de pull y push deben revisarse con `EXPLAIN (ANALYZE, BUFFERS)` cuando estén implementadas. PostgreSQL recomienda mantener autovacuum y actualizar estadísticas; reducir recursos sin observar esos datos puede convertir un ahorro de RAM en latencia o crecimiento de disco.

## Fuentes técnicas

- Docker: [resource constraints](https://docs.docker.com/engine/containers/resource_constraints).
- PostgreSQL: [resource consumption](https://www.postgresql.org/docs/current/runtime-config-resource.html), [routine maintenance](https://www.postgresql.org/docs/current/maintenance.html) y [WAL compression](https://www.postgresql.org/docs/current/runtime-config-wal.html).
- Node.js: [`--max-old-space-size`](https://nodejs.org/docs/latest/api/cli.html).
- Node.js Docker: [best practices](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md).
- NestJS: [Fastify adapter](https://docs.nestjs.com/techniques/performance).
- node-postgres: [pooling](https://node-postgres.com/features/pooling) y [pool sizing](https://node-postgres.com/guides/pool-sizing).
- Supabase Free: [límites actuales](https://supabase.com/pricing).
- Render Free: [limitaciones](https://render.com/docs/free).
