# @decolumax/sync-contract

Especificación y modelos compartidos del protocolo de sincronización V3 Connected entre el cliente Flutter (`apps/client`) y el futuro backend (`apps/api`).

## Propósito

- Contrato agnóstico de tipos y esquemas de payload JSON.
- Definición de operaciones de sincronización (`UPSERT`, `DELETE`).
- Códigos de error unificados y semántica de resolución de conflictos.
- Esquema canónico para el Outbox (`sync_queue`) y el Ingestion Engine.

## Documentación Canónica

La especificación completa del protocolo se encuentra en:
[docs/sync_protocol_v3.md](../../docs/sync_protocol_v3.md)
