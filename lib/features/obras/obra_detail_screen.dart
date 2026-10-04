import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/obra.dart';
import '../../core/models/worker.dart';
import '../../core/models/work_log.dart';
import '../../core/models/stock_movement.dart';
import '../../core/models/tool_assignment.dart';
import '../../core/theme/app_theme.dart';
import '../inventory/stock_movement_form_dialog.dart';
import '../work_logs/work_log_form_dialog.dart';

class ObraDetailScreen extends StatelessWidget {
  final Obra obra;
  final LocalStorageService storage;

  const ObraDetailScreen({
    super.key,
    required this.obra,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Gastos directos de materiales
    final gastosObra = storage.gastos
        .where((g) => g.obraId == obra.id)
        .toList();
    final totalMateriales = gastosObra.fold<double>(
      0.0,
      (acc, g) => acc + g.montoTotal,
    );

    return Scaffold(
      appBar: AppBar(title: Text(obra.nombre)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.skyAccent,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.calendar_plus, size: 20),
        label: const Text(
          'Registrar Jornada',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final workers = await storage.workerRepository.getActiveWorkers();
          if (!context.mounted) return;
          if (workers.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No hay trabajadores activos. Agregue uno primero en Socios y Personal.',
                ),
              ),
            );
            return;
          }
          showDialog(
            context: context,
            builder: (_) => WorkLogFormDialog(
              workers: workers,
              obras: [obra],
              obraPreseleccionadaId: obra.id,
              onGuardar: (log) => storage.workLogRepository.createWorkLog(log),
            ),
          );
        },
      ),
      body: StreamBuilder<int>(
        stream: storage.workLogRepository.watchProjectLaborCostCents(obra.id),
        builder: (context, laborCostSnapshot) {
          final laborCostCents = laborCostSnapshot.data ?? 0;
          final laborCost = laborCostCents / 100.0;

          return StreamBuilder<int>(
            stream: storage.inventoryRepository.watchProjectMaterialCostCents(
              obra.id,
            ),
            builder: (context, materialCostSnapshot) {
              final materialCostCents = materialCostSnapshot.data ?? 0;
              final materialAlmacenCost = materialCostCents / 100.0;
              final inversionTotal =
                  totalMateriales + materialAlmacenCost + laborCost;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta de Presupuesto y Costos Derivados
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  obra.clienteNombre ?? 'Sin cliente',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.skyAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    obra.estado.etiqueta,
                                    style: const TextStyle(
                                      color: AppTheme.skyAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Desglose Financiero de Obra',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  _buildFinancialRow(
                                    'Presupuesto Pactado:',
                                    currency.format(obra.presupuesto),
                                    Colors.white,
                                  ),
                                  const Divider(height: 16),
                                  _buildFinancialRow(
                                    'Gastos Directos (Caja Chica):',
                                    currency.format(totalMateriales),
                                    AppTheme.amberSafety,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildFinancialRow(
                                    'Materiales Consumidos de Almacén:',
                                    currency.format(materialAlmacenCost),
                                    AppTheme.emeraldSuccess,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildFinancialRow(
                                    'Mano de Obra (Jornadas):',
                                    currency.format(laborCost),
                                    AppTheme.skyAccent,
                                  ),
                                  const Divider(height: 16),
                                  _buildFinancialRow(
                                    'Inversión Total Acumulada:',
                                    currency.format(inversionTotal),
                                    AppTheme.emeraldSuccess,
                                    isBold: true,
                                  ),
                                  if (obra.presupuesto > 0) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value:
                                            (inversionTotal / obra.presupuesto)
                                                .clamp(0.0, 1.0),
                                        backgroundColor: const Color(
                                          0xFF334155,
                                        ),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              inversionTotal > obra.presupuesto
                                                  ? AppTheme.coralUrgent
                                                  : AppTheme.emeraldSuccess,
                                            ),
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '${((inversionTotal / obra.presupuesto) * 100).toStringAsFixed(1)}% del presupuesto ejecutado',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón para Consumo de Material de Almacén
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        side: const BorderSide(color: AppTheme.emeraldSuccess),
                        foregroundColor: AppTheme.emeraldSuccess,
                      ),
                      icon: const Icon(LucideIcons.package_plus, size: 18),
                      label: const Text(
                        'Registrar Consumo de Material (Almacén)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final items = await storage.inventoryRepository
                            .watchActiveItems()
                            .first;
                        if (!context.mounted) return;
                        if (items.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No hay insumos en inventario. Agregue insumos en Ajustes > Inventario.',
                              ),
                            ),
                          );
                          return;
                        }
                        showDialog(
                          context: context,
                          builder: (_) => StockMovementFormDialog(
                            storage: storage,
                            items: items,
                            preselectedProjectId: obra.id,
                            preselectedMovementType: 'consumption',
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Sección Personal / Jornadas Laboradas
                    const Text(
                      'Personal / Jornadas Laboradas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    StreamBuilder<List<WorkLog>>(
                      stream: storage.workLogRepository.watchProjectWorkLogs(
                        obra.id,
                      ),
                      builder: (context, logsSnapshot) {
                        final logs = logsSnapshot.data ?? [];
                        if (logs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1E293B,
                              ).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  LucideIcons.hard_hat,
                                  size: 32,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No se han registrado jornadas en esta obra todavía.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        return FutureBuilder<List<Worker>>(
                          future: storage.workerRepository
                              .watchAllWorkers()
                              .first,
                          builder: (context, workersSnapshot) {
                            final workers = workersSnapshot.data ?? [];
                            final workersMap = {for (var w in workers) w.id: w};

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: logs.length,
                              itemBuilder: (ctx, idx) {
                                final log = logs[idx];
                                final worker = workersMap[log.workerId];
                                final workerName =
                                    worker?.name ?? 'Trabajador no encontrado';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.skyAccent
                                          .withValues(alpha: 0.15),
                                      child: const Icon(
                                        LucideIcons.user_check,
                                        color: AppTheme.skyAccent,
                                        size: 18,
                                      ),
                                    ),
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            workerName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'S/ ${log.amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.skyAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 2),
                                        Text(
                                          '${dateFormat.format(log.date)} • ${log.quantityFormatted} a S/ ${log.rate.toStringAsFixed(2)} (${log.paymentTypeLabel})',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (log.notes != null &&
                                            log.notes!.isNotEmpty)
                                          Text(
                                            log.notes!,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(
                                        LucideIcons.ellipsis_vertical,
                                        size: 16,
                                      ),
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          showDialog(
                                            context: context,
                                            builder: (_) => WorkLogFormDialog(
                                              workers: workers,
                                              obras: [obra],
                                              workLogExistente: log,
                                              onGuardar: (act) => storage
                                                  .workLogRepository
                                                  .updateWorkLog(act),
                                            ),
                                          );
                                        } else if (val == 'void') {
                                          storage.workLogRepository.voidWorkLog(
                                            log.id,
                                          );
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Editar'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'void',
                                          child: Text(
                                            'Anular jornada',
                                            style: TextStyle(
                                              color: AppTheme.coralUrgent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Sección Insumos y Materiales Consumidos de Almacén
                    const Text(
                      'Materiales e Insumos de Almacén',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    StreamBuilder<List<StockMovement>>(
                      stream: storage.inventoryRepository.watchProjectMovements(
                        obra.id,
                      ),
                      builder: (context, movesSnapshot) {
                        final moves = movesSnapshot.data ?? [];
                        if (moves.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1E293B,
                              ).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'No hay consumos de materiales de almacén en esta obra',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: moves.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final m = moves[idx];
                            return FutureBuilder(
                              future: storage.inventoryRepository.getItem(
                                m.itemId,
                              ),
                              builder: (ctx, itemSnap) {
                                final item = itemSnap.data;
                                return Card(
                                  margin: EdgeInsets.zero,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.emeraldSuccess
                                          .withValues(alpha: 0.15),
                                      child: const Icon(
                                        LucideIcons.package,
                                        color: AppTheme.emeraldSuccess,
                                        size: 18,
                                      ),
                                    ),
                                    title: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item?.name ?? 'Material',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'S/ ${(m.totalCostCents / 100.0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.emeraldSuccess,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '${m.quantity.abs().toStringAsFixed(1)} ${item?.unitLabel ?? "und"} • S/ ${(m.unitCostCents / 100.0).toStringAsFixed(2)} c/u • ${dateFormat.format(m.date)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(
                                        LucideIcons.ellipsis_vertical,
                                        size: 16,
                                      ),
                                      onSelected: (val) {
                                        if (val == 'delete') {
                                          storage.inventoryRepository
                                              .deleteMovement(m.id);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            'Anular consumo',
                                            style: TextStyle(
                                              color: AppTheme.coralUrgent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Sección Herramientas y Maquinaria en Obra
                    const Text(
                      'Herramientas y Maquinaria en Obra',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    StreamBuilder<List<ToolAssignment>>(
                      stream: storage.toolRepository
                          .watchProjectActiveAssignments(obra.id),
                      builder: (context, toolsSnap) {
                        final assignments = toolsSnap.data ?? [];
                        if (assignments.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1E293B,
                              ).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'No hay herramientas asignadas actualmente a esta obra',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: assignments.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final a = assignments[idx];
                            return FutureBuilder(
                              future: storage.toolRepository.getTool(a.toolId),
                              builder: (ctx, tSnap) {
                                final tool = tSnap.data;
                                return Card(
                                  margin: EdgeInsets.zero,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.skyAccent
                                          .withValues(alpha: 0.15),
                                      child: const Icon(
                                        LucideIcons.wrench,
                                        color: AppTheme.skyAccent,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      tool?.name ?? 'Herramienta',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Código: ${tool?.code ?? "N/A"} • Salida: ${dateFormat.format(a.assignedAt)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
