import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_nats/dart_nats.dart';
import 'package:uuid/uuid.dart';

/// Real JetStream smoke test using the same Flutter NATS dependency as the app.
/// The message is synthetic and contains no business data or E2E encryption.
Future<void> main() async {
  final uriText = _required('NATS_SMOKE_URL');
  final username = _required('NATS_SMOKE_USER');
  final password = _required('NATS_SMOKE_PASSWORD');
  final certificatePath = _required('NATS_SMOKE_CA_CERT');
  final streamName = Platform.environment['NATS_SMOKE_STREAM'] ?? 'SYNC_SMOKE';

  final context = SecurityContext(withTrustedRoots: true)
    ..setTrustedCertificates(certificatePath);
  final client = Client();
  try {
    await client.connect(
      Uri.parse(uriText),
      connectOption: ConnectOption(user: username, pass: password),
      securityContext: context as dynamic,
      retry: false,
      timeout: 5,
    );

    final jetStream = client.jetStream();
    final stream = await jetStream.createOrUpdateStream(
      StreamConfig(
        name: streamName,
        subjects: const ['sync.smoke.>'],
        storage: 'file',
        retention: 'limits',
        maxMsgs: 200000,
        maxBytes: 400000000,
        maxMsgSize: 1048576,
        maxAge: const Duration(days: 7),
        discard: 'new',
      ),
    );

    final runId = const Uuid().v4().replaceAll('-', '');
    final subject = 'sync.smoke.$runId.to.receiver';
    final durable = 'smoke_$runId';
    final messageId = 'probe_$runId';
    final consumer = await stream.createConsumer(
      ConsumerConfig(
        durable: durable,
        filterSubject: subject,
        ackPolicy: 'explicit',
        deliverPolicy: 'all',
      ),
    );

    // Random bytes stand in for an opaque envelope; no business payload is used.
    final marker = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final payload = utf8.encode(jsonEncode({'probe': base64Encode(marker)}));
    final firstAck = await jetStream.publish(
      subject,
      payload,
      opts: PubOpts(msgId: messageId),
    );
    final retryAck = await jetStream.publish(
      subject,
      payload,
      opts: PubOpts(msgId: messageId),
    );

    if (firstAck.stream != streamName || !retryAck.duplicate) {
      throw StateError('JetStream stream or message-ID deduplication failed');
    }

    final messages = await consumer.fetch(
      batch: 2,
      timeout: const Duration(seconds: 5),
    );
    if (messages.length != 1 || !listEquals(messages.single.byte, payload)) {
      throw StateError(
        'Expected one stored copy; received ${messages.length} copies',
      );
    }
    await messages.single.ackSync(timeout: const Duration(seconds: 5));

    final streamInfo = await stream.info();
    stdout.writeln(
      'PASS stream=${streamInfo.config.name} '
      'storedMessages=${streamInfo.state.messages} '
      'publishSequence=${firstAck.sequence} duplicate=${retryAck.duplicate} '
      'received=${messages.length} ack=confirmed tls=true storage=file',
    );
  } finally {
    await client.close();
  }
}

String _required(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    throw StateError('Set environment variable $key before running this test');
  }
  return value;
}

bool listEquals(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
