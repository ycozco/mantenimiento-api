import 'package:flutter/material.dart';
import '../../core/database/local_storage_service.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/purchase.dart';
import '../../core/models/supplier.dart';
import '../../core/repositories/purchase_repository.dart';

class PurchaseFormDialog extends StatefulWidget {
  const PurchaseFormDialog({super.key});

  @override
  State<PurchaseFormDialog> createState() => _PurchaseFormDialogState();
}

class _ItemLineInput {
  String? itemId;
  double quantity = 1.0;
  double unitCost = 0.0;
  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController costController = TextEditingController(
    text: '0.00',
  );

  int get unitCostCents => (unitCost * 100).round();
  int get totalCostCents => (quantity * unitCostCents).round();
  double get totalCost => totalCostCents / 100.0;
}

class _PurchaseFormDialogState extends State<PurchaseFormDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedSupplierId;
  String? _selectedPartnerId;
  DateTime _purchaseDate = DateTime.now();
  String _documentType = 'invoice';
  final _invoiceNumberController = TextEditingController();
  final _notesController = TextEditingController();

  final List<_ItemLineInput> _lines = [];
  List<InventoryItem> _availableItems = [];
  List<Supplier> _availableSuppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _addNewLine();
  }

  Future<void> _loadData() async {
    final storage = LocalStorageService();
    final items = await storage.inventoryRepository.watchActiveItems().first;
    final suppliers = await storage.purchaseRepository
        .watchActiveSuppliers()
        .first;

    if (mounted) {
      setState(() {
        _availableItems = items;
        _availableSuppliers = suppliers;
        if (storage.socios.isNotEmpty) {
          _selectedPartnerId = storage.socios.first.id;
        }
        _isLoading = false;
      });
    }
  }

  void _addNewLine() {
    setState(() {
      final line = _ItemLineInput();
      _lines.add(line);
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La compra debe contener al menos un producto.'),
        ),
      );
      return;
    }
    setState(() {
      _lines.removeAt(index);
    });
  }

  int get _grandTotalCents {
    int total = 0;
    for (final line in _lines) {
      total += line.totalCostCents;
    }
    return total;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    for (int i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.itemId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seleccione el producto en la línea ${i + 1}'),
          ),
        );
        return;
      }
      if (line.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cantidad inválida en la línea ${i + 1}')),
        );
        return;
      }
    }

    final purchase = Purchase.create(
      supplierId: _selectedSupplierId,
      paidByPartnerId: _selectedPartnerId,
      totalAmountCents: _grandTotalCents,
      date: _purchaseDate,
      documentType: _documentType,
      invoiceNumber: _invoiceNumberController.text.trim().isEmpty
          ? null
          : _invoiceNumberController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final drafts = _lines
        .map(
          (l) => PurchaseItemDraft(
            itemId: l.itemId!,
            quantity: l.quantity,
            unitCostCents: l.unitCostCents,
          ),
        )
        .toList();

    try {
      final storage = LocalStorageService();
      await storage.purchaseRepository.recordPurchase(
        purchase: purchase,
        items: drafts,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compra e inventario registrados exitosamente.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar compra: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final socios = LocalStorageService().socios;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Registrar Compra de Insumos',
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
                Expanded(
                  child: ListView(
                    children: [
                      // Encabezado de Compra
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: _selectedSupplierId,
                              decoration: const InputDecoration(
                                labelText: 'Proveedor',
                                prefixIcon: Icon(Icons.storefront),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Compra Directa / Sin Proveedor'),
                                ),
                                ..._availableSuppliers.map(
                                  (s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.name),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedSupplierId = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: _selectedPartnerId,
                              decoration: const InputDecoration(
                                labelText: 'Pagado por (Socio)',
                                prefixIcon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Caja de la Empresa'),
                                ),
                                ...socios.map(
                                  (socio) => DropdownMenuItem(
                                    value: socio.id,
                                    child: Text(socio.nombre),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedPartnerId = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _documentType,
                              decoration: const InputDecoration(
                                labelText: 'Comprobante',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'invoice',
                                  child: Text('Factura'),
                                ),
                                DropdownMenuItem(
                                  value: 'receipt',
                                  child: Text('Boleta'),
                                ),
                                DropdownMenuItem(
                                  value: 'ticket',
                                  child: Text('Ticket / Nota'),
                                ),
                                DropdownMenuItem(
                                  value: 'none',
                                  child: Text('Sin Comprobante'),
                                ),
                                DropdownMenuItem(
                                  value: 'other',
                                  child: Text('Otro'),
                                ),
                              ],
                              onChanged: (val) => setState(
                                () => _documentType = val ?? 'invoice',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _invoiceNumberController,
                              decoration: const InputDecoration(
                                labelText: 'N° Documento (Opcional)',
                                hintText: 'F001-00234',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _purchaseDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 1),
                                  ),
                                );
                                if (d != null) {
                                  setState(() => _purchaseDate = d);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Fecha',
                                  prefixIcon: Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                  ),
                                ),
                                child: Text(
                                  '${_purchaseDate.day}/${_purchaseDate.month}/${_purchaseDate.year}',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Tabla de Líneas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Productos Comprados',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: _addNewLine,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Agregar Producto'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._lines.asMap().entries.map((entry) {
                        final index = entry.key;
                        final line = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: line.itemId,
                                    decoration: InputDecoration(
                                      labelText: 'Item #${index + 1}',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                    ),
                                    items: _availableItems.map((item) {
                                      return DropdownMenuItem(
                                        value: item.id,
                                        child: Text(
                                          '${item.name} (${item.unit})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        line.itemId = val;
                                        final matched = _availableItems
                                            .firstWhere((i) => i.id == val);
                                        if (line.unitCost == 0.0 &&
                                            matched.defaultCostCents > 0) {
                                          line.unitCost =
                                              matched.defaultCostCents / 100.0;
                                          line.costController.text = line
                                              .unitCost
                                              .toStringAsFixed(2);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: line.quantityController,
                                    decoration: const InputDecoration(
                                      labelText: 'Cantidad',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(
                                        val.replaceAll(',', '.'),
                                      );
                                      if (parsed != null) {
                                        setState(() => line.quantity = parsed);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: line.costController,
                                    decoration: const InputDecoration(
                                      labelText: 'Costo Unit (S/)',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(
                                        val.replaceAll(',', '.'),
                                      );
                                      if (parsed != null) {
                                        setState(() => line.unitCost = parsed);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    'S/ ${line.totalCost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeLine(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notas adicionales de compra',
                          hintText: 'Condiciones de despacho, garantía, etc.',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL DE COMPRA',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'S/ ${(_grandTotalCents / 100.0).toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmar Compra'),
                        ),
                      ],
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
