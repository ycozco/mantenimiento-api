import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/obra.dart';
import '../../core/models/worker.dart';
import '../../core/models/work_log.dart';
import '../../core/theme/app_theme.dart';

class WorkLogFormDialog extends StatefulWidget {
  final List<Worker> workers;
  final List<Obra> obras;
  final String? obraPreseleccionadaId;
  final String? workerPreseleccionadoId;
  final String? maintenanceVisitId;
  final WorkLog? workLogExistente;
  final ValueChanged<WorkLog> onGuardar;

  const WorkLogFormDialog({
    super.key,
    required this.workers,
    required this.obras,
    this.obraPreseleccionadaId,
    this.workerPreseleccionadoId,
    this.maintenanceVisitId,
    this.workLogExistente,
    required this.onGuardar,
  });

  @override
  State<WorkLogFormDialog> createState() => _WorkLogFormDialogState();
}

class _WorkLogFormDialogState extends State<WorkLogFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedWorkerId;
  String? _selectedProjectId;
  String? _selectedVisitId;
  late DateTime _fecha;
  late String _tipoPago;
  late TextEditingController _cantidadCtrl;
  late TextEditingController _tarifaCtrl;
  late TextEditingController _notasCtrl;

  @override
  void initState() {
    super.initState();
    final log = widget.workLogExistente;

    _selectedWorkerId = log?.workerId ?? widget.workerPreseleccionadoId;
    if (_selectedWorkerId == null && widget.workers.isNotEmpty) {
      _selectedWorkerId = widget.workers.first.id;
    }

    _selectedVisitId = log?.maintenanceVisitId ?? widget.maintenanceVisitId;

    if (_selectedVisitId == null) {
      _selectedProjectId = log?.projectId ?? widget.obraPreseleccionadaId;
      if (_selectedProjectId == null && widget.obras.isNotEmpty) {
        _selectedProjectId = widget.obras.first.id;
      }
    } else {
      _selectedProjectId = null;
    }

    _fecha = log?.date ?? DateTime.now();

    final worker = _getWorker(_selectedWorkerId);
    _tipoPago =
        log?.paymentType ??
        worker?.defaultPaymentType ??
        AppConstants.paymentTypeDaily;

    final initialQuantity = log?.quantity ?? 1.0;
    _cantidadCtrl = TextEditingController(
      text: initialQuantity % 1 == 0
          ? initialQuantity.toInt().toString()
          : initialQuantity.toString(),
    );

    final initialRate = log != null
        ? log.rateCents / 100.0
        : (worker != null ? worker.defaultRateCents / 100.0 : 0.0);
    _tarifaCtrl = TextEditingController(
      text: initialRate > 0 ? initialRate.toStringAsFixed(2) : '',
    );

    _notasCtrl = TextEditingController(text: log?.notes ?? '');

    _cantidadCtrl.addListener(() => setState(() {}));
    _tarifaCtrl.addListener(() => setState(() {}));
  }

  Worker? _getWorker(String? id) {
    if (id == null) return null;
    try {
      return widget.workers.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  void _onWorkerChanged(String? newWorkerId) {
    if (newWorkerId == null) return;
    setState(() {
      _selectedWorkerId = newWorkerId;
      final worker = _getWorker(newWorkerId);
      if (worker != null && widget.workLogExistente == null) {
        // Pre-cargar valores por defecto del trabajador sin sobreescribir el historial
        _tipoPago = worker.defaultPaymentType;
        final rate = worker.defaultRateCents / 100.0;
        _tarifaCtrl.text = rate > 0 ? rate.toStringAsFixed(2) : '';
      }
    });
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _tarifaCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  int _calcularTotalCents() {
    final qty = double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final rateDouble =
        double.tryParse(_tarifaCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final rateCents = (rateDouble * 100).round();

    return WorkLog.calculateAmountCents(
      paymentType: _tipoPago,
      quantity: qty,
      rateCents: rateCents,
    );
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWorkerId == null) return;
    if (_selectedProjectId == null && _selectedVisitId == null) return;

    final qty = double.tryParse(_cantidadCtrl.text.replaceAll(',', '.')) ?? 1.0;
    final rateDouble =
        double.tryParse(_tarifaCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final rateCents = (rateDouble * 100).round();
    final amountCents = _calcularTotalCents();

    final workLog = widget.workLogExistente != null
        ? widget.workLogExistente!.copyWith(
            workerId: _selectedWorkerId!,
            projectId: _selectedVisitId != null ? null : _selectedProjectId,
            maintenanceVisitId: _selectedVisitId,
            date: _fecha,
            paymentType: _tipoPago,
            quantity: qty,
            rateCents: rateCents,
            amountCents: amountCents,
            notes: _notasCtrl.text.trim().isEmpty
                ? null
                : _notasCtrl.text.trim(),
          )
        : WorkLog(
            id: const Uuid().v4(),
            workerId: _selectedWorkerId!,
            projectId: _selectedVisitId != null ? null : _selectedProjectId,
            maintenanceVisitId: _selectedVisitId,
            date: _fecha,
            paymentType: _tipoPago,
            quantity: qty,
            rateCents: rateCents,
            amountCents: amountCents,
            notes: _notasCtrl.text.trim().isEmpty
                ? null
                : _notasCtrl.text.trim(),
          );

    widget.onGuardar(workLog);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.workLogExistente != null;
    final totalCents = _calcularTotalCents();
    final totalFormatted = (totalCents / 100.0).toStringAsFixed(2);
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
                        LucideIcons.calendar_check,
                        color: AppTheme.skyAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        esEdicion ? 'Editar Jornada' : 'Registrar Jornada',
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
                DropdownButtonFormField<String>(
                  initialValue: _selectedWorkerId,
                  decoration: const InputDecoration(
                    labelText: 'Trabajador *',
                    prefixIcon: Icon(LucideIcons.hard_hat, size: 18),
                  ),
                  dropdownColor: const Color(0xFF0F172A),
                  items: widget.workers.map((w) {
                    final tarifaStr = w.defaultRateCents > 0
                        ? ' (S/ ${(w.defaultRateCents / 100).toStringAsFixed(0)} ${w.paymentTypeLabel})'
                        : '';
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        '${w.name}$tarifaStr',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onWorkerChanged,
                  validator: (v) => v == null ? 'Seleccione trabajador' : null,
                ),
                const SizedBox(height: 12),
                if (_selectedVisitId != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldSuccess.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.emeraldSuccess.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          LucideIcons.wrench,
                          color: AppTheme.emeraldSuccess,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Jornada asociada a Visita de Mantenimiento',
                            style: TextStyle(
                              color: AppTheme.emeraldSuccess,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProjectId,
                    decoration: const InputDecoration(
                      labelText: 'Obra / Proyecto *',
                      prefixIcon: Icon(LucideIcons.building, size: 18),
                    ),
                    dropdownColor: const Color(0xFF0F172A),
                    items: widget.obras.map((o) {
                      return DropdownMenuItem(
                        value: o.id,
                        child: Text(o.nombre, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedProjectId = val),
                    validator: (v) => v == null ? 'Seleccione la obra' : null,
                  ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fecha,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _fecha = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de la jornada *',
                      prefixIcon: Icon(LucideIcons.calendar, size: 18),
                    ),
                    child: Text(
                      dateFormat.format(_fecha),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _tipoPago,
                  decoration: const InputDecoration(
                    labelText: 'Modalidad de pago para esta jornada',
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
                      setState(() {
                        _tipoPago = val;
                        if (_tipoPago == AppConstants.paymentTypeFixed) {
                          _cantidadCtrl.text = '1';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cantidadCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _tipoPago == AppConstants.paymentTypeHourly
                              ? 'Horas trabajadas *'
                              : _tipoPago == AppConstants.paymentTypeFixed
                              ? 'Cantidad destajos *'
                              : 'Días trabajados *',
                          hintText: _tipoPago == AppConstants.paymentTypeHourly
                              ? 'Ej: 6.5'
                              : 'Ej: 1',
                          prefixIcon: const Icon(LucideIcons.hash, size: 18),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Obligatorio';
                          }
                          final n = double.tryParse(val.replaceAll(',', '.'));
                          if (n == null || n <= 0) {
                            return 'Mayor a 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _tarifaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _tipoPago == AppConstants.paymentTypeHourly
                              ? 'Tarifa x hora (S/) *'
                              : _tipoPago == AppConstants.paymentTypeFixed
                              ? 'Monto acordado (S/) *'
                              : 'Tarifa x día (S/) *',
                          hintText: 'Ej: 70.00',
                          prefixIcon: const Icon(
                            LucideIcons.badge_dollar_sign,
                            size: 18,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Obligatorio';
                          }
                          final n = double.tryParse(val.replaceAll(',', '.'));
                          if (n == null || n < 0) {
                            return 'Válido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tarjeta de Previsualización del Total Devengado
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.skyAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total devengado:',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'S/ $totalFormatted',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.skyAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Detalle de la labor (opcional)',
                    hintText: 'Zanja, vaciado de falso piso, etc.',
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
                        backgroundColor: AppTheme.skyAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: Text(
                        esEdicion ? 'Actualizar' : 'Guardar Jornada',
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
