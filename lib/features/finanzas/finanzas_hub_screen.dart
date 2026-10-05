import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/collection.dart';
import '../../core/models/labor_payment.dart';
import '../../core/models/obra.dart';
import '../../core/models/purchase.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import '../collections/collection_form_dialog.dart';
import '../gastos/gastos_screen.dart';
import '../payments/labor_payment_form_dialog.dart';
import '../purchases/purchase_form_dialog.dart';
import '../socios_clientes/socios_clientes_screen.dart';

class FinanzasHubScreen extends StatefulWidget {
  final LocalStorageService storage;
  final int initialTab;

  const FinanzasHubScreen({
    super.key,
    required this.storage,
    this.initialTab = 0,
  });

  @override
  State<FinanzasHubScreen> createState() => _FinanzasHubScreenState();
}

class _FinanzasHubScreenState extends State<FinanzasHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.coins, color: AppTheme.emeraldSuccess, size: 24),
            SizedBox(width: 10),
            Text('Centro Financiero'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.emeraldSuccess,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(
              icon: Icon(LucideIcons.trending_up, size: 16),
              text: 'Rentabilidad',
            ),
            Tab(
              icon: Icon(LucideIcons.receipt, size: 16),
              text: 'Cobros a Clientes',
            ),
            Tab(
              icon: Icon(LucideIcons.hard_hat, size: 16),
              text: 'Pagos Trabajadores',
            ),
            Tab(
              icon: Icon(LucideIcons.shopping_cart, size: 16),
              text: 'Compras Insumos',
            ),
            Tab(
              icon: Icon(LucideIcons.scale, size: 16),
              text: 'Gastos y Socios',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRentabilidadTab(),
          _buildCobrosTab(),
          _buildPagosTrabajadoresTab(),
          _buildComprasTab(),
          _buildGastosSociosTab(),
        ],
      ),
    );
  }

  // ==================== TAB 1: RENTABILIDAD DE PROYECTOS ====================
  Widget _buildRentabilidadTab() {
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final obras = widget.storage.obras;

    if (obras.isEmpty) {
      return const EmptyStateView(
        icon: LucideIcons.trending_up,
        title: 'Sin proyectos u obras registradas',
        message:
            'Cree una obra para visualizar costos, cobros y margen de rentabilidad.',
        iconColor: AppTheme.emeraldSuccess,
      );
    }

    return ConstrainedContent(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: obras.length,
        itemBuilder: (context, index) {
          final obra = obras[index];
          final agreedRevenueCents = (obra.presupuesto * 100).round();

          return StreamBuilder(
            stream: widget.storage.projectFinancialService
                .watchProjectFinancialSummary(obra.id, agreedRevenueCents),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      obra.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }

              final summary = snapshot.data;
              if (summary == null) return const SizedBox.shrink();

              final isPositiveMargin = summary.grossMarginCents >= 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              obra.nombre,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPositiveMargin
                                  ? AppTheme.emeraldSuccess.withValues(
                                      alpha: 0.15,
                                    )
                                  : AppTheme.coralUrgent.withValues(
                                      alpha: 0.15,
                                    ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Margen ${summary.grossMarginPercent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: isPositiveMargin
                                    ? AppTheme.emeraldSuccess
                                    : AppTheme.coralUrgent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricMini(
                              label: 'Presupuesto',
                              value: currency.format(summary.revenue),
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricMini(
                              label: 'Costo Total',
                              value: currency.format(summary.totalCost),
                              color: AppTheme.amberSafety,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricMini(
                              label: 'Margen Bruto',
                              value: currency.format(summary.grossMargin),
                              color: isPositiveMargin
                                  ? AppTheme.emeraldSuccess
                                  : AppTheme.coralUrgent,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricMini(
                              label: 'Cobrado al Cliente',
                              value: currency.format(summary.collected),
                              color: AppTheme.emeraldSuccess,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricMini(
                              label: 'Por Cobrar',
                              value: currency.format(summary.receivable),
                              color: AppTheme.skyAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ==================== TAB 2: COBROS A CLIENTES ====================
  Widget _buildCobrosTab() {
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_nuevo_cobro',
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const CollectionFormDialog(),
          );
        },
        backgroundColor: AppTheme.emeraldSuccess,
        foregroundColor: const Color(0xFF0F172A),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Registrar Cobro'),
      ),
      body: ConstrainedContent(
        child: StreamBuilder<List<Collection>>(
          stream: widget.storage.collectionRepository.watchAllCollections(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateView(message: 'Cargando cobros...');
            }

            final collections = snapshot.data ?? [];
            if (collections.isEmpty) {
              return EmptyStateView(
                icon: LucideIcons.receipt,
                title: 'No hay cobros registrados',
                message:
                    'Registre abonos o liquidaciones de clientes vinculados a proyectos.',
                actionLabel: 'Registrar Cobro',
                onAction: () {
                  showDialog(
                    context: context,
                    builder: (_) => const CollectionFormDialog(),
                  );
                },
                iconColor: AppTheme.emeraldSuccess,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final c = collections[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.emeraldSuccess.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.arrow_down_left,
                        color: AppTheme.emeraldSuccess,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            c.clientName ?? c.projectName ?? 'Cobro a Cliente',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          currency.format(c.amount),
                          style: const TextStyle(
                            color: AppTheme.emeraldSuccess,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              dateFormat.format(c.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.slateCard,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                c.paymentMethod.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            if (c.reference != null &&
                                c.reference!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Ref: ${c.reference}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (c.projectName != null && c.clientName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Obra: ${c.projectName}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.skyAccent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        LucideIcons.trash,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Anular Cobro'),
                            content: Text(
                              '¿Desea anular el cobro de ${currency.format(c.amount)}? El saldo pendiente de la obra se recalculará automáticamente.',
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
                                child: const Text('Anular'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await widget.storage.collectionRepository
                              .deleteCollection(c.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cobro anulado correctamente.'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ==================== TAB 3: PAGOS A TRABAJADORES ====================
  Widget _buildPagosTrabajadoresTab() {
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_nuevo_pago_trabajador',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SociosClientesScreen(storage: widget.storage, initialTab: 1),
            ),
          );
        },
        backgroundColor: AppTheme.amberSafety,
        foregroundColor: const Color(0xFF0F172A),
        icon: const Icon(LucideIcons.hard_hat),
        label: const Text('Ver Personal y Pagar'),
      ),
      body: ConstrainedContent(
        child: StreamBuilder<List<LaborPayment>>(
          stream: widget.storage.laborPaymentRepository.watchAllPayments(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateView(
                message: 'Cargando pagos laborales...',
              );
            }

            final payments = snapshot.data ?? [];
            if (payments.isEmpty) {
              return EmptyStateView(
                icon: LucideIcons.hard_hat,
                title: 'No hay pagos de mano de obra',
                message:
                    'Registre liquidaciones, adelantos o pagos semanales a operarios.',
                actionLabel: 'Ver Personal y Pagar',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SociosClientesScreen(
                        storage: widget.storage,
                        initialTab: 1,
                      ),
                    ),
                  );
                },
                iconColor: AppTheme.amberSafety,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                final p = payments[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.amberSafety.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.arrow_up_right,
                        color: AppTheme.amberSafety,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pago de Mano de Obra',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          currency.format(p.amount),
                          style: const TextStyle(
                            color: AppTheme.amberSafety,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              dateFormat.format(p.paymentDate),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.slateCard,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.paymentMethod.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (p.notes != null && p.notes!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            p.notes!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        LucideIcons.trash,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Anular Pago Laboral'),
                            content: Text(
                              '¿Desea anular el pago de ${currency.format(p.amount)}? La deuda pendiente con el trabajador se restablecerá automáticamente.',
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
                                child: const Text('Anular'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await widget.storage.laborPaymentRepository
                              .voidPayment(p.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pago laboral anulado.'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ==================== TAB 4: COMPRAS DE INSUMOS ====================
  Widget _buildComprasTab() {
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_nueva_compra',
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const PurchaseFormDialog(),
          );
        },
        backgroundColor: AppTheme.skyAccent,
        foregroundColor: const Color(0xFF0F172A),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Registrar Compra'),
      ),
      body: ConstrainedContent(
        child: StreamBuilder<List<Purchase>>(
          stream: widget.storage.purchaseRepository.watchPurchases(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateView(message: 'Cargando compras...');
            }

            final purchases = snapshot.data ?? [];
            if (purchases.isEmpty) {
              return EmptyStateView(
                icon: LucideIcons.shopping_cart,
                title: 'No hay compras registradas',
                message:
                    'Registre compras a proveedores para abastecer el inventario.',
                actionLabel: 'Registrar Compra',
                onAction: () {
                  showDialog(
                    context: context,
                    builder: (_) => const PurchaseFormDialog(),
                  );
                },
                iconColor: AppTheme.skyAccent,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: purchases.length,
              itemBuilder: (context, index) {
                final p = purchases[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.skyAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.truck,
                        color: AppTheme.skyAccent,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            p.supplierName ?? 'Compra a Proveedor',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          currency.format(p.totalAmount),
                          style: const TextStyle(
                            color: AppTheme.skyAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              dateFormat.format(p.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white60,
                              ),
                            ),
                            if (p.invoiceNumber != null &&
                                p.invoiceNumber!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Doc: ${p.invoiceNumber}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ==================== TAB 5: GASTOS DIRECTOS Y BALANCE DE SOCIOS ====================
  Widget _buildGastosSociosTab() {
    return GastosScreen(storage: widget.storage);
  }

  Widget _buildMetricMini({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white60),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
