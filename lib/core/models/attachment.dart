import 'dart:io';
import 'package:uuid/uuid.dart';

class Attachment {
  final String id;
  final String workspaceId;
  final String parentType; // 'project', 'maintenance_visit', 'purchase', etc.
  final String parentId;
  final String? stage; // 'before', 'during', 'after'
  final String kind; // 'image', 'pdf', 'document'
  final String provider; // 'external_url', 'local', 'server'
  final String? url;
  final String? storageKey;
  final String? localFilePath;
  final String fileName;
  final int fileSizeBytes;
  final String mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final int version;
  final DateTime? deletedAt;

  Attachment({
    required this.id,
    this.workspaceId = 'default',
    required this.parentType,
    required this.parentId,
    this.stage,
    this.kind = 'image',
    this.provider = 'external_url',
    this.url,
    this.storageKey,
    this.localFilePath,
    required this.fileName,
    this.fileSizeBytes = 0,
    this.mimeType = 'image/jpeg',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.version = 1,
    this.deletedAt,
  });

  /// Factory para registrar un adjunto mediante URL externa (Google Drive, ImgBB, etc.)
  factory Attachment.createUrl({
    String? id,
    String workspaceId = 'default',
    required String parentType,
    required String parentId,
    required String url,
    required String fileName,
    String kind = 'image',
    String? stage,
    String? mimeType,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final trimmedUrl = url.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        (!uri.isScheme('http') && !uri.isScheme('https')) ||
        !uri.hasAuthority) {
      throw ArgumentError(
        'URL inválida: "$url". Debe ser una dirección web válida con https:// o http://',
      );
    }

    final now = DateTime.now();
    return Attachment(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      parentType: parentType,
      parentId: parentId,
      stage: stage,
      kind: kind,
      provider: 'external_url',
      url: trimmedUrl,
      fileName: fileName.trim().isEmpty ? 'Enlace adjunto' : fileName.trim(),
      mimeType:
          mimeType ?? (kind == 'image' ? 'image/jpeg' : 'application/pdf'),
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      createdBy: createdBy,
      version: 1,
    );
  }

  /// Factory para registrar un PDF o documento local
  factory Attachment.createLocalFile({
    String? id,
    String workspaceId = 'default',
    required String parentType,
    required String parentId,
    required String localFilePath,
    required String fileName,
    String kind = 'pdf',
    String? stage,
    int? fileSizeBytes,
    String? mimeType,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    if (localFilePath.trim().isEmpty) {
      throw ArgumentError('La ruta del archivo local no puede estar vacía.');
    }

    int computedSize = fileSizeBytes ?? 0;
    try {
      final file = File(localFilePath);
      if (file.existsSync()) {
        computedSize = file.lengthSync();
      }
    } catch (_) {
      // Manejo seguro si no se puede leer el tamaño en esta plataforma
    }

    final now = DateTime.now();
    return Attachment(
      id: id ?? const Uuid().v4(),
      workspaceId: workspaceId,
      parentType: parentType,
      parentId: parentId,
      stage: stage,
      kind: kind,
      provider: 'local',
      localFilePath: localFilePath.trim(),
      fileName: fileName.trim().isEmpty ? 'Documento PDF' : fileName.trim(),
      fileSizeBytes: computedSize,
      mimeType: mimeType ?? 'application/pdf',
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      createdBy: createdBy,
      version: 1,
    );
  }

  /// Verifica si el archivo físico local existe en el dispositivo
  bool get isLocalFileAvailable {
    if (provider != 'local' || localFilePath == null) return true;
    try {
      return File(localFilePath!).existsSync();
    } catch (_) {
      return false;
    }
  }

  bool get isImage => kind == 'image';
  bool get isPdf => kind == 'pdf';
  bool get isExternalUrl => provider == 'external_url';
}
