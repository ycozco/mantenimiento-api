class SyncTransportProbeResult {
  const SyncTransportProbeResult({
    required this.supported,
    required this.connected,
    required this.message,
    this.elapsed,
  });

  final bool supported;
  final bool connected;
  final String message;
  final Duration? elapsed;
}

typedef SyncTransportProbe = Future<SyncTransportProbeResult> Function();

const syncEndpointHost = 'mant.qpsecure.cloud';
const syncEndpointPort = 4422;
