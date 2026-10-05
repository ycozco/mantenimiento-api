import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/obra.dart';
import '../../core/models/stock_movement.dart';
import '../../core/theme/app_theme.dart';

class StockMovementFormDialog extends StatefulWidget {
  final LocalStorageService storage;
  final List<InventoryItem> items;
  final String? preselectedItemId;
  final String? preselectedMovementType;
  final String? preselectedProjectId;
  final String? preselectedVisitId;
  final List<Obra> obras;

  const StockMovementFormDialog({
    super.key,
    required this.storage,
    required this.items,
    this.preselectedItemId,
    this.preselectedMovementType,
    this.preselectedProjectId,
    this.preselectedVisitId,
    this.obras = const [],
  });

  @override
  State<StockMovementFormDialog> createState() =>
      _StockMovementFormDialogState();
}

class _StockMovementFormDialogState extends State<StockMovementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedItemId;
  late String _movementType;
  String? _selectedProjectId;
  String? _selectedVisitId;
  late DateTime _fecha;
  late TextEditingController _quantityCtrl;
  late TextEditingController _unitCostCtrl;
  late TextEditingController _notesCtrl;
  double _currentStock = 0.0;
  bool _loadingStock = false;
  String? _errorMessage;

  final List<Map<String, String>> _movementTypes = [
    {'value': 'purchase', 'label': 'Entrada por Compra (+)'},
    {'value': 'consumption', 'label': 'Salida por Consumo (-)'},
    {'value': 'adjustment', 'label': 'Ajuste de Inventario (+ / -)'},
    {'value': 'return', 'label': 'Devolución al Almacén (+)'},
    {'value': 'loss', 'label': 'Pérdida / Merma / Rotura (-)'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedItemId = widget.preselectedItemId;
    if (_selectedItemId == null && widget.items.isNotEmpty) {
      _selectedItemId = widget.items.first.id;
    }

    _movementType = widget.preselectedMovementType ?? 'consumption';
    _selectedProjectId = widget.preselectedProjectId;
    _selectedVisitId = widget.preselectedVisitId;
    _fecha = DateTime.now();

    _quantityCtrl = TextEditingController(text: '1');
    _notesCtrl = TextEditingController();

    final item = _getSelectedItem();
    final defaultCost = item != null ? (item.defaultCostCents / 100.0) : 0.0;
    _unitCostCtrl = TextEditingController(
      text: defaultCost > 0 ? defaultCost.toStringAsFixed(2) : '',
    );

    _quantityCtrl.addListener(() => setState(() {}));
    _unitCostCtrl.addListener(() => setState(() {}));

    _refreshStock();
  }

  InventoryItem? _getSelectedItem() {
    if (_selectedItemId == null) return null;
    try {
      return widget.items.firstWhere((i) => i.id == _selectedItemId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshStock() async {
    if (_selectedItemId == null) return;
    setState(() => _loadingStock = true);
    final stock = await widget.storage.inventoryRepository.getItemStock(
      _selectedItemId!,
    );
    if (mounted) {
      setState(() {
        _currentStock = stock;
        _loadingStock = false;
      });
    }
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _unitCostCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double _getCalculatedNewStock() {
    final qty = double.tryParse(_quantityCtrl.text.replaceAll(',', '.')) ?? 0.0;
    switch (_movementType) {
      case 'consumption':
      case 'loss':
        return _currentStock - qty.abs();
      case 'purchase':
      case 'return':
        return _currentStock + qty.abs();
      case 'adjustment':
      default:
        return _currentStock + qty;
    }
  }

  int _calculateTotalCents() {
    final qty =
        (double.tryParse(_quantityCtrl.text.replaceAll(',', '.')) ?? 0.0).abs();
    final costDouble =
        double.tryParse(_unitCostCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final costCents = (costDouble * 100).round();
    return (qty * costCents).round();
  }

  Future<void> _guardar() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItemId == null) return;

    final qty = double.tryParse(_quantityCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final costDouble =
        double.tryParse(_unitCostCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final costCents = (costDouble * 100).round();

    final newStock = _getCalculatedNewStock();
    if (newStock < -0.0001 &&
        (_movementType == 'consumption' || _movementType == 'loss')) {
      setState(() {
        _errorMessage =
            'Stock insuficiente. Stock actual: $_currentStock, intentando retirar: ${qty.abs()}';
      });
      return;
    }

    try {
      final movement = StockMovement.create(
        itemId: _selectedItemId!,
        movementType: _movementType,
        quantity: qty,
        unitCostCents: costCents,
        projectId: _selectedProjectId,
        visitId: _selectedVisitId,
        date: _fecha,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await widget.storage.inventoryRepository.recordMovement(movement);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _getSelectedItem();
    final newStock = _getCalculatedNewStock();
    final totalCents = _calculateTotalCents();
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
                        color: AppTheme.amberSafety.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.arrow_left_right,
                        color: AppTheme.amberSafety,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Movimiento de Stock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Item Selector (if not preselected)
                if (widget.preselectedItemId == null)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedItemId,
                    decoration: const InputDecoration(
                      labelText: 'Insumo / Material *',
                      prefixIcon: Icon(LucideIcons.package, size: 18),
                    ),
                    dropdownColor: const Color(0xFF0F172A),
                    items: widget.items.map((i) {
                      return DropdownMenuItem(
                        value: i.id,
                        child: Text(
                          '${i.name} (${i.unitLabel})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        setState(() {
                          _selectedItemId = id;
                          final it = _getSelectedItem();
                          if (it != null && it.defaultCostCents > 0) {
                            _unitCostCtrl.text = (it.defaultCostCents / 100.0)
                                .toStringAsFixed(2);
                          }
                        });
                        _refreshStock();
                      }
                    },
                    validator: (v) => v == null ? 'Seleccione un insumo' : null,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.package,
                          color: AppTheme.skyAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item?.name ?? 'Insumo',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Categoría: ${item?.categoryLabel ?? ""} | Unidad: ${item?.unitLabel ?? ""}',
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
                  ),

                const SizedBox(height: 12),

                // Movement Type
                DropdownButtonFormField<String>(
                  initialValue: _movementType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Movimiento *',
                    prefixIcon: Icon(LucideIcons.activity, size: 18),
                  ),
                  dropdownColor: const Color(0xFF0F172A),
                  items: _movementTypes.map((m) {
                    return DropdownMenuItem(
                      value: m['value'],
                      child: Text(m['label']!),
                    );
                  }).toList(),
                  onChanged: widget.preselectedMovementType != null
                      ? null
                      : (v) {
                          if (v != null) setState(() => _movementType = v);
                        },
                ),

                const SizedBox(height: 12),

                // Target Context (Obra or Visit)
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
                            'Consumo imputado a Visita de Mantenimiento',
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
                else if (_movementType == 'consumption' &&
                    widget.obras.isNotEmpty &&
                    widget.preselectedProjectId == null)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProjectId,
                    decoration: const InputDecoration(
                      labelText: 'Obra / Proyecto (Opcional)',
                      prefixIcon: Icon(LucideIcons.building, size: 18),
                    ),
                    dropdownColor: const Color(0xFF0F172A),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Ninguna (Consumo general de almacén)'),
                      ),
                      ...widget.obras.map((o) {
                        return DropdownMenuItem(
                          value: o.id,
                          child: Text(
                            o.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _selectedProjectId = v),
                  )
                else if (_selectedProjectId != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.skyAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.skyAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          LucideIcons.building,
                          color: AppTheme.skyAccent,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Consumo imputado a la Obra',
                            style: TextStyle(
                              color: AppTheme.skyAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Quantity and Unit Cost
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Cantidad (${item?.unitLabel ?? "und"}) *',
                          prefixIcon: const Icon(LucideIcons.hash, size: 18),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Requerido';
                          }
                          final parsed = double.tryParse(
                            v.replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed <= 0) {
                            return '> 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _unitCostCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Costo Unit. (S/)',
                          prefixIcon: Icon(
                            LucideIcons.circle_dollar_sign,
                            size: 18,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final parsed = double.tryParse(
                            v.replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed < 0) {
                            return 'Inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Date Picker
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
                      labelText: 'Fecha del Movimiento *',
                      prefixIcon: Icon(LucideIcons.calendar, size: 18),
                    ),
                    child: Text(
                      dateFormat.format(_fecha),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas / Guía / Motivo (Opcional)',
                    prefixIcon: Icon(LucideIcons.file_text, size: 18),
                  ),
                ),

                const SizedBox(height: 16),

                // Stock Preview Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: newStock < 0
                          ? AppTheme.coralUrgent
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Stock actual:',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          _loadingStock
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  '${_currentStock.toStringAsFixed(1)} ${item?.unitLabel ?? ""}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Stock resultante:',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          Text(
                            '${newStock.toStringAsFixed(1)} ${item?.unitLabel ?? ""}',
                            style: TextStyle(
                              color: newStock < 0
                                  ? AppTheme.coralUrgent
                                  : (newStock <= (item?.minStockAlert ?? 0)
                                        ? AppTheme.amberSafety
                                        : AppTheme.emeraldSuccess),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 12, color: Color(0xFF334155)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Valor del movimiento:',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          Text(
                            'S/ $totalFormatted',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
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

                const SizedBox(height: 20),

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
                        backgroundColor: AppTheme.amberSafety,
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _guardar,
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: const Text(
                        'Registrar Movimiento',
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
