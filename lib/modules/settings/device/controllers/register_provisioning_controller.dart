import 'package:flutter/foundation.dart';

import '../../../../../core/network/v2_api_client.dart';
import '../../../../../core/services/local/database_service.dart';
import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../models/register_provisioning_models.dart';

class RegisterProvisioningController {
  RegisterProvisioningController._() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(
      _onSessionChanged,
    );
  }

  static final RegisterProvisioningController instance =
      RegisterProvisioningController._();

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
      snapshotNotifier.value = const RegisterProvisioningSnapshot(
        isLoading: false,
        isSaving: false,
        registers: <RegisterProvisioningRecord>[],
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
              .map(
                (row) =>
                    row.map((key, value) => MapEntry(key.toString(), value)),
              )
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
