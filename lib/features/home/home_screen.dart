import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../mantenimientos/mantenimientos_screen.dart';
import '../obras/obras_screen.dart';
import '../gastos/gastos_screen.dart';
import '../socios_clientes/socios_clientes_screen.dart';
import '../ajustes/ajustes_screen.dart';

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
          MantenimientosScreen(storage: widget.storage),
          ObrasScreen(storage: widget.storage),
          GastosScreen(storage: widget.storage),
          SociosClientesScreen(storage: widget.storage),
          AjustesScreen(storage: widget.storage),
        ];

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
                  icon: Icon(LucideIcons.calendar_clock, color: Colors.grey),
                  selectedIcon: Icon(
                    LucideIcons.calendar_clock,
                    color: AppTheme.amberSafety,
                  ),
                  label: 'Servicios',
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
                  icon: Icon(LucideIcons.coins, color: Colors.grey),
                  selectedIcon: Icon(
                    LucideIcons.coins,
                    color: AppTheme.emeraldSuccess,
                  ),
                  label: 'Gastos',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.users, color: Colors.grey),
                  selectedIcon: Icon(
                    LucideIcons.users,
                    color: AppTheme.amberSafety,
                  ),
                  label: 'Socios',
                ),
                NavigationDestination(
                  icon: Icon(LucideIcons.settings, color: Colors.grey),
                  selectedIcon: Icon(LucideIcons.settings, color: Colors.white),
                  label: 'Ajustes',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
