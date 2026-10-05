import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/attachment.dart';
import '../../core/theme/app_theme.dart';
import 'attachment_form_dialog.dart';

class AttachmentListWidget extends StatelessWidget {
  final LocalStorageService storage;
  final String parentType;
  final String parentId;
  final String sectionTitle;

  const AttachmentListWidget({
    super.key,
    required this.storage,
    required this.parentType,
    required this.parentId,
    this.sectionTitle = 'Archivos, Planos y Evidencias',
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.paperclip,
                      color: AppTheme.skyAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sectionTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    final attachment = await showDialog<Attachment>(
                      context: context,
                      builder: (_) => AttachmentFormDialog(
                        parentType: parentType,
                        parentId: parentId,
                      ),
                    );
                    if (attachment != null) {
                      await storage.attachmentRepository.createAttachment(
                        attachment,
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Adjuntar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Attachment>>(
              stream: storage.attachmentRepository.watchAttachmentsForParent(
                parentType,
                parentId,
              ),
              builder: (context, snapshot) {
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'No hay evidencias ni documentos adjuntos.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  );
                }

                return Column(
                  children: list.map((a) {
                    final isAvailable = a.isLocalFileAvailable;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAvailable
                              ? const Color(0xFF1E293B)
                              : AppTheme.coralUrgent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: a.isImage
                              ? AppTheme.skyAccent.withValues(alpha: 0.15)
                              : AppTheme.emeraldSuccess.withValues(alpha: 0.15),
                          child: Icon(
                            a.isImage
                                ? LucideIcons.image
                                : a.isPdf
                                ? LucideIcons.file_text
                                : LucideIcons.file,
                            color: a.isImage
                                ? AppTheme.skyAccent
                                : AppTheme.emeraldSuccess,
                            size: 16,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                a.fileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (a.stage != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF334155),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  a.stage!.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              a.isExternalUrl
                                  ? 'Enlace web: ${a.url}'
                                  : 'Ruta local: ${a.localFilePath}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: a.isExternalUrl
                                    ? AppTheme.skyAccent
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '${dateFormat.format(a.createdAt)} • ${a.provider == "external_url" ? "Nube / Web" : "Archivo Local"}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                if (!isAvailable) ...[
                                  const SizedBox(width: 8),
                                  const Text(
                                    '⚠️ Archivo local no disponible',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.coralUrgent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.copy, size: 16),
                              tooltip: 'Copiar enlace o ruta',
                              onPressed: () {
                                final textToCopy = a.isExternalUrl
                                    ? a.url ?? ''
                                    : a.localFilePath ?? '';
                                Clipboard.setData(
                                  ClipboardData(text: textToCopy),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copiado al portapapeles'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.trash,
                                size: 16,
                                color: Colors.grey,
                              ),
                              tooltip: 'Eliminar adjunto',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Eliminar Adjunto'),
                                    content: Text(
                                      '¿Desea quitar "${a.fileName}"? Se mantendrá el historial con soft-delete.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await storage.attachmentRepository
                                      .deleteAttachment(a.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
