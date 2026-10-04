import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/worker.dart';
import '../../core/models/work_log.dart';
import '../../core/theme/app_theme.dart';
import 'worker_form_dialog.dart';
import '../work_logs/work_log_form_dialog.dart';

class WorkerDetailScreen extends StatelessWidget {
  final String workerId;
  final LocalStorageService storage;

  const WorkerDetailScreen({
    super.key,
    required this.workerId,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return StreamBuilder<Worker?>(
      stream: storage.workerRepository.watchWorker(workerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Trabajador')),
            body: const Center(child: Text('Trabajador no encontrado')),
          );
        }

        final worker = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(worker.name),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.pencil, size: 20),
                tooltip: 'Editar trabajador',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => WorkerFormDialog(
                      workerExistente: worker,
                      onGuardar: (act) =>
                          storage.workerRepository.updateWorker(act),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  worker.isActive ? LucideIcons.user_x : LucideIcons.user_check,
                  size: 20,
                  color: worker.isActive
                      ? AppTheme.coralUrgent
                      : AppTheme.emeraldSuccess,
                ),
                tooltip: worker.isActive
                    ? 'Desactivar trabajador'
                    : 'Activar trabajador',
                onPressed: () {
                  if (worker.isActive) {
                    storage.workerRepository.deactivateWorker(worker.id);
                  } else {
                    storage.workerRepository.activateWorker(worker.id);
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarjeta de perfil
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.amberSafety.withValues(
                                alpha: 0.2,
                              ),
                              child: const Icon(
                                LucideIcons.hard_hat,
                                color: AppTheme.amberSafety,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          worker.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: worker.isActive
                                              ? AppTheme.emeraldSuccess
                                                    .withValues(alpha: 0.2)
                                              : Colors.grey.withValues(
                                                  alpha: 0.2,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          worker.isActive
                                              ? 'Activo'
                                              : 'Inactivo',
                                          style: TextStyle(
                                            color: worker.isActive
                                                ? AppTheme.emeraldSuccess
                                                : Colors.grey,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (worker.specialty != null &&
                                      worker.specialty!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      worker.specialty!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.amberSafety,
                                      ),
                                    ),
                                  ],
                                  if (worker.phone != null &&
                                      worker.phone!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.phone,
                                          size: 13,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          worker.phone!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (worker.notes != null &&
                            worker.notes!.isNotEmpty) ...[
                          const Divider(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              worker.notes!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Resumen Financiero y Métricas
                StreamBuilder<List<WorkLog>>(
                  stream: storage.workLogRepository.watchWorkerWorkLogs(
                    worker.id,
                  ),
                  builder: (context, logsSnapshot) {
                    final logs = logsSnapshot.data ?? [];
                    final totalJornadas = logs.length;
                    final totalDevengadoCents = logs.fold<int>(
                      0,
                      (acc, l) => acc + l.amountCents,
                    );
                    final totalDevengado = totalDevengadoCents / 100.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Jornadas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$totalJornadas',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Devengado',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'S/ ${totalDevengado.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.skyAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Historial de Jornadas
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Historial de Jornadas',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.skyAccent,
                              ),
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: const Text('Registrar Jornada'),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => WorkLogFormDialog(
                                    workers: [worker],
                                    obras: storage.obras,
                                    workerPreseleccionadoId: worker.id,
                                    onGuardar: (log) => storage
                                        .workLogRepository
                                        .createWorkLog(log),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (logs.isEmpty)
                          Container(
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
                                  LucideIcons.calendar_x,
                                  size: 32,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Sin jornadas registradas aún',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: logs.length,
                            itemBuilder: (ctx, idx) {
                              final log = logs[idx];
                              final obra = storage.obras.firstWhere(
                                (o) => o.id == log.projectId,
                                orElse: () => storage.obras.isNotEmpty
                                    ? storage.obras.first
                                    : storage.obras.first,
                              );

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.skyAccent
                                        .withValues(alpha: 0.15),
                                    child: const Icon(
                                      LucideIcons.calendar,
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
                                          obra.nombre,
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
                                            workers: [worker],
                                            obras: storage.obras,
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
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
