import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/models/tool.dart';
import '../../core/theme/app_theme.dart';

class ToolFormDialog extends StatefulWidget {
  final Tool? toolExistente;
  final ValueChanged<Tool> onGuardar;

  const ToolFormDialog({
    super.key,
    this.toolExistente,
    required this.onGuardar,
  });

  @override
  State<ToolFormDialog> createState() => _ToolFormDialogState();
}

class _ToolFormDialogState extends State<ToolFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _serialCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _notesCtrl;
  late String _category;
  late String _condition;

  final List<Map<String, String>> _categories = [
    {'value': 'motorized', 'label': 'Motorizada (Desbrozadora, motosierra)'},
    {'value': 'electric', 'label': 'Eléctrica / Batería (Cortasetos, taladro)'},
    {'value': 'manual', 'label': 'Manual (Pala, tijera de podar, rastrillo)'},
    {'value': 'safety', 'label': 'EPP y Seguridad'},
    {'value': 'measurement', 'label': 'Medición y Niveles'},
  ];

  final List<Map<String, String>> _conditions = [
    {'value': 'good', 'label': 'Buen estado (Operativa)'},
    {'value': 'fair', 'label': 'Regular / Desgaste normal'},
    {'value': 'damaged', 'label': 'Dañada / Requiere servicio'},
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.toolExistente;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _codeCtrl = TextEditingController(text: t?.code ?? '');
    _brandCtrl = TextEditingController(text: t?.brandModel ?? '');
    _serialCtrl = TextEditingController(text: t?.serialNumber ?? '');
    _priceCtrl = TextEditingController(
      text: t != null && t.purchasePriceCents > 0
          ? (t.purchasePriceCents / 100.0).toStringAsFixed(2)
          : '',
    );
    _notesCtrl = TextEditingController(text: t?.notes ?? '');
    _category = t?.category ?? 'motorized';
    _condition = t?.condition ?? 'good';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _brandCtrl.dispose();
    _serialCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;

    final priceDouble =
        double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final priceCents = (priceDouble * 100).round();

    final tool = widget.toolExistente != null
        ? widget.toolExistente!.copyWith(
            name: _nameCtrl.text.trim(),
            code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
            category: _category,
            brandModel: _brandCtrl.text.trim().isEmpty
                ? null
                : _brandCtrl.text.trim(),
            serialNumber: _serialCtrl.text.trim().isEmpty
                ? null
                : _serialCtrl.text.trim(),
            purchasePriceCents: priceCents,
            condition: _condition,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          )
        : Tool.create(
            name: _nameCtrl.text.trim(),
            code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
            category: _category,
            brandModel: _brandCtrl.text.trim().isEmpty
                ? null
                : _brandCtrl.text.trim(),
            serialNumber: _serialCtrl.text.trim().isEmpty
                ? null
                : _serialCtrl.text.trim(),
            purchasePriceCents: priceCents,
            condition: _condition,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );

    widget.onGuardar(tool);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.toolExistente != null;

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
                        LucideIcons.wrench,
                        color: AppTheme.skyAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        esEdicion
                            ? 'Editar Herramienta'
                            : 'Nueva Herramienta / Activo',
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
                    labelText: 'Nombre / Descripción *',
                    hintText: 'Ej. Desbrozadora Stihl FS 55',
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
                      child: TextFormField(
                        controller: _codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Código / Placa',
                          hintText: 'Ej. DESB-001',
                          prefixIcon: Icon(LucideIcons.barcode, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _brandCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Marca / Modelo',
                          hintText: 'Ej. Husqvarna 128LD',
                          prefixIcon: Icon(LucideIcons.file_cog, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _serialCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nº Serie (Opcional)',
                          prefixIcon: Icon(LucideIcons.hash, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _condition,
                        decoration: const InputDecoration(
                          labelText: 'Estado Físico *',
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
                          if (v != null) setState(() => _condition = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Precio Compra (S/)',
                          hintText: '0.00',
                          prefixIcon: Icon(
                            LucideIcons.circle_dollar_sign,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas / Observaciones (Opcional)',
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
                        backgroundColor: AppTheme.skyAccent,
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
