import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class StaffSyncAdapter extends BaseV2SyncAdapter {
  StaffSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(V2SyncContext context) async {
    final payload = await buildClient(context).getJson('api/v2/pos-staff');
    final rows = payload is List
        ? payload
              .whereType<dynamic>()
              .map(
                (item) => (item as Map).map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              .toList(growable: false)
        : payload is Map<String, dynamic>
        ? (payload['data'] is List
              ? V2SyncUtils.asMapList(payload['data'])
              : payload['data'] is Map<String, dynamic>
              ? <Map<String, dynamic>>[
                  V2SyncUtils.asMap(payload['data']) ??
                      const <String, dynamic>{},
                ]
              : V2SyncUtils.asMapList(payload['value']))
        : const <Map<String, dynamic>>[];

    var upsertedCount = 0;
    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      final now = V2SyncUtils.nowIso();

      await txn.update(
        'staff',
        <String, Object?>{'deleted_at': now, 'updated_at': now},
        where: 'tenant_id = ?',
        whereArgs: <Object?>[tenantId],
      );

      for (final row in rows) {
        final remoteId = V2SyncUtils.asString(
          row['staffid'] ?? row['staff_id'],
        );
        final email = V2SyncUtils.asString(row['email']);
        if (remoteId == null && email == null) {
          continue;
        }

        await databaseService.upsertByUnique(
          txn,
          'staff',
          where: remoteId != null
              ? 'tenant_id = ? AND remote_id = ?'
              : 'tenant_id = ? AND email = ?',
          whereArgs: remoteId != null
              ? <Object?>[tenantId, remoteId]
              : <Object?>[tenantId, email],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'remote_id': remoteId,
            'role_name': V2SyncUtils.asString(row['role']),
            'role_code': _roleCodeFromName(V2SyncUtils.asString(row['role'])),
            'first_name': V2SyncUtils.asString(row['firstname']),
            'last_name': V2SyncUtils.asString(row['lastname']),
            'full_name': _fullName(row),
            'email': email,
            'phone_number': V2SyncUtils.asString(row['phonenumber']),
            'is_active':
                V2SyncUtils.intToBoolFlag(row['active'], defaultValue: true)
                ? 1
                : 0,
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'remote_id': remoteId,
            'role_name': V2SyncUtils.asString(row['role']),
            'role_code': _roleCodeFromName(V2SyncUtils.asString(row['role'])),
            'first_name': V2SyncUtils.asString(row['firstname']),
            'last_name': V2SyncUtils.asString(row['lastname']),
            'full_name': _fullName(row),
            'email': email,
            'phone_number': V2SyncUtils.asString(row['phonenumber']),
            'is_active':
                V2SyncUtils.intToBoolFlag(row['active'], defaultValue: true)
                ? 1
                : 0,
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
        endpointName: 'pos-staff',
        scopeKey: 'default',
        notes: 'Staff cache synced for account switching.',
      );
    });

    return V2SyncResult(
      endpointName: 'pos-staff',
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
    );
  }

  String? _roleCodeFromName(String? roleName) {
    final normalized = roleName?.trim().toLowerCase();
    switch (normalized) {
      case 'owner':
      case 'admin':
        return 'owner';
      case 'supervisor':
        return 'supervisor';
      case 'kitchen':
        return 'kitchen';
      case 'cashier':
        return 'cashier';
      case 'programmer':
        return 'programmer';
      default:
        return normalized;
    }
  }

  String _fullName(Map<String, dynamic> row) {
    return [
      V2SyncUtils.asString(row['firstname']),
      V2SyncUtils.asString(row['lastname']),
    ].whereType<String>().join(' ').trim();
  }
}
