import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/models/inventory_item.dart';
import '../../core/theme/app_theme.dart';

class InventoryItemFormDialog extends StatefulWidget {
  final InventoryItem? itemExistente;
  final ValueChanged<InventoryItem> onGuardar;

  const InventoryItemFormDialog({
    super.key,
    this.itemExistente,
    required this.onGuardar,
  });

  @override
  State<InventoryItemFormDialog> createState() =>
      _InventoryItemFormDialogState();
}

class _InventoryItemFormDialogState extends State<InventoryItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _skuCtrl;
  late TextEditingController _minStockCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _notesCtrl;
  late String _category;
  late String _unit;

  final List<Map<String, String>> _categories = [
    {'value': 'plants', 'label': 'Plantas y Flores'},
    {'value': 'materials', 'label': 'Materiales (Tierra, arena, piedra)'},
    {'value': 'supplies', 'label': 'Insumos / Fertilizantes / Químicos'},
    {'value': 'pipes', 'label': 'Tuberías y Riego'},
    {'value': 'other', 'label': 'Otro'},
  ];

  final List<Map<String, String>> _units = [
    {'value': 'unit', 'label': 'Unidad (und)'},
    {'value': 'm3', 'label': 'Metro cúbico (m³)'},
    {'value': 'kg', 'label': 'Kilogramo (kg)'},
    {'value': 'm', 'label': 'Metro lineal (m)'},
    {'value': 'bag', 'label': 'Bolsa'},
    {'value': 'sack', 'label': 'Saco'},
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.itemExistente;
    _nameCtrl = TextEditingController(text: item?.name ?? '');
    _skuCtrl = TextEditingController(text: item?.sku ?? '');
    _minStockCtrl = TextEditingController(
      text: item != null
          ? (item.minStockAlert % 1 == 0
                ? item.minStockAlert.toInt().toString()
                : item.minStockAlert.toString())
          : '0',
    );
    _costCtrl = TextEditingController(
      text: item != null && item.defaultCostCents > 0
          ? (item.defaultCostCents / 100.0).toStringAsFixed(2)
          : '',
    );
    _notesCtrl = TextEditingController(text: item?.notes ?? '');
    _category = item?.category ?? 'plants';
    _unit = item?.unit ?? 'unit';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _minStockCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final minStock =
        double.tryParse(_minStockCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final costDouble =
        double.tryParse(_costCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final costCents = (costDouble * 100).round();

    final item = widget.itemExistente != null
        ? widget.itemExistente!.copyWith(
            name: _nameCtrl.text.trim(),
            sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
            category: _category,
            unit: _unit,
            minStockAlert: minStock,
            defaultCostCents: costCents,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          )
        : InventoryItem.create(
            name: _nameCtrl.text.trim(),
            sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
            category: _category,
            unit: _unit,
            minStockAlert: minStock,
            defaultCostCents: costCents,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );

    widget.onGuardar(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.itemExistente != null;

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
                        LucideIcons.package,
                        color: AppTheme.emeraldSuccess,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        esEdicion
                            ? 'Editar Insumo/Material'
                            : 'Nuevo Insumo/Material',
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
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Insumo / Material *',
                    hintText: 'Ej. Mioporo, Tierra preparada, Manguera 1/2"',
                    prefixIcon: Icon(LucideIcons.tag, size: 18),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingrese el nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoría *',
                          prefixIcon: Icon(LucideIcons.layers, size: 18),
                        ),
                        dropdownColor: const Color(0xFF0F172A),
                        items: _categories.map((c) {
                          return DropdownMenuItem(
                            value: c['value'],
                            child: Text(
                              c['label']!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _category = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _unit,
                        decoration: const InputDecoration(
                          labelText: 'Unidad *',
                          prefixIcon: Icon(LucideIcons.ruler, size: 18),
                        ),
                        dropdownColor: const Color(0xFF0F172A),
                        items: _units.map((u) {
                          return DropdownMenuItem(
                            value: u['value'],
                            child: Text(u['label']!),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _unit = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minStockCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Alerta Stock Mínimo',
                          hintText: 'Ej. 50',
                          prefixIcon: Icon(LucideIcons.info, size: 18),
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Costo Ref. (S/)',
                          hintText: '0.00',
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
                TextFormField(
                  controller: _skuCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código / SKU (Opcional)',
                    hintText: 'Ej. MIO-001',
                    prefixIcon: Icon(LucideIcons.barcode, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas adicionales (Opcional)',
                    prefixIcon: Icon(LucideIcons.file_text, size: 18),
                  ),
                ),
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
                      label: Text(esEdicion ? 'Actualizar' : 'Guardar'),
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
