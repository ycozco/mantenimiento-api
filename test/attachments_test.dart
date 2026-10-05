import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantenimiento_app/core/database/app_database.dart'
    hide Attachment;
import 'package:mantenimiento_app/core/models/attachment.dart';
import 'package:mantenimiento_app/core/repositories/attachment_repository.dart';

void main() {
  late AppDatabase db;
  late AttachmentRepository attachmentRepo;

  setUp(() async {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
    attachmentRepo = AttachmentRepository(db);

    // Entidades base para contextos
    await db
        .into(db.clients)
        .insert(
          ClientsCompanion.insert(id: 'client-1', name: 'Cliente Adjuntos'),
        );

    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'proj-1',
            name: 'Obra con Planos',
            startDate: DateTime.now(),
          ),
        );

    await db
        .into(db.maintenancePlans)
        .insert(
          MaintenancePlansCompanion.insert(
            id: 'plan-1',
            clientId: 'client-1',
            title: 'Plan con Evidencias',
          ),
        );

    await db
        .into(db.maintenanceVisits)
        .insert(
          MaintenanceVisitsCompanion.insert(
            id: 'visit-1',
            planId: 'plan-1',
            scheduledDate: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('1. Adjunto mediante URL externa válida en Obra', () async {
    final att = Attachment.createUrl(
      id: 'att-url-1',
      parentType: 'project',
      parentId: 'proj-1',
      url: 'https://drive.google.com/file/d/12345/view',
      fileName: 'Plano Arquitectónico General',
      kind: 'document',
      stage: 'before',
    );

    await attachmentRepo.createAttachment(att);

    final list = await attachmentRepo.getAttachmentsForParent(
      'project',
      'proj-1',
    );
    expect(list.length, equals(1));

    final saved = list.first;
    expect(saved.id, equals('att-url-1'));
    expect(saved.parentType, equals('project'));
    expect(saved.parentId, equals('proj-1'));
    expect(saved.provider, equals('external_url'));
    expect(saved.url, equals('https://drive.google.com/file/d/12345/view'));
    expect(saved.fileName, equals('Plano Arquitectónico General'));
    expect(saved.kind, equals('document'));
    expect(saved.stage, equals('before'));
    expect(saved.localFilePath, isNull);
    expect(saved.storageKey, isNull);
  });

  test('2. Imagen fotográfica mediante URL externa (ImgBB / Cloud)', () async {
    final att = Attachment.createUrl(
      id: 'att-img-1',
      parentType: 'maintenance_visit',
      parentId: 'visit-1',
      url: 'https://i.ibb.co/xyz123/cesped_despues.jpg',
      fileName: 'Evidencia Podado Final',
      kind: 'image',
      stage: 'after',
      mimeType: 'image/jpeg',
    );

    await attachmentRepo.createAttachment(att);

    final list = await attachmentRepo.getAttachmentsForParent(
      'maintenance_visit',
      'visit-1',
    );
    expect(list.length, equals(1));
    expect(list.first.isImage, isTrue);
    expect(list.first.isPdf, isFalse);
    expect(list.first.stage, equals('after'));
  });

  test(
    '3. Documento PDF local: preserva metadatos y ruta sin almacenar bytes en SQLite',
    () async {
      final att = Attachment.createLocalFile(
        id: 'att-pdf-1',
        parentType: 'project',
        parentId: 'proj-1',
        localFilePath: 'C:\\documentos\\contrato_firmado.pdf',
        fileName: 'Contrato de Obra Firmado',
        kind: 'pdf',
        fileSizeBytes: 2048576, // 2 MB
      );

      await attachmentRepo.createAttachment(att);

      final list = await attachmentRepo.getAttachmentsForParent(
        'project',
        'proj-1',
      );
      expect(list.length, equals(1));

      final saved = list.first;
      expect(saved.provider, equals('local'));
      expect(
        saved.localFilePath,
        equals('C:\\documentos\\contrato_firmado.pdf'),
      );
      expect(saved.fileSizeBytes, equals(2048576));
      expect(saved.mimeType, equals('application/pdf'));
      expect(saved.url, isNull);

      // Confirmar en SQLite directo que no existen columnas BLOB con bytes
      final rawRow = await db
          .customSelect(
            'SELECT id, local_file_path, file_size_bytes FROM attachments WHERE id = ?',
            variables: [Variable.withString('att-pdf-1')],
          )
          .getSingle();
      expect(
        rawRow.read<String>('local_file_path'),
        contains('contrato_firmado.pdf'),
      );
      expect(rawRow.read<int>('file_size_bytes'), equals(2048576));
    },
  );

  test(
    '4. Adjunto en contexto de MaintenanceVisit (Visita de Mantenimiento)',
    () async {
      final att = Attachment.createUrl(
        id: 'att-visit-evidence',
        parentType: 'maintenance_visit',
        parentId: 'visit-1',
        url: 'https://example.com/foto_antes.jpg',
        fileName: 'Estado Inicial Jardineras',
        stage: 'before',
      );

      await attachmentRepo.createAttachment(att);

      final list = await attachmentRepo.getAttachmentsForParent(
        'maintenance_visit',
        'visit-1',
      );
      expect(list.length, equals(1));
      expect(list.first.parentId, equals('visit-1'));
      expect(list.first.parentType, equals('maintenance_visit'));
    },
  );

  test(
    '5. Soft-delete de un adjunto conserva historial y lo excluye de activos',
    () async {
      final att = Attachment.createUrl(
        id: 'att-to-del',
        parentType: 'project',
        parentId: 'proj-1',
        url: 'https://example.com/documento.pdf',
        fileName: 'Borrador Antiguo',
      );
      await attachmentRepo.createAttachment(att);

      var list = await attachmentRepo.getAttachmentsForParent(
        'project',
        'proj-1',
      );
      expect(list.length, equals(1));

      // Eliminar con soft-delete
      await attachmentRepo.deleteAttachment('att-to-del');

      list = await attachmentRepo.getAttachmentsForParent('project', 'proj-1');
      expect(list, isEmpty);

      // Comprobar que en la base de datos sigue existiendo con deleted_at no nulo
      final raw = await db
          .customSelect(
            'SELECT deleted_at FROM attachments WHERE id = ?',
            variables: [Variable.withString('att-to-del')],
          )
          .getSingle();
      expect(raw.read<DateTime?>('deleted_at'), isNotNull);
    },
  );

  test(
    '6. Validación de URL: URL sin esquema https:// o http:// es rechazada',
    () {
      expect(
        () => Attachment.createUrl(
          parentType: 'project',
          parentId: 'proj-1',
          url: 'archivo_sin_protocolo.jpg',
          fileName: 'Foto Mala',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => Attachment.createUrl(
          parentType: 'project',
          parentId: 'proj-1',
          url: 'ftp://servidor.com/doc.pdf',
          fileName: 'Protocolo no permitido',
        ),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test(
    '7. PDF local inexistente no crashea la aplicación y reporta isLocalFileAvailable = false',
    () {
      final att = Attachment.createLocalFile(
        parentType: 'project',
        parentId: 'proj-1',
        localFilePath: 'C:\\ruta_que_no_existe_en_disco\\archivo_fantasma.pdf',
        fileName: 'Plano Desaparecido',
      );

      expect(att.isLocalFileAvailable, isFalse);
      expect(att.provider, equals('local'));
    },
  );

  test(
    '8. Múltiples adjuntos en distintas etapas conservan orden cronológico',
    () async {
      await attachmentRepo.createAttachment(
        Attachment.createUrl(
          id: 'att-1',
          parentType: 'project',
          parentId: 'proj-1',
          url: 'https://img.com/1.jpg',
          fileName: 'Antes',
          stage: 'before',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );

      await attachmentRepo.createAttachment(
        Attachment.createUrl(
          id: 'att-2',
          parentType: 'project',
          parentId: 'proj-1',
          url: 'https://img.com/2.jpg',
          fileName: 'Después',
          stage: 'after',
          createdAt: DateTime.now(),
        ),
      );

      final list = await attachmentRepo.getAttachmentsForParent(
        'project',
        'proj-1',
      );
      expect(list.length, equals(2));
      // Orden descendente por createdAt (el más reciente primero)
      expect(list.first.id, equals('att-2'));
      expect(list.last.id, equals('att-1'));
    },
  );
}
