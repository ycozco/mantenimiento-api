import 'package:flutter/material.dart';

/// Shared section hierarchy; actions move below the title when space is tight.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.color,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final heading = Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: foreground,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      header: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (trailing == null) return heading;
          if (constraints.maxWidth < 420 ||
              MediaQuery.textScalerOf(context).scale(12) > 18) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, trailing!],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              trailing!,
            ],
          );
        },
      ),
    );
  }
}
