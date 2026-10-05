import 'package:flutter/material.dart';
import '../../core/models/supplier.dart';

class SupplierFormDialog extends StatefulWidget {
  final Supplier? supplier;

  const SupplierFormDialog({super.key, this.supplier});

  @override
  State<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _contactController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _taxIdController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _contactController = TextEditingController(
      text: widget.supplier?.contactName ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.supplier?.phone ?? '',
    );
    _emailController = TextEditingController(
      text: widget.supplier?.email ?? '',
    );
    _taxIdController = TextEditingController(
      text: widget.supplier?.taxId ?? '',
    );
    _addressController = TextEditingController(
      text: widget.supplier?.address ?? '',
    );
    _notesController = TextEditingController(
      text: widget.supplier?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxIdController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (widget.supplier == null) {
      final newSupplier = Supplier.create(
        name: _nameController.text.trim(),
        contactName: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        taxId: _taxIdController.text.trim().isEmpty
            ? null
            : _taxIdController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      Navigator.pop(context, newSupplier);
    } else {
      final updated = widget.supplier!.copyWith(
        name: _nameController.text.trim(),
        contactName: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        taxId: _taxIdController.text.trim().isEmpty
            ? null
            : _taxIdController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      Navigator.pop(context, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.supplier != null;
    return AlertDialog(
      title: Text(isEditing ? 'Editar Proveedor' : 'Nuevo Proveedor'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Razón Social o Nombre *',
                  hintText: 'Ej. Vivero La Floresta / Juan Pérez',
                  prefixIcon: Icon(Icons.storefront),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingrese el nombre del proveedor'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contacto (Opcional)',
                  hintText: 'Nombre de la persona de contacto',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _taxIdController,
                      decoration: const InputDecoration(
                        labelText: 'RUC / DNI (Opcional)',
                        hintText: '20123456789',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        hintText: '958123456',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  hintText: 'ventas@proveedor.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección / Ubicación',
                  hintText: 'Av. Las Gardenias 102, Tiabaya',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas adicionales',
                  hintText: 'Crédito a 15 días, despachos los martes...',
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Guardar Cambios' : 'Registrar'),
        ),
      ],
    );
  }
}
