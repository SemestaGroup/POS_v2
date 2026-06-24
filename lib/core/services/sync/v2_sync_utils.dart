import 'dart:convert';

abstract final class V2SyncUtils {
  static String nowIso() => DateTime.now().toUtc().toIso8601String();

  static String? asString(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int asInt(dynamic value, {int fallback = 0}) {
    if (value == null) {
      return fallback;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse(value.toString()) ?? fallback;
  }

  static double asDouble(dynamic value, {double fallback = 0}) {
    if (value == null) {
      return fallback;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? fallback;
  }

  static int moneyToMinor(dynamic value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    final normalized = value.toString().replaceAll(',', '').trim();
    return num.tryParse(normalized)?.round() ?? 0;
  }

  static bool intToBoolFlag(dynamic value, {bool defaultValue = false}) {
    if (value == null) {
      return defaultValue;
    }
    if (value is bool) {
      return value;
    }
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) {
      return defaultValue;
    }
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'active';
  }

  static Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  static List<Map<String, dynamic>> asMapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  static List<String> asStringList(dynamic value) {
    if (value == null) {
      return const <String>[];
    }
    if (value is List) {
      return value
          .map(asString)
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final text = asString(value);
    if (text == null) {
      return const <String>[];
    }

    final decoded = decodeLooseJson(text);
    if (decoded is List) {
      return decoded
          .map(asString)
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static dynamic decodeLooseJson(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return value;
    }
    if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
      return value;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return value;
    }
  }

  static String? encodeJson(dynamic value) {
    if (value == null) {
      return null;
    }
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }
}
