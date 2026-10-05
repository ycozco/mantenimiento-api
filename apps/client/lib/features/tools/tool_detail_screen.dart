import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/tool.dart';
import '../../core/models/tool_assignment.dart';
import '../../core/theme/app_theme.dart';
import 'tool_assignment_dialog.dart';
import 'tool_form_dialog.dart';
import 'tool_return_dialog.dart';

class ToolDetailScreen extends StatefulWidget {
  final Tool tool;
  final LocalStorageService storage;

  const ToolDetailScreen({
    super.key,
    required this.tool,
    required this.storage,
  });

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<ToolDetailScreen> {
  late Tool _tool;

  @override
  void initState() {
    super.initState();
    _tool = widget.tool;
  }

  Future<void> _recargarTool() async {
    final t = await widget.storage.toolRepository.getTool(_tool.id);
    if (t != null && mounted) {
      setState(() => _tool = t);
    }
  }

  void _abrirAsignacion() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ToolAssignmentDialog(tool: _tool, storage: widget.storage),
    );
    if (res == true) _recargarTool();
  }

  void _abrirDevolucion(ToolAssignment assignment) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => ToolReturnDialog(
        assignment: assignment,
        tool: _tool,
        storage: widget.storage,
      ),
    );
    if (res == true) _recargarTool();
  }

  Color _getStatusColor() {
    switch (_tool.currentStatus) {
      case 'available':
        return AppTheme.emeraldSuccess;
      case 'assigned':
        return AppTheme.skyAccent;
      case 'maintenance':
        return AppTheme.amberSafety;
      case 'retired':
        return AppTheme.coralUrgent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final statusColor = _getStatusColor();

    return Scaffold(
      appBar: AppBar(
        title: Text(_tool.name),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 20),
            tooltip: 'Editar Herramienta',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ToolFormDialog(
                  toolExistente: _tool,
                  onGuardar: (actualizado) async {
                    await widget.storage.toolRepository.updateTool(actualizado);
                    _recargarTool();
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tarjeta Principal del Activo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E293B),
                    statusColor.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _tool.categoryLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _tool.statusLabel.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tool.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (_tool.brandModel != null)
                    Text(
                      _tool.brandModel!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Código / Placa',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            _tool.code ?? 'Sin código',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estado Físico',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            _tool.conditionLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (_tool.purchasePriceCents > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Valor Activo',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              currency.format(_tool.purchasePriceSoles),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (_tool.notes != null && _tool.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _tool.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Custodia Actual (Si está asignada)
            FutureBuilder<ToolAssignment?>(
              future: widget.storage.toolRepository.getActiveAssignment(
                _tool.id,
              ),
              builder: (context, assignmentSnap) {
                final assignment = assignmentSnap.data;

                if (assignment != null) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.skyAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              LucideIcons.user_check,
                              color: AppTheme.skyAccent,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'CUSTODIA ACTUAL ACTIVA',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.skyAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (assignment.workerId != null)
                          FutureBuilder(
                            future: widget.storage.workerRepository
                                .getWorkerById(assignment.workerId!),
                            builder: (ctx, wSnap) => Row(
                              children: [
                                const Text(
                                  'Responsable: ',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  wSnap.data?.name ?? 'Trabajador',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (assignment.projectId != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                'Obra / Destino: ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                widget.storage.obras
                                    .firstWhere(
                                      (o) => o.id == assignment.projectId,
                                      orElse: () => widget.storage.obras.first,
                                    )
                                    .nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.skyAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'Fecha Entrega: ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              dateFormat.format(assignment.assignedAt),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (assignment.expectedReturnAt != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                'Retorno Esperado: ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                dateFormat.format(assignment.expectedReturnAt!),
                                style: const TextStyle(
                                  color: AppTheme.amberSafety,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emeraldSuccess,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _abrirDevolucion(assignment),
                          icon: const Icon(LucideIcons.undo_2, size: 18),
                          label: const Text(
                            'Registrar Devolución al Almacén',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Botones de Acción cuando NO está asignada
                if (_tool.isAvailable) {
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.skyAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _abrirAsignacion,
                          icon: const Icon(
                            LucideIcons.arrow_up_right,
                            size: 18,
                          ),
                          label: const Text(
                            'Entregar / Asignar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Enviar a Mantenimiento',
                        onPressed: () async {
                          await widget.storage.toolRepository.sendToMaintenance(
                            _tool.id,
                          );
                          _recargarTool();
                        },
                        icon: const Icon(LucideIcons.wrench, size: 18),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        tooltip: 'Dar de Baja / Retirar',
                        onPressed: () async {
                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Dar de Baja Herramienta'),
                              content: const Text(
                                '¿Está seguro de retirar esta herramienta? Ya no podrá ser asignada.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.coralUrgent,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Confirmar Baja'),
                                ),
                              ],
                            ),
                          );
                          if (confirmar == true) {
                            await widget.storage.toolRepository.retireTool(
                              _tool.id,
                            );
                            _recargarTool();
                          }
                        },
                        icon: const Icon(LucideIcons.trash, size: 18),
                      ),
                    ],
                  );
                }

                if (_tool.isInMaintenance) {
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emeraldSuccess,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            await widget.storage.toolRepository.markAvailable(
                              _tool.id,
                            );
                            _recargarTool();
                          },
                          icon: const Icon(LucideIcons.check_check, size: 18),
                          label: const Text(
                            'Marcar Reparada y Disponible',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Dar de Baja Definitiva',
                        onPressed: () async {
                          await widget.storage.toolRepository.retireTool(
                            _tool.id,
                          );
                          _recargarTool();
                        },
                        icon: const Icon(LucideIcons.trash, size: 18),
                      ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),

            const SizedBox(height: 24),

            // Historial de Custodia (Ledger de Asignaciones)
            const Row(
              children: [
                Icon(LucideIcons.clock, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Text(
                  'HISTORIAL DE CUSTODIA Y DEVOLUCIONES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            StreamBuilder<List<ToolAssignment>>(
              stream: widget.storage.toolRepository.watchToolHistory(_tool.id),
              builder: (context, historySnap) {
                final history = historySnap.data ?? [];

                if (history.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Center(
                      child: Text(
                        'No hay registros históricos de asignación para esta herramienta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final h = history[idx];
                    final isPendingReturn = h.returnedAt == null;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPendingReturn
                              ? AppTheme.skyAccent.withValues(alpha: 0.4)
                              : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isPendingReturn
                                  ? AppTheme.skyAccent.withValues(alpha: 0.15)
                                  : AppTheme.emeraldSuccess.withValues(
                                      alpha: 0.15,
                                    ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isPendingReturn
                                  ? LucideIcons.arrow_up_right
                                  : LucideIcons.check,
                              color: isPendingReturn
                                  ? AppTheme.skyAccent
                                  : AppTheme.emeraldSuccess,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (h.workerId != null)
                                      FutureBuilder(
                                        future: widget.storage.workerRepository
                                            .getWorkerById(h.workerId!),
                                        builder: (ctx, wSnap) => Text(
                                          wSnap.data?.name ?? 'Trabajador',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      )
                                    else
                                      const Text(
                                        'Asignación directa a Obra/Visita',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    Text(
                                      isPendingReturn ? 'EN USO' : 'DEVUELTO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isPendingReturn
                                            ? AppTheme.skyAccent
                                            : AppTheme.emeraldSuccess,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Salida: ${dateFormat.format(h.assignedAt)}'
                                  '${h.returnedAt != null ? " • Retorno: ${dateFormat.format(h.returnedAt!)}" : ""}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (h.projectId != null ||
                                    h.maintenanceVisitId != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    h.projectId != null
                                        ? 'Destino: Obra'
                                        : 'Destino: Visita Mantenimiento',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                                if (h.notes != null && h.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    h.notes!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
