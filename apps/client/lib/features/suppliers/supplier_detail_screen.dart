import 'package:flutter/material.dart';
import '../../core/database/local_storage_service.dart';
import '../../core/models/supplier.dart';
import 'supplier_form_dialog.dart';

class SupplierDetailScreen extends StatefulWidget {
  final String supplierId;

  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final storage = LocalStorageService();
    final repo = storage.purchaseRepository;

    return FutureBuilder<Supplier?>(
      future: repo.getSupplier(widget.supplierId),
      builder: (context, snapshot) {
        final supplier = snapshot.data;
        if (supplier == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Proveedor')),
            body: const Center(child: Text('Proveedor no encontrado')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(supplier.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final updated = await showDialog<Supplier>(
                    context: context,
                    builder: (ctx) => SupplierFormDialog(supplier: supplier),
                  );
                  if (updated != null) {
                    await repo.updateSupplier(updated);
                    setState(() {});
                  }
                },
              ),

              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Eliminar Proveedor'),
                      content: Text(
                        '¿Está seguro de dar de baja a "${supplier.name}"? Los comprobantes previos se mantendrán.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await repo.deleteSupplier(supplier.id);
                    if (context.mounted) {
                      Navigator.pop(context);
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.storefront,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (supplier.taxId != null)
                                  Text(
                                    'RUC/DNI: ${supplier.taxId}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      if (supplier.contactName != null) ...[
                        _buildInfoRow(
                          Icons.person_outline,
                          'Contacto',
                          supplier.contactName!,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (supplier.phone != null) ...[
                        _buildInfoRow(
                          Icons.phone_outlined,
                          'Teléfono',
                          supplier.phone!,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (supplier.email != null) ...[
                        _buildInfoRow(
                          Icons.email_outlined,
                          'Correo',
                          supplier.email!,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (supplier.address != null) ...[
                        _buildInfoRow(
                          Icons.location_on_outlined,
                          'Dirección',
                          supplier.address!,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (supplier.notes != null) ...[
                        _buildInfoRow(
                          Icons.notes_outlined,
                          'Notas',
                          supplier.notes!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
      ],
    );
  }
}
