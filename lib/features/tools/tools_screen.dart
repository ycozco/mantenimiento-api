import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/tool.dart';
import '../../core/theme/app_theme.dart';
import 'tool_detail_screen.dart';
import 'tool_form_dialog.dart';

class ToolsScreen extends StatefulWidget {
  final LocalStorageService storage;

  const ToolsScreen({super.key, required this.storage});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String _busqueda = '';
  String _statusFiltro = 'all';

  final List<Map<String, String>> _filtrosStatus = [
    {'value': 'all', 'label': 'Todas'},
    {'value': 'available', 'label': 'Disponibles'},
    {'value': 'assigned', 'label': 'Asignadas / En Uso'},
    {'value': 'maintenance', 'label': 'En Taller'},
    {'value': 'retired', 'label': 'Retiradas'},
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return AppTheme.emeraldSuccess;
      case 'assigned':
        return AppTheme.skyAccent;
      case 'maintenance':
        return AppTheme.amberSafety;
      case 'retired':
        return AppTheme.coralUrgent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.wrench, color: AppTheme.skyAccent, size: 24),
            SizedBox(width: 10),
            Text('Herramientas y Activos'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.skyAccent,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text(
          'Nueva Herramienta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => ToolFormDialog(
              onGuardar: (tool) =>
                  widget.storage.toolRepository.createTool(tool),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // Barra de Búsqueda y Filtros de Estado
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppTheme.slateDark,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, código o serie...',
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
                    children: _filtrosStatus.map((f) {
                      final isSelected = _statusFiltro == f['value'];
                      final filterColor = _getStatusColor(f['value']!);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(f['label']!),
                          selectedColor: filterColor.withValues(alpha: 0.2),
                          checkmarkColor: filterColor,
                          labelStyle: TextStyle(
                            color: isSelected ? filterColor : Colors.grey,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          backgroundColor: const Color(0xFF1E293B),
                          side: BorderSide(
                            color: isSelected
                                ? filterColor
                                : const Color(0xFF334155),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _statusFiltro = f['value']!);
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

          // Lista de Herramientas
          Expanded(
            child: StreamBuilder<List<Tool>>(
              stream: widget.storage.toolRepository.watchAllTools(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var tools = snapshot.data ?? [];

                // Filtro por Estado
                if (_statusFiltro != 'all') {
                  tools = tools
                      .where((t) => t.currentStatus == _statusFiltro)
                      .toList();
                }

                // Filtro por Texto de Búsqueda
                if (_busqueda.isNotEmpty) {
                  tools = tools
                      .where(
                        (t) =>
                            t.name.toLowerCase().contains(_busqueda) ||
                            (t.code != null &&
                                t.code!.toLowerCase().contains(_busqueda)) ||
                            (t.brandModel != null &&
                                t.brandModel!.toLowerCase().contains(
                                  _busqueda,
                                )) ||
                            (t.serialNumber != null &&
                                t.serialNumber!.toLowerCase().contains(
                                  _busqueda,
                                )),
                      )
                      .toList();
                }

                if (tools.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.wrench,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay herramientas en esta categoría',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.skyAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ToolFormDialog(
                                onGuardar: (t) =>
                                    widget.storage.toolRepository.createTool(t),
                              ),
                            );
                          },
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: const Text('Registrar Primera Herramienta'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: tools.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tool = tools[index];
                    final statusColor = _getStatusColor(tool.currentStatus);

                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ToolDetailScreen(
                                tool: tool,
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
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  LucideIcons.wrench,
                                  color: statusColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            tool.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: statusColor.withValues(
                                                alpha: 0.4,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            tool.statusLabel.toUpperCase(),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${tool.categoryLabel} ${tool.code != null ? "• Código: ${tool.code}" : ""} ${tool.brandModel != null ? "• ${tool.brandModel}" : ""}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (tool.isAssigned)
                                      FutureBuilder(
                                        future: widget.storage.toolRepository
                                            .getActiveAssignment(tool.id),
                                        builder: (ctx, assignSnap) {
                                          final a = assignSnap.data;
                                          if (a == null) {
                                            return const SizedBox.shrink();
                                          }
                                          if (a.workerId != null) {
                                            return FutureBuilder(
                                              future: widget
                                                  .storage
                                                  .workerRepository
                                                  .getWorkerById(a.workerId!),
                                              builder: (c, wSnap) => Text(
                                                'Custodio: ${wSnap.data?.name ?? "Trabajador"}',
                                                style: const TextStyle(
                                                  color: AppTheme.skyAccent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          }
                                          return const Text(
                                            'Custodia en Obra / Visita',
                                            style: TextStyle(
                                              color: AppTheme.skyAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      Text(
                                        'Estado físico: ${tool.conditionLabel}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8),
                                        ),
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
            ),
          ),
        ],
      ),
    );
  }
}
