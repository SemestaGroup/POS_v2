import 'package:flutter/foundation.dart';

import '../../../../../app/role_access/role_manager.dart';
import '../../../../../core/network/v2_api_client.dart';
import '../../../../../core/services/local/database_service.dart';
import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../models/profile_settings_state.dart';

class ProfileSettingsController {
  ProfileSettingsController._();

  static final ProfileSettingsController instance =
      ProfileSettingsController._();

  final ValueNotifier<ProfileSettingsState> stateNotifier =
      ValueNotifier<ProfileSettingsState>(
    const ProfileSettingsState(isLoading: false, isLoggingOut: false),
  );

  Future<void> refresh() async {
    stateNotifier.value = stateNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );
    try {
      final session = PosV2RuntimeSessionStore.instance.currentSession ??
          await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        session: session,
        roleLabel: session == null
            ? null
            : RoleManager.roleToString(RoleManager.fromCode(session.staffRoleCode)),
      );
    } catch (error) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> logoutCurrentDevice() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found.');
    }

    stateNotifier.value = stateNotifier.value.copyWith(
      isLoggingOut: true,
      clearError: true,
    );
    try {
      await V2ApiClient(baseUrl: session.baseUrl, authToken: session.authToken)
          .postEnvelope(
        'api/v2/pos-auth/logout',
        body: <String, dynamic>{
          'staff_id': int.tryParse(session.staffId ?? ''),
          'device_id': session.deviceId,
          'reason': 'Logout from profile settings',
        },
      );
    } catch (_) {}

    await DatabaseService.instance.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'app_session',
        <String, Object?>{
          'status': 'logged_out',
          'logged_out_at': now,
          'updated_at': now,
        },
        where: 'status = ?',
        whereArgs: const <Object?>['active'],
      );
      await txn.update(
        'device_session',
        <String, Object?>{
          'status': 'logged_out',
          'updated_at': now,
        },
        where: 'tenant_id = ? AND device_id = ? AND status = ?',
        whereArgs: <Object?>[session.tenantId, session.deviceId, 'active'],
      );
    });

    PosV2RuntimeSessionStore.instance.setSession(null);
    RoleManager.changeRole(AppRole.cashier);
    stateNotifier.value = stateNotifier.value.copyWith(
      isLoggingOut: false,
      keepSession: false,
      session: null,
      roleLabel: null,
    );
  }
}
