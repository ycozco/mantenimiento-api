import 'package:flutter/material.dart';
import '../../core/database/local_storage_service.dart';
import '../../core/models/capital_movement.dart';

class CapitalMovementFormDialog extends StatefulWidget {
  final String partnerId;

  const CapitalMovementFormDialog({super.key, required this.partnerId});

  @override
  State<CapitalMovementFormDialog> createState() =>
      _CapitalMovementFormDialogState();
}

class _CapitalMovementFormDialogState extends State<CapitalMovementFormDialog> {
  final _formKey = GlobalKey<FormState>();

  String _movementType = 'contribution';
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _selectedProjectId;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(
      _amountController.text.replaceAll(',', '.'),
    );
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un monto válido mayor a 0.')),
      );
      return;
    }

    final amountCents = (parsedAmount * 100).round();

    final movement = CapitalMovement.create(
      partnerId: widget.partnerId,
      projectId: _selectedProjectId,
      type: _movementType,
      amountCents: amountCents,
      date: _date,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    Navigator.pop(context, movement);
  }

  @override
  Widget build(BuildContext context) {
    final storage = LocalStorageService();
    final obras = storage.obras;

    return AlertDialog(
      title: const Text('Registrar Movimiento de Capital'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _movementType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Movimiento *',
                  prefixIcon: Icon(Icons.swap_horiz),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'contribution',
                    child: Text('Aporte de Capital (+)'),
                  ),
                  DropdownMenuItem(
                    value: 'partnerExpense',
                    child: Text('Gasto Pagado Personalmente (+)'),
                  ),
                  DropdownMenuItem(
                    value: 'withdrawal',
                    child: Text('Retiro de Capital (-)'),
                  ),
                  DropdownMenuItem(
                    value: 'profitDistribution',
                    child: Text('Distribución de Utilidades (-)'),
                  ),
                  DropdownMenuItem(
                    value: 'adjustment',
                    child: Text('Ajuste de Capital (±)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _movementType = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto (S/) *',
                  hintText: '500.00',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingrese el monto';
                  }
                  final p = double.tryParse(val.replaceAll(',', '.'));
                  if (p == null || p <= 0) {
                    return 'Monto inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha del Movimiento',
                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text('${_date.day}/${_date.month}/${_date.year}'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedProjectId,
                decoration: const InputDecoration(
                  labelText: 'Obra Relacionada (Opcional)',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Ninguna (Movimiento General)'),
                  ),
                  ...obras.map(
                    (o) => DropdownMenuItem(value: o.id, child: Text(o.nombre)),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedProjectId = val),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas / Justificación',
                  hintText:
                      'Pago de flete con tarjeta personal, aporte inicial...',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Registrar')),
      ],
    );
  }
}
