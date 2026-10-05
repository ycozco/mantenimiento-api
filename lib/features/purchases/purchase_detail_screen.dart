import 'package:flutter/material.dart';
import '../../core/database/local_storage_service.dart';
import '../../core/models/purchase.dart';
import '../../core/models/purchase_item.dart';

class PurchaseDetailScreen extends StatelessWidget {
  final String purchaseId;

  const PurchaseDetailScreen({super.key, required this.purchaseId});

  @override
  Widget build(BuildContext context) {
    final storage = LocalStorageService();
    final repo = storage.purchaseRepository;

    return FutureBuilder<Purchase?>(
      future: repo.getPurchase(purchaseId),
      builder: (context, snapshot) {
        final purchase = snapshot.data;
        if (purchase == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle de Compra')),
            body: const Center(child: Text('Compra no encontrada')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Compra ${purchase.invoiceNumber ?? purchase.documentType}',
            ),
            actions: [
              if (!purchase.isDeleted)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  tooltip: 'Anular Compra',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Anular Compra'),
                        content: const Text(
                          '¿Está seguro de anular esta compra? Se revertirán los movimientos de stock en el Kardex si el inventario aún está disponible.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Anular'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      try {
                        await repo.cancelPurchase(
                          purchase.id,
                          reason: 'Anulación manual',
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Compra anulada y stock revertido.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    }
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: purchase.isDeleted
                    ? Colors.red.shade50
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Información del Comprobante',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (purchase.isDeleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ANULADA',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Proveedor: ${purchase.supplierName ?? "Compra Directa"}',
                      ),
                      Text(
                        'Pagado por: ${purchase.partnerName ?? "Caja de Empresa"}',
                      ),
                      Text(
                        'Fecha: ${purchase.date.day}/${purchase.date.month}/${purchase.date.year}',
                      ),
                      Text('Tipo: ${purchase.documentType.toUpperCase()}'),
                      if (purchase.invoiceNumber != null)
                        Text('Número: ${purchase.invoiceNumber}'),
                      if (purchase.notes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Notas: ${purchase.notes}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Líneas de Detalle',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<PurchaseItem>>(
                stream: repo.watchPurchaseItems(purchase.id),
                builder: (context, itemSnap) {
                  final items = itemSnap.data ?? [];
                  if (items.isEmpty) {
                    return const Text('Sin líneas registradas');
                  }
                  return Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final it = items[i];
                        return ListTile(
                          title: Text(it.itemName ?? it.itemId),
                          subtitle: Text(
                            '${it.quantity} ${it.itemUnit ?? "unid"} × S/ ${it.unitCost.toStringAsFixed(2)}',
                          ),
                          trailing: Text(
                            'S/ ${it.totalCost.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'TOTAL: S/ ${purchase.totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
