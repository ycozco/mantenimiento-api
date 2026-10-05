# Decolumax V3 — Infrastructure

Este directorio albergará la infraestructura para la etapa **V3 Connected** de Decolumax (T-22+).

## Estructura

- `docker/`: Configuración y definiciones de contenedores para servicios de backend y base de datos (PostgreSQL, APIs).
- `nginx/`: Configuración de proxy inverso, terminación TLS y enrutamiento hacia la API de sincronización.
- `postgres/`: Scripts de inicialización, esquemas relacionales del servidor y migraciones para la base de datos PostgreSQL.
- `backup/`: Políticas y scripts de copias de seguridad automáticas del servidor de producción.
- `scripts/`: Scripts operativos de despliegue, mantenimiento y chequeo de salud (healthcheck).

> **Nota:** La infraestructura real se implementará en T-22+. Durante T-20 y T-21 no se levantan servicios ni contenedores ficticios.
