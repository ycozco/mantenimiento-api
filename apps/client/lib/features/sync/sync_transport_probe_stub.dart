import 'sync_transport_probe_result.dart';

Future<SyncTransportProbeResult> probePlatformSyncTransport() async =>
    const SyncTransportProbeResult(
      supported: false,
      connected: false,
      message:
          'El navegador no permite abrir una conexión TCP NATS. La versión web necesita un gateway HTTP o WebSocket configurado en el servidor.',
    );
