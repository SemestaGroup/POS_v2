import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';

class RegisterProvisioningRecord {
  const RegisterProvisioningRecord({
    required this.id,
    required this.locationId,
    required this.registerId,
    required this.registerName,
    required this.isActive,
    this.deviceIdHint,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String locationId;
  final String registerId;
  final String registerName;
  final bool isActive;
  final String? deviceIdHint;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  factory RegisterProvisioningRecord.fromMap(Map<String, dynamic> row) {
    return RegisterProvisioningRecord(
      id: _asInt(row['id']) ?? 0,
      locationId: row['location_id']?.toString() ?? '',
      registerId: row['register_id']?.toString() ?? '',
      registerName: row['register_name']?.toString() ?? '',
      isActive: _asBool(row['active'], defaultValue: true),
      deviceIdHint: row['device_id_hint']?.toString(),
      notes: row['notes']?.toString(),
      createdAt: row['created_at']?.toString(),
      updatedAt: row['updated_at']?.toString(),
    );
  }
}

class RegisterProvisioningSnapshot {
  const RegisterProvisioningSnapshot({
    required this.isLoading,
    required this.isSaving,
    required this.registers,
    this.session,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final List<RegisterProvisioningRecord> registers;
  final PosV2RuntimeSession? session;
  final String? errorMessage;

  String? get currentRegisterId => session?.registerId;

  RegisterProvisioningSnapshot copyWith({
    bool? isLoading,
    bool? isSaving,
    List<RegisterProvisioningRecord>? registers,
    PosV2RuntimeSession? session,
    bool keepSession = true,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RegisterProvisioningSnapshot(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      registers: registers ?? this.registers,
      session: keepSession ? (session ?? this.session) : session,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

bool _asBool(Object? value, {required bool defaultValue}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return defaultValue;
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}
