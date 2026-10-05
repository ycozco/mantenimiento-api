import 'package:flutter/material.dart';

/// Centralized breakpoint definitions for responsive design across Decolumax V2.
/// - Compact: Phones (< 600 px)
/// - Medium: Tablets & small laptops (600 - 1023 px)
/// - Expanded: Desktop & wide displays (>= 1024 px)
enum ScreenBreakpoint { compact, medium, expanded }

class AppResponsive {
  static const double compactBreakpoint = 600;
  static const double mediumBreakpoint = 1024;
  static const double maxContentWidth = 1200;

  static ScreenBreakpoint getBreakpoint(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactBreakpoint) {
      return ScreenBreakpoint.compact;
    } else if (width < mediumBreakpoint) {
      return ScreenBreakpoint.medium;
    } else {
      return ScreenBreakpoint.expanded;
    }
  }

  static bool isCompact(BuildContext context) =>
      getBreakpoint(context) == ScreenBreakpoint.compact;

  static bool isMedium(BuildContext context) =>
      getBreakpoint(context) == ScreenBreakpoint.medium;

  static bool isExpanded(BuildContext context) =>
      getBreakpoint(context) == ScreenBreakpoint.expanded;

  static bool isWide(BuildContext context) => !isCompact(context);

  /// Select a value according to current screen breakpoint.
  static T value<T>(
    BuildContext context, {
    required T compact,
    T? medium,
    T? expanded,
  }) {
    final bp = getBreakpoint(context);
    switch (bp) {
      case ScreenBreakpoint.compact:
        return compact;
      case ScreenBreakpoint.medium:
        return medium ?? compact;
      case ScreenBreakpoint.expanded:
        return expanded ?? medium ?? compact;
    }
  }
}

/// A wrapper widget that constraints content width on wide displays (tablet/desktop)
/// and centers it, avoiding awkward stretched forms or cards on 1920px+ monitors.
class ConstrainedContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = AppResponsive.maxContentWidth,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A responsive layout builder that switches widgets based on breakpoint.
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context) compact;
  final Widget Function(BuildContext context)? medium;
  final Widget Function(BuildContext context)? expanded;

  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final bp = AppResponsive.getBreakpoint(context);
    switch (bp) {
      case ScreenBreakpoint.compact:
        return compact(context);
      case ScreenBreakpoint.medium:
        return (medium ?? compact)(context);
      case ScreenBreakpoint.expanded:
        return (expanded ?? medium ?? compact)(context);
    }
  }
}
