import 'dart:io';
import 'package:flutter/foundation.dart';

import 'sync_transport_probe_result.dart';

Future<SyncTransportProbeResult> probePlatformSyncTransport() async {
  final started = DateTime.now();
  SecureSocket? socket;
  try {
    socket = await SecureSocket.connect(
      syncEndpointHost,
      syncEndpointPort,
      timeout: const Duration(seconds: 7),
    );
    return SyncTransportProbeResult(
      supported: true,
      connected: true,
      elapsed: DateTime.now().difference(started),
      message:
          'Conexión TLS y certificado válidos. Esta comprobación no autentica una cuenta NATS ni envía datos.',
    );
  } on HandshakeException {
    return const SyncTransportProbeResult(
      supported: true,
      connected: false,
      message:
          'No se pudo validar TLS. Revisa el certificado, el nombre del servidor y la fecha del dispositivo.',
    );
  } on SocketException catch (error) {
    debugPrint('Sync TLS probe socket error: ${error.message}');
    return const SyncTransportProbeResult(
      supported: true,
      connected: false,
      message:
          'No se alcanzó el servicio. Comprueba internet, DNS y el puerto público 4422.',
    );
  } on Object catch (error) {
    debugPrint('Sync TLS probe error: $error');
    return const SyncTransportProbeResult(
      supported: true,
      connected: false,
      message: 'Falló la comprobación TLS. Inténtalo nuevamente.',
    );
  } finally {
    socket?.destroy();
  }
}
