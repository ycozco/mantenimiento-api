import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/local_storage_service.dart';
import '../../core/database/app_database.dart';
import '../../core/repositories/sync_queue_repository.dart';
import '../../core/repositories/sync_inbox_repository.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/services/sync_api_client.dart';
import '../../core/theme/app_responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_title.dart';
import '../../core/widgets/state_views.dart';
import 'sync_transport_probe.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({
    super.key,
    required this.storage,
    this.probe,
    this.deviceIdLoader,
  });

  final LocalStorageService storage;
  final SyncTransportProbe? probe;
  final Future<String> Function()? deviceIdLoader;

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  final _api = SyncApiClient();
  final _workspaceController = TextEditingController(text: 'decolumax');
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final SyncQueueRepository _queue = SyncQueueRepository(
    widget.storage.db,
  );
  late final Future<String> _deviceId =
      (widget.deviceIdLoader ?? DeviceIdentityService().getOrCreateDeviceId)();

  SyncTransportProbeResult? _probeResult;
  bool _probing = false;
  bool _apiBusy = false;
  bool _signedIn = false;
  String? _workspaceId;
  String? _workspaceSlug;
  String? _apiMessage;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    try {
      final signedIn = await _api.isSignedIn;
      final workspaceId = await _api.workspaceId();
      final workspaceSlug = await _api.workspaceSlug();
      if (!mounted) return;
      setState(() {
        _signedIn = signedIn && workspaceId != null;
        _workspaceId = workspaceId;
        _workspaceSlug = workspaceSlug;
        if (workspaceSlug != null) _workspaceController.text = workspaceSlug;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _apiMessage = 'No se pudo restaurar la sesión: $error');
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _apiBusy = true;
      _apiMessage = null;
    });
    try {
      await _api.login(
        workspaceSlug: _workspaceController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        deviceId: await _deviceId,
      );
      final id = await _api.workspaceId();
      final slug = await _api.workspaceSlug();
      if (!mounted) return;
      setState(() {
        _signedIn = true;
        _workspaceId = id;
        _workspaceSlug = slug;
        _passwordController.clear();
        _apiMessage = 'Sesión iniciada. Ya puedes descargar sobres cifrados.';
      });
    } catch (error) {
      if (mounted) setState(() => _apiMessage = '$error');
    } finally {
      if (mounted) setState(() => _apiBusy = false);
    }
  }

  Future<void> _pullChanges() async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    setState(() {
      _apiBusy = true;
      _apiMessage = null;
    });
    try {
      final inbox = SyncInboxRepository(
        widget.storage.db,
        workspaceId: workspaceId,
      );
      var cursor = await inbox.cursor;
      var received = 0;
      var pages = 0;
      var hasMore = true;
      while (hasMore && pages < 5) {
        final page = await _api.pull(cursor: cursor);
        await inbox.savePage(changes: page.changes, nextCursor: page.cursor);
        cursor = page.cursor;
        received += page.changes.length;
        hasMore = page.hasMore;
        pages++;
      }
      if (mounted) {
        setState(
          () => _apiMessage = received == 0
              ? 'Conectado. No hay sobres nuevos para este workspace.'
              : 'Se guardaron $received sobres cifrados en este dispositivo.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _apiMessage = '$error');
    } finally {
      if (mounted) setState(() => _apiBusy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _apiBusy = true);
    try {
      await _api.logout();
      if (mounted) {
        setState(() {
          _signedIn = false;
          _workspaceId = null;
          _workspaceSlug = null;
          _apiMessage = 'Sesión cerrada en este dispositivo.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _apiMessage = '$error');
    } finally {
      if (mounted) setState(() => _apiBusy = false);
    }
  }

  Future<void> _runProbe() async {
    setState(() => _probing = true);
    try {
      final result = await (widget.probe ?? probeSyncTransport)();
      if (mounted) setState(() => _probeResult = result);
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const AppPageTitle(
            title: 'Sincronización',
            icon: Icons.sync_rounded,
            color: AppTheme.skyAccent,
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Estado'),
              Tab(text: 'Organización'),
              Tab(text: 'Dispositivos'),
              Tab(text: 'Conflictos'),
            ],
          ),
        ),
        body: ConstrainedContent(
          child: TabBarView(
            children: [
              _buildStatusTab(),
              _buildOrganizationTab(),
              _buildDevicesTab(),
              _buildConflictsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTab() => StreamBuilder<List<SyncQueueData>>(
    stream: _queue.watchRecent(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorStateView(
          error: 'No se pudo leer la cola local: ${snapshot.error}',
        );
      }
      if (!snapshot.hasData) {
        return const LoadingStateView(message: 'Leyendo cola local…');
      }

      final rows = snapshot.data!;
      final pending = rows.where((row) => row.status == 'PENDING').length;
      final sending = rows.where((row) => row.status == 'SENDING').length;
      final delivered = rows.where((row) => row.status == 'DELIVERED').length;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectionCard(
            result: _probeResult,
            probing: _probing,
            onProbe: _runProbe,
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.inventory_2_outlined,
            title: 'Cola local de cambios',
            subtitle:
                'Estos estados describen datos guardados en este dispositivo. Aún no hay un backend que confirme su aplicación en otro socio.',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Pendientes',
                        value: pending,
                        color: AppTheme.amberSafety,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        label: 'En proceso',
                        value: sending,
                        color: AppTheme.skyAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        label: 'Entregados',
                        value: delivered,
                        color: AppTheme.emeraldSuccess,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No hay operaciones en la cola local.'),
                  )
                else
                  ...rows.take(8).map(_operationTile),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildApiCard(),
          const SizedBox(height: 12),
          if (_signedIn && _workspaceId != null) _buildInboxCard(),
          const SizedBox(height: 12),
          const _NoticeCard(
            icon: Icons.lock_outline_rounded,
            title: 'Sobres cifrados; aplicación pendiente',
            message:
                'La app guarda los sobres recibidos antes de mover el cursor. Aún falta acordar las claves entre socios, cifrar la outbox local y aplicar cambios a las tablas de negocio.',
          ),
        ],
      );
    },
  );

  Widget _buildApiCard() => _SectionCard(
    icon: Icons.cloud_sync_rounded,
    title: 'API de sincronización',
    subtitle: _signedIn
        ? 'Conectado a ${_workspaceSlug ?? 'workspace'}'
        : 'Inicia sesión con una cuenta de la organización.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_signedIn) ...[
          TextField(
            controller: _workspaceController,
            decoration: const InputDecoration(
              labelText: 'Organización / workspace',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Correo'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Contraseña'),
            obscureText: true,
            onSubmitted: (_) {
              if (!_apiBusy) _login();
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _apiBusy ? null : _login,
            icon: const Icon(Icons.login_rounded),
            label: Text(_apiBusy ? 'Conectando…' : 'Iniciar sesión'),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _apiBusy ? null : _pullChanges,
                  icon: _apiBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(_apiBusy ? 'Descargando…' : 'Descargar cambios'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Cerrar sesión',
                onPressed: _apiBusy ? null : _logout,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ID workspace: $_workspaceId',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_apiMessage != null) ...[
          const SizedBox(height: 10),
          Text(_apiMessage!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );

  Widget _buildInboxCard() {
    final repository = SyncInboxRepository(
      widget.storage.db,
      workspaceId: _workspaceId!,
    );
    return StreamBuilder<List<SyncInboxData>>(
      stream: repository.watchRecent(),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <SyncInboxData>[];
        return _SectionCard(
          icon: Icons.inbox_outlined,
          title: 'Sobres recibidos',
          subtitle:
              '${items.length} guardados localmente; pendientes de descifrado y aplicación.',
          child: items.isEmpty
              ? const Text('No hay sobres cifrados recibidos.')
              : Column(
                  children: items
                      .take(5)
                      .map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.enhanced_encryption_outlined,
                          ),
                          title: Text(item.entityType),
                          subtitle: Text(
                            'Secuencia ${item.serverSequence} · ${item.operationId}',
                          ),
                          trailing: const Text('Cifrado'),
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }

  Widget _operationTile(SyncQueueData row) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      row.status == 'DELIVERED'
          ? Icons.check_circle_outline
          : row.status == 'SENDING'
          ? Icons.sync
          : Icons.schedule,
      color: row.status == 'DELIVERED'
          ? AppTheme.emeraldSuccess
          : AppTheme.amberSafety,
    ),
    title: Text('${row.operation} · ${row.entityTable}'),
    subtitle: Text(
      '${row.entityId} · ${row.queuedAt.toLocal()}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: Text(row.status, style: Theme.of(context).textTheme.labelSmall),
  );

  Widget _buildOrganizationTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _SectionCard(
        icon: Icons.apartment_rounded,
        title: 'Identidad de organización',
        subtitle: _signedIn
            ? 'Sesión autenticada en la organización.'
            : 'La sesión aún no está autenticada.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ValueLine(
              label: _signedIn ? 'ID workspace' : 'ID local',
              value: _workspaceId ?? AppConstants.defaultWorkspaceId,
            ),
            const SizedBox(height: 10),
            _ValueLine(
              label: 'Membresía',
              value: _signedIn
                  ? 'Sesión confirmada por servidor'
                  : 'No verificada por servidor',
            ),
            const SizedBox(height: 14),
            const _NoticeCard(
              icon: Icons.lock_outline_rounded,
              title: 'Invitaciones todavía no disponibles',
              message:
                  'Crear o aceptar códigos requiere una API que valide la organización, el uso único, el vencimiento y la aprobación del administrador. Esta app no inventará códigos locales que parezcan autorizaciones reales.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Acceso y seguridad',
        subtitle: 'La sesión de usuario ya usa el servicio de identidad.',
        child: Text(
          'La app no recibe claves NATS. El backend valida la sesión y la limita al workspace. La aprobación de dispositivos, invitaciones y revocación individual aún no están implementadas.',
        ),
      ),
    ],
  );

  Widget _buildDevicesTab() => FutureBuilder<String>(
    future: _deviceId,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorStateView(
          error: 'No se pudo leer la identidad local del dispositivo.',
        );
      }
      if (!snapshot.hasData) {
        return const LoadingStateView(message: 'Preparando este dispositivo…');
      }

      final deviceId = snapshot.data!;
      final platformName = kIsWeb
          ? 'Navegador web'
          : switch (defaultTargetPlatform) {
              TargetPlatform.android => 'Android',
              TargetPlatform.iOS => 'iOS',
              TargetPlatform.windows => 'Windows',
              TargetPlatform.macOS => 'macOS',
              TargetPlatform.linux => 'Linux',
              TargetPlatform.fuchsia => 'Fuchsia',
            };

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            icon: Icons.devices_rounded,
            title: 'Este dispositivo',
            subtitle: 'Identificador local estable; no es una credencial.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ValueLine(label: 'Plataforma', value: platformName),
                const SizedBox(height: 10),
                _ValueLine(label: 'ID de dispositivo', value: deviceId),
                const SizedBox(height: 10),
                _ValueLine(
                  label: 'Estado de registro',
                  value: _signedIn
                      ? 'Sesión vinculada; gestión de dispositivos pendiente'
                      : 'Aún no vinculado',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _NoticeCard(
            icon: Icons.phonelink_erase_rounded,
            title: 'Gestión de dispositivos pendiente del backend',
            message:
                'La lista de socios, aprobación y revocación no puede mantenerse solo en cada teléfono. Se habilitará cuando el servicio central registre y revoque claves por dispositivo.',
          ),
        ],
      );
    },
  );

  Widget _buildConflictsTab() => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      _SectionCard(
        icon: Icons.compare_arrows_rounded,
        title: 'Resolución de conflictos',
        subtitle: 'No se han recibido conflictos de sincronización.',
        child: _NoticeCard(
          icon: Icons.info_outline_rounded,
          title: 'El inbox aún no está implementado',
          message:
              'No se declara que no existan conflictos en el servidor: esta app aún no descarga ni aplica eventos entrantes. La resolución se conectará al registro local y al cursor del dispositivo.',
        ),
      ),
      SizedBox(height: 12),
      _SectionCard(
        icon: Icons.restore_rounded,
        title: 'Recuperación',
        subtitle: 'Los respaldos actuales son locales.',
        child: Text(
          'Todavía no existe un cursor remoto ni un snapshot de sincronización para reanudar cambios después de una ausencia prolongada.',
        ),
      ),
    ],
  );
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.result,
    required this.probing,
    required this.onProbe,
  });

  final SyncTransportProbeResult? result;
  final bool probing;
  final VoidCallback onProbe;

  @override
  Widget build(BuildContext context) {
    final color = result == null
        ? AppTheme.skyAccent
        : result!.connected
        ? AppTheme.emeraldSuccess
        : AppTheme.coralUrgent;
    final status = result == null
        ? 'Sin comprobar desde este cliente'
        : result!.connected
        ? 'TLS disponible'
        : result!.supported
        ? 'No conectado'
        : 'Transporte no compatible';

    return _SectionCard(
      icon: Icons.cloud_outlined,
      title: 'Servicio NATS',
      subtitle: 'tls://$syncEndpointHost:$syncEndpointPort',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, size: 11, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (result?.elapsed != null)
                Text('${result!.elapsed!.inMilliseconds} ms'),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 8),
            Text(result!.message),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'El VPS confirmó el servicio. Usa esta acción para revisar DNS, puerto y certificado desde este cliente.',
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: probing ? null : onProbe,
            icon: probing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check_rounded),
            label: Text(probing ? 'Comprobando…' : 'Comprobar canal TLS'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.skyAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}

class _ValueLine extends StatelessWidget {
  const _ValueLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 130,
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
      Expanded(child: SelectableText(value)),
    ],
  );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.amberSafety),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
