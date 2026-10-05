import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/maintenance_plan.dart';
import '../../core/models/maintenance_visit.dart';
import '../../core/models/work_log.dart';
import '../../core/models/stock_movement.dart';
import '../../core/models/tool_assignment.dart';
import '../../core/theme/app_theme.dart';
import '../attachments/attachment_list_widget.dart';
import '../inventory/stock_movement_form_dialog.dart';
import '../work_logs/work_log_form_dialog.dart';

class MaintenanceVisitDetailScreen extends StatefulWidget {
  final String visitId;
  final String planId;
  final LocalStorageService storage;

  const MaintenanceVisitDetailScreen({
    super.key,
    required this.visitId,
    required this.planId,
    required this.storage,
  });

  @override
  State<MaintenanceVisitDetailScreen> createState() =>
      _MaintenanceVisitDetailScreenState();
}

class _MaintenanceVisitDetailScreenState
    extends State<MaintenanceVisitDetailScreen> {
  late Future<MaintenancePlan?> _planFuture;

  @override
  void initState() {
    super.initState();
    _planFuture = widget.storage.maintenanceRepository.getPlanById(
      widget.planId,
    );
  }

  Color _getStatusColor(VisitStatus status) {
    switch (status) {
      case VisitStatus.scheduled:
        return AppTheme.amberSafety;
      case VisitStatus.inProgress:
        return AppTheme.skyAccent;
      case VisitStatus.completed:
        return AppTheme.emeraldSuccess;
      case VisitStatus.cancelled:
        return AppTheme.coralUrgent;
    }
  }

  Future<void> _showCompleteDialog(MaintenanceVisit visit) async {
    final notesController = TextEditingController(
      text: visit.technicianNotes ?? '',
    );
    DateTime executedDate = visit.completedDate ?? DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Completar Visita',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Al completar esta visita se registrará en el historial y se programará automáticamente la próxima visita del plan.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: executedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setDialogState(() => executedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de Ejecución Real',
                    prefixIcon: Icon(LucideIcons.calendar),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(executedDate),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Observaciones / Informe Técnico',
                  prefixIcon: Icon(LucideIcons.file_text),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldSuccess,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Confirmar y Finalizar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await widget.storage.maintenanceRepository.completeVisit(
        visit.id,
        executedDate: executedDate,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visita completada y próxima fecha programada'),
            backgroundColor: AppTheme.emeraldSuccess,
          ),
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return FutureBuilder<MaintenancePlan?>(
      future: _planFuture,
      builder: (context, planSnapshot) {
        final plan = planSnapshot.data;

        return StreamBuilder<List<MaintenanceVisit>>(
          stream: widget.storage.maintenanceRepository.watchVisitsForPlan(
            widget.planId,
          ),
          builder: (context, visitsSnapshot) {
            final visits = visitsSnapshot.data ?? [];
            final visit = visits.firstWhere(
              (v) => v.id == widget.visitId,
              orElse: () => MaintenanceVisit(
                id: widget.visitId,
                planId: widget.planId,
                scheduledDate: DateTime.now(),
              ),
            );

            return Scaffold(
              appBar: AppBar(
                title: Text(plan?.title ?? 'Visita de Mantenimiento'),
                actions: [
                  if (!visit.isCompleted && !visit.isCancelled)
                    PopupMenuButton<String>(
                      icon: const Icon(LucideIcons.ellipsis_vertical),
                      onSelected: (val) async {
                        if (val == 'cancel') {
                          await widget.storage.maintenanceRepository
                              .cancelVisit(visit.id);
                          if (context.mounted) setState(() {});
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text(
                            'Cancelar Visita',
                            style: TextStyle(color: AppTheme.coralUrgent),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tarjeta Estado de la Visita
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      visit.status,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getStatusColor(
                                        visit.status,
                                      ).withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    visit.status.label.toUpperCase(),
                                    style: TextStyle(
                                      color: _getStatusColor(visit.status),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Visita #${visit.version}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.calendar,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Programada: ${dateFormat.format(visit.scheduledDate)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            if (visit.completedDate != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    LucideIcons.calendar_check,
                                    size: 16,
                                    color: AppTheme.emeraldSuccess,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ejecutada: ${dateFormat.format(visit.completedDate!)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.emeraldSuccess,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (visit.technicianNotes != null &&
                                visit.technicianNotes!.isNotEmpty) ...[
                              const Divider(height: 20),
                              Text(
                                visit.technicianNotes!,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Costos y Jornadas de la Visita (Mano de Obra + Materiales)
                    StreamBuilder<int>(
                      stream: widget.storage.maintenanceRepository
                          .watchVisitLaborCostCents(visit.id),
                      builder: (context, laborSnapshot) {
                        final laborCost = (laborSnapshot.data ?? 0) / 100.0;

                        return StreamBuilder<int>(
                          stream: widget.storage.inventoryRepository
                              .watchVisitMaterialCostCents(visit.id),
                          builder: (context, matSnapshot) {
                            final matCost = (matSnapshot.data ?? 0) / 100.0;
                            final totalCost = laborCost + matCost;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Mano de Obra:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        'S/ ${laborCost.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.skyAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Insumos / Materiales:',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        'S/ ${matCost.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.emeraldSuccess,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(
                                    height: 16,
                                    color: Color(0xFF334155),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Costo Total de la Visita:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'S/ ${totalCost.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.amberSafety,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Jornadas Laborales Asociadas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jornadas en esta Visita',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (!visit.isCancelled)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.skyAccent,
                            ),
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Registrar Jornada'),
                            onPressed: () async {
                              final workers = await widget
                                  .storage
                                  .workerRepository
                                  .getActiveWorkers();
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (_) => WorkLogFormDialog(
                                    workers: workers,
                                    obras: const [],
                                    maintenanceVisitId: visit.id,
                                    onGuardar: (log) => widget
                                        .storage
                                        .workLogRepository
                                        .createWorkLog(log),
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    StreamBuilder<List<WorkLog>>(
                      stream: widget.storage.maintenanceRepository
                          .watchVisitWorkLogs(visit.id),
                      builder: (context, logsSnapshot) {
                        final logs = logsSnapshot.data ?? [];
                        if (logs.isEmpty) {
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
                              'No se han registrado jornadas para esta visita',
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
                          itemCount: logs.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final log = logs[idx];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.skyAccent
                                      .withValues(alpha: 0.15),
                                  child: const Icon(
                                    LucideIcons.user,
                                    color: AppTheme.skyAccent,
                                    size: 18,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    FutureBuilder(
                                      future: widget.storage.workerRepository
                                          .getWorkerById(log.workerId),
                                      builder: (ctx, wSnap) => Text(
                                        wSnap.data?.name ?? 'Trabajador',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
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
                                subtitle: Text(
                                  '${dateFormat.format(log.date)} • ${log.quantityFormatted} (${log.paymentTypeLabel})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(
                                    LucideIcons.ellipsis_vertical,
                                    size: 16,
                                  ),
                                  onSelected: (val) {
                                    if (val == 'void') {
                                      widget.storage.workLogRepository
                                          .voidWorkLog(log.id);
                                    }
                                  },
                                  itemBuilder: (_) => [
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
                    ),
                    const SizedBox(height: 24),

                    // Materiales e Insumos Consumidos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Insumos / Materiales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (!visit.isCancelled)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.emeraldSuccess,
                            ),
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Registrar Consumo'),
                            onPressed: () async {
                              final items = await widget
                                  .storage
                                  .inventoryRepository
                                  .watchActiveItems()
                                  .first;
                              if (!context.mounted) return;
                              if (items.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No hay insumos registrados en el inventario. Agregue uno en Ajustes > Inventario.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              showDialog(
                                context: context,
                                builder: (_) => StockMovementFormDialog(
                                  storage: widget.storage,
                                  items: items,
                                  preselectedVisitId: visit.id,
                                  preselectedMovementType: 'consumption',
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    StreamBuilder<List<StockMovement>>(
                      stream: widget.storage.inventoryRepository
                          .watchVisitMovements(visit.id),
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
                              'No se han registrado consumos de materiales para esta visita',
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
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final m = moves[idx];
                            return FutureBuilder(
                              future: widget.storage.inventoryRepository
                                  .getItem(m.itemId),
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
                                          item?.name ?? 'Insumo',
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
                                      '${m.quantity.abs().toStringAsFixed(1)} ${item?.unitLabel ?? "und"} • S/ ${(m.unitCostCents / 100.0).toStringAsFixed(2)} c/u',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(
                                        LucideIcons.ellipsis_vertical,
                                        size: 16,
                                      ),
                                      onSelected: (val) {
                                        if (val == 'delete') {
                                          widget.storage.inventoryRepository
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

                    // Herramientas Asignadas a esta Visita
                    const Text(
                      'Herramientas Asignadas a la Visita',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    StreamBuilder<List<ToolAssignment>>(
                      stream: widget.storage.toolRepository
                          .watchVisitActiveAssignments(visit.id),
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
                              'No hay herramientas asignadas actualmente a esta visita',
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
                              future: widget.storage.toolRepository.getTool(
                                a.toolId,
                              ),
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
                    const SizedBox(height: 24),

                    // Archivos y Evidencias Fotográficas
                    AttachmentListWidget(
                      parentType: 'maintenance_visit',
                      parentId: visit.id,
                      storage: widget.storage,
                    ),
                    const SizedBox(height: 28),

                    // Barra de Acciones de Visita
                    if (!visit.isCompleted && !visit.isCancelled) ...[
                      Row(
                        children: [
                          if (visit.isScheduled)
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: const BorderSide(
                                    color: AppTheme.skyAccent,
                                  ),
                                  foregroundColor: AppTheme.skyAccent,
                                ),
                                icon: const Icon(LucideIcons.play, size: 18),
                                label: const Text('Iniciar Visita'),
                                onPressed: () async {
                                  await widget.storage.maintenanceRepository
                                      .startVisit(visit.id);
                                  if (context.mounted) setState(() {});
                                },
                              ),
                            ),
                          if (visit.isScheduled) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: AppTheme.emeraldSuccess,
                                foregroundColor: Colors.black,
                              ),
                              icon: const Icon(
                                LucideIcons.check_check,
                                size: 18,
                              ),
                              label: const Text(
                                'Completar Visita',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _showCompleteDialog(visit),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
