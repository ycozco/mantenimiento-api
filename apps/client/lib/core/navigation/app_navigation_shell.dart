import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_responsive.dart';
import '../widgets/app_brand_mark.dart';
import 'app_destination.dart';

/// Owns presentation only. The caller handles intents and keeps feature state.
class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.child,
  });

  final AppDestination selected;
  final ValueChanged<AppDestination> onSelected;
  final Widget child;

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  late final Animation<double> _opacity = Tween(
    begin: 0.72,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.curve));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.duration(context);
    if (_controller.duration == Duration.zero) _controller.value = 1;
  }

  @override
  void didUpdateWidget(AppNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      if (AppMotion.duration(context) == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // A bottom bar also suits short landscape windows and enlarged text.
    final size = MediaQuery.sizeOf(context);
    final railMinHeight = 460 + MediaQuery.textScalerOf(context).scale(70);
    final showRail =
        !AppResponsive.isCompact(context) &&
        size.height - MediaQuery.paddingOf(context).vertical >= railMinHeight;

    return Scaffold(
      body: Row(
        children: [
          if (showRail)
            SafeArea(
              right: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: NavigationRail(
                    selectedIndex: widget.selected.index,
                    onDestinationSelected: (index) =>
                        widget.onSelected(AppDestination.values[index]),
                    backgroundColor: colors.surface,
                    indicatorColor: widget.selected.color.withValues(
                      alpha: 0.16,
                    ),
                    labelType: NavigationRailLabelType.all,
                    leading: const Padding(
                      padding: EdgeInsets.fromLTRB(8, 16, 8, 24),
                      child: Column(
                        children: [
                          AppBrandMark(size: 42),
                          SizedBox(height: 8),
                          Text(
                            'DECOLUMAX',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    destinations: [
                      for (final destination in AppDestination.values)
                        NavigationRailDestination(
                          icon: _DestinationIcon(
                            destination: destination,
                            selected: destination == widget.selected,
                          ),
                          label: Text(destination.label),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            key: const ValueKey('navigation-content'),
            child: FadeTransition(opacity: _opacity, child: widget.child),
          ),
        ],
      ),
      bottomNavigationBar: showRail
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: colors.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: NavigationBar(
                      height: 74,
                      elevation: 0,
                      selectedIndex: widget.selected.index,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysShow,
                      animationDuration: AppMotion.duration(context),
                      backgroundColor: colors.surface,
                      indicatorColor: widget.selected.color.withValues(
                        alpha: 0.16,
                      ),
                      surfaceTintColor: Colors.transparent,
                      onDestinationSelected: (index) =>
                          widget.onSelected(AppDestination.values[index]),
                      destinations: [
                        for (final destination in AppDestination.values)
                          NavigationDestination(
                            tooltip: destination.label,
                            label: destination.compactLabel,
                            icon: _DestinationIcon(
                              destination: destination,
                              selected: destination == widget.selected,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({required this.destination, required this.selected});

  final AppDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: selected ? 1.08 : 1,
    duration: AppMotion.duration(context),
    curve: AppMotion.curve,
    child: Icon(
      destination.icon,
      size: 24,
      color: selected
          ? destination.color
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
