import 'dart:convert';

import 'package:http/http.dart' as http;

import 'v2_api_debug_logger.dart';

class V2ApiClient {
  const V2ApiClient({required this.baseUrl, required this.authToken});

  final String baseUrl;
  final String authToken;

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$normalizedBase$normalizedPath');

    if (query == null || query.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  Map<String, String> get _jsonHeaders => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (authToken.trim().isNotEmpty) 'authtoken': authToken.trim(),
  };

  Map<String, String> get _plainHeaders => {
    'Accept': 'application/json',
    if (authToken.trim().isNotEmpty) 'authtoken': authToken.trim(),
  };

  Future<Map<String, dynamic>> getEnvelope(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final uri = _buildUri(path, query);
    return _sendAndDecode(
      method: 'GET',
      uri: uri,
      headers: _plainHeaders,
      requestBody: null,
      send: () => http.get(uri, headers: _plainHeaders).timeout(const Duration(seconds: 15)),
    );
  }

  Future<dynamic> getJson(String path, {Map<String, dynamic>? query}) async {
    final uri = _buildUri(path, query);
    return _sendAndDecodeAny(
      method: 'GET',
      uri: uri,
      headers: _plainHeaders,
      requestBody: null,
      send: () => http.get(uri, headers: _plainHeaders).timeout(const Duration(seconds: 15)),
    );
  }

  Future<Map<String, dynamic>> postEnvelope(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final requestBody = body ?? <String, dynamic>{};
    final uri = _buildUri(path);
    return _sendAndDecode(
      method: 'POST',
      uri: uri,
      headers: _jsonHeaders,
      requestBody: requestBody,
      send: () =>
          http.post(uri, headers: _jsonHeaders, body: jsonEncode(requestBody)).timeout(const Duration(seconds: 15)),
    );
  }

  Future<Map<String, dynamic>> putEnvelope(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final requestBody = body ?? <String, dynamic>{};
    final uri = _buildUri(path);
    return _sendAndDecode(
      method: 'PUT',
      uri: uri,
      headers: _jsonHeaders,
      requestBody: requestBody,
      send: () =>
          http.put(uri, headers: _jsonHeaders, body: jsonEncode(requestBody)).timeout(const Duration(seconds: 15)),
    );
  }

  Future<Map<String, dynamic>> deleteEnvelope(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final requestBody = body ?? <String, dynamic>{};
    final uri = _buildUri(path);
    return _sendAndDecode(
      method: 'DELETE',
      uri: uri,
      headers: _jsonHeaders,
      requestBody: requestBody,
      send: () async {
        final request = http.Request('DELETE', uri);
        request.headers.addAll(_jsonHeaders);
        request.body = jsonEncode(requestBody);
        final streamed = await request.send().timeout(const Duration(seconds: 15));
        return http.Response.fromStream(streamed);
      },
    );
  }

  Future<Map<String, dynamic>> _sendAndDecode({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Object? requestBody,
    required Future<http.Response> Function() send,
  }) async {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    final stopwatch = Stopwatch()..start();

    try {
      final response = await send();
      final decoded = _decodeJsonBody(response);
      stopwatch.stop();
      _log(
        requestId: requestId,
        method: method,
        uri: uri,
        headers: headers,
        requestBody: requestBody,
        statusCode: response.statusCode,
        responseBody: decoded,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      return _ensureSuccessfulEnvelope(decoded, response.statusCode);
    } catch (error) {
      stopwatch.stop();
      _log(
        requestId: requestId,
        method: method,
        uri: uri,
        headers: headers,
        requestBody: requestBody,
        statusCode: null,
        responseBody: null,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<dynamic> _sendAndDecodeAny({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Object? requestBody,
    required Future<http.Response> Function() send,
  }) async {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    final stopwatch = Stopwatch()..start();

    try {
      final response = await send();
      final decoded = _decodeJsonBody(response);
      stopwatch.stop();
      _log(
        requestId: requestId,
        method: method,
        uri: uri,
        headers: headers,
        requestBody: requestBody,
        statusCode: response.statusCode,
        responseBody: decoded,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      return decoded;
    } catch (error) {
      stopwatch.stop();
      _log(
        requestId: requestId,
        method: method,
        uri: uri,
        headers: headers,
        requestBody: requestBody,
        statusCode: null,
        responseBody: null,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error.toString(),
      );
      rethrow;
    }
  }

  dynamic _decodeJsonBody(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid server response (${response.statusCode})');
    }

    return decoded;
  }

  Map<String, dynamic> _ensureSuccessfulEnvelope(
    dynamic decoded,
    int statusCode,
  ) {
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format ($statusCode)');
    }

    final success = decoded['status'] == true;
    if (!success) {
      final msg = decoded['message']?.toString() ?? '';
      if (msg.toLowerCase().contains('no data')) {
        return decoded;
      }
      throw Exception(msg.isNotEmpty ? msg : 'Request failed');
    }

    return decoded;
  }

  void _log({
    required String requestId,
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Object? requestBody,
    required int? statusCode,
    required Object? responseBody,
    required int durationMs,
    String? error,
  }) {
    final sanitizedHeaders = headers.map(
      (key, value) => MapEntry(
        key,
        key.toLowerCase() == 'authtoken' ? '<redacted>' : value,
      ),
    );
    V2ApiDebugLogger.instance.log(
      V2ApiDebugEntry(
        requestId: requestId,
        timestamp: DateTime.now(),
        method: method,
        url: uri.toString(),
        headers: sanitizedHeaders,
        requestBody: requestBody,
        statusCode: statusCode,
        responseBody: responseBody,
        error: error,
        durationMs: durationMs,
      ),
    );
  }
}
