import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/app_theme.dart';

/// One catalog for the mobile bar, rail and navigation intents.
enum AppDestination {
  home('Inicio', LucideIcons.layout_dashboard, AppTheme.amberSafety),
  projects('Obras', LucideIcons.hard_hat, AppTheme.skyAccent),
  maintenance(
    'Mantenimiento',
    LucideIcons.calendar_clock,
    AppTheme.amberSafety,
    compactLabel: 'Mantto.',
  ),
  finance('Finanzas', LucideIcons.coins, AppTheme.emeraldSuccess),
  more('Más', LucideIcons.menu, AppTheme.amberSafety);

  const AppDestination(
    this.label,
    this.icon,
    this.color, {
    String? compactLabel,
  }) : compactLabel = compactLabel ?? label;

  final String label;
  final String compactLabel;
  final IconData icon;
  final Color color;
}

/// A screen asks to navigate without depending on tab indexes or shell layout.
class NavigateToIntent extends Intent {
  const NavigateToIntent(this.destination);

  final AppDestination destination;
}
