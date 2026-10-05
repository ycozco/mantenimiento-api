# Resultado de Implementación: T-16 — Backup / Restore V2 Completo

## 1. Resumen Ejecutivo
Se implementó el sistema integral de **Copia de Seguridad y Restauración V2** (`BackupRestoreService`) que cubre el 100% del grafo relacional de Decolumax EIRL en SQLite/Drift, reemplazando el antiguo exportador V1 que únicamente serializaba las 5 entidades originales. La restauración es completamente transaccional (con rollback garantizado ante cualquier falla), respeta el orden estricto de dependencias por Foreign Keys y preserva centavos enteros, timestamps ISO 8601 y soft-deletes.

- **Estado:** `T-16 CLOSED`
- **Tests totales acumulados en el proyecto:** 170 passing (14 tests exhaustivos en `test/backup_restore_v2_test.dart`)
- **Análisis estático:** `flutter analyze`: 0 issues
- **Commit:** `feat(backup): implement T-16 complete V2 backup and restore`

---

## 2. Especificación del Formato de Backup V2

### 2.1 Metadatos de Cabecera
```json
{
  "backupFormatVersion": 2,
  "schemaVersion": 2,
  "createdAt": "2026-10-04T20:52:00.000Z",
  "appVersion": "1.0.0+1",
  "workspaceId": "default",
  "data": { ... }
}
```

### 2.2 Entidades de Negocio Incluidas (21 Tablas Drift)
1. `users` (Usuarios y operadores del sistema)
2. `partners` (Socios comerciales)
3. `workers` (Trabajadores de campo)
4. `clients` (Clientes comerciales y residenciales)
5. `client_locations` (Sedes y direcciones de clientes)
6. `projects` (Obras y proyectos)
7. `maintenance_plans` (Planes de mantenimiento recurrentes)
8. `maintenance_visits` (Historial y programación de visitas)
9. `suppliers` (Proveedores de materiales y viveros)
10. `inventory_items` (Insumos, plantas y materiales)
11. `purchases` (Cabeceras de compras de insumos)
12. `purchase_items` (Detalle de ítems comprados)
13. `stock_movements` (Ledger Kardex de inventario)
14. `tools` (Herramientas y maquinaria)
15. `tool_assignments` (Historial de custodia de herramientas)
16. `work_logs` (Jornadas laborales ejecutadas)
17. `labor_payments` (Pagos de mano de obra)
18. `expenses` (Gastos operativos y fletes)
19. `capital_movements` (Aportes y retiros de socios)
20. `collections` (Cobros registrados a clientes)
21. `attachments` (Metadatos de evidencias fotográficas y PDFs)
22. `app_metadata` (Configuración de empresa `company_settings`, monedas, zonas horarias y versiones)

### 2.3 Entidades y Componentes Excluidos Intencionalmente
- **`sync_queue`:** Es una cola transaccional efímera para sincronización outbox. Restaurar tareas pendientes de una cola antigua a otro dispositivo sin backend provocaría conflictos y duplicidades de eventos.
- **`DevicePreferences`:** Las preferencias de UI (tema visual oscuro/claro, activar notificaciones en este dispositivo) se mantienen en `SharedPreferences` del terminal físico y no pertenecen al respaldo de la empresa.
- **Archivos Binarios (PDFs / Fotos):** Siguiendo la arquitectura Local-First, el JSON transporta rutas y metadatos de los adjuntos, sin incrustar Base64 ni BLOBs gigantes que degraden la memoria o excedan los límites del sistema.

---

## 3. Protocolo de Restauración e Integridad Referencial

### 3.1 Orden Estricto de Limpieza (Hijos a Padres)
Para evitar violaciones de `PRAGMA foreign_keys = ON;`, la purga previa a la inserción se realiza en orden inverso de dependencias:
`attachments` $\to$ `collections` $\to$ `capital_movements` $\to$ `expenses` $\to$ `labor_payments` $\to$ `work_logs` $\to$ `tool_assignments` $\to$ `stock_movements` $\to$ `purchase_items` $\to$ `purchases` $\to$ `tools` $\to$ `inventory_items` $\to$ `suppliers` $\to$ `maintenance_visits` $\to$ `maintenance_plans` $\to$ `projects` $\to$ `client_locations` $\to$ `clients` $\to$ `workers` $\to$ `partners` $\to$ `users` $\to$ `app_metadata`.

### 3.2 Orden Estricto de Inserción (Padres a Hijos)
La restauración inserta entidades desde las raíces hacia las hojas:
`users` $\to$ `partners` $\to$ `workers` $\to$ `clients` $\to$ `client_locations` $\to$ `projects` $\to$ `maintenance_plans` $\to$ `maintenance_visits` $\to$ `suppliers` $\to$ `inventory_items` $\to$ `purchases` $\to$ `purchase_items` $\to$ `stock_movements` $\to$ `tools` $\to$ `tool_assignments` $\to$ `work_logs` $\to$ `labor_payments` $\to$ `expenses` $\to$ `capital_movements` $\to$ `collections` $\to$ `attachments` $\to$ `app_metadata`.

### 3.3 Atomicidad y Rollback
Toda la restauración se ejecuta dentro de un bloque `db.transaction(() async { ... })`. Si el JSON contiene una clave foránea huérfana, un tipo incompatible o se produce cualquier error, la transacción revierte inmediatamente (**ROLLBACK**) y el estado previo de la base de datos permanece intacto.

### 3.4 Compatibilidad Hacia Atrás (Formato V1)
Si el usuario intenta restaurar un respaldo antiguo de la versión 1 (generado antes de la migración Drift), `BackupRestoreService` detecta la firma estructural V1 (`version: 1` o campos raíz `socios` / `mantenimientos`) y ejecuta automáticamente `DataMigrationService.executeMigrationFromJson(...)`, migrando los datos antiguos al nuevo esquema sin pérdida.

---

## 4. Cobertura de Pruebas Automatizadas

En `test/backup_restore_v2_test.dart` (14 pruebas passing):
1. **Export vacío:** Estructura JSON válida con metadatos y colecciones vacías.
2. **Export completo y Metadata:** Verificación de versiones (`backupFormatVersion: 2`, `schemaVersion: 2`, `appVersion: 1.0.0+1`).
3. **Round-trip completo crítico:** Poblado de una base de datos con un grafo masivo de 20 entidades interconectadas $\to$ Exportación $\to$ Creación de base limpia $\to$ Restauración $\to$ Verificación campo por campo de equivalencia funcional exacta.
4. **Integridad de Foreign Keys:** Restaura respetando relaciones padre-hijo bajo `PRAGMA foreign_keys = ON;`.
5. **Centavos exactos:** Preserva montos enteros en centavos sin redondeos.
6. **Fechas ISO 8601:** Deserialización de `DateTime` exacta.
7. **Soft deletes:** Registros eliminados conservan su `deletedAt`.
8. **Metadatos de Attachments:** Preservación de nombres de archivo y rutas sin almacenamiento de bytes BLOB.
9. **JSON corrupto:** Retorna fallo descriptivo sin crashear.
10. **Versión incompatible:** Rechaza backups con versiones mayores a la soportada.
11. **Rollback transaccional:** Ante falla de integridad, la base actual no sufre alteraciones.
12. **Compatibilidad V1:** Restauración exitosa de backups legados.
13. **Restore repetido e idempotente:** Múltiples ejecuciones del mismo archivo mantienen el estado íntegro.
14. **Exclusión de `sync_queue`:** No se exporta ni restaura infraestructura outbox obsoleta.
