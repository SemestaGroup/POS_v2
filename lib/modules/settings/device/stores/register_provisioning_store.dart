import 'package:flutter/foundation.dart';

import '../../../../../core/network/v2_api_client.dart';
import '../../../../../core/services/local/database_service.dart';
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

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString());
  }

  static bool _asBool(Object? value, {required bool defaultValue}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return defaultValue;
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
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

class RegisterProvisioningStore {
  RegisterProvisioningStore._() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(_onSessionChanged);
  }

  static final RegisterProvisioningStore instance = RegisterProvisioningStore._();

  final ValueNotifier<RegisterProvisioningSnapshot> snapshotNotifier =
      ValueNotifier<RegisterProvisioningSnapshot>(
        const RegisterProvisioningSnapshot(
          isLoading: false,
          isSaving: false,
          registers: <RegisterProvisioningRecord>[],
        ),
      );

  void _onSessionChanged() {
    refresh(silent: true);
  }

  Future<void> refresh({bool silent = false}) async {
    final session = PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();

    if (session == null) {
      snapshotNotifier.value = RegisterProvisioningSnapshot(
        isLoading: false,
        isSaving: false,
        registers: const <RegisterProvisioningRecord>[],
        session: null,
        errorMessage: 'No active session found.',
      );
      return;
    }

    if (!silent) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: true,
        session: session,
        clearError: true,
      );
    }

    final actingStaffId = int.tryParse(session.staffId ?? '');
    if (actingStaffId == null || actingStaffId <= 0) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        session: session,
        errorMessage:
            'Current account does not have a mapped staff_id for register provisioning.',
      );
      return;
    }

    try {
      final envelope = await V2ApiClient(
        baseUrl: session.baseUrl,
        authToken: session.authToken,
      ).getEnvelope(
        'api/v2/backoffice/pos-registers',
        query: <String, dynamic>{
          'acting_staff_id': actingStaffId,
          if (session.locationId.isNotEmpty) 'location_id': session.locationId,
          'limit': 200,
          'page': 1,
        },
      );

      final rawRows = envelope['data'];
      final rows = rawRows is List
          ? rawRows
              .whereType<Map>()
              .map((row) => row.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ))
              .toList(growable: false)
          : const <Map<String, dynamic>>[];

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        session: session,
        registers: rows.map(RegisterProvisioningRecord.fromMap).toList(),
        clearError: true,
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        session: session,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> createRegister({
    required String locationId,
    required String registerId,
    required String registerName,
    String? deviceIdHint,
    String? notes,
    required bool isActive,
  }) async {
    final session = await _requireSession();
    final actingStaffId = _requireActingStaffId(session);
    await _runMutation(() async {
      await V2ApiClient(
        baseUrl: session.baseUrl,
        authToken: session.authToken,
      ).postEnvelope(
        'api/v2/backoffice/pos-registers',
        body: <String, dynamic>{
          'acting_staff_id': actingStaffId,
          'location_id': int.tryParse(locationId) ?? 0,
          'register_id': registerId.trim(),
          'register_name': registerName.trim(),
          'device_id_hint': deviceIdHint?.trim(),
          'notes': notes?.trim(),
          'active': isActive,
        },
      );
    });
  }

  Future<void> updateRegister({
    required int id,
    required String locationId,
    required String registerId,
    required String registerName,
    String? deviceIdHint,
    String? notes,
    required bool isActive,
  }) async {
    final session = await _requireSession();
    final actingStaffId = _requireActingStaffId(session);
    await _runMutation(() async {
      await V2ApiClient(
        baseUrl: session.baseUrl,
        authToken: session.authToken,
      ).putEnvelope(
        'api/v2/backoffice/pos-registers/$id',
        body: <String, dynamic>{
          'acting_staff_id': actingStaffId,
          'location_id': int.tryParse(locationId) ?? 0,
          'register_id': registerId.trim(),
          'register_name': registerName.trim(),
          'device_id_hint': deviceIdHint?.trim(),
          'notes': notes?.trim(),
          'active': isActive,
        },
      );
    });
  }

  Future<void> deleteRegister(int id) async {
    final session = await _requireSession();
    final actingStaffId = _requireActingStaffId(session);
    await _runMutation(() async {
      await V2ApiClient(
        baseUrl: session.baseUrl,
        authToken: session.authToken,
      ).deleteEnvelope(
        'api/v2/backoffice/pos-registers/$id',
        body: <String, dynamic>{'acting_staff_id': actingStaffId},
      );
    });
  }

  Future<void> assignCurrentDeviceRegister(String? registerId) async {
    final session = await _requireSession();
    final staffId = _requireActingStaffId(session);
    final deviceId = (session.deviceId ?? '').trim();
    if (deviceId.isEmpty) {
      throw Exception('This session does not have a valid device_id.');
    }

    await _runMutation(() async {
      await V2ApiClient(
        baseUrl: session.baseUrl,
        authToken: session.authToken,
      ).postEnvelope(
        'api/v2/pos-auth/session-touch',
        body: <String, dynamic>{
          'staff_id': staffId,
          'device_id': deviceId,
          'register_id': registerId?.trim() ?? '',
        },
      );

      await DatabaseService.instance.transaction((txn) async {
        final now = DateTime.now().toUtc().toIso8601String();
        await txn.update(
          'app_session',
          <String, Object?>{
            'register_id': _normalizeNullable(registerId),
            'updated_at': now,
          },
          where: 'tenant_id = ? AND status = ?',
          whereArgs: <Object?>[session.tenantId, 'active'],
        );
        await txn.update(
          'device_session',
          <String, Object?>{
            'register_id': _normalizeNullable(registerId),
            'updated_at': now,
          },
          where: 'tenant_id = ? AND device_id = ? AND status = ?',
          whereArgs: <Object?>[session.tenantId, deviceId, 'active'],
        );
      });

      await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    });
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isSaving: true,
      clearError: true,
    );
    try {
      await action();
      await refresh(silent: true);
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isSaving: false,
        clearError: true,
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isSaving: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<PosV2RuntimeSession> _requireSession() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found.');
    }
    return session;
  }

  int _requireActingStaffId(PosV2RuntimeSession session) {
    final actingStaffId = int.tryParse(session.staffId ?? '');
    if (actingStaffId == null || actingStaffId <= 0) {
      throw Exception(
        'This account does not have a valid staff_id for register provisioning.',
      );
    }
    return actingStaffId;
  }

  String? _normalizeNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
