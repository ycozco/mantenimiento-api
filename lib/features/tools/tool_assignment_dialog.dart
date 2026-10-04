import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/tool.dart';
import '../../core/models/tool_assignment.dart';
import '../../core/models/worker.dart';
import '../../core/theme/app_theme.dart';

class ToolAssignmentDialog extends StatefulWidget {
  final Tool tool;
  final LocalStorageService storage;
  final String? preselectedWorkerId;
  final String? preselectedProjectId;
  final String? preselectedVisitId;

  const ToolAssignmentDialog({
    super.key,
    required this.tool,
    required this.storage,
    this.preselectedWorkerId,
    this.preselectedProjectId,
    this.preselectedVisitId,
  });

  @override
  State<ToolAssignmentDialog> createState() => _ToolAssignmentDialogState();
}

class _ToolAssignmentDialogState extends State<ToolAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedWorkerId;
  String? _selectedProjectId;
  String? _selectedVisitId;
  late String _conditionOut;
  DateTime? _expectedReturnAt;
  late TextEditingController _notesCtrl;
  List<Worker> _workers = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedWorkerId = widget.preselectedWorkerId;
    _selectedProjectId = widget.preselectedProjectId;
    _selectedVisitId = widget.preselectedVisitId;
    _conditionOut = widget.tool.condition;
    _notesCtrl = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    final workers = await widget.storage.workerRepository.getActiveWorkers();
    if (mounted) {
      setState(() {
        _workers = workers;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    if (_selectedWorkerId == null &&
        _selectedProjectId == null &&
        _selectedVisitId == null) {
      setState(() {
        _errorMessage =
            'Debe asignar la herramienta al menos a un Trabajador, Obra o Visita de mantenimiento.';
      });
      return;
    }

    try {
      final assignment = ToolAssignment.create(
        toolId: widget.tool.id,
        workerId: _selectedWorkerId,
        projectId: _selectedProjectId,
        maintenanceVisitId: _selectedVisitId,
        expectedReturnAt: _expectedReturnAt,
        conditionOut: _conditionOut,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await widget.storage.toolRepository.assignTool(assignment);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

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
                        color: AppTheme.skyAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.user_check,
                        color: AppTheme.skyAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Entregar / Asignar Herramienta',
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

                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  // Trabajador Custodio
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedWorkerId,
                    decoration: const InputDecoration(
                      labelText: 'Trabajador Responsable / Custodio',
                      prefixIcon: Icon(LucideIcons.hard_hat, size: 18),
                    ),
                    dropdownColor: const Color(0xFF0F172A),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sin trabajador específico'),
                      ),
                      ..._workers.map((w) {
                        return DropdownMenuItem(
                          value: w.id,
                          child: Text(w.name, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _selectedWorkerId = v),
                  ),

                  const SizedBox(height: 12),

                  // Obra de Destino
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedProjectId,
                    decoration: const InputDecoration(
                      labelText: 'Obra / Proyecto de Destino',
                      prefixIcon: Icon(LucideIcons.building, size: 18),
                    ),
                    dropdownColor: const Color(0xFF0F172A),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sin obra específica'),
                      ),
                      ...widget.storage.obras.map((o) {
                        return DropdownMenuItem(
                          value: o.id,
                          child: Text(
                            o.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: widget.preselectedProjectId != null
                        ? null
                        : (v) => setState(() => _selectedProjectId = v),
                  ),

                  const SizedBox(height: 12),

                  // Estado Físico de Entrega
                  DropdownButtonFormField<String>(
                    initialValue: _conditionOut,
                    decoration: const InputDecoration(
                      labelText: 'Estado Físico al Entregar',
                      prefixIcon: Icon(LucideIcons.activity, size: 18),
                    ),
                    dropdownColor: const Color(0xFF0F172A),
                    items: const [
                      DropdownMenuItem(
                        value: 'good',
                        child: Text('Buen estado / Operativa'),
                      ),
                      DropdownMenuItem(
                        value: 'fair',
                        child: Text('Regular / Desgaste visible'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _conditionOut = v);
                    },
                  ),

                  const SizedBox(height: 12),

                  // Fecha Estimada de Devolución
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _expectedReturnAt ??
                            DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _expectedReturnAt = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fecha Estimada de Retorno (Opcional)',
                        prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                        suffixIcon: _expectedReturnAt != null
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () =>
                                    setState(() => _expectedReturnAt = null),
                              )
                            : null,
                      ),
                      child: Text(
                        _expectedReturnAt != null
                            ? dateFormat.format(_expectedReturnAt!)
                            : 'No definida',
                        style: TextStyle(
                          color: _expectedReturnAt != null
                              ? Colors.white
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notas / Accesorios incluidos (Opcional)',
                      prefixIcon: Icon(LucideIcons.file_text, size: 18),
                    ),
                  ),
                ],

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
                        backgroundColor: AppTheme.skyAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _loading ? null : _guardar,
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: const Text(
                        'Confirmar Entrega',
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
