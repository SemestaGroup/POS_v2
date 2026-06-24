import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class ServiceTablesSyncAdapter extends BaseV2SyncAdapter {
  ServiceTablesSyncAdapter({super.databaseService});

  Future<V2SyncResult> syncBackofficeList(
    V2SyncContext context, {
    required int actingStaffId,
    Map<String, dynamic>? query,
  }) async {
    final mergedQuery = <String, dynamic>{
      'acting_staff_id': actingStaffId,
      ...?query,
    };
    final envelope = await buildClient(
      context,
    ).getEnvelope('api/v2/backoffice/pos-service-tables', query: mergedQuery);
    return _syncRows(
      context,
      V2SyncUtils.asMapList(envelope['data']),
      scopeKey: mergedQuery.toString(),
      endpointName: 'backoffice/pos-service-tables',
    );
  }

  Future<V2SyncResult> syncLookup(
    V2SyncContext context, {
    String? qrToken,
    String? tableCode,
  }) async {
    final query = <String, dynamic>{
      ...?_nonEmptyQueryEntry('qr_token', qrToken),
      ...?_nonEmptyQueryEntry('table_code', tableCode),
    };
    final envelope = await buildClient(
      context,
    ).getEnvelope('api/v2/pos-service-tables/lookup', query: query);
    final row = V2SyncUtils.asMap(envelope['data']);
    return _syncRows(
      context,
      row == null
          ? const <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[row],
      scopeKey: query.toString(),
      endpointName: 'pos-service-tables/lookup',
    );
  }

  Future<V2SyncResult> _syncRows(
    V2SyncContext context,
    List<Map<String, dynamic>> rows, {
    required String scopeKey,
    required String endpointName,
  }) async {
    var upsertedCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      final now = V2SyncUtils.nowIso();
      for (final row in rows) {
        final remoteId = V2SyncUtils.asString(row['id']);
        final locationId =
            V2SyncUtils.asString(row['location_id']) ?? context.locationId;
        final tableCode = V2SyncUtils.asString(row['table_code']);
        if (remoteId == null && tableCode == null) {
          continue;
        }
        final where = remoteId != null
            ? 'tenant_id = ? AND remote_id = ?'
            : 'tenant_id = ? AND location_id = ? AND table_code = ?';
        final whereArgs = remoteId != null
            ? <Object?>[tenantId, remoteId]
            : <Object?>[tenantId, locationId, tableCode];
        await databaseService.upsertByUnique(
          txn,
          'service_table',
          where: where,
          whereArgs: whereArgs,
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'remote_id': remoteId,
            'location_id': locationId,
            'area_name': V2SyncUtils.asString(row['area_name']),
            'table_code': tableCode,
            'table_name': V2SyncUtils.asString(row['table_name']) ?? tableCode,
            'capacity': V2SyncUtils.asInt(row['capacity']),
            'qr_token': V2SyncUtils.asString(row['qr_token']),
            'default_source_channel': V2SyncUtils.asString(
              row['default_source_channel'],
            ),
            'self_order_enabled':
                V2SyncUtils.intToBoolFlag(
                  row['self_order_enabled'],
                  defaultValue: true,
                )
                ? 1
                : 0,
            'is_active':
                V2SyncUtils.intToBoolFlag(row['active'], defaultValue: true)
                ? 1
                : 0,
            'entry_url': V2SyncUtils.asString(row['entry_url']),
            'notes': V2SyncUtils.asString(row['notes']),
            'metadata_json': row['metadata_json'] is String
                ? row['metadata_json']
                : V2SyncUtils.encodeJson(row['metadata_json']),
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'location_id': locationId,
            'area_name': V2SyncUtils.asString(row['area_name']),
            'table_code': tableCode,
            'table_name': V2SyncUtils.asString(row['table_name']) ?? tableCode,
            'capacity': V2SyncUtils.asInt(row['capacity']),
            'qr_token': V2SyncUtils.asString(row['qr_token']),
            'default_source_channel': V2SyncUtils.asString(
              row['default_source_channel'],
            ),
            'self_order_enabled':
                V2SyncUtils.intToBoolFlag(
                  row['self_order_enabled'],
                  defaultValue: true,
                )
                ? 1
                : 0,
            'is_active':
                V2SyncUtils.intToBoolFlag(row['active'], defaultValue: true)
                ? 1
                : 0,
            'entry_url': V2SyncUtils.asString(row['entry_url']),
            'notes': V2SyncUtils.asString(row['notes']),
            'metadata_json': row['metadata_json'] is String
                ? row['metadata_json']
                : V2SyncUtils.encodeJson(row['metadata_json']),
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
        endpointName: endpointName,
        scopeKey: scopeKey,
        notes: 'Service table data synced locally.',
      );
    });

    return V2SyncResult(
      endpointName: endpointName,
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
      meta: <String, Object?>{'scopeKey': scopeKey},
    );
  }

  Map<String, dynamic>? _nonEmptyQueryEntry(String key, String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return <String, dynamic>{key: value};
  }
}
