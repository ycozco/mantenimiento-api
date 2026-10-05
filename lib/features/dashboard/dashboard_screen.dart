import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/dashboard_summary.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_theme.dart';
import '../inventory/inventory_screen.dart';
import '../tools/tools_screen.dart';
import '../calendar/calendar_screen.dart';
import '../socios_clientes/socios_clientes_screen.dart';

class DashboardScreen extends StatelessWidget {
  final LocalStorageService storage;
  final Function(int)? onNavigateTab;

  const DashboardScreen({super.key, required this.storage, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.amberSafety.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.layout_dashboard,
                color: AppTheme.amberSafety,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Panel Operacional',
                style: TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DashboardSummary>(
        stream: storage.dashboardService.watchDashboardSummary(),
        builder: (context, snapshot) {
          final summary = snapshot.data ?? DashboardSummary();

          return RefreshIndicator(
            onRefresh: () async {
              // Drift streams react automatically, but this provides standard UX
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: ConstrainedContent(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // BANNER DE ALERTAS URGENTES (si aplica)
                  if (summary.hasUrgentAlerts) ...[
                    _buildUrgentAlertsBanner(context, summary),
                    const SizedBox(height: 16),
                  ],

                  // SECCIÓN 1: HOY Y MANTENIMIENTOS
                  _buildSectionHeader(
                    title: 'HOY Y AGENDA INMEDIATA',
                    icon: LucideIcons.calendar,
                    color: AppTheme.amberSafety,
                    trailing: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CalendarScreen(storage: storage),
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.calendar_days, size: 14),
                      label: const Text(
                        'Ver Calendario',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Mantenimientos Hoy',
                          value: '${summary.visitsTodayCount}',
                          subtitle: summary.visitsTodayCount == 1
                              ? '1 visita programada'
                              : '${summary.visitsTodayCount} visitas programadas',
                          icon: LucideIcons.calendar_check,
                          color: AppTheme.emeraldSuccess,
                          onTap: () => onNavigateTab?.call(2), // Mantenimientos
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Próximos 7 días',
                          value: '${summary.visitsUpcoming7DaysCount}',
                          subtitle: 'Visitas en agenda',
                          icon: LucideIcons.calendar_clock,
                          color: AppTheme.skyAccent,
                          onTap: () => onNavigateTab?.call(2), // Mantenimientos
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SECCIÓN 2: FINANZAS DE OBRAS ACTIVAS
                  _buildSectionHeader(
                    title: 'FINANZAS DE OBRAS ACTIVAS',
                    icon: LucideIcons.coins,
                    color: AppTheme.emeraldSuccess,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Obras en Ejecución: ${summary.activeProjectsCount}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    onNavigateTab?.call(1), // Obras
                                icon: const Icon(
                                  LucideIcons.arrow_right,
                                  size: 16,
                                ),
                                label: const Text('Ver Obras'),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          _buildFinancialRow(
                            'Presupuesto Total Activo:',
                            currency.format(
                              summary.activeProjectsAgreedRevenue,
                            ),
                            Colors.white,
                            isBold: true,
                          ),
                          const SizedBox(height: 6),
                          _buildFinancialRow(
                            'Costo Total Ejecutado:',
                            currency.format(summary.activeProjectsTotalCost),
                            AppTheme.amberSafety,
                          ),
                          const SizedBox(height: 6),
                          _buildFinancialRow(
                            'Margen Bruto Proyectado:',
                            '${currency.format(summary.activeProjectsGrossMargin)} (${summary.activeProjectsGrossMarginPercent.toStringAsFixed(1)}%)',
                            summary.activeProjectsGrossMarginCents >= 0
                                ? AppTheme.emeraldSuccess
                                : AppTheme.coralUrgent,
                            isBold: true,
                          ),
                          const Divider(height: 16),
                          _buildFinancialRow(
                            'Total Cobrado:',
                            currency.format(summary.activeProjectsCollected),
                            AppTheme.emeraldSuccess,
                          ),
                          const SizedBox(height: 6),
                          _buildFinancialRow(
                            'Por Cobrar a Clientes:',
                            currency.format(summary.activeProjectsReceivable),
                            AppTheme.skyAccent,
                            isBold: true,
                          ),
                          if (summary.totalPendingLaborDebtCents > 0) ...[
                            const Divider(height: 16),
                            _buildFinancialRow(
                              'Pasivo Laboral Pendiente (Jornadas):',
                              currency.format(summary.totalPendingLaborDebt),
                              AppTheme.coralUrgent,
                              isBold: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SECCIÓN 3: OPERACIONES Y ACTIVOS
                  _buildSectionHeader(
                    title: 'RECURSOS Y OPERACIONES',
                    icon: LucideIcons.hard_hat,
                    color: AppTheme.skyAccent,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Personal Activo',
                          value: '${summary.activeWorkersCount}',
                          subtitle: 'Trabajadores habilitados',
                          icon: LucideIcons.users,
                          color: AppTheme.skyAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SociosClientesScreen(
                                  storage: storage,
                                  initialTab: 1,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Herramientas Afuera',
                          value: '${summary.assignedToolsCount}',
                          subtitle: summary.toolsInMaintenanceCount > 0
                              ? '${summary.toolsInMaintenanceCount} en taller'
                              : 'En obras / visitas',
                          icon: LucideIcons.wrench,
                          color: summary.overdueToolReturnsCount > 0
                              ? AppTheme.coralUrgent
                              : AppTheme.amberSafety,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ToolsScreen(storage: storage),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SECCIÓN 4: ALERTAS DE INVENTARIO
                  _buildSectionHeader(
                    title: 'ESTADO DE INVENTARIO (KARDEX)',
                    icon: LucideIcons.package,
                    color: AppTheme.amberSafety,
                  ),
                  const SizedBox(height: 8),
                  if (summary.stockAlerts.isEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.circle_check,
                              color: AppTheme.emeraldSuccess,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Todos los insumos se encuentran en niveles adecuados de stock.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InventoryScreen(storage: storage),
                                  ),
                                );
                              },
                              child: const Text('Ver Almacén'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
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
                                  '${summary.outOfStockItemsCount} agotados • ${summary.lowStockItemsCount} bajo mínimo',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.coralUrgent,
                                    fontSize: 13,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            InventoryScreen(storage: storage),
                                      ),
                                    );
                                  },
                                  child: const Text('Ir a Inventario'),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Column(
                              children: summary.stockAlerts.take(4).map((
                                alert,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            alert.isOutOfStock
                                                ? LucideIcons.triangle_alert
                                                : LucideIcons.circle_alert,
                                            size: 16,
                                            color: alert.isOutOfStock
                                                ? AppTheme.coralUrgent
                                                : AppTheme.amberSafety,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            alert.itemName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${alert.currentStock.toStringAsFixed(1)} / mín. ${alert.minStockAlert.toStringAsFixed(1)} ${alert.unit}',
                                        style: TextStyle(
                                          color: alert.isOutOfStock
                                              ? AppTheme.coralUrgent
                                              : AppTheme.amberSafety,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUrgentAlertsBanner(
    BuildContext context,
    DashboardSummary summary,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.coralUrgent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.coralUrgent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                LucideIcons.octagon_alert,
                color: AppTheme.coralUrgent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'ATENCIÓN OPERACIONAL REQUERIDA',
                style: TextStyle(
                  color: AppTheme.coralUrgent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (summary.visitsOverdueCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• ${summary.visitsOverdueCount} ${summary.visitsOverdueCount == 1 ? "visita de mantenimiento vencida" : "visitas de mantenimiento vencidas"} pendiente de atención.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          if (summary.overdueToolReturnsCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• ${summary.overdueToolReturnsCount} ${summary.overdueToolReturnsCount == 1 ? "herramienta con retorno vencido" : "herramientas con retornos vencidos"}.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          if (summary.outOfStockItemsCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• ${summary.outOfStockItemsCount} ${summary.outOfStockItemsCount == 1 ? "insumo de almacén totalmente agotado" : "insumos de almacén totalmente agotados"}.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
