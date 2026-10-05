import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/obra.dart';
import '../../core/models/cliente.dart';
import '../../core/models/socio.dart';
import '../../core/theme/app_theme.dart';

class ObraFormDialog extends StatefulWidget {
  final Obra? obraExistente;
  final List<Cliente> clientes;
  final List<Socio> socios;
  final Function(Obra) onGuardar;

  const ObraFormDialog({
    super.key,
    this.obraExistente,
    required this.clientes,
    required this.socios,
    required this.onGuardar,
  });

  @override
  State<ObraFormDialog> createState() => _ObraFormDialogState();
}

class _ObraFormDialogState extends State<ObraFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _ubicacionCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _presupuestoCtrl;

  String? _clienteId;
  String? _clienteNombre;
  EstadoObra _estado = EstadoObra.enProgreso;
  final Set<String> _sociosSeleccionados = {};

  @override
  void initState() {
    super.initState();
    final o = widget.obraExistente;
    _nombreCtrl = TextEditingController(text: o?.nombre ?? '');
    _ubicacionCtrl = TextEditingController(text: o?.ubicacion ?? '');
    _descCtrl = TextEditingController(text: o?.descripcion ?? '');
    _presupuestoCtrl = TextEditingController(
      text: o != null && o.presupuesto > 0
          ? o.presupuesto.toStringAsFixed(0)
          : '',
    );

    if (o != null) {
      _clienteId = o.clienteId;
      _clienteNombre = o.clienteNombre;
      _estado = o.estado;
      _sociosSeleccionados.addAll(o.sociosAsignados);
    } else {
      if (widget.clientes.isNotEmpty) {
        _clienteId = widget.clientes.first.id;
        _clienteNombre = widget.clientes.first.nombre;
      }
      _sociosSeleccionados.addAll(widget.socios.map((s) => s.id));
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _ubicacionCtrl.dispose();
    _descCtrl.dispose();
    _presupuestoCtrl.dispose();
    super.dispose();
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
                        color: AppTheme.skyAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.hard_hat,
                        color: AppTheme.skyAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.obraExistente == null
                            ? 'Nueva Obra / Proyecto'
                            : 'Editar Obra',
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
                        const Text(
                          'Nombre de la Obra / Proyecto',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nombreCtrl,
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Ingresa el nombre de la obra'
                              : null,
                          decoration: const InputDecoration(
                            hintText:
                                'Ej. Instalación Eléctrica Nave 4, Remodelación Local',
                            prefixIcon: Icon(
                              LucideIcons.building,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Cliente asociado
                        const Text(
                          'Cliente (Opcional)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _clienteId,
                          dropdownColor: AppTheme.slateSurface,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              LucideIcons.user,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Sin cliente específico'),
                            ),
                            ...widget.clientes.map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.nombre),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _clienteId = val;
                              _clienteNombre = val != null
                                  ? widget.clientes
                                        .firstWhere((c) => c.id == val)
                                        .nombre
                                  : null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Presupuesto y Estado
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Presupuesto Total (\$) ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _presupuestoCtrl,
                                    keyboardType: TextInputType.number,
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Estado',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<EstadoObra>(
                                    initialValue: _estado,
                                    dropdownColor: AppTheme.slateSurface,
                                    decoration: const InputDecoration(),
                                    items: EstadoObra.values.map((e) {
                                      return DropdownMenuItem(
                                        value: e,
                                        child: Text(e.etiqueta),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _estado = val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Ubicación
                        const Text(
                          'Ubicación / Dirección',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _ubicacionCtrl,
                          decoration: const InputDecoration(
                            hintText:
                                'Ej. Zona Industrial Nave 2, Calle 10 #23',
                            prefixIcon: Icon(
                              LucideIcons.map_pin,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Socios Participantes
                        const Text(
                          'Socios Inversionistas / Encargados',
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
                                    _sociosSeleccionados.remove(s.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Descripción
                        const Text(
                          'Detalles de la Obra',
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
                                'Alcance del proyecto, notas de compras, etc.',
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
                        backgroundColor: AppTheme.skyAccent,
                      ),
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          final nueva = Obra(
                            id: widget.obraExistente?.id ?? const Uuid().v4(),
                            nombre: _nombreCtrl.text.trim(),
                            clienteId: _clienteId,
                            clienteNombre: _clienteNombre,
                            ubicacion: _ubicacionCtrl.text.trim(),
                            descripcion: _descCtrl.text.trim(),
                            presupuesto:
                                double.tryParse(_presupuestoCtrl.text) ?? 0.0,
                            fechaInicio:
                                widget.obraExistente?.fechaInicio ??
                                DateTime.now(),
                            estado: _estado,
                            sociosAsignados: _sociosSeleccionados.toList(),
                          );
                          widget.onGuardar(nueva);
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
}
