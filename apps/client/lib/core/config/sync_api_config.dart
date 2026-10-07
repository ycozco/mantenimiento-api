import 'package:flutter/foundation.dart';

class SyncApiConfig {
  static const _configured = String.fromEnvironment('SYNC_API_BASE_URL');

  static Uri get baseUri {
    if (_configured.isNotEmpty) return Uri.parse(_configured);
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return Uri.parse('http://$host:3000/api/v1');
  }
}
