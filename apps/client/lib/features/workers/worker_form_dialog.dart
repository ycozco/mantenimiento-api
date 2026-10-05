import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/worker.dart';
import '../../core/theme/app_theme.dart';

class WorkerFormDialog extends StatefulWidget {
  final Worker? workerExistente;
  final ValueChanged<Worker> onGuardar;

  const WorkerFormDialog({
    super.key,
    this.workerExistente,
    required this.onGuardar,
  });

  @override
  State<WorkerFormDialog> createState() => _WorkerFormDialogState();
}

class _WorkerFormDialogState extends State<WorkerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _especialidadCtrl;
  late TextEditingController _tarifaCtrl;
  late TextEditingController _notasCtrl;

  late String _tipoPagoSeleccionado;

  @override
  void initState() {
    super.initState();
    final w = widget.workerExistente;
    _nombreCtrl = TextEditingController(text: w?.name ?? '');
    _telefonoCtrl = TextEditingController(text: w?.phone ?? '');
    _especialidadCtrl = TextEditingController(text: w?.specialty ?? '');
    _tarifaCtrl = TextEditingController(
      text: w != null && w.defaultRateCents > 0
          ? (w.defaultRateCents / 100.0).toStringAsFixed(2)
          : '',
    );
    _notasCtrl = TextEditingController(text: w?.notes ?? '');
    _tipoPagoSeleccionado =
        w?.defaultPaymentType ?? AppConstants.paymentTypeDaily;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _especialidadCtrl.dispose();
    _tarifaCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final tarifaDouble =
        double.tryParse(_tarifaCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final tarifaCents = (tarifaDouble * 100).round();

    final worker = widget.workerExistente != null
        ? widget.workerExistente!.copyWith(
            name: _nombreCtrl.text.trim(),
            phone: _telefonoCtrl.text.trim().isEmpty
                ? null
                : _telefonoCtrl.text.trim(),
            specialty: _especialidadCtrl.text.trim().isEmpty
                ? null
                : _especialidadCtrl.text.trim(),
            defaultPaymentType: _tipoPagoSeleccionado,
            defaultRateCents: tarifaCents,
            notes: _notasCtrl.text.trim().isEmpty
                ? null
                : _notasCtrl.text.trim(),
          )
        : Worker(
            id: const Uuid().v4(),
            name: _nombreCtrl.text.trim(),
            phone: _telefonoCtrl.text.trim().isEmpty
                ? null
                : _telefonoCtrl.text.trim(),
            specialty: _especialidadCtrl.text.trim().isEmpty
                ? null
                : _especialidadCtrl.text.trim(),
            defaultPaymentType: _tipoPagoSeleccionado,
            defaultRateCents: tarifaCents,
            notes: _notasCtrl.text.trim().isEmpty
                ? null
                : _notasCtrl.text.trim(),
          );

    widget.onGuardar(worker);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.workerExistente != null;

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
                        color: AppTheme.amberSafety.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.user,
                        color: AppTheme.amberSafety,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        esEdicion ? 'Editar Trabajador' : 'Nuevo Trabajador',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo *',
                    hintText: 'Ej: Juan Pérez',
                    prefixIcon: Icon(LucideIcons.user, size: 18),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _telefonoCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          hintText: '999111222',
                          prefixIcon: Icon(LucideIcons.phone, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _especialidadCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Especialidad',
                          hintText: 'Albañil, peón...',
                          prefixIcon: Icon(LucideIcons.hammer, size: 18),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _tipoPagoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Modalidad de pago predeterminada',
                    prefixIcon: Icon(LucideIcons.clock, size: 18),
                  ),
                  dropdownColor: const Color(0xFF0F172A),
                  items: const [
                    DropdownMenuItem(
                      value: AppConstants.paymentTypeDaily,
                      child: Text('Por día (jornal diario)'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.paymentTypeHourly,
                      child: Text('Por hora'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.paymentTypeFixed,
                      child: Text('Fijo / Destajo'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _tipoPagoSeleccionado = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tarifaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        _tipoPagoSeleccionado == AppConstants.paymentTypeHourly
                        ? 'Tarifa predeterminada por hora (S/)'
                        : _tipoPagoSeleccionado == AppConstants.paymentTypeFixed
                        ? 'Tarifa predeterminada por destajo (S/)'
                        : 'Tarifa predeterminada por día (S/)',
                    hintText: 'Ej: 70.00',
                    prefixIcon: const Icon(
                      LucideIcons.badge_dollar_sign,
                      size: 18,
                    ),
                  ),
                  validator: (val) {
                    if (val != null && val.isNotEmpty) {
                      final n = double.tryParse(val.replaceAll(',', '.'));
                      if (n == null || n < 0) {
                        return 'Ingrese un monto válido';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notasCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas adicionales (opcional)',
                    hintText: 'Disponibilidad, contacto de emergencia, etc.',
                    prefixIcon: Icon(LucideIcons.file_text, size: 18),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.amberSafety,
                        foregroundColor: const Color(0xFF0F172A),
                      ),
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: Text(
                        esEdicion ? 'Actualizar' : 'Guardar',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _guardar,
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
