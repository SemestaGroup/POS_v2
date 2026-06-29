import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class BrandsSyncAdapter extends BaseV2SyncAdapter {
  BrandsSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(V2SyncContext context) async {
    final envelope = await buildClient(
      context,
    ).getEnvelope('api/v2/pos-brands');
    final rows = V2SyncUtils.asMapList(envelope['data'] ?? envelope['brands']);
    var upsertedCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      final now = V2SyncUtils.nowIso();

      await txn.update(
        'brand',
        <String, Object?>{'deleted_at': now, 'updated_at': now},
        where: 'tenant_id = ?',
        whereArgs: <Object?>[tenantId],
      );

      for (final row in rows) {
        final remoteId = V2SyncUtils.asString(row['id']);
        if (remoteId == null) {
          continue;
        }
        await databaseService.upsertByUnique(
          txn,
          'brand',
          where: 'tenant_id = ? AND remote_id = ?',
          whereArgs: <Object?>[tenantId, remoteId],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'remote_id': remoteId,
            'code': V2SyncUtils.asString(row['commodity_group_code']),
            'name': V2SyncUtils.asString(row['name']),
            'display_flag':
                V2SyncUtils.intToBoolFlag(row['display'], defaultValue: true)
                ? 1
                : 0,
            'sort_order': V2SyncUtils.asInt(row['order']),
            'note': V2SyncUtils.asString(row['note']),
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'code': V2SyncUtils.asString(row['commodity_group_code']),
            'name': V2SyncUtils.asString(row['name']),
            'display_flag':
                V2SyncUtils.intToBoolFlag(row['display'], defaultValue: true)
                ? 1
                : 0,
            'sort_order': V2SyncUtils.asInt(row['order']),
            'note': V2SyncUtils.asString(row['note']),
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
        endpointName: 'pos-brands',
        scopeKey: 'default',
        notes: 'Brand master synced from api/v2/pos-brands.',
      );
    });

    return V2SyncResult(
      endpointName: 'pos-brands',
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
    );
  }
}
