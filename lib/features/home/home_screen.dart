import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../finanzas/finanzas_hub_screen.dart';
import '../mantenimientos/mantenimientos_screen.dart';
import '../mas/mas_menu_screen.dart';
import '../obras/obras_screen.dart';

class HomeScreen extends StatefulWidget {
  final LocalStorageService storage;

  const HomeScreen({super.key, required this.storage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.storage,
      builder: (context, _) {
        final screens = [
          DashboardScreen(
            storage: widget.storage,
            onNavigateTab: (index) => setState(() => _currentIndex = index),
          ),
          ObrasScreen(storage: widget.storage),
          MantenimientosScreen(storage: widget.storage),
          FinanzasHubScreen(storage: widget.storage),
          MasMenuScreen(storage: widget.storage),
        ];

        final isCompact = AppResponsive.isCompact(context);

        if (!isCompact) {
          // Responsive layout for Tablet / Desktop / Web
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  backgroundColor: AppTheme.slateDark,
                  indicatorColor: AppTheme.amberSafety.withValues(alpha: 0.2),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.amberSafety.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.hammer,
                            color: AppTheme.amberSafety,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'DECOLUMAX',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(LucideIcons.layout_dashboard),
                      selectedIcon: Icon(
                        LucideIcons.layout_dashboard,
                        color: AppTheme.amberSafety,
                      ),
                      label: Text('Inicio'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(LucideIcons.hard_hat),
                      selectedIcon: Icon(
                        LucideIcons.hard_hat,
                        color: AppTheme.skyAccent,
                      ),
                      label: Text('Obras'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(LucideIcons.calendar_clock),
                      selectedIcon: Icon(
                        LucideIcons.calendar_clock,
                        color: AppTheme.amberSafety,
                      ),
                      label: Text('Mantenimiento'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(LucideIcons.coins),
                      selectedIcon: Icon(
                        LucideIcons.coins,
                        color: AppTheme.emeraldSuccess,
                      ),
                      label: Text('Finanzas'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(LucideIcons.menu),
                      selectedIcon: Icon(
                        LucideIcons.menu,
                        color: AppTheme.amberSafety,
                      ),
                      label: Text('Más'),
                    ),
                  ],
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFF1E293B),
                ),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: screens),
                ),
              ],
            ),
          );
        }

        // Mobile layout with NavigationBar
        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              backgroundColor: AppTheme.slateDark,
              indicatorColor: AppTheme.amberSafety.withValues(alpha: 0.2),
              surfaceTintColor: Colors.transparent,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(LucideIcons.layout_dashboard, color: Colors.grey),
                  selectedIcon: Icon(
                    LucideIcons.layout_dashboard,
                    color: AppTheme.amberSafety,
                  ),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.hard_hat, color: Colors.grey),
                  selectedIcon: Icon(
                    LucideIcons.hard_hat,
                    color: AppTheme.skyAccent,
                  ),
                  label: 'Obras',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.calendar_clock, color: Colors.grey),
                  selectedIcon: Icon(
                    LucideIcons.calendar_clock,
                    color: AppTheme.amberSafety,
                  ),
                  label: 'Mantenimiento',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.coins, color: Colors.grey),
                  selectedIcon: Icon(
                    LucideIcons.coins,
                    color: AppTheme.emeraldSuccess,
                  ),
                  label: 'Finanzas',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.menu, color: Colors.grey),
                  selectedIcon: Icon(
                    LucideIcons.menu,
                    color: AppTheme.amberSafety,
                  ),
                  label: 'Más',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
