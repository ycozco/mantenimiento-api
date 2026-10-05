import 'package:flutter/material.dart';
import '../../core/database/local_storage_service.dart';
import '../../core/models/supplier.dart';
import 'supplier_form_dialog.dart';
import 'supplier_detail_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final storage = LocalStorageService();
    final repo = storage.purchaseRepository;

    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar por nombre, RUC o contacto...',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Supplier>>(
              stream: repo.watchActiveSuppliers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data ?? [];
                final filtered = all.where((s) {
                  if (_searchQuery.isEmpty) return true;
                  return s.name.toLowerCase().contains(_searchQuery) ||
                      (s.taxId != null &&
                          s.taxId!.toLowerCase().contains(_searchQuery)) ||
                      (s.contactName != null &&
                          s.contactName!.toLowerCase().contains(_searchQuery));
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No hay proveedores registrados'
                              : 'No se encontraron proveedores',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sup = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          sup.name.isNotEmpty ? sup.name[0].toUpperCase() : 'P',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        sup.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        [
                          if (sup.taxId != null && sup.taxId!.isNotEmpty)
                            'RUC: ${sup.taxId}',
                          if (sup.contactName != null &&
                              sup.contactName!.isNotEmpty)
                            'Contacto: ${sup.contactName}',
                          if (sup.phone != null && sup.phone!.isNotEmpty)
                            'Telf: ${sup.phone}',
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SupplierDetailScreen(supplierId: sup.id),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newSupplier = await showDialog<Supplier>(
            context: context,
            builder: (_) => const SupplierFormDialog(),
          );
          if (newSupplier != null) {
            await repo.createSupplier(newSupplier);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Proveedor'),
      ),
    );
  }
}
