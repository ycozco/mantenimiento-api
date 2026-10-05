import 'package:flutter/material.dart';
import '../../core/database/local_storage_service.dart';
import '../../core/models/collection.dart';
import '../../core/models/obra.dart';

class CollectionFormDialog extends StatefulWidget {
  final Obra? obra;

  const CollectionFormDialog({super.key, this.obra});

  @override
  State<CollectionFormDialog> createState() => _CollectionFormDialogState();
}

class _CollectionFormDialogState extends State<CollectionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedClientId;
  String? _selectedProjectId;
  String? _receivedByPartnerId;
  DateTime _date = DateTime.now();
  final _amountController = TextEditingController();
  String _paymentMethod = 'cash';
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  int _previouslyCollectedCents = 0;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    if (widget.obra != null) {
      _selectedProjectId = widget.obra!.id;
      _selectedClientId = widget.obra!.clienteId;
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final storage = LocalStorageService();
    if (storage.socios.isNotEmpty) {
      _receivedByPartnerId = storage.socios.first.id;
    }

    if (_selectedProjectId != null) {
      final summary = await storage.collectionRepository
          .getProjectBillingSummary(
            _selectedProjectId!,
            ((widget.obra?.presupuesto ?? 0) * 100).round(),
          );
      _previouslyCollectedCents = summary.collectedCents;
    }

    if (mounted) {
      setState(() => _loadingBalance = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe seleccionar un cliente.')),
      );
      return;
    }

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

    final collection = Collection.create(
      clientId: _selectedClientId!,
      projectId: _selectedProjectId,
      amountCents: amountCents,
      date: _date,
      receivedByPartnerId: _receivedByPartnerId,
      paymentMethod: _paymentMethod,
      reference: _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    Navigator.pop(context, collection);
  }

  @override
  Widget build(BuildContext context) {
    final storage = LocalStorageService();
    final clientes = storage.clientes;
    final socios = storage.socios;

    final budgetCents = ((widget.obra?.presupuesto ?? 0) * 100).round();
    final thisPaymentAmount =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final thisPaymentCents = (thisPaymentAmount * 100).round();
    final newTotalCollectedCents = _previouslyCollectedCents + thisPaymentCents;
    final newReceivableCents = budgetCents - newTotalCollectedCents;
    final isOverpaid = newReceivableCents < 0;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Registrar Cobro a Cliente',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Panel Informativo de Saldos de la Obra
                  if (widget.obra != null && !_loadingBalance) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Presupuesto de Venta:'),
                              Text(
                                'S/ ${widget.obra!.presupuesto.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Cobrado previamente:'),
                              Text(
                                'S/ ${(_previouslyCollectedCents / 100.0).toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isOverpaid
                                    ? 'Saldo a favor (Sobrepago):'
                                    : 'Saldo por cobrar:',
                              ),
                              Text(
                                'S/ ${(newReceivableCents.abs() / 100.0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isOverpaid
                                      ? Colors.amber
                                      : Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          if (isOverpaid)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '⚠️ Advertencia: El cobro supera el presupuesto acordado.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Cliente
                  if (widget.obra == null) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedClientId,
                      decoration: const InputDecoration(
                        labelText: 'Cliente *',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: clientes.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nombre),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedClientId = val),
                      validator: (val) =>
                          val == null ? 'Seleccione un cliente' : null,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Monto y Fecha
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Monto a Cobrar (S/) *',
                            hintText: '1500.00',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return 'Ingrese monto';
                            final p = double.tryParse(val.replaceAll(',', '.'));
                            if (p == null || p <= 0) return 'Monto inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(
                                const Duration(days: 30),
                              ),
                            );
                            if (d != null) setState(() => _date = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha del Cobro',
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            child: Text(
                              '${_date.day}/${_date.month}/${_date.year}',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Método de pago y socio receptor
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Método de Pago',
                            prefixIcon: Icon(Icons.payment),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text('Efectivo'),
                            ),
                            DropdownMenuItem(
                              value: 'transfer',
                              child: Text('Transferencia'),
                            ),
                            DropdownMenuItem(
                              value: 'yape',
                              child: Text('Yape'),
                            ),
                            DropdownMenuItem(
                              value: 'plin',
                              child: Text('Plin'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Otro'),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _paymentMethod = val ?? 'cash'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _receivedByPartnerId,
                          decoration: const InputDecoration(
                            labelText: 'Cobrado por (Socio)',
                            prefixIcon: Icon(Icons.account_circle_outlined),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Empresa / Directo'),
                            ),
                            ...socios.map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.nombre),
                              ),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _receivedByPartnerId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'N° Operación / Referencia (Opcional)',
                      hintText: 'Ej. Op. 482910 / Cheque #12',
                      prefixIcon: Icon(Icons.receipt_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas adicionales',
                      hintText:
                          'Primer adelanto del 50%, saldo contra entrega...',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check),
                        label: const Text('Registrar Cobro'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
