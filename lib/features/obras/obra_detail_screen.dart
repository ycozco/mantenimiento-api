import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/obra.dart';
import '../../core/models/worker.dart';
import '../../core/models/work_log.dart';
import '../../core/theme/app_theme.dart';
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
          final inversionTotal = totalMateriales + laborCost;

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
                                'Gastos Materiales/Directos:',
                                currency.format(totalMateriales),
                                AppTheme.amberSafety,
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
                                    value: (inversionTotal / obra.presupuesto)
                                        .clamp(0.0, 1.0),
                                    backgroundColor: const Color(0xFF334155),
                                    valueColor: AlwaysStoppedAnimation<Color>(
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
                          color: const Color(0xFF1E293B).withValues(alpha: 0.5),
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
                      future: storage.workerRepository.watchAllWorkers().first,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
              ],
            ),
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
