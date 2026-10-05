# Servidor de Decolumax

Estado: planificación, sin API ni despliegue implementados.

Esta carpeta será la raíz de la API de sincronización y de sus recursos de despliegue. El usuario confirmó que necesita la API de Decolumax. No hay un proveedor externo de webhooks definido.

El cliente permanece en `apps/client`. El contrato compartido permanece en `packages/sync-contract`. La estructura anterior que proponía `apps/api` debe actualizarse al implementar el servidor para evitar dos ubicaciones oficiales.

Plan de trabajo, correcciones previas y criterios de cierre: [PLAN.md](PLAN.md).
