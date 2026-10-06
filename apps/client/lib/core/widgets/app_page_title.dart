import 'package:flutter/material.dart';

/// App bar title with a single layout contract for narrow and enlarged text.
class AppPageTitle extends StatelessWidget {
  const AppPageTitle({
    super.key,
    required this.title,
    this.icon,
    this.color,
    this.leading,
  }) : assert(icon == null || leading == null);

  final String title;
  final IconData? icon;
  final Color? color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      children: [
        if (leading != null || icon != null) ...[
          leading ?? Icon(icon, size: 24, color: color),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Tooltip(
            message: title,
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    ),
  );
}
