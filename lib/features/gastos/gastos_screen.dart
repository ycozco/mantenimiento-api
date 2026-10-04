import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/gasto.dart';
import '../../core/models/socio.dart';
import '../../core/models/balance_calculator.dart';
import '../../core/theme/app_theme.dart';
import 'gasto_form_dialog.dart';

class GastosScreen extends StatefulWidget {
  final LocalStorageService storage;

  const GastosScreen({super.key, required this.storage});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getIconoCategoria(CategoriaGasto cat) {
    switch (cat) {
      case CategoriaGasto.gasolina:
        return LucideIcons.fuel;
      case CategoriaGasto.mantenimientoVehiculoHerramienta:
        return LucideIcons.wrench;
      case CategoriaGasto.comida:
        return LucideIcons.utensils;
      case CategoriaGasto.materialesObra:
        return LucideIcons.package;
      case CategoriaGasto.herramientas:
        return LucideIcons.hammer;
      case CategoriaGasto.viaticos:
        return LucideIcons.car;
      case CategoriaGasto.otro:
        return LucideIcons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.coins, color: AppTheme.emeraldSuccess, size: 24),
            SizedBox(width: 10),
            Text('Gastos e Inversiones'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.emeraldSuccess,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(LucideIcons.receipt, size: 18), text: 'Gastos Registrados'),
            Tab(icon: Icon(LucideIcons.scale, size: 18), text: 'Balance de Socios'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.emeraldSuccess,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Registrar Gasto', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => GastoFormDialog(
              socios: widget.storage.socios,
              obras: widget.storage.obras,
              mantenimientos: widget.storage.mantenimientos,
              onGuardar: (gasto) => widget.storage.agregarGasto(gasto),
            ),
          );
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGastosList(),
          _buildBalanceTab(),
        ],
      ),
    );
  }

  Widget _buildGastosList() {
    final gastos = widget.storage.gastos;
    final total = gastos.fold(0.0, (acc, g) => acc + g.montoTotal);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    if (gastos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppTheme.slateCard, shape: BoxShape.circle),
              child: const Icon(LucideIcons.receipt, size: 48, color: AppTheme.emeraldSuccess),
            ),
            const SizedBox(height: 16),
            const Text('No hay gastos registrados aún', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Registra gastos de gasolina, comidas o compras para dividirlos entre socios.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Resumen total gastado
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.slateSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Gastado / Invertido', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(currency.format(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldSuccess.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${gastos.length} gastos', style: const TextStyle(color: AppTheme.emeraldSuccess, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            itemCount: gastos.length,
            itemBuilder: (ctx, idx) {
              final gasto = gastos[idx];
              final socioPagador = widget.storage.socios.firstWhere(
                (s) => s.id == gasto.pagadoPorSocioId,
                orElse: () => Socio(id: gasto.pagadoPorSocioId, nombre: 'Socio'),
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(socioPagador.colorValue).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getIconoCategoria(gasto.categoria), color: Color(socioPagador.colorValue), size: 22),
                  ),
                  title: Text(gasto.concepto, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Pagó: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            socioPagador.nombre,
                            style: TextStyle(fontSize: 12, color: Color(socioPagador.colorValue), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Text('• ${DateFormat('dd/MM/yy').format(gasto.fecha)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      if (gasto.obraNombre != null) ...[
                        const SizedBox(height: 2),
                        Text('Obra: ${gasto.obraNombre}', style: const TextStyle(fontSize: 11, color: AppTheme.skyAccent)),
                      ],
                      const SizedBox(height: 2),
                      Text('Reparto: ${gasto.tipoReparto.etiqueta}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(currency.format(gasto.montoTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.emeraldSuccess)),
                      IconButton(
                        icon: const Icon(LucideIcons.trash, size: 16, color: Colors.grey),
                        onPressed: () => _confirmarEliminarGasto(gasto.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceTab() {
    final socios = widget.storage.socios;
    final gastos = widget.storage.gastos;
    final resumenes = BalanceCalculator.calcularResumenes(socios: socios, gastos: gastos);
    final deudas = BalanceCalculator.calcularDeudasSimplificadas(socios: socios, gastos: gastos);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de "¿Quién debe a quién?"
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.slateSurface, const Color(0xFF162032)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.emeraldSuccess.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.hand_coins, color: AppTheme.emeraldSuccess, size: 22),
                    SizedBox(width: 10),
                    Text('Liquidación Directa de Cuentas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                if (deudas.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldSuccess.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.circle_check, color: AppTheme.emeraldSuccess, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('¡Todas las cuentas están cuadradas! Nadie le debe a nadie.', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],
                    ),
                  )
                else
                  ...deudas.map((d) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                CircleAvatar(radius: 5, backgroundColor: Color(d.deudor.colorValue)),
                                Text(d.deudor.nombre, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                const Text('→ paga a', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                CircleAvatar(radius: 5, backgroundColor: Color(d.acreedor.colorValue)),
                                Text(d.acreedor.nombre, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(currency.format(d.monto), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.amberSafety, fontSize: 14)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Aporte y Cuota de Cada Socio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),

          // Desglose por socio
          ...resumenes.map((r) {
            Color colorSaldo;
            String textoSaldo;
            if (r.tieneSaldoAFavor) {
              colorSaldo = AppTheme.emeraldSuccess;
              textoSaldo = '+ Le deben ${currency.format(r.saldoNeto)}';
            } else if (r.tieneDeuda) {
              colorSaldo = AppTheme.coralUrgent;
              textoSaldo = '- Debe ${currency.format(-r.saldoNeto)}';
            } else {
              colorSaldo = Colors.grey;
              textoSaldo = 'Al día (\$0.00)';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 12, backgroundColor: Color(r.socio.colorValue)),
                        const SizedBox(width: 10),
                        Text(r.socio.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorSaldo.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(textoSaldo, style: TextStyle(color: colorSaldo, fontWeight: FontWeight.bold, fontSize: 12)),
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
                            const Text('Puso de su bolsillo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(currency.format(r.totalPagado), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Cuota que le correspondía', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(currency.format(r.totalDeberiaPagar), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _confirmarEliminarGasto(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.slateSurface,
        title: const Text('Eliminar Gasto'),
        content: const Text('¿Deseas eliminar este registro de gasto? El balance se recalculará automáticamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coralUrgent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              widget.storage.eliminarGasto(id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
