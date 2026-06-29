import 'dart:convert';

class PrinterPaperProfile {
  const PrinterPaperProfile({
    required this.id,
    required this.label,
    required this.widthMm,
    required this.defaultCharsPerLine,
    required this.isRoll,
    required this.supportsAutoCut,
  });

  final String id;
  final String label;
  final double widthMm;
  final int defaultCharsPerLine;
  final bool isRoll;
  final bool supportsAutoCut;
}

const kPrinterPaperProfiles = <PrinterPaperProfile>[
  PrinterPaperProfile(
    id: 'thermal_50',
    label: 'Thermal 50mm',
    widthMm: 50,
    defaultCharsPerLine: 24,
    isRoll: true,
    supportsAutoCut: false,
  ),
  PrinterPaperProfile(
    id: 'thermal_58',
    label: 'Thermal 58mm',
    widthMm: 58,
    defaultCharsPerLine: 32,
    isRoll: true,
    supportsAutoCut: false,
  ),
  PrinterPaperProfile(
    id: 'thermal_76',
    label: 'Thermal 76mm',
    widthMm: 76,
    defaultCharsPerLine: 42,
    isRoll: true,
    supportsAutoCut: true,
  ),
  PrinterPaperProfile(
    id: 'thermal_80',
    label: 'Thermal 80mm',
    widthMm: 80,
    defaultCharsPerLine: 48,
    isRoll: true,
    supportsAutoCut: true,
  ),
  PrinterPaperProfile(
    id: 'sheet_a5',
    label: 'Sheet A5',
    widthMm: 148,
    defaultCharsPerLine: 64,
    isRoll: false,
    supportsAutoCut: false,
  ),
  PrinterPaperProfile(
    id: 'sheet_a4',
    label: 'Sheet A4',
    widthMm: 210,
    defaultCharsPerLine: 90,
    isRoll: false,
    supportsAutoCut: false,
  ),
  PrinterPaperProfile(
    id: 'custom_roll',
    label: 'Custom Roll',
    widthMm: 58,
    defaultCharsPerLine: 32,
    isRoll: true,
    supportsAutoCut: true,
  ),
];

const kPrinterRoles = <String>['cashier', 'kitchen', 'label', 'report'];

class PrinterDeviceConfig {
  const PrinterDeviceConfig({
    required this.id,
    required this.printerKey,
    required this.displayName,
    required this.connectionType,
    required this.paperProfileId,
    required this.networkPort,
    required this.fontScale,
    required this.lineSpacing,
    required this.supportsAutoCut,
    required this.roles,
    required this.roleBrandFilters,
    required this.isActive,
    this.connectionTarget,
    this.customWidthMm,
    this.charsPerLine,
    this.notes,
    this.lastTestedAt,
  });

  final int id;
  final String printerKey;
  final String displayName;
  final String connectionType;
  final String? connectionTarget;
  final int networkPort;
  final String paperProfileId;
  final double? customWidthMm;
  final int? charsPerLine;
  final double fontScale;
  final double lineSpacing;
  final bool supportsAutoCut;
  final List<String> roles;
  final Map<String, List<String>> roleBrandFilters;
  final String? notes;
  final bool isActive;
  final String? lastTestedAt;

  PrinterPaperProfile get paperProfile =>
      kPrinterPaperProfiles.firstWhere((profile) => profile.id == paperProfileId,
          orElse: () => kPrinterPaperProfiles[1]);

  double get effectiveWidthMm =>
      paperProfileId == 'custom_roll' ? (customWidthMm ?? paperProfile.widthMm) : paperProfile.widthMm;

  int get effectiveCharsPerLine =>
      (charsPerLine != null && charsPerLine! > 0) ? charsPerLine! : paperProfile.defaultCharsPerLine;

