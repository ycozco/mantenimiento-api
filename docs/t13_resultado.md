# Resultado de Implementación: T-13 — Attachments: URLs + PDFs Locales

## 1. Resumen Ejecutivo
Se implementó de manera completa y robusta la gestión de adjuntos (**Attachments**) para obras y visitas de mantenimiento de Decolumax EIRL, respetando la arquitectura Local-First y las restricciones de almacenamiento en SQLite (cero BLOBs / cero Base64).

- **Estado:** `T-13 CLOSED`
- **Tests totales:** 136 passing (8 tests específicos en `test/attachments_test.dart`)
- **Análisis estático:** `flutter analyze`: 0 issues
- **Commit:** `feat(attachments): implement T-13 local attachments and external URLs`

---

## 2. Modelo de Datos y Persistencia

### 2.1 Esquema de la Tabla `attachments`
La tabla Drift existente en `app_database.dart` cuenta con:
- `id` (UUID PK)
- `workspaceId` (Text, default 'default')
- `parentType` (Text, ej. `'project'`, `'maintenance_visit'`)
- `parentId` (Text, UUID de la entidad padre)
- `stage` (Text nullable, ej. `'before'`, `'during'`, `'after'`)
- `kind` (Text, `'image'`, `'pdf'`, `'document'`)
- `provider` (Text, `'external_url'`, `'local'`)
- `url` (Text nullable, HTTPS/HTTP para almacenamiento en la nube o servicios de imágenes)
- `storageKey` (Text nullable, reservado para VPS futuro)
- `localFilePath` (Text nullable, ruta en el sistema de archivos del dispositivo)
- `fileName` (Text, nombre descriptivo del archivo)
- `fileSizeBytes` (Int, tamaño en bytes)
- `mimeType` (Text, ej. `'image/jpeg'`, `'application/pdf'`)
- `createdAt`, `updatedAt`, `createdBy`, `version`, `deletedAt` (Auditoría y soft-delete)

### 2.2 Principios Críticos Respetados
1. **Sin Bytes en SQLite:** No se almacenan imágenes o PDFs como BLOBs ni Base64 dentro de la base de datos local.
2. **URLs Externas Seguras:** Validación estricta de esquemas `https://` y `http://` rechazando esquemas inseguros o rutas relativas no estructuradas.
3. **Manejo Seguro de Archivos Locales:** El getter `isLocalFileAvailable` comprueba en tiempo de ejecución si el archivo sigue presente físicamente en el dispositivo sin generar excepciones ni bloqueos.
4. **Soft-delete:** Los adjuntos borrados marcan `deletedAt`, manteniendo la trazabilidad histórica y auditoría sin pérdida destructiva.

---

## 3. Componentes Implementados

1. **Modelo de Dominio:** `lib/core/models/attachment.dart`
   - Factories `Attachment.createUrl` y `Attachment.createLocalFile`
   - Getters `isImage`, `isPdf`, `isLocalFileAvailable`, `humanFileSize`
2. **Repositorio:** `lib/core/repositories/attachment_repository.dart`
   - `createAttachment`, `getAttachmentsForParent`, `watchAttachmentsForParent`, `deleteAttachment`
   - Manejo de reactividad y exclusión automática de eliminados lógicos (`deletedAt.isNull()`)
3. **Interfaz de Usuario Reutilizable:**
   - `lib/features/attachments/attachment_form_dialog.dart`: Diálogo intuitivo con selector de tipo (Enlace URL vs Archivo Local), validación, campos de etapa (Antes / Durante / Después) y tipo de contenido.
   - `lib/features/attachments/attachment_list_widget.dart`: Componente reactivo incrustable que lista evidencias fotográficas, documentos PDF y enlaces, permitiendo abrirlos de forma segura (`url_launcher` / visor) y eliminarlos lógicamente.
4. **Integración en Módulos:**
   - `lib/features/obras/obra_detail_screen.dart`: Sección "Archivos y Planos de la Obra"
   - `lib/features/mantenimientos/maintenance_visit_detail_screen.dart`: Sección "Archivos y Evidencias Fotográficas"

---

## 4. Cobertura de Pruebas Automatizadas

En `test/attachments_test.dart` (8 tests):
1. Registro de adjunto mediante URL externa válida en Obra.
2. Evidencia fotográfica externa con URL de servicio cloud/ImgBB.
3. Documento PDF local: preservación de metadatos y ruta sin almacenar bytes en SQLite.
4. Adjunto en contexto de Visita de Mantenimiento (`MaintenanceVisit`).
5. Soft-delete de adjunto: exclusión de listas activas y conservación de trazabilidad.
6. Validación de URL: rechazo de URLs inválidas o sin protocolo seguro.
7. Comprobación segura de PDF local inexistente (`isLocalFileAvailable = false`) sin crasheos.
8. Orden cronológico descendente según fecha de registro.
