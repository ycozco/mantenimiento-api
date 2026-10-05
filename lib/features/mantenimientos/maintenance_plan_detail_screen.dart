import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/maintenance_plan.dart';
import '../../core/models/maintenance_visit.dart';
import '../../core/models/maintenance_financial_summary.dart';
import '../../core/theme/app_theme.dart';
import '../collections/collection_form_dialog.dart';
import 'maintenance_visit_detail_screen.dart';

class MaintenancePlanDetailScreen extends StatelessWidget {
  final String planId;
  final LocalStorageService storage;

  const MaintenancePlanDetailScreen({
    super.key,
    required this.planId,
    required this.storage,
  });

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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return FutureBuilder<MaintenancePlan?>(
      future: storage.maintenanceRepository.getPlanById(planId),
      builder: (context, planSnapshot) {
        if (!planSnapshot.hasData || planSnapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Plan de Mantenimiento')),
            body: const Center(child: Text('Plan no encontrado')),
          );
        }

        final plan = planSnapshot.data!;
        final cliente = storage.clientes.firstWhere(
          (c) => c.id == plan.clientId,
          orElse: () => storage.clientes.isNotEmpty
              ? storage.clientes.first
              : storage.clientes.first,
        );

        return Scaffold(
          appBar: AppBar(title: Text(plan.title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarjeta de Información del Plan
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.emeraldSuccess
                                  .withValues(alpha: 0.2),
                              child: const Icon(
                                LucideIcons.calendar_clock,
                                color: AppTheme.emeraldSuccess,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.building,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        cliente.nombre,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Frecuencia',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cada ${plan.intervalDays} días',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Próxima Visita',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateFormat.format(plan.nextDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.amberSafety,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (plan.description != null &&
                            plan.description!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            plan.description!,
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Resumen Financiero del Plan
                StreamBuilder<MaintenanceFinancialSummary>(
                  stream: storage.maintenanceFinancialService
                      .watchPlanFinancials(plan.id),
                  builder: (context, finSnapshot) {
                    final summary = finSnapshot.data;
                    final billingLabel = plan.billingType == 'monthly'
                        ? 'Tarifa Mensual'
                        : (plan.billingType == 'custom'
                              ? 'Tarifa Personalizada'
                              : 'Tarifa por Visita');
                    final agreedTariff = (plan.agreedAmountCents / 100.0)
                        .toStringAsFixed(2);
                    final revenue = ((summary?.revenueCents ?? 0) / 100.0)
                        .toStringAsFixed(2);
                    final collected = ((summary?.collectedCents ?? 0) / 100.0)
                        .toStringAsFixed(2);
                    final receivable = ((summary?.receivableCents ?? 0) / 100.0)
                        .toStringAsFixed(2);
                    final totalCost = ((summary?.totalCostCents ?? 0) / 100.0)
                        .toStringAsFixed(2);
                    final margin = ((summary?.grossMarginCents ?? 0) / 100.0)
                        .toStringAsFixed(2);
                    final marginPct = (summary?.grossMarginPercent ?? 0.0)
                        .toStringAsFixed(1);

                    return Card(
                      color: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF1E293B)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.banknote,
                                      size: 18,
                                      color: AppTheme.emeraldSuccess,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Economía del Plan ($billingLabel)',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'S/ $agreedTariff',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.skyAccent,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, color: Color(0xFF334155)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Facturación / Ingresos',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'S/ $revenue',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Costos Operativos',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'S/ $totalCost',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.coralUrgent,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Margen Bruto',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'S/ $margin ($marginPct%)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color:
                                            (summary?.grossMarginCents ?? 0) >=
                                                0
                                            ? AppTheme.emeraldSuccess
                                            : AppTheme.coralUrgent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cobrado',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'S/ $collected',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.emeraldSuccess,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Saldo por Cobrar',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'S/ $receivable',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.amberSafety,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.emeraldSuccess,
                                  side: const BorderSide(
                                    color: AppTheme.emeraldSuccess,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(LucideIcons.receipt, size: 16),
                                label: const Text('Registrar Cobro al Plan'),
                                onPressed: () async {
                                  final col = await showDialog(
                                    context: context,
                                    builder: (_) => CollectionFormDialog(
                                      planId: plan.id,
                                      initialClientId: plan.clientId,
                                      targetAmountCents:
                                          (summary?.receivableCents ?? 0) > 0
                                          ? summary!.receivableCents
                                          : plan.agreedAmountCents,
                                      title: 'Cobro de Plan: ${plan.title}',
                                    ),
                                  );
                                  if (col != null) {
                                    await storage.collectionRepository
                                        .recordCollection(col);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Historial Real de Visitas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Historial de Visitas',
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
                      label: const Text('Programar Visita Extra'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          await storage.maintenanceRepository.createVisit(
                            MaintenanceVisit(
                              planId: plan.id,
                              scheduledDate: picked,
                              status: VisitStatus.scheduled,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                StreamBuilder<List<MaintenanceVisit>>(
                  stream: storage.maintenanceRepository.watchVisitsForPlan(
                    plan.id,
                  ),
                  builder: (context, visitsSnapshot) {
                    final visits = visitsSnapshot.data ?? [];
                    if (visits.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'No hay visitas registradas para este plan',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visits.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final visit = visits[idx];
                        final statusColor = _getStatusColor(visit.status);

                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MaintenanceVisitDetailScreen(
                                    visitId: visit.id,
                                    planId: plan.id,
                                    storage: storage,
                                  ),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withValues(
                                alpha: 0.15,
                              ),
                              child: Icon(
                                visit.isCompleted
                                    ? LucideIcons.calendar_check
                                    : LucideIcons.calendar,
                                color: statusColor,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateFormat.format(
                                    visit.completedDate ?? visit.scheduledDate,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    visit.status.label,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  visit.isCompleted &&
                                          visit.completedDate != null
                                      ? 'Ejecutada el ${dateFormat.format(visit.completedDate!)}'
                                      : 'Programada para el ${dateFormat.format(visit.scheduledDate)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (visit.technicianNotes != null &&
                                    visit.technicianNotes!.isNotEmpty)
                                  Text(
                                    visit.technicianNotes!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: const Icon(
                              LucideIcons.chevron_right,
                              color: Colors.grey,
                              size: 18,
                            ),
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
      },
    );
  }
}
