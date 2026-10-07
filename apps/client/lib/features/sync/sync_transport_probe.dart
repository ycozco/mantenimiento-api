import 'sync_transport_probe_result.dart';
import 'sync_transport_probe_stub.dart'
    if (dart.library.io) 'sync_transport_probe_io.dart' as platform;

export 'sync_transport_probe_result.dart';

Future<SyncTransportProbeResult> probeSyncTransport() =>
    platform.probePlatformSyncTransport();
