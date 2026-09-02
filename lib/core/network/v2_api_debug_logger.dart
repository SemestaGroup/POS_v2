import 'dart:convert';

import 'package:flutter/foundation.dart';

class V2ApiDebugEntry {
  const V2ApiDebugEntry({
    required this.requestId,
    required this.timestamp,
    required this.method,
    required this.url,
    required this.headers,
    required this.durationMs,
    this.requestBody,
    this.statusCode,
    this.responseBody,
    this.error,
  });

  final String requestId;
  final DateTime timestamp;
  final String method;
  final String url;
  final Map<String, Object?> headers;
  final Object? requestBody;
  final int? statusCode;
  final Object? responseBody;
  final String? error;
  final int durationMs;

  bool get isSuccess => error == null;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'requestId': requestId,
      'timestamp': timestamp.toIso8601String(),
      'method': method,
      'url': url,
      'headers': headers,
      'requestBody': requestBody,
      'statusCode': statusCode,
      'responseBody': responseBody,
      'error': error,
      'durationMs': durationMs,
      'isSuccess': isSuccess,
    };
  }
}

/// Request/response field names whose values must never reach the debug log,
/// regardless of how deeply nested they are in the payload.
const Set<String> _sensitiveFieldNames = <String>{
  'password',
  'pin',
  'authtoken',
  'auth_token',
  'token',
  'access_token',
  'refresh_token',
  'secret',
  'apikey',
  'api_key',
  'card_number',
  'cvv',
  'otp',
};

class V2ApiDebugLogger {
  V2ApiDebugLogger._();

  static final V2ApiDebugLogger instance = V2ApiDebugLogger._();

  void log(V2ApiDebugEntry entry) {
    final buffer = StringBuffer();
    buffer.writeln('[V2 API DEBUG] ${entry.method} ${entry.url}');

    if (entry.requestBody != null) {
      buffer.writeln('--- Body ---');
      buffer.writeln(
        _truncateChars(jsonEncode(_redactSensitive(entry.requestBody))),
      );
    }

    buffer.writeln('--- Response ---');
    if (entry.error != null) {
      buffer.writeln(_truncateChars(entry.error!));
    } else if (entry.responseBody != null) {
      buffer.writeln(_truncateChars(jsonEncode(_sanitizeResponse(entry))));
    } else {
      buffer.writeln('Status: ${entry.statusCode}');
    }

    debugPrint(buffer.toString());
  }

  Object? _sanitizeResponse(V2ApiDebugEntry entry) {
    final isGeneratedReportKey =
        entry.method == 'POST' &&
        Uri.tryParse(entry.url)?.path.endsWith('/api/v2/pos-options') == true;
    final response = _redactSensitive(entry.responseBody);
    if (!isGeneratedReportKey || response is! Map) {
      return response;
    }

    final sanitized = Map<Object?, Object?>.from(response);
    if (sanitized.containsKey('data')) {
      sanitized['data'] = '<redacted>';
    }
    return sanitized;
  }

  /// Recursively walks [value] and replaces any map value whose key matches
  /// [_sensitiveFieldNames] (case-insensitive) with `<redacted>`, so secrets
  /// never leak into logs even when buried inside nested objects/arrays.
  Object? _redactSensitive(Object? value) {
    if (value is Map) {
      return value.map((key, v) {
        final isSensitive =
            key is String &&
            _sensitiveFieldNames.contains(key.toLowerCase());
        return MapEntry(key, isSensitive ? '<redacted>' : _redactSensitive(v));
      });
    }
    if (value is List) {
      return value.map(_redactSensitive).toList();
    }
    return value;
  }

  String _truncateChars(String text, {int maxChars = 1000}) {
    if (text.length > maxChars) {
      return '${text.substring(0, maxChars)}...';
    }
    return text;
  }
}
