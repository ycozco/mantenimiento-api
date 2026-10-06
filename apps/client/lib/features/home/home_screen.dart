import 'package:flutter/material.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/navigation/app_destination.dart';
import '../../core/navigation/app_navigation_shell.dart';
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
  AppDestination _selected = AppDestination.home;

  void _navigate(AppDestination destination) {
    if (_selected == destination) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selected = destination);
  }

  Widget _screen(AppDestination destination) => switch (destination) {
    AppDestination.home => DashboardScreen(storage: widget.storage),
    AppDestination.projects => ObrasScreen(storage: widget.storage),
    AppDestination.maintenance => MantenimientosScreen(storage: widget.storage),
    AppDestination.finance => FinanzasHubScreen(storage: widget.storage),
    AppDestination.more => MasMenuScreen(storage: widget.storage),
  };

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      NavigateToIntent: CallbackAction<NavigateToIntent>(
        onInvoke: (intent) {
          _navigate(intent.destination);
          return null;
        },
      ),
    },
    child: ListenableBuilder(
      listenable: widget.storage,
      builder: (context, _) => AppNavigationShell(
        selected: _selected,
        onSelected: (destination) =>
            Actions.invoke(context, NavigateToIntent(destination)),
        child: IndexedStack(
          index: _selected.index,
          children: [
            for (final destination in AppDestination.values)
              TickerMode(
                key: ValueKey(destination),
                enabled: destination == _selected,
                child: _screen(destination),
              ),
          ],
        ),
      ),
    ),
  );
}
