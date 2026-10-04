import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/gasto.dart';
import '../../core/models/socio.dart';
import '../../core/models/obra.dart';
import '../../core/models/mantenimiento.dart';
import '../../core/theme/app_theme.dart';

class GastoFormDialog extends StatefulWidget {
  final Gasto? gastoExistente;
  final List<Socio> socios;
  final List<Obra> obras;
  final List<Mantenimiento> mantenimientos;
  final String? obraPreseleccionadaId;
  final Function(Gasto) onGuardar;

  const GastoFormDialog({
    super.key,
    this.gastoExistente,
    required this.socios,
    required this.obras,
    required this.mantenimientos,
    this.obraPreseleccionadaId,
    required this.onGuardar,
  });

  @override
  State<GastoFormDialog> createState() => _GastoFormDialogState();
}

class _GastoFormDialogState extends State<GastoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _conceptoCtrl;
  late TextEditingController _montoCtrl;
  late TextEditingController _notaCtrl;

  CategoriaGasto _categoria = CategoriaGasto.gasolina;
  DateTime _fecha = DateTime.now();
  String? _pagadoPorSocioId;
  String? _obraId;
  TipoReparto _tipoReparto = TipoReparto.equitativo;

  // Participaciones
  final Map<String, double> _participaciones = {};
  final Map<String, TextEditingController> _customControllers = {};

  @override
  void initState() {
    super.initState();
    final g = widget.gastoExistente;
    _conceptoCtrl = TextEditingController(text: g?.concepto ?? '');
    _montoCtrl = TextEditingController(
      text: g != null ? g.montoTotal.toStringAsFixed(2) : '',
    );
    _notaCtrl = TextEditingController(text: g?.nota ?? '');

    if (g != null) {
      _categoria = g.categoria;
      _fecha = g.fecha;
      _pagadoPorSocioId = g.pagadoPorSocioId;
      _obraId = g.obraId;
      _tipoReparto = g.tipoReparto;
      _participaciones.addAll(g.participaciones);
    } else {
      _obraId = widget.obraPreseleccionadaId;
      if (widget.socios.isNotEmpty) {
        _pagadoPorSocioId = widget.socios.first.id;
        for (final s in widget.socios) {
          _participaciones[s.id] = 1.0; // Equitativo default
        }
      }
    }

    for (final s in widget.socios) {
      final valor = _participaciones[s.id] ?? 0.0;
      _customControllers[s.id] = TextEditingController(
        text: valor > 0 ? valor.toStringAsFixed(0) : '',
      );
    }
  }

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _montoCtrl.dispose();
    _notaCtrl.dispose();
    for (final ctrl in _customControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  IconData _getIconoCategoria(CategoriaGasto cat) {
    switch (cat) {
      case CategoriaGasto.gasolina:
        return LucideIcons.fuel;
      case CategoriaGasto.mantenimientoVehiculoHerramienta:
        return LucideIcons.wrench;
      case CategoriaGasto.comida:
        return LucideIcons.utensils;
      case CategoriaGasto.materialesObra:
        return LucideIcons.package;
      case CategoriaGasto.herramientas:
        return LucideIcons.hammer;
      case CategoriaGasto.viaticos:
        return LucideIcons.car;
      case CategoriaGasto.otro:
        return LucideIcons.receipt;
    }
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
                        color: AppTheme.emeraldSuccess.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.receipt,
                        color: AppTheme.emeraldSuccess,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.gastoExistente == null
                            ? 'Registrar Gasto / Inversión'
                            : 'Editar Gasto',
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
                        // Concepto
                        const Text(
                          'Concepto del Gasto',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _conceptoCtrl,
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Ingresa el concepto'
                              : null,
                          decoration: const InputDecoration(
                            hintText:
                                'Ej. Gasolina camioneta, Cemento obra B, Almuerzo',
                            prefixIcon: Icon(
                              LucideIcons.file_text,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Monto y Categoría
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Monto Total (\$)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _montoCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (val) {
                                      final d = double.tryParse(val ?? '');
                                      if (d == null || d <= 0) {
                                        return 'Monto válido';
                                      }
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(
                                        LucideIcons.dollar_sign,
                                        size: 18,
                                        color: AppTheme.emeraldSuccess,
                                      ),
                                      hintText: '0.00',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Categoría',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<CategoriaGasto>(
                                    initialValue: _categoria,
                                    isExpanded: true,
                                    dropdownColor: AppTheme.slateSurface,
                                    decoration: const InputDecoration(),
                                    items: CategoriaGasto.values.map((cat) {
                                      return DropdownMenuItem(
                                        value: cat,
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getIconoCategoria(cat),
                                              size: 16,
                                              color: AppTheme.amberSafety,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                cat.etiqueta,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _categoria = val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Pagado Por
                        const Text(
                          '¿Quién Pagó el Gasto?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _pagadoPorSocioId,
                          dropdownColor: AppTheme.slateSurface,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              LucideIcons.wallet,
                              size: 18,
                              color: AppTheme.emeraldSuccess,
                            ),
                          ),
                          items: widget.socios.map((s) {
                            return DropdownMenuItem(
                              value: s.id,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 6,
                                    backgroundColor: Color(s.colorValue),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(s.nombre),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _pagadoPorSocioId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Vinculado a Obra (opcional)
                        const Text(
                          'Vincular a Obra (Opcional)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _obraId,
                          dropdownColor: AppTheme.slateSurface,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              LucideIcons.hard_hat,
                              size: 18,
                              color: AppTheme.skyAccent,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Gasto General / Sin obra'),
                            ),
                            ...widget.obras.map(
                              (o) => DropdownMenuItem(
                                value: o.id,
                                child: Text(o.nombre),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _obraId = val),
                        ),
                        const SizedBox(height: 16),

                        // Tipo de Reparto
                        const Text(
                          '¿Cómo se Comparte este Gasto?',
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
                            ChoiceChip(
                              label: const Text('Equitativo (Partes Iguales)'),
                              selected: _tipoReparto == TipoReparto.equitativo,
                              selectedColor: AppTheme.amberSafety,
                              labelStyle: TextStyle(
                                color: _tipoReparto == TipoReparto.equitativo
                                    ? const Color(0xFF0F172A)
                                    : Colors.white70,
                                fontWeight:
                                    _tipoReparto == TipoReparto.equitativo
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(
                                () => _tipoReparto = TipoReparto.equitativo,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Por Partes / Porcentaje'),
                              selected: _tipoReparto == TipoReparto.porPartes,
                              selectedColor: AppTheme.amberSafety,
                              labelStyle: TextStyle(
                                color: _tipoReparto == TipoReparto.porPartes
                                    ? const Color(0xFF0F172A)
                                    : Colors.white70,
                                fontWeight:
                                    _tipoReparto == TipoReparto.porPartes
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(
                                () => _tipoReparto = TipoReparto.porPartes,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Detalle de participación de cada socio
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tipoReparto == TipoReparto.equitativo
                                    ? 'Socios que comparten el gasto en partes iguales:'
                                    : 'Porcentaje (%) asignado a cada socio:',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...widget.socios.map((s) {
                                final participa = _participaciones.containsKey(
                                  s.id,
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 6,
                                        backgroundColor: Color(s.colorValue),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          s.nombre,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (_tipoReparto ==
                                          TipoReparto.equitativo)
                                        Checkbox(
                                          value: participa,
                                          activeColor: AppTheme.amberSafety,
                                          checkColor: const Color(0xFF0F172A),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _participaciones[s.id] = 1.0;
                                              } else {
                                                if (_participaciones.length >
                                                    1) {
                                                  _participaciones.remove(s.id);
                                                }
                                              }
                                            });
                                          },
                                        )
                                      else
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            controller:
                                                _customControllers[s.id],
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              suffixText: '%',
                                            ),
                                            onChanged: (val) {
                                              final d =
                                                  double.tryParse(val) ?? 0.0;
                                              _participaciones[s.id] = d;
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Nota opcional
                        const Text(
                          'Notas / Factura / Detalle',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _notaCtrl,
                          decoration: const InputDecoration(
                            hintText:
                                'Número de ticket, litros de gasolina, etc.',
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldSuccess,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          final monto = double.tryParse(_montoCtrl.text) ?? 0.0;
                          String? nombreObra;
                          if (_obraId != null) {
                            final o = widget.obras
                                .where((item) => item.id == _obraId)
                                .firstOrNull;
                            nombreObra = o?.nombre;
                          }

                          final nuevoGasto = Gasto(
                            id: widget.gastoExistente?.id ?? const Uuid().v4(),
                            concepto: _conceptoCtrl.text.trim(),
                            categoria: _categoria,
                            montoTotal: monto,
                            fecha: _fecha,
                            pagadoPorSocioId:
                                _pagadoPorSocioId ?? widget.socios.first.id,
                            obraId: _obraId,
                            obraNombre: nombreObra,
                            tipoReparto: _tipoReparto,
                            participaciones: Map.from(_participaciones),
                            nota: _notaCtrl.text.trim(),
                          );
                          widget.onGuardar(nuevoGasto);
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: const Text('Guardar Gasto'),
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
