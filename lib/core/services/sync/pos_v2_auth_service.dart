import 'dart:math';

import '../../../app/role_access/role_manager.dart';
import '../../constants/app_constants.dart';
import '../../network/v2_api_client.dart';
import '../../network/v2_api_fixed_auth.dart';
import 'base_v2_sync_adapter.dart';
import 'bootstrap_sync_adapter.dart';
import 'pos_v2_runtime_session_store.dart';
import 'v2_sync_context.dart';
import 'v2_sync_utils.dart';

class PosV2LoginResult {
  const PosV2LoginResult({required this.session});

  final PosV2RuntimeSession session;
}

class PosV2AuthService extends BaseV2SyncAdapter {
  PosV2AuthService({super.databaseService});

  final BootstrapSyncAdapter _bootstrapSync = BootstrapSyncAdapter();

  Future<void> logoutLocationAndClearLocalData({
    String reason = 'Logout location and clear local data',
  }) async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();

    if (session != null) {
      try {
        final sessionCode = await resolveActiveDeviceSessionCode(session);
        await V2ApiClient(
          baseUrl: session.baseUrl,
          authToken: session.authToken,
        ).postEnvelope(
          'api/v2/pos-auth/logout',
          body: <String, dynamic>{
            'session_code': sessionCode,
            'staff_id': int.tryParse(session.staffId ?? ''),
            'device_id': session.deviceId,
            'reason': reason,
          },
        );
      } catch (_) {
        // Keep logout resilient even if remote endpoint is unavailable.
      }
    }

