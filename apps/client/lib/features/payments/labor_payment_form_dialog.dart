import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/models/labor_payment.dart';
import '../../core/models/worker.dart';
import '../../core/models/obra.dart';
import '../../core/theme/app_theme.dart';

class LaborPaymentFormDialog extends StatefulWidget {
  final Worker worker;
  final List<Obra> obras;
  final int currentBalanceCents;
  final LaborPayment? pagoExistente;
  final Future<void> Function(LaborPayment pago) onGuardar;

  const LaborPaymentFormDialog({
    super.key,
    required this.worker,
    required this.obras,
    required this.currentBalanceCents,
    this.pagoExistente,
    required this.onGuardar,
  });

  @override
  State<LaborPaymentFormDialog> createState() => _LaborPaymentFormDialogState();
}

class _LaborPaymentFormDialogState extends State<LaborPaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _montoController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late PaymentMethod _selectedMethod;
  String? _selectedProjectId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.pagoExistente;
    _montoController = TextEditingController(
      text: p != null ? p.amount.toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: p?.notes ?? '');
    _selectedDate = p?.paymentDate ?? DateTime.now();
    _selectedMethod = p != null
        ? PaymentMethodExt.fromString(p.paymentMethod)
        : PaymentMethod.cash;
    _selectedProjectId = p?.projectId;
  }

  @override
  void dispose() {
    _montoController.disposeDisposeSafe();
    _notesController.disposeDisposeSafe();
    super.dispose();
  }

  int get _enteredAmountCents {
    final parsed = double.tryParse(_montoController.text.trim()) ?? 0.0;
    return (parsed * 100).round();
  }

  int get _posteriorBalanceCents {
    return widget.currentBalanceCents - _enteredAmountCents;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amountCents = _enteredAmountCents;
    if (amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El monto del pago debe ser mayor a 0'),
          backgroundColor: AppTheme.coralUrgent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final pago =
          (widget.pagoExistente ??
                  LaborPayment(
                    workerId: widget.worker.id,
                    amountCents: amountCents,
                  ))
              .copyWith(
                workerId: widget.worker.id,
                projectId: _selectedProjectId,
                amountCents: amountCents,
                paymentDate: _selectedDate,
                paymentMethod: _selectedMethod.nameCode,
                notes: _notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim(),
              );

      await widget.onGuardar(pago);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar pago: $e'),
            backgroundColor: AppTheme.coralUrgent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currentBalance = widget.currentBalanceCents / 100.0;
    final posteriorBalance = _posteriorBalanceCents / 100.0;
    final isAdvance = _posteriorBalanceCents < 0;

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
                // Encabezado
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldSuccess.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.banknote,
                        color: AppTheme.emeraldSuccess,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.pagoExistente != null
                                ? 'Editar Pago'
                                : 'Registrar Pago',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.worker.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.amberSafety,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Resumen en vivo de saldos
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAdvance
                          ? AppTheme.coralUrgent.withValues(alpha: 0.5)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Saldo Pendiente Actual:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            'S/ ${currentBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: currentBalance > 0
                                  ? AppTheme.amberSafety
                                  : (currentBalance == 0
                                        ? AppTheme.emeraldSuccess
                                        : AppTheme.skyAccent),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 12, color: Color(0xFF334155)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Saldo Posterior:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            'S/ ${posteriorBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: posteriorBalance > 0
                                  ? AppTheme.amberSafety
                                  : (posteriorBalance == 0
                                        ? AppTheme.emeraldSuccess
                                        : AppTheme.coralUrgent),
                            ),
                          ),
                        ],
                      ),
                      if (isAdvance) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.info,
                              size: 14,
                              color: AppTheme.coralUrgent,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Este pago excede lo devengado y generará un adelanto de S/ ${(-posteriorBalance).toStringAsFixed(2)}.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.coralUrgent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Campo Monto
                TextFormField(
                  controller: _montoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'Monto a Pagar (S/) *',
                    prefixIcon: Icon(LucideIcons.circle_dollar_sign),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el monto a pagar';
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'El monto debe ser un número mayor a 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Fecha de Pago
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de Pago *',
                      prefixIcon: Icon(LucideIcons.calendar),
                    ),
                    child: Text(
                      dateFormat.format(_selectedDate),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Método de Pago
                DropdownButtonFormField<PaymentMethod>(
                  initialValue: _selectedMethod,
                  decoration: const InputDecoration(
                    labelText: 'Método de Pago *',
                    prefixIcon: Icon(LucideIcons.credit_card),
                  ),
                  dropdownColor: const Color(0xFF1E293B),
                  items: PaymentMethod.values.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(
                        m.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMethod = val);
                  },
                ),
                const SizedBox(height: 14),

                // Obra Opcional
                DropdownButtonFormField<String?>(
                  initialValue: _selectedProjectId,
                  decoration: const InputDecoration(
                    labelText: 'Obra Relacionada (Opcional)',
                    prefixIcon: Icon(LucideIcons.building),
                  ),
                  dropdownColor: const Color(0xFF1E293B),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'Ninguna (Pago general)',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    ...widget.obras.map((o) {
                      return DropdownMenuItem(
                        value: o.id,
                        child: Text(
                          o.nombre,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedProjectId = val),
                ),
                const SizedBox(height: 14),

                // Notas / Referencia
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Notas / Número de Operación (Opcional)',
                    prefixIcon: Icon(LucideIcons.file_text),
                  ),
                ),
                const SizedBox(height: 20),

                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldSuccess,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _isSaving ? null : _submit,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(LucideIcons.check, size: 16),
                      label: Text(
                        widget.pagoExistente != null
                            ? 'Actualizar Pago'
                            : 'Guardar Pago',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

extension on TextEditingController {
  void disposeDisposeSafe() {
    dispose();
  }
}
