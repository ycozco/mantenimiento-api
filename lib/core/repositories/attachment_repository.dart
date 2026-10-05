import 'package:drift/drift.dart';

import '../database/app_database.dart' as db;
import '../models/attachment.dart';

class AttachmentRepository {
  final db.AppDatabase _db;

  AttachmentRepository(this._db);

  /// Registra un nuevo adjunto (URL externa o archivo local)
  Future<void> createAttachment(Attachment attachment) async {
    await _db
        .into(_db.attachments)
        .insert(
          db.AttachmentsCompanion.insert(
            id: attachment.id,
            workspaceId: Value(attachment.workspaceId),
            parentType: attachment.parentType,
            parentId: attachment.parentId,
            stage: Value(attachment.stage),
            kind: Value(attachment.kind),
            provider: Value(attachment.provider),
            url: Value(attachment.url),
            storageKey: Value(attachment.storageKey),
            localFilePath: Value(attachment.localFilePath),
            fileName: attachment.fileName,
            fileSizeBytes: Value(attachment.fileSizeBytes),
            mimeType: Value(attachment.mimeType),
            createdAt: Value(attachment.createdAt),
            updatedAt: Value(attachment.updatedAt),
            createdBy: Value(attachment.createdBy),
            version: Value(attachment.version),
            deletedAt: Value(attachment.deletedAt),
          ),
        );
  }

  /// Observa reactivamente los adjuntos de una entidad padre (ej. Obra, Visita)
  Stream<List<Attachment>> watchAttachmentsForParent(
    String parentType,
    String parentId,
  ) {
    return (_db.select(_db.attachments)
          ..where(
            (tbl) =>
                tbl.parentType.equals(parentType) &
                tbl.parentId.equals(parentId) &
                tbl.deletedAt.isNull(),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch()
        .map((rows) => rows.map(_fromDrift).toList());
  }

  /// Obtiene los adjuntos activos de una entidad padre
  Future<List<Attachment>> getAttachmentsForParent(
    String parentType,
    String parentId,
  ) async {
    final rows =
        await (_db.select(_db.attachments)
              ..where(
                (tbl) =>
                    tbl.parentType.equals(parentType) &
                    tbl.parentId.equals(parentId) &
                    tbl.deletedAt.isNull(),
              )
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
            .get();
    return rows.map(_fromDrift).toList();
  }

  /// Soft-delete de un adjunto conservando trazabilidad
  Future<void> deleteAttachment(String id) async {
    await (_db.update(
      _db.attachments,
    )..where((tbl) => tbl.id.equals(id))).write(
      db.AttachmentsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Attachment _fromDrift(db.Attachment row) {
    return Attachment(
      id: row.id,
      workspaceId: row.workspaceId,
      parentType: row.parentType,
      parentId: row.parentId,
      stage: row.stage,
      kind: row.kind,
      provider: row.provider,
      url: row.url,
      storageKey: row.storageKey,
      localFilePath: row.localFilePath,
      fileName: row.fileName,
      fileSizeBytes: row.fileSizeBytes,
      mimeType: row.mimeType,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      createdBy: row.createdBy,
      version: row.version,
      deletedAt: row.deletedAt,
    );
  }
}
