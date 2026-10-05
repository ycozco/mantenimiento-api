import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/tool.dart';
import '../../core/models/tool_assignment.dart';
import '../../core/theme/app_theme.dart';

class ToolReturnDialog extends StatefulWidget {
  final ToolAssignment assignment;
  final Tool tool;
  final LocalStorageService storage;

  const ToolReturnDialog({
    super.key,
    required this.assignment,
    required this.tool,
    required this.storage,
  });

  @override
  State<ToolReturnDialog> createState() => _ToolReturnDialogState();
}

class _ToolReturnDialogState extends State<ToolReturnDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _returnDate;
  late String _conditionIn;
  bool _sendToMaintenance = false;
  late TextEditingController _notesCtrl;
  String? _errorMessage;

  final List<Map<String, String>> _conditions = [
    {'value': 'good', 'label': 'Buen estado (Operativa sin daños)'},
    {'value': 'fair', 'label': 'Regular / Desgaste normal de uso'},
    {'value': 'damaged', 'label': 'Dañada / Requiere taller o reparación'},
  ];

  @override
  void initState() {
    super.initState();
    _returnDate = DateTime.now();
    _conditionIn = widget.assignment.conditionOut;
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    try {
      await widget.storage.toolRepository.returnTool(
        assignmentId: widget.assignment.id,
        returnedAt: _returnDate,
        conditionIn: _conditionIn,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        sendToMaintenance: _sendToMaintenance || _conditionIn == 'damaged',
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldSuccess.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.undo_2,
                        color: AppTheme.emeraldSuccess,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Registrar Devolución',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.tool.name,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Fecha y Hora de Retorno
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _returnDate,
                      firstDate: widget.assignment.assignedAt,
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _returnDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Devolución *',
                      prefixIcon: Icon(LucideIcons.calendar, size: 18),
                    ),
                    child: Text(
                      dateFormat.format(_returnDate),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Estado Físico de Recepción
                DropdownButtonFormField<String>(
                  initialValue: _conditionIn,
                  decoration: const InputDecoration(
                    labelText: 'Estado Físico al Recibir *',
                    prefixIcon: Icon(LucideIcons.activity, size: 18),
                  ),
                  dropdownColor: const Color(0xFF0F172A),
                  items: _conditions.map((c) {
                    return DropdownMenuItem(
                      value: c['value'],
                      child: Text(c['label']!),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _conditionIn = v;
                        if (v == 'damaged') _sendToMaintenance = true;
                      });
                    }
                  },
                ),

                const SizedBox(height: 12),

                // Checkbox Enviar a Mantenimiento
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Enviar a Mantenimiento / Taller',
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  subtitle: const Text(
                    'La herramienta quedará no disponible hasta que se registre su reparación.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  value: _sendToMaintenance || _conditionIn == 'damaged',
                  activeColor: AppTheme.amberSafety,
                  onChanged: (val) {
                    if (_conditionIn != 'damaged') {
                      setState(() => _sendToMaintenance = val ?? false);
                    }
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones de Devolución (Opcional)',
                    hintText: 'Ej. Cuchilla desafilada, devuelta limpia, etc.',
                    prefixIcon: Icon(LucideIcons.file_text, size: 18),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.coralUrgent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.coralUrgent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.info,
                          color: AppTheme.coralUrgent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.coralUrgent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldSuccess,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _guardar,
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: const Text(
                        'Confirmar Devolución',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
