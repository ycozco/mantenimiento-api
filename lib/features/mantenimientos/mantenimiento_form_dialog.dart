import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/mantenimiento.dart';
import '../../core/models/cliente.dart';
import '../../core/models/socio.dart';
import '../../core/theme/app_theme.dart';

class MantenimientoFormDialog extends StatefulWidget {
  final Mantenimiento? mantenimientoExistente;
  final List<Cliente> clientes;
  final List<Socio> socios;
  final Function(Mantenimiento) onGuardar;

  const MantenimientoFormDialog({
    super.key,
    this.mantenimientoExistente,
    required this.clientes,
    required this.socios,
    required this.onGuardar,
  });

  @override
  State<MantenimientoFormDialog> createState() =>
      _MantenimientoFormDialogState();
}

class _MantenimientoFormDialogState extends State<MantenimientoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _diasCustomCtrl;
  late TextEditingController _amountCtrl;

  String? _clienteIdSeleccionado;
  String _clienteNombre = '';
  TipoFrecuencia _tipoFrecuencia = TipoFrecuencia.unMes;
  DateTime _fechaProximo = DateTime.now().add(const Duration(days: 30));
  final Set<String> _sociosSeleccionados = {};
  String _billingType = 'perVisit';

  @override
  void initState() {
    super.initState();
    final m = widget.mantenimientoExistente;
    _tituloCtrl = TextEditingController(text: m?.titulo ?? '');
    _descCtrl = TextEditingController(text: m?.descripcion ?? '');
    _diasCustomCtrl = TextEditingController(
      text: (m?.diasPersonalizados ?? 15).toString(),
    );
    _amountCtrl = TextEditingController(
      text: m != null && m.agreedAmountCents > 0
          ? (m.agreedAmountCents / 100.0).toStringAsFixed(2)
          : '',
    );
    if (m != null) {
      _billingType = m.billingType;
      _clienteIdSeleccionado = m.clienteId;
      _clienteNombre = m.clienteNombre;
      _tipoFrecuencia = m.tipoFrecuencia;
      _fechaProximo = m.fechaProximo;
      _sociosSeleccionados.addAll(m.responsablesIds);
    } else {
      if (widget.clientes.isNotEmpty) {
        _clienteIdSeleccionado = widget.clientes.first.id;
        _clienteNombre = widget.clientes.first.nombre;
      }
      _sociosSeleccionados.addAll(widget.socios.map((s) => s.id));
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _diasCustomCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _ajustarFechaPorFrecuencia(TipoFrecuencia freq) {
    setState(() {
      _tipoFrecuencia = freq;
      final now = DateTime.now();
      switch (freq) {
        case TipoFrecuencia.unMes:
          _fechaProximo = now.add(const Duration(days: 30));
          break;
        case TipoFrecuencia.unMesYMedio:
          _fechaProximo = now.add(const Duration(days: 45));
          break;
        case TipoFrecuencia.dosMeses:
          _fechaProximo = now.add(const Duration(days: 60));
          break;
        case TipoFrecuencia.personalizado:
          final dias = int.tryParse(_diasCustomCtrl.text) ?? 15;
          _fechaProximo = now.add(Duration(days: dias));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.slateSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.amberSafety.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.calendar_clock,
                        color: AppTheme.amberSafety,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.mantenimientoExistente == null
                            ? 'Nuevo Mantenimiento'
                            : 'Editar Mantenimiento',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selector de Cliente
                        const Text(
                          'Cliente',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (widget.clientes.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.slateCard,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'No hay clientes registrados aún. Se creará uno por defecto.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.amber,
                              ),
                            ),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: _clienteIdSeleccionado,
                            dropdownColor: AppTheme.slateSurface,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                LucideIcons.user,
                                size: 18,
                                color: Colors.grey,
                              ),
                            ),
                            items: widget.clientes.map((c) {
                              return DropdownMenuItem(
                                value: c.id,
                                child: Text(c.nombre),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _clienteIdSeleccionado = val;
                                  _clienteNombre = widget.clientes
                                      .firstWhere((c) => c.id == val)
                                      .nombre;
                                });
                              }
                            },
                          ),
                        const SizedBox(height: 16),

                        // Título del Mantenimiento
                        const Text(
                          'Título / Servicio',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _tituloCtrl,
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Ingresa un título'
                              : null,
                          decoration: const InputDecoration(
                            hintText:
                                'Ej. Revisión Bombas, Cambio Filtros, Tableros',
                            prefixIcon: Icon(
                              LucideIcons.wrench,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Selector de Frecuencia
                        const Text(
                          'Frecuencia del Mantenimiento',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFrecuenciaChip(
                              TipoFrecuencia.unMes,
                              '1 Mes (30d)',
                            ),
                            _buildFrecuenciaChip(
                              TipoFrecuencia.unMesYMedio,
                              '1.5 Meses (45d)',
                            ),
                            _buildFrecuenciaChip(
                              TipoFrecuencia.dosMeses,
                              '2 Meses (60d)',
                            ),
                            _buildFrecuenciaChip(
                              TipoFrecuencia.personalizado,
                              'Personalizado',
                            ),
                          ],
                        ),

                        if (_tipoFrecuencia ==
                            TipoFrecuencia.personalizado) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text(
                                'Cada cuántos días: ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  controller: _diasCustomCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    final d = int.tryParse(val);
                                    if (d != null && d > 0) {
                                      setState(() {
                                        _fechaProximo = DateTime.now().add(
                                          Duration(days: d),
                                        );
                                      });
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'días',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Fecha Próxima
                        const Text(
                          'Fecha del Próximo Mantenimiento',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaProximo,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                              builder: (ctx, child) => Theme(
                                data: AppTheme.darkTheme,
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setState(() => _fechaProximo = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF334155),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.calendar,
                                  size: 18,
                                  color: AppTheme.amberSafety,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat(
                                    'EEEE dd MMMM, yyyy',
                                    'es',
                                  ).format(_fechaProximo),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  LucideIcons.chevron_down,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Socios Asignados
                        const Text(
                          'Socios Responsables (2 o más)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.socios.map((s) {
                            final sel = _sociosSeleccionados.contains(s.id);
                            return FilterChip(
                              label: Text(s.nombre),
                              selected: sel,
                              selectedColor: Color(
                                s.colorValue,
                              ).withValues(alpha: 0.3),
                              checkmarkColor: Color(s.colorValue),
                              avatar: CircleAvatar(
                                radius: 8,
                                backgroundColor: Color(s.colorValue),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _sociosSeleccionados.add(s.id);
                                  } else {
                                    if (_sociosSeleccionados.length > 1) {
                                      _sociosSeleccionados.remove(s.id);
                                    }
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // Modelo Económico y Tarifa
                        const Text(
                          'Facturación y Tarifa Acordada',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: _billingType,
                                decoration: const InputDecoration(
                                  labelText: 'Modalidad de Cobro',
                                  prefixIcon: Icon(
                                    LucideIcons.banknote,
                                    size: 18,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'perVisit',
                                    child: Text('Cobro por Visita'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child: Text('Tarifa Mensual'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'custom',
                                    child: Text('Personalizada / Eventual'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _billingType = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _amountCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Tarifa (S/)',
                                  hintText: '350.00',
                                  prefixText: 'S/ ',
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Notas adicionales
                        const Text(
                          'Notas / Descripción',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText:
                                'Detalles técnicos, herramientas a llevar, etc.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          final tariffDouble =
                              double.tryParse(
                                _amountCtrl.text.replaceAll(',', '.'),
                              ) ??
                              0.0;
                          final nuevo = Mantenimiento(
                            id:
                                widget.mantenimientoExistente?.id ??
                                const Uuid().v4(),
                            clienteId: _clienteIdSeleccionado ?? 'c_default',
                            clienteNombre: _clienteNombre.isNotEmpty
                                ? _clienteNombre
                                : 'Cliente General',
                            titulo: _tituloCtrl.text.trim(),
                            descripcion: _descCtrl.text.trim(),
                            tipoFrecuencia: _tipoFrecuencia,
                            diasPersonalizados:
                                int.tryParse(_diasCustomCtrl.text) ?? 30,
                            fechaProximo: _fechaProximo,
                            responsablesIds: _sociosSeleccionados.toList(),
                            billingType: _billingType,
                            agreedAmountCents: (tariffDouble * 100).round(),
                          );
                          widget.onGuardar(nuevo);
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: const Text('Guardar'),
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

  Widget _buildFrecuenciaChip(TipoFrecuencia freq, String label) {
    final isSelected = _tipoFrecuencia == freq;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.amberSafety,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => _ajustarFechaPorFrecuencia(freq),
    );
  }
}
