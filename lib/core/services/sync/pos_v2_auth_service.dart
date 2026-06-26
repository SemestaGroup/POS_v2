import '../../network/v2_api_client.dart';
import '../../network/v2_api_fixed_auth.dart';
import 'base_v2_sync_adapter.dart';
import 'bootstrap_sync_adapter.dart';
import 'pos_v2_runtime_session_store.dart';
import 'v2_sync_context.dart';
import 'v2_sync_utils.dart';

class PosV2LoginResult {
  const PosV2LoginResult({
    required this.session,
    required this.loginEnvelope,
    required this.bootstrapEnvelope,
  });

  final PosV2RuntimeSession session;
  final Map<String, dynamic> loginEnvelope;
  final Map<String, dynamic> bootstrapEnvelope;
}

class PosV2AuthService extends BaseV2SyncAdapter {
  PosV2AuthService({super.databaseService});

  final BootstrapSyncAdapter _bootstrapSync = BootstrapSyncAdapter();

  Future<PosV2RuntimeSession> loginOnly({
    required String loginBaseUrl,
    required String email,
    required String password,
    required String deviceId,
    String? registerId,
  }) async {
    final loginClient = V2ApiClient(
      baseUrl: loginBaseUrl,
      authToken: kFlinkV2FixedAuthToken,
    );
    final loginEnvelope = await loginClient.postEnvelope(
      'api/v2/pos-auth/login',
      body: <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'device_id': deviceId.trim(),
      },
    );

    final loginData =
        V2SyncUtils.asMap(loginEnvelope['data']) ?? const <String, dynamic>{};
    final staff =
        V2SyncUtils.asMap(loginData['staff']) ?? const <String, dynamic>{};
    final deviceSession =
        V2SyncUtils.asMap(loginData['device_session']) ??
        const <String, dynamic>{};
    final policies =
        V2SyncUtils.asMap(loginData['policies']) ?? const <String, dynamic>{};
    final effectiveBaseUrl =
        V2SyncUtils.asString(loginData['base_url']) ?? loginBaseUrl.trim();
    final effectiveToken =
        V2SyncUtils.asString(loginData['auth_token']) ??
        kFlinkV2FixedAuthToken;
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
        tenantName: V2SyncUtils.asString(loginData['tenant_name']),
        roleCode: V2SyncUtils.asString(staff['role_code']),
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
          'role_code': V2SyncUtils.asString(staff['role_code']),
          'role_name': V2SyncUtils.asString(staff['role_code']),
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
          'role_code': V2SyncUtils.asString(staff['role_code']),
          'role_name': V2SyncUtils.asString(staff['role_code']),
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
          'staff_role_code': V2SyncUtils.asString(staff['role_code']),
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
          'staff_role_code': V2SyncUtils.asString(staff['role_code']),
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
  }) async {
    final session = await loginOnly(
      loginBaseUrl: loginBaseUrl,
      email: email,
      password: password,
      deviceId: deviceId,
      registerId: registerId,
    );
    await runBootstrapSync(session);
    return PosV2LoginResult(
      session: session,
      loginEnvelope: const <String, dynamic>{},
      bootstrapEnvelope: const <String, dynamic>{},
    );
  }

  Future<PosV2RuntimeSession> pinLoginOnly({
    required String tenantBaseUrl,
    required String email,
    required String pin,
    required String deviceId,
    String? registerId,
  }) async {
    final client = V2ApiClient(
      baseUrl: tenantBaseUrl,
      authToken: kFlinkV2FixedAuthToken,
    );
    final loginEnvelope = await client.postEnvelope(
      'api/v2/pos-auth/pin-login',
      body: <String, dynamic>{
        'email': email.trim(),
        'pin': pin.trim(),
        'device_id': deviceId.trim(),
      },
    );

    final loginData =
        V2SyncUtils.asMap(loginEnvelope['data']) ?? const <String, dynamic>{};
    final staff =
        V2SyncUtils.asMap(loginData['staff']) ?? const <String, dynamic>{};
    final deviceSession =
        V2SyncUtils.asMap(loginData['device_session']) ??
        const <String, dynamic>{};
    final effectiveBaseUrl =
        V2SyncUtils.asString(loginData['base_url']) ?? tenantBaseUrl.trim();
    final effectiveToken =
        V2SyncUtils.asString(loginData['auth_token']) ??
        kFlinkV2FixedAuthToken;
    final runtimeSession = PosV2RuntimeSessionStore.instance.currentSession;
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
        roleCode: V2SyncUtils.asString(staff['role_code']),
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
          'role_code': V2SyncUtils.asString(staff['role_code']),
          'role_name': V2SyncUtils.asString(staff['role_code']),
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
          'role_code': V2SyncUtils.asString(staff['role_code']),
          'role_name': V2SyncUtils.asString(staff['role_code']),
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
          'staff_role_code': V2SyncUtils.asString(staff['role_code']),
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
          'staff_role_code': V2SyncUtils.asString(staff['role_code']),
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
  }) async {
    final session = await pinLoginOnly(
      tenantBaseUrl: tenantBaseUrl,
      email: email,
      pin: pin,
      deviceId: deviceId,
      registerId: registerId,
    );
    await runBootstrapSync(session);
    return PosV2LoginResult(
      session: session,
      loginEnvelope: const <String, dynamic>{},
      bootstrapEnvelope: const <String, dynamic>{},
    );
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
}
