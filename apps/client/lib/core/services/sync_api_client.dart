import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/sync_api_config.dart';

class SyncApiClient {
  SyncApiClient({http.Client? client, FlutterSecureStorage? secureStorage})
    : _client = client ?? http.Client(),
      _storage = secureStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  Uri _uri(String path, [Map<String, String>? query]) {
    final base = SyncApiConfig.baseUri.toString().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    return Uri.parse(
      '$base/${path.replaceFirst(RegExp(r'^/+'), '')}',
    ).replace(queryParameters: query);
  }

  Future<void> login({
    required String workspaceSlug,
    required String email,
    required String password,
    required String deviceId,
  }) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'workspaceSlug': workspaceSlug,
        'email': email,
        'password': password,
        'deviceId': deviceId,
      }),
    );
    final data = _decode(response);
    await _storeTokens(data);
  }

  Future<SyncPullPage> pull({required String cursor, int limit = 50}) async {
    var token = await _storage.read(key: 'sync_access_token');
    if (token == null) {
      throw const SyncApiException('Inicia sesión para sincronizar.');
    }
    var response = await _client.get(
      _uri('/sync/pull', {'cursor': cursor, 'limit': '$limit'}),
      headers: {'authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      token = await _refresh();
      response = await _client.get(
        _uri('/sync/pull', {'cursor': cursor, 'limit': '$limit'}),
        headers: {'authorization': 'Bearer $token'},
      );
    }
    final data = _decode(response);
    return SyncPullPage(
      changes: (data['changes'] as List<dynamic>).cast<Map<String, dynamic>>(),
      cursor: data['cursor'] as String,
      hasMore: data['hasMore'] as bool,
    );
  }

  /// Publishes an already encrypted envelope. Callers must never pass plaintext.
  Future<Map<String, dynamic>> push({
    required String operationId,
    required String entityType,
    required String entityId,
    required int schemaVersion,
    required String nonce,
    required String ciphertext,
  }) async {
    var token = await _storage.read(key: 'sync_access_token');
    if (token == null) {
      throw const SyncApiException('Inicia sesión para sincronizar.');
    }
    Future<http.Response> send(String accessToken) => _client.post(
      _uri('/sync/push'),
      headers: {
        'authorization': 'Bearer $accessToken',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'operationId': operationId,
        'entityType': entityType,
        'entityId': entityId,
        'schemaVersion': schemaVersion,
        'nonce': nonce,
        'ciphertext': ciphertext,
      }),
    );
    var response = await send(token);
    if (response.statusCode == 401) {
      token = await _refresh();
      response = await send(token);
    }
    return _decode(response);
  }

  Future<void> logout() async {
    final refresh = await _storage.read(key: 'sync_refresh_token');
    if (refresh != null) {
      try {
        await _client.post(
          _uri('/auth/logout'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}),
        );
      } finally {
        await _clearTokens();
      }
    } else {
      await _clearTokens();
    }
  }

  Future<String> _refresh() async {
    final refresh = await _storage.read(key: 'sync_refresh_token');
    if (refresh == null) {
      throw const SyncApiException('La sesión expiró; inicia sesión.');
    }
    final response = await _client.post(
      _uri('/auth/refresh'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'refreshToken': refresh}),
    );
    final data = _decode(response);
    await _storeTokens(data);
    return data['accessToken'] as String;
  }

  Future<void> _storeTokens(Map<String, dynamic> data) async {
    await _storage.write(
      key: 'sync_access_token',
      value: data['accessToken'] as String,
    );
    await _storage.write(
      key: 'sync_refresh_token',
      value: data['refreshToken'] as String,
    );
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      await _storage.write(
        key: 'sync_workspace_id',
        value: user['workspaceId'] as String?,
      );
      await _storage.write(
        key: 'sync_workspace_slug',
        value: user['workspaceSlug'] as String?,
      );
    }
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: 'sync_access_token');
    await _storage.delete(key: 'sync_refresh_token');
    await _storage.delete(key: 'sync_workspace_id');
    await _storage.delete(key: 'sync_workspace_slug');
  }

  Future<String?> workspaceId() => _storage.read(key: 'sync_workspace_id');
  Future<String?> workspaceSlug() => _storage.read(key: 'sync_workspace_slug');
  Future<bool> get isSignedIn async =>
      (await _storage.read(key: 'sync_refresh_token')) != null;

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw SyncApiException(
        'Respuesta inválida del API (${response.statusCode}).',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body['message'];
      throw SyncApiException(
        message is String ? message : 'Error HTTP ${response.statusCode}.',
      );
    }
    return body;
  }
}

class SyncPullPage {
  const SyncPullPage({
    required this.changes,
    required this.cursor,
    required this.hasMore,
  });
  final List<Map<String, dynamic>> changes;
  final String cursor;
  final bool hasMore;
}

class SyncApiException implements Exception {
  const SyncApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
