import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:intl/intl.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/models/calendar_event.dart';
import '../../core/theme/app_theme.dart';
import '../mantenimientos/maintenance_visit_detail_screen.dart';
import '../obras/obra_detail_screen.dart';
import '../tools/tool_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  final LocalStorageService storage;

  const CalendarScreen({super.key, required this.storage});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarSourceType? _selectedFilter;
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM, yyyy', 'es');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda y Calendario Operativo'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.calendar_search),
            tooltip: 'Filtrar por fecha específica',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: const Icon(LucideIcons.x),
              tooltip: 'Limpiar filtro de fecha',
              onPressed: () => setState(() => _selectedDate = null),
            ),
        ],
      ),
      body: Column(
        children: [
          // FILTROS POR TIPO DE ORIGEN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todos', null),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Mantenimientos',
                    CalendarSourceType.maintenanceVisit,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('Obras', CalendarSourceType.project),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Herramientas',
                    CalendarSourceType.toolReturn,
                  ),
                ],
              ),
            ),
          ),

          if (_selectedDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.amberSafety.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtrado por: ${dateFormat.format(_selectedDate!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.amberSafety,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _selectedDate = null),
                    child: const Text(
                      'Ver todos',
                      style: TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // LISTA DE EVENTOS
          Expanded(
            child: StreamBuilder<List<CalendarEvent>>(
              stream: widget.storage.calendarService.watchEvents(
                filterType: _selectedFilter,
                fromDate: _selectedDate != null
                    ? DateTime(
                        _selectedDate!.year,
                        _selectedDate!.month,
                        _selectedDate!.day,
                      )
                    : null,
                toDate: _selectedDate != null
                    ? DateTime(
                        _selectedDate!.year,
                        _selectedDate!.month,
                        _selectedDate!.day,
                        23,
                        59,
                        59,
                      )
                    : null,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final events = snapshot.data ?? [];
                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.calendar_x,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedDate != null
                              ? 'No hay eventos operacionales para este día'
                              : 'No hay eventos operacionales registrados',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _buildEventCard(
                      context,
                      event,
                      dateFormat,
                      timeFormat,
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

  Widget _buildFilterChip(String label, CalendarSourceType? type) {
    final isSelected = _selectedFilter == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.skyAccent.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.skyAccent : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _selectedFilter = type),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    CalendarEvent event,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    final Color badgeColor;
    final IconData icon;

    switch (event.sourceType) {
      case CalendarSourceType.maintenanceVisit:
        badgeColor = event.status == 'overdue'
            ? AppTheme.coralUrgent
            : AppTheme.emeraldSuccess;
        icon = LucideIcons.calendar_check;
        break;
      case CalendarSourceType.project:
        badgeColor = AppTheme.skyAccent;
        icon = LucideIcons.hard_hat;
        break;
      case CalendarSourceType.toolReturn:
        badgeColor = event.status == 'overdue'
            ? AppTheme.coralUrgent
            : AppTheme.amberSafety;
        icon = LucideIcons.wrench;
        break;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleEventTap(context, event),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: badgeColor.withValues(alpha: 0.15),
                    child: Icon(icon, color: badgeColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      event.sourceTypeLabel.toUpperCase(),
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: event.status == 'overdue'
                          ? AppTheme.coralUrgent.withValues(alpha: 0.2)
                          : const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: event.status == 'overdue'
                            ? AppTheme.coralUrgent
                            : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (event.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  event.subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(LucideIcons.clock, size: 13, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${dateFormat.format(event.startDate)} • ${timeFormat.format(event.startDate)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleEventTap(
    BuildContext context,
    CalendarEvent event,
  ) async {
    switch (event.sourceType) {
      case CalendarSourceType.project:
        final matches = widget.storage.obras.where(
          (o) => o.id == event.sourceId,
        );
        if (matches.isNotEmpty && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ObraDetailScreen(
                obra: matches.first,
                storage: widget.storage,
              ),
            ),
          );
        }
        break;
      case CalendarSourceType.toolReturn:
        final tool = await widget.storage.toolRepository.getTool(
          event.sourceId,
        );
        if (tool != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ToolDetailScreen(tool: tool, storage: widget.storage),
            ),
          );
        }
        break;
      case CalendarSourceType.maintenanceVisit:
        final visit = await widget.storage.maintenanceRepository.getVisitById(
          event.sourceId,
        );
        if (visit != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MaintenanceVisitDetailScreen(
                visitId: visit.id,
                planId: visit.planId,
                storage: widget.storage,
              ),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${event.title} - ${event.subtitle ?? ""}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        break;
    }
  }
}
