import 'package:flutter/material.dart';

import '../../core/database/local_storage_service.dart';
import '../../core/repositories/sync_queue_repository.dart';
import '../../core/theme/app_theme.dart';
import 'sync_center_screen.dart';

/// Reports local Outbox state without claiming that another device applied it.
class SyncStatusCard extends StatelessWidget {
  const SyncStatusCard({super.key, required this.storage});

  final LocalStorageService storage;

  @override
  Widget build(BuildContext context) {
    final queue = SyncQueueRepository(storage.db);
    return StreamBuilder(
      stream: queue.watchRecent(limit: 500),
      builder: (context, snapshot) {
        final pending = snapshot.data
                ?.where((operation) => operation.status == 'PENDING')
                .length ??
            0;
        final headline = snapshot.hasError
            ? 'No se pudo leer la cola local'
            : pending > 0
            ? '$pending cambios guardados en este dispositivo'
            : 'Cola local sin cambios pendientes';

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SyncCenterScreen(storage: storage),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.skyAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.sync_rounded, color: AppTheme.skyAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headline, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        const Text(
                          'Abrir centro de sincronización',
                          style: TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
