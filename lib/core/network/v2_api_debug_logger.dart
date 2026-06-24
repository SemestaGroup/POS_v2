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

class V2ApiDebugLogger {
  V2ApiDebugLogger._();

  static final V2ApiDebugLogger instance = V2ApiDebugLogger._();

  void log(V2ApiDebugEntry entry) {
    final buffer = StringBuffer();
    buffer.writeln('[V2 API DEBUG] ${entry.method} ${entry.url}');
    
    if (entry.requestBody != null) {
      buffer.writeln('--- Body ---');
      buffer.writeln(_truncateChars(jsonEncode(entry.requestBody)));
    }
    
    buffer.writeln('--- Response ---');
    if (entry.error != null) {
      buffer.writeln(_truncateChars(entry.error!));
    } else if (entry.responseBody != null) {
      buffer.writeln(_truncateChars(jsonEncode(entry.responseBody)));
    } else {
      buffer.writeln('Status: ${entry.statusCode}');
    }
    
    debugPrint(buffer.toString());
  }

  String _truncateChars(String text, {int maxChars = 1000}) {
    if (text.length > maxChars) {
      return '${text.substring(0, maxChars)}...';
    }
    return text;
  }
}
