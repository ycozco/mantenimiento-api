import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/stock_movement.dart';
import '../../core/theme/app_theme.dart';
import 'inventory_item_form_dialog.dart';
import 'stock_movement_form_dialog.dart';

class InventoryItemDetailScreen extends StatefulWidget {
  final InventoryItem item;
  final LocalStorageService storage;

  const InventoryItemDetailScreen({
    super.key,
    required this.item,
    required this.storage,
  });

  @override
  State<InventoryItemDetailScreen> createState() =>
      _InventoryItemDetailScreenState();
}

class _InventoryItemDetailScreenState extends State<InventoryItemDetailScreen> {
  late InventoryItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  void _abrirDialogoMovimiento(String type) {
    showDialog(
      context: context,
      builder: (_) => StockMovementFormDialog(
        storage: widget.storage,
        items: [_item],
        preselectedItemId: _item.id,
        preselectedMovementType: type,
        obras: widget.storage.obras,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 20),
            tooltip: 'Editar Insumo',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => InventoryItemFormDialog(
                  itemExistente: _item,
                  onGuardar: (actualizado) async {
                    await widget.storage.inventoryRepository.updateItem(
                      actualizado,
                    );
                    if (mounted) {
                      setState(() => _item = actualizado);
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<double>(
        stream: widget.storage.inventoryRepository.watchItemStock(_item.id),
        builder: (context, stockSnapshot) {
          final currentStock = stockSnapshot.data ?? 0.0;
          final isLowStock = currentStock <= _item.minStockAlert;
          final isOutOfStock = currentStock <= 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta de Stock Principal
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E293B),
                        isOutOfStock
                            ? AppTheme.coralUrgent.withValues(alpha: 0.15)
                            : (isLowStock
                                  ? AppTheme.amberSafety.withValues(alpha: 0.15)
                                  : AppTheme.emeraldSuccess.withValues(
                                      alpha: 0.15,
                                    )),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOutOfStock
                          ? AppTheme.coralUrgent.withValues(alpha: 0.4)
                          : (isLowStock
                                ? AppTheme.amberSafety.withValues(alpha: 0.4)
                                : AppTheme.emeraldSuccess.withValues(
                                    alpha: 0.4,
                                  )),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _item.categoryLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isOutOfStock
                                      ? AppTheme.coralUrgent
                                      : (isLowStock
                                            ? AppTheme.amberSafety
                                            : AppTheme.emeraldSuccess),
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _item.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_item.sku != null)
                                Text(
                                  'SKU: ${_item.sku}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? AppTheme.coralUrgent.withValues(alpha: 0.2)
                                  : (isLowStock
                                        ? AppTheme.amberSafety.withValues(
                                            alpha: 0.2,
                                          )
                                        : AppTheme.emeraldSuccess.withValues(
                                            alpha: 0.2,
                                          )),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isOutOfStock
                                  ? 'AGOTADO'
                                  : (isLowStock ? 'BAJO STOCK' : 'EN STOCK'),
                              style: TextStyle(
                                color: isOutOfStock
                                    ? AppTheme.coralUrgent
                                    : (isLowStock
                                          ? AppTheme.amberSafety
                                          : AppTheme.emeraldSuccess),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'STOCK DISPONIBLE',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${currentStock.toStringAsFixed(1)} ${_item.unitLabel}',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: isOutOfStock
                                      ? AppTheme.coralUrgent
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: const Color(0xFF334155),
                          ),
                          Column(
                            children: [
                              const Text(
                                'ALERTA MÍNIMA',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_item.minStockAlert.toStringAsFixed(1)} ${_item.unitLabel}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: const Color(0xFF334155),
                          ),
                          Column(
                            children: [
                              const Text(
                                'COSTO REF.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(_item.defaultCostSoles),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Botones Rápidos de Operación
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emeraldSuccess,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _abrirDialogoMovimiento('purchase'),
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: const Text(
                          'Entrada / Compra',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.amberSafety,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _abrirDialogoMovimiento('consumption'),
                        icon: const Icon(LucideIcons.minus, size: 18),
                        label: const Text(
                          'Consumo / Salida',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Ajuste de Stock',
                      onPressed: () => _abrirDialogoMovimiento('adjustment'),
                      icon: const Icon(
                        LucideIcons.sliders_horizontal,
                        size: 18,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Historial / Kardex / Ledger
                const Row(
                  children: [
                    Icon(LucideIcons.clock, color: Colors.grey, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'KARDEX Y MOVIMIENTOS HISTÓRICOS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                StreamBuilder<List<StockMovement>>(
                  stream: widget.storage.inventoryRepository.watchItemMovements(
                    _item.id,
                  ),
                  builder: (context, movementsSnapshot) {
                    final movements = movementsSnapshot.data ?? [];

                    if (movements.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Center(
                          child: Text(
                            'No hay movimientos registrados para este insumo.\nUse los botones de arriba para registrar compras o consumos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: movements.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final m = movements[index];
                        final isNegative = m.quantity < 0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isNegative
                                      ? AppTheme.amberSafety.withValues(
                                          alpha: 0.15,
                                        )
                                      : AppTheme.emeraldSuccess.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isNegative
                                      ? LucideIcons.arrow_down_right
                                      : LucideIcons.arrow_up_right,
                                  color: isNegative
                                      ? AppTheme.amberSafety
                                      : AppTheme.emeraldSuccess,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          m.typeLabel,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${isNegative ? "" : "+"}${m.quantity.toStringAsFixed(1)} ${_item.unitLabel}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isNegative
                                                ? AppTheme.amberSafety
                                                : AppTheme.emeraldSuccess,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          dateFormat.format(m.date),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (m.totalCostCents > 0)
                                          Text(
                                            'Costo: ${currency.format(m.totalCostSoles)} (${currency.format(m.unitCostSoles)}/${_item.unitLabel})',
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (m.projectId != null ||
                                        m.visitId != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: m.projectId != null
                                              ? AppTheme.skyAccent.withValues(
                                                  alpha: 0.15,
                                                )
                                              : AppTheme.emeraldSuccess
                                                    .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          m.projectId != null
                                              ? 'Obra asignada'
                                              : 'Visita de Mantenimiento',
                                          style: TextStyle(
                                            color: m.projectId != null
                                                ? AppTheme.skyAccent
                                                : AppTheme.emeraldSuccess,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (m.notes != null &&
                                        m.notes!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        m.notes!,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
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
}
