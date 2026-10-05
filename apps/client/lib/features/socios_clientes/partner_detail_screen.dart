import 'package:flutter/material.dart';
import '../../core/database/local_storage_service.dart';
import '../../core/models/capital_movement.dart';
import '../../core/models/socio.dart';
import '../../core/theme/app_theme.dart';
import 'capital_movement_form_dialog.dart';

class PartnerDetailScreen extends StatefulWidget {
  final Socio socio;

  const PartnerDetailScreen({super.key, required this.socio});

  @override
  State<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends State<PartnerDetailScreen> {
  String? _selectedFilterType;

  @override
  Widget build(BuildContext context) {
    final storage = LocalStorageService();
    final repo = storage.partnerRepository;

    return Scaffold(
      appBar: AppBar(title: Text(widget.socio.nombre)),
      body: Column(
        children: [
          // Resumen de Saldos Derivados del Ledger
          StreamBuilder<PartnerBalanceSummary>(
            stream: repo.watchPartnerBalance(widget.socio.id),
            builder: (context, snapshot) {
              final summary =
                  snapshot.data ??
                  PartnerBalanceSummary(
                    partnerId: widget.socio.id,
                    contributionsCents: 0,
                    withdrawalsCents: 0,
                    partnerExpensesCents: 0,
                    profitDistributionsCents: 0,
                    adjustmentsCents: 0,
                  );

              final netBalance = summary.netBalance;
              final isPositive = netBalance >= 0;

              return Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.slateDark,
                child: Column(
                  children: [
                    // Tarjeta Principal Saldo Neto
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPositive
                              ? AppTheme.emeraldSuccess
                              : Colors.redAccent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SALDO NETO EN EMPRESA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isPositive
                                    ? 'A favor del socio'
                                    : 'En contra / Adelantos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isPositive
                                      ? Colors.green.shade300
                                      : Colors.red.shade300,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'S/ ${netBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isPositive
                                  ? AppTheme.emeraldSuccess
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Desglose de 4 cuadrantes
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            'Aportes',
                            'S/ ${summary.contributions.toStringAsFixed(2)}',
                            Icons.arrow_upward,
                            Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'Gastos Pers.',
                            'S/ ${summary.partnerExpenses.toStringAsFixed(2)}',
                            Icons.receipt_long,
                            Colors.amberAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'Retiros',
                            'S/ ${summary.withdrawals.toStringAsFixed(2)}',
                            Icons.arrow_downward,
                            Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'Utilidades',
                            'S/ ${summary.profitDistributions.toStringAsFixed(2)}',
                            Icons.pie_chart_outline,
                            Colors.purpleAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Filtros de Tipo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historial de Movimientos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                DropdownButton<String?>(
                  value: _selectedFilterType,
                  hint: const Text('Todos'),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(
                      value: 'contribution',
                      child: Text('Aportes'),
                    ),
                    DropdownMenuItem(
                      value: 'partnerExpense',
                      child: Text('Gastos Pers.'),
                    ),
                    DropdownMenuItem(
                      value: 'withdrawal',
                      child: Text('Retiros'),
                    ),
                    DropdownMenuItem(
                      value: 'profitDistribution',
                      child: Text('Utilidades'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedFilterType = val),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de Movimientos
          Expanded(
            child: StreamBuilder<List<CapitalMovement>>(
              stream: repo.watchPartnerMovements(
                widget.socio.id,
                type: _selectedFilterType,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final movements = snapshot.data ?? [];
                if (movements.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No hay movimientos registrados para este socio',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: movements.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final mov = movements[index];
                    final isCredit = mov.isCredit;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCredit
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
                        child: Icon(
                          isCredit ? Icons.add : Icons.remove,
                          color: isCredit ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text(
                        mov.typeLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        [
                          '${mov.date.day}/${mov.date.month}/${mov.date.year}',
                          if (mov.projectName != null)
                            'Obra: ${mov.projectName}',
                          if (mov.notes != null) mov.notes!,
                        ].join(' • '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isCredit ? "+" : "-"} S/ ${mov.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isCredit ? Colors.green : Colors.orange,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.grey,
                            ),
                            tooltip: 'Anular movimiento',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Anular Movimiento'),
                                  content: Text(
                                    '¿Desea anular este movimiento de ${mov.typeLabel} por S/ ${mov.amount.toStringAsFixed(2)}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Anular'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await repo.deleteCapitalMovement(mov.id);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newMovement = await showDialog<CapitalMovement>(
            context: context,
            builder: (_) =>
                CapitalMovementFormDialog(partnerId: widget.socio.id),
          );

          if (newMovement != null) {
            await repo.recordCapitalMovement(newMovement);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Registrar Movimiento'),
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
