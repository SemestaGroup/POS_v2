import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class PosRolesSyncAdapter extends BaseV2SyncAdapter {
  PosRolesSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(V2SyncContext context) async {
    final envelope = await buildClient(
      context,
    ).getEnvelope('api/v2/pos-roles');
    final rows = V2SyncUtils.asMapList(envelope['data'] ?? envelope['roles']);
    var upsertedCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      final now = V2SyncUtils.nowIso();

      await txn.update(
        'pos_role',
        <String, Object?>{'deleted_at': now, 'updated_at': now},
        where: 'tenant_id = ?',
        whereArgs: <Object?>[tenantId],
      );

      for (final row in rows) {
        final roleId = V2SyncUtils.asString(row['role_id']);
        if (roleId == null) {
          continue;
        }
        await databaseService.upsertByUnique(
          txn,
          'pos_role',
          where: 'tenant_id = ? AND role_id = ?',
          whereArgs: <Object?>[tenantId, roleId],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'role_id': roleId,
            'name': V2SyncUtils.asString(row['name']) ?? '',
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'name': V2SyncUtils.asString(row['name']) ?? '',
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
        endpointName: 'pos-roles',
        scopeKey: 'default',
        notes: 'POS Roles synced from api/v2/pos-roles.',
      );
    });

    return V2SyncResult(
      endpointName: 'pos-roles',
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
    );
  }
}
