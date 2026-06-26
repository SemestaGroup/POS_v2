import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class BootstrapSyncAdapter extends BaseV2SyncAdapter {
  BootstrapSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(V2SyncContext context) async {
    final envelope = await buildClient(
      context,
    ).getEnvelope(
      'api/v2/pos-bootstrap',
      query: <String, dynamic>{
        if (context.staffId?.isNotEmpty == true) 'staff_id': context.staffId,
        if (context.deviceId?.isNotEmpty == true) 'device_id': context.deviceId,
        if (context.locationId.isNotEmpty) 'location_id': context.locationId,
        if (context.registerId?.isNotEmpty == true)
          'register_id': context.registerId,
      },
    );
    final data =
        V2SyncUtils.asMap(envelope['data']) ?? const <String, dynamic>{};
    final tenant =
        V2SyncUtils.asMap(data['tenant']) ?? const <String, dynamic>{};
    final options =
        V2SyncUtils.asMap(data['options']) ?? const <String, dynamic>{};
    final paymentModes = V2SyncUtils.asMapList(data['payment_modes']);
    final orderTypes = V2SyncUtils.asMapList(data['order_types']);
    final staffProfile = V2SyncUtils.asMap(data['staff_profile']);
    final activeDeviceSession = V2SyncUtils.asMap(
      data['active_device_session'],
    );
    final resolvedLocationId =
        V2SyncUtils.asString(tenant['location_id']) ?? context.locationId;

    var upsertedCount = 0;

    await databaseService.transaction((txn) async {
      final now = V2SyncUtils.nowIso();
      final tenantId = await ensureTenantId(
        txn,
        context,
        tenantName: V2SyncUtils.asString(tenant['tenant_name']),
        roleCode: V2SyncUtils.asString(staffProfile?['role']),
      );

      await txn.update(
        'app_tenant',
        <String, Object?>{'last_bootstrap_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: <Object?>[tenantId],
      );
      if (resolvedLocationId.isNotEmpty) {
        await txn.update(
          'app_tenant',
          <String, Object?>{
            'location_id': resolvedLocationId,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: <Object?>[tenantId],
        );
      }

      int? staffLocalId;
      if (staffProfile != null && staffProfile.isNotEmpty) {
        final staffRemoteId = V2SyncUtils.asString(
          staffProfile['staffid'] ?? staffProfile['staff_id'],
        );
        final fullName = [
          V2SyncUtils.asString(staffProfile['firstname']),
          V2SyncUtils.asString(staffProfile['lastname']),
        ].whereType<String>().join(' ').trim();
        staffLocalId = await databaseService.upsertByUnique(
          txn,
          'staff',
          where: 'tenant_id = ? AND remote_id = ?',
          whereArgs: <Object?>[tenantId, staffRemoteId],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'remote_id': staffRemoteId,
            'role_code': V2SyncUtils.asString(staffProfile['role']),
            'role_name': V2SyncUtils.asString(staffProfile['role']),
            'first_name': V2SyncUtils.asString(staffProfile['firstname']),
            'last_name': V2SyncUtils.asString(staffProfile['lastname']),
            'full_name': fullName.isEmpty ? context.staffFullName : fullName,
            'email':
                V2SyncUtils.asString(staffProfile['email']) ??
                context.staffEmail,
            'phone_number': V2SyncUtils.asString(staffProfile['phonenumber']),
            'is_active': V2SyncUtils.intToBoolFlag(staffProfile['active'])
                ? 1
                : 0,
            'raw_payload_json': V2SyncUtils.encodeJson(staffProfile),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'role_code': V2SyncUtils.asString(staffProfile['role']),
            'role_name': V2SyncUtils.asString(staffProfile['role']),
            'first_name': V2SyncUtils.asString(staffProfile['firstname']),
            'last_name': V2SyncUtils.asString(staffProfile['lastname']),
            'full_name': fullName.isEmpty ? context.staffFullName : fullName,
            'email':
                V2SyncUtils.asString(staffProfile['email']) ??
                context.staffEmail,
            'phone_number': V2SyncUtils.asString(staffProfile['phonenumber']),
            'is_active': V2SyncUtils.intToBoolFlag(staffProfile['active'])
                ? 1
                : 0,
            'raw_payload_json': V2SyncUtils.encodeJson(staffProfile),
            'last_synced_at': now,
            'updated_at': now,
            'deleted_at': null,
          },
        );
        upsertedCount += 1;
      }

      int? deviceSessionLocalId;
      if (activeDeviceSession != null && activeDeviceSession.isNotEmpty) {
        final remoteId = V2SyncUtils.asString(activeDeviceSession['id']);
        final sessionCode = V2SyncUtils.asString(
          activeDeviceSession['session_code'],
        );
        final uniqueWhere = sessionCode != null
            ? 'tenant_id = ? AND session_code = ?'
            : 'tenant_id = ? AND remote_id = ?';
        final uniqueArgs = sessionCode != null
            ? <Object?>[tenantId, sessionCode]
            : <Object?>[tenantId, remoteId];
        deviceSessionLocalId = await databaseService.upsertByUnique(
          txn,
          'device_session',
          where: uniqueWhere,
          whereArgs: uniqueArgs,
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'staff_id': staffLocalId,
            'remote_id': remoteId,
            'session_code': sessionCode,
            'staff_remote_id': V2SyncUtils.asString(
              activeDeviceSession['staff_id'] ?? context.staffId,
            ),
            'staff_role_code': V2SyncUtils.asString(
              activeDeviceSession['staff_role_code'],
            ),
            'device_id':
                V2SyncUtils.asString(activeDeviceSession['device_id']) ??
                context.deviceId,
            'register_id':
                V2SyncUtils.asString(activeDeviceSession['register_id']) ??
                context.registerId,
            'device_name': V2SyncUtils.asString(
              activeDeviceSession['device_name'],
            ),
            'platform': V2SyncUtils.asString(activeDeviceSession['platform']),
            'app_version': V2SyncUtils.asString(
              activeDeviceSession['app_version'],
            ),
            'login_method': V2SyncUtils.asString(
              activeDeviceSession['login_method'],
            ),
            'status':
                V2SyncUtils.asString(activeDeviceSession['status']) ?? 'active',
            'metadata_json': V2SyncUtils.encodeJson(
              activeDeviceSession['metadata_json'],
            ),
            'last_seen_at':
                V2SyncUtils.asString(activeDeviceSession['last_seen_at']) ??
                now,
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'staff_id': staffLocalId,
            'remote_id': remoteId,
            'session_code': sessionCode,
            'staff_remote_id': V2SyncUtils.asString(
              activeDeviceSession['staff_id'] ?? context.staffId,
            ),
            'staff_role_code': V2SyncUtils.asString(
              activeDeviceSession['staff_role_code'],
            ),
            'device_id':
                V2SyncUtils.asString(activeDeviceSession['device_id']) ??
                context.deviceId,
            'register_id':
                V2SyncUtils.asString(activeDeviceSession['register_id']) ??
                context.registerId,
            'device_name': V2SyncUtils.asString(
              activeDeviceSession['device_name'],
            ),
            'platform': V2SyncUtils.asString(activeDeviceSession['platform']),
            'app_version': V2SyncUtils.asString(
              activeDeviceSession['app_version'],
            ),
            'login_method': V2SyncUtils.asString(
              activeDeviceSession['login_method'],
            ),
            'status':
                V2SyncUtils.asString(activeDeviceSession['status']) ?? 'active',
            'metadata_json': V2SyncUtils.encodeJson(
              activeDeviceSession['metadata_json'],
            ),
            'last_seen_at':
                V2SyncUtils.asString(activeDeviceSession['last_seen_at']) ??
                now,
            'last_synced_at': now,
            'updated_at': now,
            'deleted_at': null,
          },
        );
        upsertedCount += 1;
      }

      if (staffLocalId != null || deviceSessionLocalId != null) {
        final sessionWhere = deviceSessionLocalId != null
            ? 'tenant_id = ? AND device_session_id = ? AND status = ?'
            : 'tenant_id = ? AND staff_remote_id = ? AND status = ?';
        final sessionArgs = deviceSessionLocalId != null
            ? <Object?>[tenantId, deviceSessionLocalId, 'active']
            : <Object?>[tenantId, context.staffId, 'active'];

        await databaseService.upsertByUnique(
          txn,
          'app_session',
          where: sessionWhere,
          whereArgs: sessionArgs,
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'staff_id': staffLocalId,
            'device_session_id': deviceSessionLocalId,
            'location_id': resolvedLocationId,
            'staff_remote_id': context.staffId,
            'staff_email': context.staffEmail,
            'staff_full_name': context.staffFullName,
            'staff_role_code': V2SyncUtils.asString(staffProfile?['role']),
            'base_url': context.normalizedBaseUrl,
            'auth_token': context.authToken,
            'device_id': context.deviceId,
            'register_id': context.registerId,
            'status': 'active',
            'logged_in_at': now,
            'last_seen_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'staff_id': staffLocalId,
            'device_session_id': deviceSessionLocalId,
            'location_id': resolvedLocationId,
            'staff_remote_id': context.staffId,
            'staff_email': context.staffEmail,
            'staff_full_name': context.staffFullName,
            'staff_role_code': V2SyncUtils.asString(staffProfile?['role']),
            'base_url': context.normalizedBaseUrl,
            'auth_token': context.authToken,
            'device_id': context.deviceId,
            'register_id': context.registerId,
            'last_seen_at': now,
            'updated_at': now,
          },
        );
        upsertedCount += 1;
      }

      for (final entry in options.entries) {
        final optionName = entry.key;
        final rawValue = entry.value;
        final parsedValue = rawValue is String
            ? V2SyncUtils.decodeLooseJson(rawValue)
            : rawValue;
        final optionJson = parsedValue is Map || parsedValue is List
            ? V2SyncUtils.encodeJson(parsedValue)
            : null;
        final optionText = rawValue is String
            ? rawValue
            : V2SyncUtils.encodeJson(rawValue) ?? '';
        final valueKind = optionJson == null ? 'text' : 'json';

        await databaseService.upsertByUnique(
          txn,
          'pos_option',
          where: 'tenant_id = ? AND option_name = ?',
          whereArgs: <Object?>[tenantId, optionName],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'option_name': optionName,
            'option_value_text': optionText,
            'option_value_json': optionJson,
            'value_kind': valueKind,
            'autoload': 1,
            'source_endpoint': 'pos-bootstrap',
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'option_value_text': optionText,
            'option_value_json': optionJson,
            'value_kind': valueKind,
            'autoload': 1,
            'source_endpoint': 'pos-bootstrap',
            'last_synced_at': now,
            'updated_at': now,
            'deleted_at': null,
          },
        );
        upsertedCount += 1;

        if (parsedValue is Map || parsedValue is List) {
          await databaseService.upsertByUnique(
            txn,
            'policy_snapshot',
            where: 'tenant_id = ? AND policy_name = ?',
            whereArgs: <Object?>[tenantId, optionName],
            insertValues: <String, Object?>{
              'tenant_id': tenantId,
              'policy_name': optionName,
              'source_option_name': optionName,
              'source_endpoint': 'pos-bootstrap',
              'policy_json': V2SyncUtils.encodeJson(parsedValue),
              'last_synced_at': now,
              'created_at': now,
              'updated_at': now,
            },
            updateValues: <String, Object?>{
              'source_option_name': optionName,
              'source_endpoint': 'pos-bootstrap',
              'policy_json': V2SyncUtils.encodeJson(parsedValue),
              'last_synced_at': now,
              'updated_at': now,
              'deleted_at': null,
            },
          );
          upsertedCount += 1;
        }
      }

      await txn.update(
        'payment_mode',
        <String, Object?>{'deleted_at': now, 'updated_at': now},
        where: 'tenant_id = ?',
        whereArgs: <Object?>[tenantId],
      );
      for (final row in paymentModes) {
        final remoteId = V2SyncUtils.asString(row['id']);
        await databaseService.upsertByUnique(
          txn,
          'payment_mode',
          where: 'tenant_id = ? AND remote_id = ?',
          whereArgs: <Object?>[tenantId, remoteId],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'remote_id': remoteId,
            'name': V2SyncUtils.asString(row['name']),
            'description': V2SyncUtils.asString(row['description']),
            'allow_pos':
                V2SyncUtils.intToBoolFlag(row['allow_pos'], defaultValue: true)
                ? 1
                : 0,
            'is_active':
                V2SyncUtils.intToBoolFlag(row['active'], defaultValue: true)
                ? 1
                : 0,
            'selected_by_default':
                V2SyncUtils.intToBoolFlag(row['selected_by_default']) ? 1 : 0,
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'name': V2SyncUtils.asString(row['name']),
            'description': V2SyncUtils.asString(row['description']),
            'allow_pos':
                V2SyncUtils.intToBoolFlag(row['allow_pos'], defaultValue: true)
                ? 1
                : 0,
            'is_active':
                V2SyncUtils.intToBoolFlag(row['active'], defaultValue: true)
                ? 1
                : 0,
            'selected_by_default':
                V2SyncUtils.intToBoolFlag(row['selected_by_default']) ? 1 : 0,
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'updated_at': now,
            'deleted_at': null,
          },
        );
        upsertedCount += 1;
      }

      await txn.update(
        'order_type',
        <String, Object?>{'deleted_at': now, 'updated_at': now},
        where: 'tenant_id = ?',
        whereArgs: <Object?>[tenantId],
      );
      for (final row in orderTypes) {
        final remoteId = V2SyncUtils.asString(row['id']);
        final code = V2SyncUtils.asString(row['code']) ?? remoteId;
        await databaseService.upsertByUnique(
          txn,
          'order_type',
          where: 'tenant_id = ? AND remote_id = ?',
          whereArgs: <Object?>[tenantId, remoteId],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'remote_id': remoteId,
            'code': code,
            'name': V2SyncUtils.asString(row['name']),
            'description': V2SyncUtils.asString(row['description']),
            'is_active': 1,
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'code': code,
            'name': V2SyncUtils.asString(row['name']),
            'description': V2SyncUtils.asString(row['description']),
            'is_active': 1,
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'updated_at': now,
            'deleted_at': null,
          },
        );
        upsertedCount += 1;
      }

      await touchCheckpoint(
        txn,
        tenantId,
        endpointName: 'pos-bootstrap',
        scopeKey: 'default',
        notes: 'Bootstrap snapshot stored locally.',
      );
    });

    return V2SyncResult(
      endpointName: 'pos-bootstrap',
      fetchedCount: 1,
      upsertedCount: upsertedCount,
      meta: <String, Object?>{'tenantKey': context.tenantKey},
    );
  }
}