  factory PrinterDeviceConfig.fromRow(Map<String, Object?> row) {
    return PrinterDeviceConfig(
      id: _asInt(row['id']) ?? 0,
      printerKey: row['printer_key']?.toString() ?? '',
      displayName: row['display_name']?.toString() ?? 'Printer',
      connectionType: row['connection_type']?.toString() ?? 'system',
      connectionTarget: row['connection_target']?.toString(),
      networkPort: _asInt(row['network_port']) ?? 9100,
      paperProfileId: row['paper_profile_id']?.toString() ?? 'thermal_58',
      customWidthMm: _asDouble(row['custom_width_mm']),
      charsPerLine: _asInt(row['chars_per_line']),
      fontScale: _asDouble(row['font_scale']) ?? 1,
      lineSpacing: _asDouble(row['line_spacing']) ?? 1,
      supportsAutoCut: _asBool(row['supports_autocut']),
      roles: _decodeStringList(row['roles_json']),
      roleBrandFilters: _decodeRoleBrandFilters(row['role_brand_filters_json']),
      notes: row['notes']?.toString(),
      isActive: _asBool(row['is_active'], defaultValue: true),
      lastTestedAt: row['last_tested_at']?.toString(),
    );
  }

  PrinterDeviceConfig copyWith({
    int? id,
    String? printerKey,
    String? displayName,
    String? connectionType,
    String? connectionTarget,
    int? networkPort,
    String? paperProfileId,
    double? customWidthMm,
    int? charsPerLine,
    double? fontScale,
    double? lineSpacing,
    bool? supportsAutoCut,
    List<String>? roles,
    Map<String, List<String>>? roleBrandFilters,
    String? notes,
    bool? isActive,
    String? lastTestedAt,
  }) {
    return PrinterDeviceConfig(
      id: id ?? this.id,
      printerKey: printerKey ?? this.printerKey,
      displayName: displayName ?? this.displayName,
      connectionType: connectionType ?? this.connectionType,
      connectionTarget: connectionTarget ?? this.connectionTarget,
      networkPort: networkPort ?? this.networkPort,
      paperProfileId: paperProfileId ?? this.paperProfileId,
      customWidthMm: customWidthMm ?? this.customWidthMm,
      charsPerLine: charsPerLine ?? this.charsPerLine,
      fontScale: fontScale ?? this.fontScale,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      supportsAutoCut: supportsAutoCut ?? this.supportsAutoCut,
      roles: roles ?? this.roles,
      roleBrandFilters: roleBrandFilters ?? this.roleBrandFilters,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      lastTestedAt: lastTestedAt ?? this.lastTestedAt,
    );
  }
}

class PrinterSettingsState {
  const PrinterSettingsState({
    required this.isLoading,
    required this.isSaving,
    required this.printers,
    required this.availableBrands,
    this.lastDispatchResult,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final List<PrinterDeviceConfig> printers;
  final List<String> availableBrands;
  final String? lastDispatchResult;
  final String? errorMessage;

  PrinterSettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<PrinterDeviceConfig>? printers,
    List<String>? availableBrands,
    String? lastDispatchResult,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrinterSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      printers: printers ?? this.printers,
      availableBrands: availableBrands ?? this.availableBrands,
      lastDispatchResult: lastDispatchResult ?? this.lastDispatchResult,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString().split('.').first);
}

double? _asDouble(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _asBool(Object? value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is int) return value == 1;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return defaultValue;
  return normalized == '1' || normalized == 'true' || normalized == 'yes' || normalized == 'on';
}

List<String> _decodeStringList(Object? raw) {
  final text = raw?.toString();
  if (text == null || text.isEmpty) {
    return const <String>[];
  }
  try {
    final dynamic parsed = _jsonDecode(text);
    if (parsed is List) {
      return parsed.map((e) => e.toString()).toList(growable: false);
    }
  } catch (_) {}
  return const <String>[];
}

Map<String, List<String>> _decodeRoleBrandFilters(Object? raw) {
  final text = raw?.toString();
  if (text == null || text.isEmpty) {
    return const <String, List<String>>{};
  }
  try {
    final dynamic parsed = _jsonDecode(text);
    if (parsed is Map) {
      return parsed.map(
        (key, value) => MapEntry(
          key.toString(),
          value is List
              ? value.map((e) => e.toString()).toList(growable: false)
              : <String>[],
        ),
      );
    }
  } catch (_) {}
  return const <String, List<String>>{};
}

dynamic _jsonDecode(String text) {
  return jsonDecode(text);
}
