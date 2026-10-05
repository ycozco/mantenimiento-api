import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/obra.dart';
import '../../core/models/socio.dart';
import '../../core/theme/app_theme.dart';
import 'obra_form_dialog.dart';
import 'obra_detail_screen.dart';
import '../gastos/gasto_form_dialog.dart';
import '../work_logs/work_log_form_dialog.dart';

class ObrasScreen extends StatefulWidget {
  final LocalStorageService storage;

  const ObrasScreen({super.key, required this.storage});

  @override
  State<ObrasScreen> createState() => _ObrasScreenState();
}

class _ObrasScreenState extends State<ObrasScreen> {
  @override
  Widget build(BuildContext context) {
    final obras = widget.storage.obras;
    final gastos = widget.storage.gastos;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.hard_hat, color: AppTheme.skyAccent, size: 24),
            SizedBox(width: 10),
            Text('Obras y Proyectos'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.skyAccent,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text(
          'Nueva Obra',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => ObraFormDialog(
              clientes: widget.storage.clientes,
              socios: widget.storage.socios,
              onGuardar: (o) => widget.storage.agregarObra(o),
            ),
          );
        },
      ),
      body: obras.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: obras.length,
              itemBuilder: (ctx, idx) {
                final obra = obras[idx];
                final gastosObra = gastos
                    .where((g) => g.obraId == obra.id)
                    .toList();
                final totalGastado = gastosObra.fold(
                  0.0,
                  (acc, g) => acc + g.montoTotal,
                );

                return _buildObraCard(obra, totalGastado, gastosObra.length);
              },
            ),
    );
  }

  Widget _buildObraCard(Obra obra, double totalGastado, int cantidadGastos) {
    Color estadoColor;
    switch (obra.estado) {
      case EstadoObra.enProgreso:
        estadoColor = AppTheme.skyAccent;
        break;
      case EstadoObra.finalizada:
        estadoColor = AppTheme.emeraldSuccess;
        break;
      case EstadoObra.pausada:
        estadoColor = AppTheme.amberSafety;
        break;
      case EstadoObra.planificada:
        estadoColor = Colors.grey;
        break;
    }

    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    return StreamBuilder<int>(
      stream: widget.storage.workLogRepository.watchProjectLaborCostCents(
        obra.id,
      ),
      builder: (context, laborSnapshot) {
        final laborCostCents = laborSnapshot.data ?? 0;
        final laborCost = laborCostCents / 100.0;
        final totalInvertido = totalGastado + laborCost;

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ObraDetailScreen(obra: obra, storage: widget.storage),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              obra.nombre,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (obra.clienteNombre != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Cliente: ${obra.clienteNombre}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: estadoColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          obra.estado.etiqueta,
                          style: TextStyle(
                            color: estadoColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Inversión vs Presupuesto con Mano de Obra
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Inversión Total',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currency.format(totalInvertido),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.emeraldSuccess,
                                    ),
                                  ),
                                  Text(
                                    'Materiales: ${currency.format(totalGastado)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  Text(
                                    'Mano de Obra: ${currency.format(laborCost)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.skyAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (obra.presupuesto > 0) ...[
                              Container(
                                width: 1,
                                height: 45,
                                color: const Color(0xFF334155),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Presupuesto Total',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currency.format(obra.presupuesto),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${((totalInvertido / obra.presupuesto) * 100).toStringAsFixed(1)}% ejecutado',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.skyAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Socios asignados
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.users, size: 14, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'Socios:',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      ...obra.sociosAsignados.map((sid) {
                        final s = widget.storage.socios.firstWhere(
                          (socio) => socio.id == sid,
                          orElse: () => Socio(id: sid, nombre: 'S'),
                        );
                        return Chip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          avatar: CircleAvatar(
                            radius: 6,
                            backgroundColor: Color(s.colorValue),
                          ),
                          label: Text(
                            s.nombre,
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Botón + Jornada
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.skyAccent.withValues(
                              alpha: 0.15,
                            ),
                            foregroundColor: AppTheme.skyAccent,
                            side: const BorderSide(
                              color: AppTheme.skyAccent,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 6,
                            ),
                          ),
                          icon: const Icon(LucideIcons.calendar_plus, size: 15),
                          label: const Text(
                            '+ Jornada',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () async {
                            final workers = await widget
                                .storage
                                .workerRepository
                                .getActiveWorkers();
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
                                obras: widget.storage.obras,
                                obraPreseleccionadaId: obra.id,
                                onGuardar: (log) => widget
                                    .storage
                                    .workLogRepository
                                    .createWorkLog(log),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Botón + Gasto
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.amberSafety.withValues(
                              alpha: 0.15,
                            ),
                            foregroundColor: AppTheme.amberSafety,
                            side: const BorderSide(
                              color: AppTheme.amberSafety,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 6,
                            ),
                          ),
                          icon: const Icon(LucideIcons.circle_plus, size: 15),
                          label: const Text(
                            '+ Gasto',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => GastoFormDialog(
                                socios: widget.storage.socios,
                                obras: widget.storage.obras,
                                mantenimientos: widget.storage.mantenimientos,
                                obraPreseleccionadaId: obra.id,
                                onGuardar: (gasto) =>
                                    widget.storage.agregarGasto(gasto),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.pencil,
                          size: 18,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => ObraFormDialog(
                              obraExistente: obra,
                              clientes: widget.storage.clientes,
                              socios: widget.storage.socios,
                              onGuardar: (actualizada) =>
                                  widget.storage.editarObra(actualizada),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.trash,
                          size: 18,
                          color: AppTheme.coralUrgent,
                        ),
                        onPressed: () => _confirmarEliminar(obra.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmarEliminar(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.slateSurface,
        title: const Text('Eliminar Obra'),
        content: const Text('¿Deseas eliminar este registro de obra?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coralUrgent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.storage.eliminarObra(id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.slateCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.hard_hat,
                size: 48,
                color: AppTheme.skyAccent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay obras registradas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Registra obras o proyectos independientes para llevar sus compras e inversiones compartidas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
