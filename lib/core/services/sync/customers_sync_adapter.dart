import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class CustomersSyncAdapter extends BaseV2SyncAdapter {
  CustomersSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(
    V2SyncContext context, {
    Map<String, dynamic>? query,
  }) async {
    final envelope = await buildClient(
      context,
    ).getEnvelope('api/v2/pos-customers', query: query);
    final rows = V2SyncUtils.asMapList((envelope['data'] as Object?));
    final scopeKey = query == null || query.isEmpty
        ? 'default'
        : query.toString();

    var upsertedCount = 0;

    await databaseService.transaction((txn) async {
      final now = V2SyncUtils.nowIso();
      final tenantId = await ensureTenantId(txn, context);

      for (final row in rows) {
        final remoteId = V2SyncUtils.asString(row['id']);
        if (remoteId == null) {
          continue;
        }

        await databaseService.upsertByUnique(
          txn,
          'customer',
          where: 'tenant_id = ? AND remote_id = ?',
          whereArgs: <Object?>[tenantId, remoteId],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'remote_id': remoteId,
            'display_name': V2SyncUtils.asString(row['nama'] ?? row['company']),
            'company_name': V2SyncUtils.asString(row['company'] ?? row['nama']),
            'phone_number': V2SyncUtils.asString(
              row['no_hp'] ?? row['phonenumber'],
            ),
            'email': V2SyncUtils.asString(row['email']),
            'address_line1': V2SyncUtils.asString(
              row['alamat'] ?? row['address'],
            ),
            'billing_street': V2SyncUtils.asString(row['billing_street']),
            'billing_city': V2SyncUtils.asString(row['billing_city']),
            'billing_state': V2SyncUtils.asString(row['billing_state']),
            'billing_postal_code': V2SyncUtils.asString(row['billing_zip']),
            'billing_country': V2SyncUtils.asString(row['billing_country']),
            'shipping_street': V2SyncUtils.asString(row['shipping_street']),
            'shipping_city': V2SyncUtils.asString(row['shipping_city']),
            'shipping_state': V2SyncUtils.asString(row['shipping_state']),
            'shipping_postal_code': V2SyncUtils.asString(row['shipping_zip']),
            'shipping_country': V2SyncUtils.asString(row['shipping_country']),
            'group_ids_json': V2SyncUtils.encodeJson(row['groups']),
            'points_balance': V2SyncUtils.asInt(
              row['value_pts'] ?? row['points'],
            ),
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'display_name': V2SyncUtils.asString(row['nama'] ?? row['company']),
            'company_name': V2SyncUtils.asString(row['company'] ?? row['nama']),
            'phone_number': V2SyncUtils.asString(
              row['no_hp'] ?? row['phonenumber'],
            ),
            'email': V2SyncUtils.asString(row['email']),
            'address_line1': V2SyncUtils.asString(
              row['alamat'] ?? row['address'],
            ),
            'billing_street': V2SyncUtils.asString(row['billing_street']),
            'billing_city': V2SyncUtils.asString(row['billing_city']),
            'billing_state': V2SyncUtils.asString(row['billing_state']),
            'billing_postal_code': V2SyncUtils.asString(row['billing_zip']),
            'billing_country': V2SyncUtils.asString(row['billing_country']),
            'shipping_street': V2SyncUtils.asString(row['shipping_street']),
            'shipping_city': V2SyncUtils.asString(row['shipping_city']),
            'shipping_state': V2SyncUtils.asString(row['shipping_state']),
            'shipping_postal_code': V2SyncUtils.asString(row['shipping_zip']),
            'shipping_country': V2SyncUtils.asString(row['shipping_country']),
            'group_ids_json': V2SyncUtils.encodeJson(row['groups']),
            'points_balance': V2SyncUtils.asInt(
              row['value_pts'] ?? row['points'],
            ),
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
        endpointName: 'pos-customers',
        scopeKey: scopeKey,
        notes: 'Customer list synced from api/v2/pos-customers.',
      );
    });

    return V2SyncResult(
      endpointName: 'pos-customers',
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
      meta: <String, Object?>{'scopeKey': scopeKey},
    );
  }
}
