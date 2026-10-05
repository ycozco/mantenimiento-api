import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../theme/app_theme.dart';

/// Reusable clean empty state widget with icon, title, description and optional action.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color iconColor;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor = AppTheme.amberSafety,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: iconColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.white60),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable error state with retry button.
class ErrorStateView extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const ErrorStateView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.coralUrgent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.circle_alert,
                size: 40,
                color: AppTheme.coralUrgent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ocurrió un inconveniente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.white60),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.rotate_cw, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable loading indicator with message.
class LoadingStateView extends StatelessWidget {
  final String? message;

  const LoadingStateView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.amberSafety),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