    await databaseService.resetDatabase();
    PosV2RuntimeSessionStore.instance.setSession(null);
    RoleManager.changeRole(AppRole.cashier);
  }

  Future<void> forceLogoutLocally() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session != null) {
      final now = V2SyncUtils.nowIso();
      await databaseService.transaction((txn) async {
        await txn.update(
          'app_session',
          <String, Object?>{
            'status': 'forced_out',
            'logged_out_at': now,
            'updated_at': now,
          },
          where: 'tenant_id = ? AND status = ?',
          whereArgs: <Object?>[session.tenantId, 'active'],
        );
      });
    }

    PosV2RuntimeSessionStore.instance.wasForcedOut = true;
    PosV2RuntimeSessionStore.instance.setSession(null);
    RoleManager.changeRole(AppRole.cashier);
  }

  Future<String?> resolveActiveDeviceSessionCode(
    PosV2RuntimeSession session,
  ) async {
    if (session.deviceId == null || session.deviceId!.trim().isEmpty) {
      return null;
    }

    final rows = await databaseService.query(
      'device_session',
      columns: const <String>['session_code'],
      where: 'tenant_id = ? AND device_id = ? AND status = ?',
      whereArgs: <Object?>[
        session.tenantId,
        session.deviceId!.trim(),
        'active',
      ],
      orderBy: 'updated_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return V2SyncUtils.asString(rows.first['session_code']);
  }

  String resolveRoleCode(
    Map<String, dynamic>? staff, {
    String? fallbackRoleCode,
  }) {
    final rawRoleCode = V2SyncUtils.asString(staff?['role_code']);
    final rawRoleName = V2SyncUtils.asString(
      staff?['role_name'] ?? staff?['role'],
    );

    // Role IDs are tenant-configurable (for example, a cashier can have ID
    // "2" in one tenant and "3" in another). Only names/codes have a stable
    // application meaning; never infer a role from a numeric database ID.
    for (final rawRole in [rawRoleCode, rawRoleName]) {
      switch (rawRole?.trim().toLowerCase()) {
        case 'owner':
        case 'admin':
          return 'owner';
        case 'supervisor':
        case 'spv':
          return 'supervisor';
        case 'kitchen':
        case 'dapur':
          return 'kitchen';
        case 'programmer':
        case 'developer':
          return 'programmer';
        case 'cashier':
        case 'kasir':
          return 'cashier';
      }
    }

    return fallbackRoleCode?.trim().isNotEmpty == true
        ? fallbackRoleCode!.trim()
        : 'cashier';
  }

  Future<PosV2RuntimeSession> discoverAndLoginOnly({
    required String centralBaseUrl,
    required String email,
    required String password,
    String? deviceId,
    String? registerId,
    bool forceLogoutOtherSession = false,
  }) async {
    final resolvedDeviceId = await _resolveOrCreateDeviceId(deviceId);
    final discoverClient = V2ApiClient(
      baseUrl: centralBaseUrl,
      authToken: kFlinkV2FixedAuthToken,
    );
    final discoverEnvelope = await discoverClient.postEnvelope(
      'api/v2/pos-auth/discover',
      body: <String, dynamic>{'email': email.trim()},
    );
    final discoverData =
        V2SyncUtils.asMap(discoverEnvelope['data']) ??
        const <String, dynamic>{};
    final tenantRows = V2SyncUtils.asMapList(discoverData['tenants']);
    if (tenantRows.isEmpty) {
      throw Exception('No tenant was discovered for this account.');
    }

    await _persistDiscoveredTenants(email: email, tenantRows: tenantRows);
    final selectedTenant = _pickDiscoveredTenant(tenantRows);
    if (selectedTenant == null) {
      throw Exception('No POS-enabled tenant was available for this account.');
    }

    final tenantBaseUrl =
        V2SyncUtils.asString(selectedTenant['base_url'])?.trim() ?? '';
    if (tenantBaseUrl.isEmpty) {
      throw Exception('Discovered tenant did not return a valid base_url.');
    }

    return loginOnly(
      loginBaseUrl: tenantBaseUrl,
      email: email,
      password: password,
      deviceId: resolvedDeviceId,
      registerId: registerId,
      discoveredTenant: selectedTenant,
      forceLogoutOtherSession: forceLogoutOtherSession,
    );
  }

  Future<PosV2RuntimeSession> loginOnly({
    required String loginBaseUrl,
    required String email,
    required String password,
    required String deviceId,
    String? registerId,
    Map<String, dynamic>? discoveredTenant,
    bool forceLogoutOtherSession = false,
  }) async {
    final loginClient = V2ApiClient(
      baseUrl: loginBaseUrl,
      authToken: kFlinkV2FixedAuthToken,
    );
    if (forceLogoutOtherSession) {
      try {
        await loginClient.postEnvelope(
          'api/v2/pos-auth/force-logout',
          body: <String, dynamic>{
            'email': email.trim(),
            'device_id': deviceId.trim(),
            'reason': 'Force logout previous session',
          },
        );
      } catch (_) {
        // Keep login resilient even if force-logout endpoint is unavailable.
      }
    }

    final loginEnvelope = await loginClient.postEnvelope(
      'api/v2/pos-auth/login',
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'device_id': deviceId.trim(),
        'app_version': AppConstants.appVersion,
        'force_logout_other_session': forceLogoutOtherSession ? 1 : 0,
        'force_logout_other_device': forceLogoutOtherSession ? 1 : 0,
        'force_logout': forceLogoutOtherSession ? 1 : 0,
      },
    );

    final loginData =
        V2SyncUtils.asMap(loginEnvelope['data']) ?? const <String, dynamic>{};
    final staffData = V2SyncUtils.asMap(loginData['staff']);
    // Some POS-auth responses put identity under `staff`, while role fields
    // remain at the top level. Merge both shapes so a role from the response
    // is never lost merely because `staff` contains an id or email.
    final staff = <String, dynamic>{...loginData, ...?staffData};
    final deviceSession =
        V2SyncUtils.asMap(loginData['device_session']) ??
        const <String, dynamic>{};
    final policies =
        V2SyncUtils.asMap(loginData['policies']) ?? const <String, dynamic>{};
    final resolvedRoleCode = resolveRoleCode(
      staff,
      fallbackRoleCode: V2SyncUtils.asString(discoveredTenant?['role_code']),
    );
    final effectiveBaseUrl = _resolveTenantBaseUrl(
      requestBaseUrl: loginBaseUrl,
      responseBaseUrl: V2SyncUtils.asString(loginData['base_url']),
    );
    final effectiveToken =
        V2SyncUtils.asString(loginData['auth_token']) ?? kFlinkV2FixedAuthToken;
    final locationId = V2SyncUtils.asString(loginData['location_id']) ?? '';
    final effectiveRegisterId = _resolveRegisterId(
      explicitRegisterId: registerId,
      deviceId: deviceId,
      responseRegisterId: V2SyncUtils.asString(deviceSession['register_id']),
    );
    if (locationId.isEmpty) {
      throw Exception(
        'Login succeeded but no location_id was resolved for this account. Configure the staff POS location before continuing.',
      );
    }
    final syncContext = V2SyncContext(
      baseUrl: effectiveBaseUrl,
      authToken: effectiveToken,
      locationId: locationId,
      tenantName: V2SyncUtils.asString(loginData['tenant_name']),
      deviceId: deviceId.trim(),
      registerId: effectiveRegisterId,
      staffId: V2SyncUtils.asString(staff['staff_id']),
      staffEmail: V2SyncUtils.asString(staff['email']) ?? email.trim(),
      staffFullName: V2SyncUtils.asString(staff['full_name']),
    );

    await databaseService.transaction((txn) async {
      final now = V2SyncUtils.nowIso();
      final tenantId = await ensureTenantId(
        txn,
        syncContext,
        tenantCode: V2SyncUtils.asString(discoveredTenant?['tenant_code']),
        tenantName:
            V2SyncUtils.asString(loginData['tenant_name']) ??
            V2SyncUtils.asString(discoveredTenant?['tenant_name']),
        roleCode: resolvedRoleCode,
      );

      await txn.update(
        'app_tenant',
        <String, Object?>{
          'tenant_remote_id': V2SyncUtils.asString(
            discoveredTenant?['tenant_id'],
          ),
          'tenant_code': V2SyncUtils.asString(discoveredTenant?['tenant_code']),
          'tenant_name':
              V2SyncUtils.asString(loginData['tenant_name']) ??
              V2SyncUtils.asString(discoveredTenant?['tenant_name']),
          // Keep the tenant-login location as the canonical runtime location.
          // Discover location_id can point to a central mapping record and may
          // differ from the tenant-local location_id returned by login.
          'location_id': locationId,
          'base_url': effectiveBaseUrl,
          'user_type': V2SyncUtils.asString(discoveredTenant?['user_type']),
          'role_code': resolvedRoleCode,
          'can_pos_login':
              V2SyncUtils.intToBoolFlag(
                discoveredTenant?['can_pos_login'],
                defaultValue: true,
              )
              ? 1
              : 0,
          'is_default':
              V2SyncUtils.intToBoolFlag(discoveredTenant?['is_default'])
              ? 1
              : 0,
          'is_active': 1,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[tenantId],
      );

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

      int? staffLocalId;
      final staffRemoteId = V2SyncUtils.asString(staff['staff_id']);
      final staffEmail = V2SyncUtils.asString(staff['email']) ?? email.trim();
      final staffWhere = staffRemoteId != null
          ? 'tenant_id = ? AND remote_id = ?'
          : 'tenant_id = ? AND email = ?';
      final staffWhereArgs = staffRemoteId != null
          ? <Object?>[tenantId, staffRemoteId]
          : <Object?>[tenantId, staffEmail];
      staffLocalId = await databaseService.upsertByUnique(
        txn,
        'staff',
        where: staffWhere,
        whereArgs: staffWhereArgs,
        insertValues: <String, Object?>{
          'tenant_id': tenantId,
          'remote_id': staffRemoteId,
          'role_remote_id': V2SyncUtils.asString(staff['role_id']),
          'role_code': resolvedRoleCode,
          'role_name':
              V2SyncUtils.asString(staff['role_name'] ?? staff['role']) ??
              resolvedRoleCode,
          'full_name': V2SyncUtils.asString(staff['full_name']),
          'email': staffEmail,
          'is_active':
              V2SyncUtils.intToBoolFlag(staff['active'], defaultValue: true)
              ? 1
              : 0,
          'last_login_at': now,
          'raw_payload_json': V2SyncUtils.encodeJson(staff),
          'last_synced_at': now,
          'created_at': now,
          'updated_at': now,
        },
        updateValues: <String, Object?>{
          'remote_id': staffRemoteId,
          'role_remote_id': V2SyncUtils.asString(staff['role_id']),
          'role_code': resolvedRoleCode,
          'role_name':
              V2SyncUtils.asString(staff['role_name'] ?? staff['role']) ??
              resolvedRoleCode,
          'full_name': V2SyncUtils.asString(staff['full_name']),
          'email': staffEmail,
          'is_active':
              V2SyncUtils.intToBoolFlag(staff['active'], defaultValue: true)
              ? 1
              : 0,
          'last_login_at': now,
          'raw_payload_json': V2SyncUtils.encodeJson(staff),
          'last_synced_at': now,
          'updated_at': now,
          'deleted_at': null,
        },
      );

      for (final entry in policies.entries) {
        await databaseService.upsertByUnique(
          txn,
          'policy_snapshot',
          where: 'tenant_id = ? AND policy_name = ?',
          whereArgs: <Object?>[tenantId, entry.key],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'policy_name': entry.key,
            'source_endpoint': 'pos-auth/login',
            'policy_json': V2SyncUtils.encodeJson(entry.value),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'source_endpoint': 'pos-auth/login',
            'policy_json': V2SyncUtils.encodeJson(entry.value),
            'last_synced_at': now,
            'updated_at': now,
          },
        );
      }

      await databaseService.upsertByUnique(
        txn,
        'app_session',
        where: 'tenant_id = ? AND staff_email = ? AND status = ?',
        whereArgs: <Object?>[tenantId, staffEmail, 'active'],
        insertValues: <String, Object?>{
          'tenant_id': tenantId,
          'staff_id': staffLocalId,
          'location_id': locationId,
          'staff_remote_id': staffRemoteId,
          'staff_email': staffEmail,
          'staff_full_name': V2SyncUtils.asString(staff['full_name']),
          'staff_role_code': resolvedRoleCode,
          'base_url': syncContext.normalizedBaseUrl,
          'auth_token': effectiveToken,
          'device_id': deviceId.trim(),
          'register_id': effectiveRegisterId,
          'status': 'active',
          'logged_in_at': now,
          'last_seen_at': now,
          'created_at': now,
          'updated_at': now,
        },
        updateValues: <String, Object?>{
          'staff_id': staffLocalId,
          'location_id': locationId,
          'staff_remote_id': staffRemoteId,
          'staff_full_name': V2SyncUtils.asString(staff['full_name']),
          'staff_role_code': resolvedRoleCode,
          'base_url': syncContext.normalizedBaseUrl,
          'auth_token': effectiveToken,
          'device_id': deviceId.trim(),
          'register_id': effectiveRegisterId,
          'last_seen_at': now,
          'updated_at': now,
        },
      );
    });

    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      throw Exception('Failed to restore runtime session after login');
    }
    return session;
  }

  Future<void> runBootstrapSync(PosV2RuntimeSession session) async {
    final syncContext = session.toSyncContext();
    await _bootstrapSync.sync(syncContext);
    await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
  }

  Future<PosV2LoginResult> loginAndSyncBootstrap({
    required String loginBaseUrl,
    required String email,
    required String password,
    required String deviceId,
    String? registerId,
    bool forceLogoutOtherSession = false,
  }) async {
    final session = await loginOnly(
      loginBaseUrl: loginBaseUrl,
      email: email,
      password: password,
      deviceId: deviceId,
      registerId: registerId,
      forceLogoutOtherSession: forceLogoutOtherSession,
    );
    await runBootstrapSync(session);
    return PosV2LoginResult(session: session);
  }

  Future<PosV2RuntimeSession> pinLoginOnly({
    required String tenantBaseUrl,
    required String email,
    required String pin,
    required String deviceId,
    String? registerId,
    String? staffId,
    String? staffRoleCode,
    String? actingStaffId,
    bool forceLogoutOtherSession = false,
  }) async {
    final resolvedDeviceId = await _resolveOrCreateDeviceId(deviceId);
    final currentSession = PosV2RuntimeSessionStore.instance.currentSession;
    final effectiveActingStaffId = actingStaffId ?? currentSession?.staffId;
    final client = V2ApiClient(
      baseUrl: tenantBaseUrl,
      authToken: kFlinkV2FixedAuthToken,
    );

    if (forceLogoutOtherSession) {
      try {
        final forceLogoutBody = <String, dynamic>{
          'email': email.trim(),
          'reason': 'Force logout previous session for staff switch',
          'force_all': 1,
          'force_all_devices': 1,
          'force': 1,
        };
        final parsedStaffId = int.tryParse(staffId ?? '');
        if (parsedStaffId != null) {
          forceLogoutBody['staff_id'] = parsedStaffId;
        }
        final parsedActingId = int.tryParse(effectiveActingStaffId ?? '');
        if (parsedActingId != null) {
          forceLogoutBody['acting_staff_id'] = parsedActingId;
        }

        await client.postEnvelope(
          'api/v2/pos-auth/force-logout',
          body: forceLogoutBody,
        );
      } catch (_) {
        // Keep login resilient even if force-logout endpoint is unavailable.
      }
    }

    final loginEnvelope = await client.postEnvelope(
      'api/v2/pos-auth/pin-login',
      body: <String, dynamic>{
        'email': email.trim(),
        'pin': pin.trim(),
        'device_id': resolvedDeviceId,
        'app_version': AppConstants.appVersion,
        'force_logout_other_session': forceLogoutOtherSession ? 1 : 0,
        'force_logout_other_device': forceLogoutOtherSession ? 1 : 0,
        'force_logout': forceLogoutOtherSession ? 1 : 0,
      },
    );

    final loginData =
        V2SyncUtils.asMap(loginEnvelope['data']) ?? const <String, dynamic>{};
    final staffData = V2SyncUtils.asMap(loginData['staff']);
    // Role information may be returned beside `staff` rather than inside it.
    // Keep the nested identity values as the priority while retaining those
    // top-level role fields.
    final staff = <String, dynamic>{...loginData, ...?staffData};
    final deviceSession =
        V2SyncUtils.asMap(loginData['device_session']) ??
        const <String, dynamic>{};
    final effectiveBaseUrl = _resolveTenantBaseUrl(
      requestBaseUrl: tenantBaseUrl,
      responseBaseUrl: V2SyncUtils.asString(loginData['base_url']),
    );
    final runtimeSession = PosV2RuntimeSessionStore.instance.currentSession;
    final resolvedRoleCode = resolveRoleCode(
      staff,
      // If an older backend omits role fields entirely, retain the role of the
      // selected, locally cached staff record—not the account just replaced.
      fallbackRoleCode: staffRoleCode ?? runtimeSession?.staffRoleCode,
    );
    final effectiveToken =
        V2SyncUtils.asString(loginData['auth_token']) ?? kFlinkV2FixedAuthToken;
    final locationId =
        V2SyncUtils.asString(loginData['location_id']) ??
        runtimeSession?.locationId ??
        '';
    final effectiveRegisterId = _resolveRegisterId(
      explicitRegisterId: registerId ?? runtimeSession?.registerId,
      deviceId: deviceId,
      responseRegisterId: V2SyncUtils.asString(deviceSession['register_id']),
    );
    if (locationId.isEmpty) {
      throw Exception(
        'PIN login succeeded but no location_id was resolved for this account. Configure the staff POS location before continuing.',
      );
    }
    final syncContext = V2SyncContext(
      baseUrl: effectiveBaseUrl,
      authToken: effectiveToken,
      locationId: locationId,
      tenantName: runtimeSession?.tenantName,
      tenantCode: runtimeSession?.tenantCode,
      deviceId: deviceId.trim(),
      registerId: effectiveRegisterId,
      staffId: V2SyncUtils.asString(staff['staff_id']),
      staffEmail: V2SyncUtils.asString(staff['email']) ?? email.trim(),
      staffFullName: V2SyncUtils.asString(staff['full_name']),
    );

    await databaseService.transaction((txn) async {
      final now = V2SyncUtils.nowIso();
      final tenantId = await ensureTenantId(
        txn,
        syncContext,
        tenantName: runtimeSession?.tenantName,
        roleCode: resolvedRoleCode,
      );

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

      final staffRemoteId = V2SyncUtils.asString(staff['staff_id']);
      final staffEmail = V2SyncUtils.asString(staff['email']) ?? email.trim();
      final staffWhere = staffRemoteId != null
          ? 'tenant_id = ? AND remote_id = ?'
          : 'tenant_id = ? AND email = ?';
      final staffWhereArgs = staffRemoteId != null
          ? <Object?>[tenantId, staffRemoteId]
          : <Object?>[tenantId, staffEmail];
      final staffLocalId = await databaseService.upsertByUnique(
        txn,
        'staff',
        where: staffWhere,
        whereArgs: staffWhereArgs,
        insertValues: <String, Object?>{
          'tenant_id': tenantId,
          'remote_id': staffRemoteId,
          'role_remote_id': V2SyncUtils.asString(staff['role_id']),
          'role_code': resolvedRoleCode,
          'role_name':
              V2SyncUtils.asString(staff['role_name'] ?? staff['role']) ??
              resolvedRoleCode,
          'full_name': V2SyncUtils.asString(staff['full_name']),
          'email': staffEmail,
          'is_active': 1,
          'last_login_at': now,
          'raw_payload_json': V2SyncUtils.encodeJson(staff),
          'last_synced_at': now,
          'created_at': now,
          'updated_at': now,
        },
        updateValues: <String, Object?>{
          'remote_id': staffRemoteId,
          'role_remote_id': V2SyncUtils.asString(staff['role_id']),
          'role_code': resolvedRoleCode,
          'role_name':
              V2SyncUtils.asString(staff['role_name'] ?? staff['role']) ??
              resolvedRoleCode,
          'full_name': V2SyncUtils.asString(staff['full_name']),
          'email': staffEmail,
          'is_active': 1,
          'last_login_at': now,
          'raw_payload_json': V2SyncUtils.encodeJson(staff),
          'last_synced_at': now,
          'updated_at': now,
          'deleted_at': null,
        },
      );

      await databaseService.upsertByUnique(
        txn,
        'app_session',
        where: 'tenant_id = ? AND staff_email = ? AND status = ?',
        whereArgs: <Object?>[tenantId, staffEmail, 'active'],
        insertValues: <String, Object?>{
          'tenant_id': tenantId,
          'staff_id': staffLocalId,
          'location_id': locationId,
          'staff_remote_id': staffRemoteId,
          'staff_email': staffEmail,
          'staff_full_name': V2SyncUtils.asString(staff['full_name']),
          'staff_role_code': resolvedRoleCode,
          'base_url': syncContext.normalizedBaseUrl,
          'auth_token': effectiveToken,
          'device_id': deviceId.trim(),
          'register_id': effectiveRegisterId,
          'status': 'active',
          'logged_in_at': now,
          'last_seen_at': now,
          'created_at': now,
          'updated_at': now,
        },
        updateValues: <String, Object?>{
          'staff_id': staffLocalId,
          'location_id': locationId,
          'staff_remote_id': staffRemoteId,
          'staff_full_name': V2SyncUtils.asString(staff['full_name']),
          'staff_role_code': resolvedRoleCode,
          'base_url': syncContext.normalizedBaseUrl,
          'auth_token': effectiveToken,
          'device_id': deviceId.trim(),
          'register_id': effectiveRegisterId,
          'status': 'active',
          'last_seen_at': now,
          'updated_at': now,
        },
      );
    });

    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      throw Exception('Failed to restore runtime session after PIN login');
    }
    return session;
  }

  Future<PosV2LoginResult> pinLoginAndSyncBootstrap({
    required String tenantBaseUrl,
    required String email,
    required String pin,
    required String deviceId,
    String? registerId,
    String? staffId,
    String? staffRoleCode,
    String? actingStaffId,
    bool forceLogoutOtherSession = false,
  }) async {
    final session = await pinLoginOnly(
      tenantBaseUrl: tenantBaseUrl,
      email: email,
      pin: pin,
      deviceId: deviceId,
      registerId: registerId,
      staffId: staffId,
      staffRoleCode: staffRoleCode,
      actingStaffId: actingStaffId,
      forceLogoutOtherSession: forceLogoutOtherSession,
    );
    await runBootstrapSync(session);
    return PosV2LoginResult(session: session);
  }

  String _resolveRegisterId({
    String? explicitRegisterId,
    required String deviceId,
    String? responseRegisterId,
  }) {
    final normalizedExplicit = explicitRegisterId?.trim();
    if (normalizedExplicit != null && normalizedExplicit.isNotEmpty) {
      return normalizedExplicit;
    }

    final normalizedResponse = responseRegisterId?.trim();
    if (normalizedResponse != null && normalizedResponse.isNotEmpty) {
      return normalizedResponse;
    }

    return deviceId.trim();
  }

  Future<void> _persistDiscoveredTenants({
    required String email,
    required List<Map<String, dynamic>> tenantRows,
  }) async {
    await databaseService.transaction((txn) async {
      final now = V2SyncUtils.nowIso();
      for (final tenant in tenantRows) {
        final baseUrl = V2SyncUtils.asString(tenant['base_url'])?.trim() ?? '';
        if (baseUrl.isEmpty) {
          continue;
        }
        final locationId = V2SyncUtils.asString(tenant['location_id']) ?? '';
        final tenantKey =
            '${baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'}::$locationId';
        await databaseService.upsertByUnique(
          txn,
          'app_tenant',
          where: 'tenant_key = ?',
          whereArgs: <Object?>[tenantKey],
          insertValues: <String, Object?>{
            'tenant_key': tenantKey,
            'tenant_remote_id': V2SyncUtils.asString(tenant['tenant_id']),
            'tenant_code': V2SyncUtils.asString(tenant['tenant_code']),
            'tenant_name': V2SyncUtils.asString(tenant['tenant_name']),
            'location_id': locationId,
            'base_url': baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
            'user_type': V2SyncUtils.asString(tenant['user_type']),
            'role_code': V2SyncUtils.asString(tenant['role_code']),
            'can_pos_login':
                V2SyncUtils.intToBoolFlag(
                  tenant['can_pos_login'],
                  defaultValue: true,
                )
                ? 1
                : 0,
            'is_default': V2SyncUtils.intToBoolFlag(tenant['is_default'])
                ? 1
                : 0,
            'is_active': 1,
            'catalog_owner': email.trim(),
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'tenant_remote_id': V2SyncUtils.asString(tenant['tenant_id']),
            'tenant_code': V2SyncUtils.asString(tenant['tenant_code']),
            'tenant_name': V2SyncUtils.asString(tenant['tenant_name']),
            'location_id': locationId,
            'base_url': baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
            'user_type': V2SyncUtils.asString(tenant['user_type']),
            'role_code': V2SyncUtils.asString(tenant['role_code']),
            'can_pos_login':
                V2SyncUtils.intToBoolFlag(
                  tenant['can_pos_login'],
                  defaultValue: true,
                )
                ? 1
                : 0,
            'is_default': V2SyncUtils.intToBoolFlag(tenant['is_default'])
                ? 1
                : 0,
            'is_active': 1,
            'catalog_owner': email.trim(),
            'updated_at': now,
          },
        );
      }
    });
  }

  Map<String, dynamic>? _pickDiscoveredTenant(
    List<Map<String, dynamic>> tenantRows,
  ) {
    final posEnabled = tenantRows
        .where((tenant) {
          return V2SyncUtils.intToBoolFlag(
            tenant['can_pos_login'],
            defaultValue: true,
          );
        })
        .toList(growable: false);
    if (posEnabled.isEmpty) {
      return null;
    }

    for (final tenant in posEnabled) {
      if (V2SyncUtils.intToBoolFlag(tenant['is_default'])) {
        return tenant;
      }
    }

    return posEnabled.first;
  }

  String _resolveTenantBaseUrl({
    required String requestBaseUrl,
    String? responseBaseUrl,
  }) {
    final normalizedRequest = requestBaseUrl.trim();
    final normalizedResponse = responseBaseUrl?.trim();
    if (normalizedResponse == null || normalizedResponse.isEmpty) {
      return normalizedRequest;
    }

    final requestUri = Uri.tryParse(normalizedRequest);
    final responseUri = Uri.tryParse(normalizedResponse);
    if (requestUri == null || responseUri == null) {
      return normalizedRequest;
    }

    if (requestUri.host.toLowerCase() == responseUri.host.toLowerCase()) {
      return normalizedResponse;
    }

    return normalizedRequest;
  }

  Future<String> _resolveOrCreateDeviceId(String? preferredDeviceId) async {
    final normalizedPreferred = preferredDeviceId?.trim();
    if (normalizedPreferred != null && normalizedPreferred.isNotEmpty) {
      return normalizedPreferred;
    }

    final sessionRows = await databaseService.rawQuery('''
      SELECT device_id
      FROM app_session
      WHERE device_id IS NOT NULL AND TRIM(device_id) != ''
      ORDER BY COALESCE(updated_at, logged_in_at, created_at) DESC
      LIMIT 1
      ''');
    final existingSessionDeviceId = sessionRows.isEmpty
        ? null
        : V2SyncUtils.asString(sessionRows.first['device_id']);
    if (existingSessionDeviceId != null) {
      return existingSessionDeviceId;
    }

    final deviceRows = await databaseService.rawQuery('''
      SELECT device_id
      FROM device_session
      WHERE device_id IS NOT NULL AND TRIM(device_id) != ''
      ORDER BY COALESCE(updated_at, created_at) DESC
      LIMIT 1
      ''');
    final existingDeviceId = deviceRows.isEmpty
        ? null
        : V2SyncUtils.asString(deviceRows.first['device_id']);
    if (existingDeviceId != null) {
      return existingDeviceId;
    }

    return _generateDeviceId();
  }

  String _generateDeviceId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final suffix = List<String>.generate(
      12,
      (_) => chars[random.nextInt(chars.length)],
      growable: false,
    ).join();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'flinkposv2-$timestamp-$suffix';
  }
}
