# Decolumax — Monorepo (V3 Connected)

Sistema integral de gestión de obras, mantenimientos, finanzas de socios, inventario y herramientas para Decolumax.

Arquitectura local-first con sincronización incremental hacia servidor central (V3).

---

## 📁 Estructura del Repositorio

```text
mantenimiento/
├── apps/
│   ├── client/                  # Aplicación Flutter (Android, Web, Desktop)
├── server/
│   └── layer/                   # API central, migraciones y despliegue (fase T-22+)
├── packages/
│   └── sync-contract/           # Definiciones y contratos del protocolo de sincronización V3
├── infrastructure/
│   ├── docker/                  # Contenedores y orquestación
│   ├── nginx/                   # Proxy inverso y SSL
│   ├── postgres/                # Esquemas y migraciones PostgreSQL
│   ├── backup/                  # Estrategias y scripts de respaldo del servidor
│   └── scripts/                 # Scripts operativos y de despliegue
├── docs/                        # Documentación técnica, arquitectónica y protocolos
├── .gitignore                   # Exclusiones globales de control de versiones
└── README.md                    # Esta guía raíz
```

---

## 🚀 Desarrollo con la Aplicación Cliente (`apps/client`)

El código de la aplicación Flutter se ubica íntegramente en `apps/client`.

Para ejecutar o compilar el cliente localmente:

```bash
# Navegar al directorio del cliente
cd apps/client

# Obtener dependencias
flutter pub get

# Análisis estático (debe reportar 0 issues)
flutter analyze

# Ejecutar suite de pruebas unitarias y de integración local
flutter test

# Ejecución en modo desarrollo
flutter run

# Compilación para entorno Web
flutter build web

# Compilación para Android (depuración)
flutter build apk --debug
```

---

## 📚 Documentación

- **Historial V1 (Offline)**: [`docs/mantenimiento.md`](docs/mantenimiento.md)
- **Arquitectura V2 Local**: [`docs/arquitectura_v2.md`](docs/arquitectura_v2.md)
- **Transición T-20**: [`docs/t20_resultado.md`](docs/t20_resultado.md)
- **Protocolo de Sincronización V3**: [`docs/sync_protocol_v3.md`](docs/sync_protocol_v3.md)
- **Plan de corrección y servidor**: [`server/layer/PLAN.md`](server/layer/PLAN.md)
- **API y despliegue**: [`server/layer/README.md`](server/layer/README.md)
