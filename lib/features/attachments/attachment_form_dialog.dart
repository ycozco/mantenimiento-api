import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../core/models/attachment.dart';

class AttachmentFormDialog extends StatefulWidget {
  final String parentType;
  final String parentId;

  const AttachmentFormDialog({
    super.key,
    required this.parentType,
    required this.parentId,
  });

  @override
  State<AttachmentFormDialog> createState() => _AttachmentFormDialogState();
}

class _AttachmentFormDialogState extends State<AttachmentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  String _provider = 'external_url'; // 'external_url' o 'local'
  String _kind = 'image'; // 'image', 'pdf', 'document'
  final _urlController = TextEditingController();
  final _pathController = TextEditingController();
  final _titleController = TextEditingController();
  String? _stage = 'during'; // 'before', 'during', 'after'

  @override
  void dispose() {
    _urlController.dispose();
    _pathController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    try {
      final Attachment attachment;
      if (_provider == 'external_url') {
        attachment = Attachment.createUrl(
          parentType: widget.parentType,
          parentId: widget.parentId,
          url: _urlController.text.trim(),
          fileName: _titleController.text.trim(),
          kind: _kind,
          stage: _stage,
        );
      } else {
        attachment = Attachment.createLocalFile(
          parentType: widget.parentType,
          parentId: widget.parentId,
          localFilePath: _pathController.text.trim(),
          fileName: _titleController.text.trim(),
          kind: _kind,
          stage: _stage,
        );
      }

      Navigator.pop(context, attachment);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adjuntar Evidencia o Archivo'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de origen
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'external_url',
                    label: Text('Enlace Web / URL'),
                    icon: Icon(LucideIcons.globe, size: 16),
                  ),
                  ButtonSegment(
                    value: 'local',
                    label: Text('PDF Local'),
                    icon: Icon(LucideIcons.file_text, size: 16),
                  ),
                ],
                selected: {_provider},
                onSelectionChanged: (set) {
                  setState(() {
                    _provider = set.first;
                    if (_provider == 'local') _kind = 'pdf';
                    if (_provider == 'external_url') _kind = 'image';
                  });
                },
              ),
              const SizedBox(height: 16),

              // Tipo de Contenido
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Archivo',
                  prefixIcon: Icon(LucideIcons.file_type),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'image',
                    child: Text('Imagen / Foto de Evidencia'),
                  ),
                  DropdownMenuItem(
                    value: 'pdf',
                    child: Text('Documento PDF (Plano / Contrato)'),
                  ),
                  DropdownMenuItem(
                    value: 'document',
                    child: Text('Otro Documento'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _kind = val);
                },
              ),
              const SizedBox(height: 12),

              // Etapa (Opcional)
              DropdownButtonFormField<String>(
                initialValue: _stage,
                decoration: const InputDecoration(
                  labelText: 'Etapa Operativa',
                  prefixIcon: Icon(LucideIcons.layers),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'before',
                    child: Text('Antes (Estado Inicial)'),
                  ),
                  DropdownMenuItem(
                    value: 'during',
                    child: Text('Durante (En Ejecución)'),
                  ),
                  DropdownMenuItem(
                    value: 'after',
                    child: Text('Después (Entrega / Concluido)'),
                  ),
                ],
                onChanged: (val) => setState(() => _stage = val),
              ),
              const SizedBox(height: 12),

              // Título descriptivo
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título o Nombre del Archivo *',
                  hintText: 'Ej. Plano Hidráulico / Foto Cerco',
                  prefixIcon: Icon(LucideIcons.tag),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingrese un nombre para el archivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Campo según el proveedor
              if (_provider == 'external_url') ...[
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL de Imagen o Documento *',
                    hintText:
                        'https://drive.google.com/... o https://i.ibb.co/...',
                    prefixIcon: Icon(LucideIcons.link),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ingrese la URL';
                    }
                    final uri = Uri.tryParse(val.trim());
                    if (uri == null ||
                        (!uri.isScheme('http') && !uri.isScheme('https'))) {
                      return 'URL inválida (debe empezar con http:// o https://)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'Soporta fotos en la nube (Google Drive, ImgBB, etc.) sin consumir almacenamiento local.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ] else ...[
                TextFormField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    labelText: 'Ruta local del PDF en el dispositivo *',
                    hintText:
                        'C:\\documentos\\plano.pdf o /storage/emulated/...',
                    prefixIcon: Icon(LucideIcons.folder),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ingrese la ruta del archivo local';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'El archivo no se copia en base de datos. Se conserva el puntero y metadatos.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(LucideIcons.check, size: 16),
          label: const Text('Guardar Adjunto'),
        ),
      ],
    );
  }
}
