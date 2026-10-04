import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/mantenimiento.dart';
import '../../core/models/socio.dart';
import '../../core/theme/app_theme.dart';
import 'mantenimiento_form_dialog.dart';

class MantenimientosScreen extends StatefulWidget {
  final LocalStorageService storage;

  const MantenimientosScreen({super.key, required this.storage});

  @override
  State<MantenimientosScreen> createState() => _MantenimientosScreenState();
}

class _MantenimientosScreenState extends State<MantenimientosScreen> {
  String _filtro = 'todos'; // todos, semana, urgentes, vencidos

  @override
  Widget build(BuildContext context) {
    final todos = widget.storage.mantenimientos;
    final filtrados = todos.where((m) {
      if (_filtro == 'semana') return m.diasRestantes <= 7 && !m.estaVencido;
      if (_filtro == 'urgentes') return m.esUrgente && !m.estaVencido;
      if (_filtro == 'vencidos') return m.estaVencido;
      return true;
    }).toList()
      ..sort((a, b) => a.fechaProximo.compareTo(b.fechaProximo));

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.calendar_clock, color: AppTheme.amberSafety, size: 24),
            SizedBox(width: 10),
            Text('Mantenimientos Programados'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.amberSafety,
        foregroundColor: const Color(0xFF0F172A),
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Programar Mantenimiento', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => MantenimientoFormDialog(
              clientes: widget.storage.clientes,
              socios: widget.storage.socios,
              onGuardar: (m) => widget.storage.agregarMantenimiento(m),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // Banner de Alertas Activas
          _buildAlertsBanner(todos),

          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('todos', 'Todos (${todos.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('semana', 'Próxima Semana (7d)'),
                const SizedBox(width: 8),
                _buildFilterChip('urgentes', 'Urgentes (≤3d)'),
                const SizedBox(width: 8),
                _buildFilterChip('vencidos', 'Vencidos'),
              ],
            ),
          ),

          Expanded(
            child: filtrados.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtrados.length,
                    itemBuilder: (ctx, idx) {
                      final item = filtrados[idx];
                      return _buildMantenimientoCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsBanner(List<Mantenimiento> items) {
    final urgentes = items.where((m) => m.diasRestantes <= 7).length;
    if (urgentes == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.amberSafety.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.amberSafety.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.bell_ring, color: AppTheme.amberSafety, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$urgentes mantenimiento(s) con alertas activas esta semana.',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final sel = _filtro == key;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      selectedColor: AppTheme.amberSafety,
      labelStyle: TextStyle(
        color: sel ? const Color(0xFF0F172A) : Colors.white70,
        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _filtro = key),
    );
  }

  Widget _buildMantenimientoCard(Mantenimiento m) {
    Color badgeColor;
    Color badgeTextColor;
    String badgeText;

    if (m.estaVencido) {
      badgeColor = AppTheme.coralUrgent.withValues(alpha: 0.2);
      badgeTextColor = AppTheme.coralUrgent;
      badgeText = 'Vencido (${-m.diasRestantes}d)';
    } else if (m.esHoy) {
      badgeColor = AppTheme.amberSafety;
      badgeTextColor = const Color(0xFF0F172A);
      badgeText = '¡HOY!';
    } else if (m.esUrgente) {
      badgeColor = AppTheme.amberSafety.withValues(alpha: 0.2);
      badgeTextColor = AppTheme.amberSafety;
      badgeText = 'Faltan ${m.diasRestantes} días';
    } else if (m.proximaSemana) {
      badgeColor = AppTheme.skyAccent.withValues(alpha: 0.2);
      badgeTextColor = AppTheme.skyAccent;
      badgeText = 'Faltan ${m.diasRestantes} días';
    } else {
      badgeColor = const Color(0xFF334155);
      badgeTextColor = Colors.white70;
      badgeText = 'En ${m.diasRestantes} días';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.clienteNombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.titulo,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.calendar, size: 14, color: Colors.grey),
                    const SizedBox(width: 5),
                    Text(
                      DateFormat('dd/MM/yyyy').format(m.fechaProximo),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.repeat, size: 14, color: AppTheme.amberSafety),
                    const SizedBox(width: 5),
                    Text(
                      m.tipoFrecuencia.etiqueta,
                      style: const TextStyle(color: AppTheme.amberSafety, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Socios: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ...m.responsablesIds.map((sid) {
                      final s = widget.storage.socios.firstWhere(
                        (socio) => socio.id == sid,
                        orElse: () => Socio(id: sid, nombre: 'S'),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Tooltip(
                          message: s.nombre,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(s.colorValue),
                            child: Text(
                              s.nombre.isNotEmpty ? s.nombre.substring(0, 1).toUpperCase() : 'S',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
            if (m.descripcion != null && m.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                m.descripcion!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldSuccess.withValues(alpha: 0.15),
                      foregroundColor: AppTheme.emeraldSuccess,
                      side: const BorderSide(color: AppTheme.emeraldSuccess, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    ),
                    icon: const Icon(LucideIcons.check_check, size: 16),
                    label: const Text(
                      'Completar',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      _mostrarConfirmarCompletar(m);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.pencil, size: 18, color: Colors.grey),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => MantenimientoFormDialog(
                        mantenimientoExistente: m,
                        clientes: widget.storage.clientes,
                        socios: widget.storage.socios,
                        onGuardar: (actualizado) => widget.storage.editarMantenimiento(actualizado),
                      ),
                    );
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.trash, size: 18, color: AppTheme.coralUrgent),
                  onPressed: () => _confirmarEliminar(m.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarConfirmarCompletar(Mantenimiento m) {
    final proxima = m.calcularProximoCiclo(DateTime.now());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.slateSurface,
        title: const Row(
          children: [
            Icon(LucideIcons.circle_check, color: AppTheme.emeraldSuccess),
            SizedBox(width: 10),
            Text('¿Mantenimiento Realizado?'),
          ],
        ),
        content: Text(
          'Se marcará como realizado hoy y se programará el siguiente ciclo automáticamente para el ${DateFormat('dd/MM/yyyy').format(proxima)} (${m.tipoFrecuencia.etiqueta}).',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldSuccess, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              widget.storage.completarMantenimiento(m.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('¡Mantenimiento completado! Siguiente fecha: ${DateFormat('dd/MM/yyyy').format(proxima)}'),
                  backgroundColor: AppTheme.emeraldSuccess,
                ),
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.slateSurface,
        title: const Text('Eliminar Mantenimiento'),
        content: const Text('¿Estás seguro de eliminar este mantenimiento programado? Las alertas asociadas se cancelarán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralUrgent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              widget.storage.eliminarMantenimiento(id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.slateCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.calendar_check, size: 48, color: AppTheme.amberSafety),
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay mantenimientos en este filtro',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Programa un mantenimiento con tus frecuencias de 1 mes, 1.5 meses, 2 meses o custom.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
