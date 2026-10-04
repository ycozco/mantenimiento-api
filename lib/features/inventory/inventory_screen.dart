import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/inventory_item.dart';
import '../../core/theme/app_theme.dart';
import 'inventory_item_detail_screen.dart';
import 'inventory_item_form_dialog.dart';

class InventoryScreen extends StatefulWidget {
  final LocalStorageService storage;

  const InventoryScreen({super.key, required this.storage});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _busqueda = '';
  String _categoriaSeleccionada = 'all';

  final List<Map<String, String>> _filtrosCategoria = [
    {'value': 'all', 'label': 'Todos'},
    {'value': 'plants', 'label': 'Plantas'},
    {'value': 'materials', 'label': 'Materiales'},
    {'value': 'supplies', 'label': 'Insumos'},
    {'value': 'pipes', 'label': 'Riego'},
  ];

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.package, color: AppTheme.emeraldSuccess, size: 24),
            SizedBox(width: 10),
            Text('Inventario y Materiales'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.emeraldSuccess,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text(
          'Nuevo Insumo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => InventoryItemFormDialog(
              onGuardar: (item) =>
                  widget.storage.inventoryRepository.createItem(item),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // Barra de Búsqueda y Filtro de Categoría
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppTheme.slateDark,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código SKU...',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => _busqueda = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filtrosCategoria.map((f) {
                      final isSelected = _categoriaSeleccionada == f['value'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(f['label']!),
                          selectedColor: AppTheme.emeraldSuccess.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppTheme.emeraldSuccess,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.emeraldSuccess
                                : Colors.grey,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          backgroundColor: const Color(0xFF1E293B),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.emeraldSuccess
                                : const Color(0xFF334155),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(
                                () => _categoriaSeleccionada = f['value']!,
                              );
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Lista Reactiva de Insumos
          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: widget.storage.inventoryRepository.watchActiveItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var items = snapshot.data ?? [];

                // Filtrar por categoría
                if (_categoriaSeleccionada != 'all') {
                  items = items
                      .where((i) => i.category == _categoriaSeleccionada)
                      .toList();
                }

                // Filtrar por texto de búsqueda
                if (_busqueda.isNotEmpty) {
                  items = items
                      .where(
                        (i) =>
                            i.name.toLowerCase().contains(_busqueda) ||
                            (i.sku != null &&
                                i.sku!.toLowerCase().contains(_busqueda)),
                      )
                      .toList();
                }

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.package_open,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay insumos ni materiales registrados',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emeraldSuccess,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => InventoryItemFormDialog(
                                onGuardar: (item) => widget
                                    .storage
                                    .inventoryRepository
                                    .createItem(item),
                              ),
                            );
                          },
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Registrar Primer Insumo'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return StreamBuilder<double>(
                      stream: widget.storage.inventoryRepository.watchItemStock(
                        item.id,
                      ),
                      builder: (context, stockSnapshot) {
                        final stock = stockSnapshot.data ?? 0.0;
                        final isLowStock = stock <= item.minStockAlert;
                        final isOutOfStock = stock <= 0;

                        return Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InventoryItemDetailScreen(
                                    item: item,
                                    storage: widget.storage,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock
                                          ? AppTheme.coralUrgent.withValues(
                                              alpha: 0.15,
                                            )
                                          : (isLowStock
                                                ? AppTheme.amberSafety
                                                      .withValues(alpha: 0.15)
                                                : AppTheme.emeraldSuccess
                                                      .withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isOutOfStock
                                          ? LucideIcons.package_x
                                          : (isLowStock
                                                ? LucideIcons.package_search
                                                : LucideIcons.package_check),
                                      color: isOutOfStock
                                          ? AppTheme.coralUrgent
                                          : (isLowStock
                                                ? AppTheme.amberSafety
                                                : AppTheme.emeraldSuccess),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Colors.white,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isOutOfStock || isLowStock)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isOutOfStock
                                                      ? AppTheme.coralUrgent
                                                            .withValues(
                                                              alpha: 0.2,
                                                            )
                                                      : AppTheme.amberSafety
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isOutOfStock
                                                      ? 'AGOTADO'
                                                      : 'BAJO STOCK',
                                                  style: TextStyle(
                                                    color: isOutOfStock
                                                        ? AppTheme.coralUrgent
                                                        : AppTheme.amberSafety,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.categoryLabel} ${item.sku != null ? "• SKU: ${item.sku}" : ""}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Stock: ${stock.toStringAsFixed(1)} ${item.unitLabel}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isOutOfStock
                                                    ? AppTheme.coralUrgent
                                                    : (isLowStock
                                                          ? AppTheme.amberSafety
                                                          : Colors.white),
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (item.defaultCostCents > 0)
                                              Text(
                                                'Ref: ${currency.format(item.defaultCostSoles)}',
                                                style: const TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    LucideIcons.chevron_right,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
