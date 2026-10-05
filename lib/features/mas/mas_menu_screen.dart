import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_theme.dart';
import '../ajustes/ajustes_screen.dart';
import '../calendar/calendar_screen.dart';
import '../inventory/inventory_screen.dart';
import '../socios_clientes/socios_clientes_screen.dart';
import '../suppliers/suppliers_screen.dart';
import '../tools/tools_screen.dart';

class MasMenuScreen extends StatelessWidget {
  final LocalStorageService storage;

  const MasMenuScreen({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(LucideIcons.menu, color: AppTheme.amberSafety, size: 24),
            SizedBox(width: 10),
            Text('Más Módulos'),
          ],
        ),
      ),
      body: ConstrainedContent(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            _buildSectionHeader(
              context,
              title: 'OPERACIONES Y RECURSOS',
              icon: LucideIcons.hammer,
            ),
            const SizedBox(height: 12),
            _buildResponsiveGrid(context, [
              _MenuOption(
                title: 'Inventario (Kardex)',
                subtitle: 'Control de insumos, stock y movimientos',
                icon: LucideIcons.package,
                iconColor: AppTheme.amberSafety,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InventoryScreen(storage: storage),
                  ),
                ),
              ),
              _MenuOption(
                title: 'Herramientas',
                subtitle: 'Custodia, asignación a cuadrilla y taller',
                icon: LucideIcons.wrench,
                iconColor: AppTheme.amberSafety,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ToolsScreen(storage: storage),
                  ),
                ),
              ),
              _MenuOption(
                title: 'Trabajadores (Personal)',
                subtitle: 'Cuadrilla, jornales y registro laboral',
                icon: LucideIcons.hard_hat,
                iconColor: AppTheme.skyAccent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SociosClientesScreen(storage: storage, initialTab: 1),
                  ),
                ),
              ),
              _MenuOption(
                title: 'Calendario Operacional',
                subtitle: 'Programación mensual y semanal de visitas',
                icon: LucideIcons.calendar,
                iconColor: AppTheme.emeraldSuccess,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalendarScreen(storage: storage),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 28),
            _buildSectionHeader(
              context,
              title: 'DIRECTORIO Y CONTACTOS',
              icon: LucideIcons.book_user,
            ),
            const SizedBox(height: 12),
            _buildResponsiveGrid(context, [
              _MenuOption(
                title: 'Clientes',
                subtitle: 'Cartera de clientes y contactos',
                icon: LucideIcons.building,
                iconColor: AppTheme.skyAccent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SociosClientesScreen(storage: storage, initialTab: 2),
                  ),
                ),
              ),
              _MenuOption(
                title: 'Proveedores',
                subtitle: 'Catálogo de proveedores y órdenes de compra',
                icon: LucideIcons.truck,
                iconColor: AppTheme.amberSafety,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SuppliersScreen()),
                ),
              ),
              _MenuOption(
                title: 'Socios',
                subtitle: 'Padrón de socios y participaciones',
                icon: LucideIcons.users,
                iconColor: AppTheme.emeraldSuccess,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SociosClientesScreen(storage: storage, initialTab: 0),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 28),
            _buildSectionHeader(
              context,
              title: 'SISTEMA Y CONFIGURACIÓN',
              icon: LucideIcons.settings_2,
            ),
            const SizedBox(height: 12),
            _buildResponsiveGrid(context, [
              _MenuOption(
                title: 'Ajustes del Sistema',
                subtitle: 'Empresa, backup, notificaciones y preferencias',
                icon: LucideIcons.settings,
                iconColor: Colors.white70,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AjustesScreen(storage: storage),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.amberSafety),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveGrid(BuildContext context, List<_MenuOption> items) {
    final isCompact = AppResponsive.isCompact(context);
    if (isCompact) {
      return Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildItemCard(item),
              ),
            )
            .toList(),
      );
    }

    final crossAxisCount = AppResponsive.value<int>(
      context,
      compact: 1,
      medium: 2,
      expanded: 3,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) =>
                    SizedBox(width: itemWidth, child: _buildItemCard(item)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildItemCard(_MenuOption item) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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
  }
}

class _MenuOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  _MenuOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
}
