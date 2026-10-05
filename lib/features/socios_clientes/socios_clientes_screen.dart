import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/socio.dart';
import '../../core/models/cliente.dart';
import '../../core/models/worker.dart';
import '../../core/theme/app_theme.dart';
import '../workers/worker_form_dialog.dart';
import '../workers/worker_detail_screen.dart';
import 'partner_detail_screen.dart';

class SociosClientesScreen extends StatefulWidget {
  final LocalStorageService storage;

  const SociosClientesScreen({super.key, required this.storage});

  @override
  State<SociosClientesScreen> createState() => _SociosClientesScreenState();
}

class _SociosClientesScreenState extends State<SociosClientesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _busquedaWorker = '';
  bool _mostrarInactivos = false;

  final List<int> _coloresDisponibles = [
    0xFFF59E0B, // Amber
    0xFF10B981, // Emerald
    0xFF0EA5E9, // Sky Blue
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFFF97316, // Orange
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
            Icon(LucideIcons.users, color: AppTheme.amberSafety, size: 24),
            SizedBox(width: 10),
            Text('Socios, Personal y Clientes'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.amberSafety,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(LucideIcons.user_check, size: 18), text: 'Socios'),
            Tab(
              icon: Icon(LucideIcons.hard_hat, size: 18),
              text: 'Personal (Cuadrilla)',
            ),
            Tab(icon: Icon(LucideIcons.building, size: 18), text: 'Clientes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSociosTab(), _buildWorkersTab(), _buildClientesTab()],
      ),
    );
  }

  // --- TAB SOCIOS ---
  Widget _buildSociosTab() {
    final socios = widget.storage.socios;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.amberSafety,
        foregroundColor: const Color(0xFF0F172A),
        icon: const Icon(LucideIcons.user_plus, size: 20),
        label: const Text(
          'Agregar Socio',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _mostrarDialogoSocio(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.amberSafety.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.amberSafety.withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.info, color: AppTheme.amberSafety, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Registra aquí a los 2 o más socios de trabajo. Todos los gastos de inversión y mantenimientos se repartirán entre ellos.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...socios.map((s) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(s.colorValue),
                  child: Text(
                    s.nombre.isNotEmpty
                        ? s.nombre.substring(0, 1).toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                title: Text(
                  s.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: s.telefono != null && s.telefono!.isNotEmpty
                    ? Text(
                        'Tel: ${s.telefono}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      )
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PartnerDetailScreen(socio: s),
                    ),
                  );
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        LucideIcons.pencil,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onPressed: () => _mostrarDialogoSocio(socioExistente: s),
                    ),
                    if (socios.length > 2)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          LucideIcons.trash,
                          size: 18,
                          color: AppTheme.coralUrgent,
                        ),
                        onPressed: () => widget.storage.eliminarSocio(s.id),
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

  void _mostrarDialogoSocio({Socio? socioExistente}) {
    final nombreCtrl = TextEditingController(
      text: socioExistente?.nombre ?? '',
    );
    final telCtrl = TextEditingController(text: socioExistente?.telefono ?? '');
    int colorSeleccionado =
        socioExistente?.colorValue ??
        _coloresDisponibles[widget.storage.socios.length %
            _coloresDisponibles.length];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.slateSurface,
          title: Text(socioExistente == null ? 'Nuevo Socio' : 'Editar Socio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Socio',
                  hintText: 'Ej. Juan Pérez',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (Opcional)',
                  hintText: '555-1234',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Color distintivo para avatares:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _coloresDisponibles.map((color) {
                  final isSelected = colorSeleccionado == color;
                  return InkWell(
                    onTap: () =>
                        setDialogState(() => colorSeleccionado = color),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final nom = nombreCtrl.text.trim();
                if (nom.isNotEmpty) {
                  if (socioExistente == null) {
                    widget.storage.agregarSocio(
                      Socio(
                        id: const Uuid().v4(),
                        nombre: nom,
                        telefono: telCtrl.text.trim(),
                        colorValue: colorSeleccionado,
                      ),
                    );
                  } else {
                    widget.storage.editarSocio(
                      socioExistente.copyWith(
                        nombre: nom,
                        telefono: telCtrl.text.trim(),
                        colorValue: colorSeleccionado,
                      ),
                    );
                  }
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB TRABAJADORES (PERSONAL DE CAMPO) ---
  Widget _buildWorkersTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.amberSafety,
        foregroundColor: const Color(0xFF0F172A),
        icon: const Icon(LucideIcons.user_plus, size: 20),
        label: const Text(
          'Nuevo Trabajador',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => WorkerFormDialog(
              onGuardar: (worker) =>
                  widget.storage.workerRepository.createWorker(worker),
            ),
          );
        },
      ),
      body: StreamBuilder<List<Worker>>(
        stream: widget.storage.workerRepository.watchAllWorkers(),
        builder: (context, snapshot) {
          final allWorkers = snapshot.data ?? [];
          final workersFiltrados = allWorkers.where((w) {
            final matchFiltro = _mostrarInactivos || w.isActive;
            if (!matchFiltro) return false;
            if (_busquedaWorker.isEmpty) return true;
            final query = _busquedaWorker.toLowerCase();
            final nameMatch = w.name.toLowerCase().contains(query);
            final specialtyMatch =
                w.specialty != null &&
                w.specialty!.toLowerCase().contains(query);
            return nameMatch || specialtyMatch;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // Buscador y Filtro
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar trabajador por nombre o labor...',
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (val) =>
                          setState(() => _busquedaWorker = val.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text(
                      'Inactivos',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: _mostrarInactivos,
                    selectedColor: AppTheme.amberSafety.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.amberSafety,
                    onSelected: (val) =>
                        setState(() => _mostrarInactivos = val),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (workersFiltrados.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(
                        LucideIcons.hard_hat,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _busquedaWorker.isNotEmpty
                            ? 'No se encontraron trabajadores para "$_busquedaWorker"'
                            : 'No hay trabajadores registrados en la cuadrilla',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Registra peones, albañiles o técnicos para asignarles jornadas.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...workersFiltrados.map((w) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: w.isActive
                            ? AppTheme.amberSafety.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        child: Icon(
                          LucideIcons.hard_hat,
                          color: w.isActive
                              ? AppTheme.amberSafety
                              : Colors.grey,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              w.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: w.isActive ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                          if (!w.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Inactivo',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (w.specialty != null &&
                                  w.specialty!.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    w.specialty!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.amberSafety,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                w.defaultRateCents > 0
                                    ? 'S/ ${(w.defaultRateCents / 100).toStringAsFixed(0)} ${w.paymentTypeLabel}'
                                    : 'Sin tarifa fijada',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          if (w.phone != null && w.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Tel: ${w.phone!}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkerDetailScreen(
                              workerId: w.id,
                              storage: widget.storage,
                            ),
                          ),
                        );
                      },
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(
                          LucideIcons.ellipsis_vertical,
                          size: 18,
                        ),
                        onSelected: (val) {
                          if (val == 'edit') {
                            showDialog(
                              context: context,
                              builder: (_) => WorkerFormDialog(
                                workerExistente: w,
                                onGuardar: (act) => widget
                                    .storage
                                    .workerRepository
                                    .updateWorker(act),
                              ),
                            );
                          } else if (val == 'toggle_active') {
                            if (w.isActive) {
                              widget.storage.workerRepository.deactivateWorker(
                                w.id,
                              );
                            } else {
                              widget.storage.workerRepository.activateWorker(
                                w.id,
                              );
                            }
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          PopupMenuItem(
                            value: 'toggle_active',
                            child: Text(
                              w.isActive ? 'Desactivar' : 'Reactivar',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  // --- TAB CLIENTES ---
  Widget _buildClientesTab() {
    final clientes = widget.storage.clientes;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.skyAccent,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.user_plus, size: 20),
        label: const Text(
          'Nuevo Cliente',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _mostrarDialogoCliente(),
      ),
      body: clientes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.building,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay clientes registrados',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Agrega un cliente para programarle mantenimientos y obras.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: clientes.length,
              itemBuilder: (ctx, idx) {
                final c = clientes[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.slateCard,
                      child: Icon(
                        LucideIcons.building,
                        color: AppTheme.skyAccent,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      c.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.telefono != null && c.telefono!.isNotEmpty)
                          Text(
                            'Tel: ${c.telefono}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        if (c.direccion != null && c.direccion!.isNotEmpty)
                          Text(
                            'Dir: ${c.direccion}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            LucideIcons.pencil,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              _mostrarDialogoCliente(clienteExistente: c),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            LucideIcons.trash,
                            size: 18,
                            color: AppTheme.coralUrgent,
                          ),
                          onPressed: () => widget.storage.eliminarCliente(c.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _mostrarDialogoCliente({Cliente? clienteExistente}) {
    final nombreCtrl = TextEditingController(
      text: clienteExistente?.nombre ?? '',
    );
    final telCtrl = TextEditingController(
      text: clienteExistente?.telefono ?? '',
    );
    final dirCtrl = TextEditingController(
      text: clienteExistente?.direccion ?? '',
    );
    final notasCtrl = TextEditingController(
      text: clienteExistente?.notas ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.slateSurface,
        title: Text(
          clienteExistente == null ? 'Nuevo Cliente' : 'Editar Cliente',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre / Razón Social',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono de Contacto',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dirCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección / Ubicación',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notasCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.skyAccent,
            ),
            onPressed: () {
              final nom = nombreCtrl.text.trim();
              if (nom.isNotEmpty) {
                if (clienteExistente == null) {
                  widget.storage.agregarCliente(
                    Cliente(
                      id: const Uuid().v4(),
                      nombre: nom,
                      telefono: telCtrl.text.trim(),
                      direccion: dirCtrl.text.trim(),
                      notas: notasCtrl.text.trim(),
                    ),
                  );
                } else {
                  widget.storage.editarCliente(
                    clienteExistente.copyWith(
                      nombre: nom,
                      telefono: telCtrl.text.trim(),
                      direccion: dirCtrl.text.trim(),
                      notas: notasCtrl.text.trim(),
                    ),
                  );
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
