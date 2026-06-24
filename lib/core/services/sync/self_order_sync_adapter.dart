import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class SelfOrderSyncAdapter extends BaseV2SyncAdapter {
  SelfOrderSyncAdapter({super.databaseService});

  Future<V2SyncResult> syncSessions(
    V2SyncContext context, {
    Map<String, dynamic>? query,
    String path = 'api/v2/pos-self-order-sessions',
  }) async {
    final envelope = await buildClient(context).getEnvelope(path, query: query);
    final data = envelope['data'];
    final rows = data is Map<String, dynamic>
        ? <Map<String, dynamic>>[data]
        : V2SyncUtils.asMapList(data);
    final scopeKey = query == null || query.isEmpty ? path : '$path::$query';

    var upsertedCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      for (final row in rows) {
        final didUpsert = await _upsertSession(txn, tenantId, row);
        if (didUpsert) {
          upsertedCount += 1;
        }
      }

      await touchCheckpoint(
        txn,
        tenantId,
        endpointName: path.replaceFirst('api/v2/', ''),
        scopeKey: scopeKey,
        notes: 'Self-order sessions synced locally.',
      );
    });

    return V2SyncResult(
      endpointName: path.replaceFirst('api/v2/', ''),
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
      meta: <String, Object?>{'scopeKey': scopeKey},
    );
  }

  Future<V2SyncResult> resolve(
    V2SyncContext context, {
    String? accessToken,
    String? sessionCode,
    String? publicCode,
    String? queueNumber,
    String? businessDate,
    String? tableCode,
  }) async {
    final query = <String, dynamic>{
      ...?_singleQueryEntry('access_token', accessToken),
      ...?_singleQueryEntry('session_code', sessionCode),
      ...?_singleQueryEntry('public_code', publicCode),
      ...?_singleQueryEntry('queue_number', queueNumber),
      ...?_singleQueryEntry('business_date', businessDate),
      ...?_singleQueryEntry('table_code', tableCode),
    };

    return syncSessions(
      context,
      query: query,
      path: 'api/v2/pos-self-order-sessions/resolve',
    );
  }

  Future<bool> _upsertSession(
    dynamic executor,
    int tenantId,
    Map<String, dynamic> row,
  ) async {
    final remoteId = V2SyncUtils.asString(row['id']);
    final sessionCode = V2SyncUtils.asString(row['session_code']);
    if (remoteId == null && sessionCode == null) {
      return false;
    }

    final serviceTableRemoteId = V2SyncUtils.asString(
      row['service_table_id'] ?? row['service_table_remote_id'],
    );
    final serviceTableLocalId = await findLocalIdByRemoteId(
      executor,
      'service_table',
      tenantId,
      serviceTableRemoteId,
    );
    final createdByStaffRemoteId = V2SyncUtils.asString(
      row['created_by_staff_id'],
    );
    final updatedByStaffRemoteId = V2SyncUtils.asString(
      row['updated_by_staff_id'],
    );
    final createdByStaffId = await findLocalIdByRemoteId(
      executor,
      'staff',
      tenantId,
      createdByStaffRemoteId,
    );
    final updatedByStaffId = await findLocalIdByRemoteId(
      executor,
      'staff',
      tenantId,
      updatedByStaffRemoteId,
    );
    final currentIdPos = V2SyncUtils.asString(row['current_id_pos']);
    final currentOrderRemoteId = V2SyncUtils.asString(
      row['current_invoice_id'],
    );
    final currentOrderId = await findOrderLocalId(
      executor,
      tenantId,
      remoteId: currentOrderRemoteId,
      idPos: currentIdPos,
    );

    final where = sessionCode != null
        ? 'tenant_id = ? AND session_code = ?'
        : 'tenant_id = ? AND remote_id = ?';
    final whereArgs = sessionCode != null
        ? <Object?>[tenantId, sessionCode]
        : <Object?>[tenantId, remoteId];
    final now = V2SyncUtils.nowIso();

    await databaseService.upsertByUnique(
      executor,
      'self_order_session',
      where: where,
      whereArgs: whereArgs,
      insertValues: <String, Object?>{
        'tenant_id': tenantId,
        'remote_id': remoteId,
        'service_table_id': serviceTableLocalId,
        'created_by_staff_id': createdByStaffId,
        'updated_by_staff_id': updatedByStaffId,
        'current_order_id': currentOrderId,
        'service_table_remote_id': serviceTableRemoteId,
        'session_code': sessionCode,
        'public_code': V2SyncUtils.asString(row['public_code']),
        'access_token': V2SyncUtils.asString(row['access_token']),
        'location_id': V2SyncUtils.asString(row['location_id']),
        'business_date': V2SyncUtils.asString(row['business_date']),
        'table_code': V2SyncUtils.asString(row['table_code']),
        'queue_number': V2SyncUtils.asInt(row['queue_number']),
        'customer_name': V2SyncUtils.asString(row['customer_name']),
        'source_channel': V2SyncUtils.asString(row['source_channel']),
        'flow_mode': V2SyncUtils.asString(row['flow_mode']),
        'payment_stage': V2SyncUtils.asString(row['payment_stage']),
        'status': V2SyncUtils.asString(row['status']),
        'order_type_code': V2SyncUtils.asString(row['order_type']),
        'current_order_remote_id': currentOrderRemoteId,
        'current_id_pos': currentIdPos,
        'feedback_url': V2SyncUtils.asString(row['feedback_url']),
        'resume_url': V2SyncUtils.asString(row['resume_url']),
        'metadata_json': row['metadata_json'] is String
            ? row['metadata_json']
            : V2SyncUtils.encodeJson(row['metadata_json']),
        'created_by_staff_remote_id': createdByStaffRemoteId,
        'updated_by_staff_remote_id': updatedByStaffRemoteId,
        'last_activity_at': V2SyncUtils.asString(row['last_activity_at']),
        'raw_payload_json': V2SyncUtils.encodeJson(row),
        'last_synced_at': now,
        'created_at': now,
        'updated_at': now,
      },
      updateValues: <String, Object?>{
        'service_table_id': serviceTableLocalId,
        'created_by_staff_id': createdByStaffId,
        'updated_by_staff_id': updatedByStaffId,
        'current_order_id': currentOrderId,
        'service_table_remote_id': serviceTableRemoteId,
        'public_code': V2SyncUtils.asString(row['public_code']),
        'access_token': V2SyncUtils.asString(row['access_token']),
        'location_id': V2SyncUtils.asString(row['location_id']),
        'business_date': V2SyncUtils.asString(row['business_date']),
        'table_code': V2SyncUtils.asString(row['table_code']),
        'queue_number': V2SyncUtils.asInt(row['queue_number']),
        'customer_name': V2SyncUtils.asString(row['customer_name']),
        'source_channel': V2SyncUtils.asString(row['source_channel']),
        'flow_mode': V2SyncUtils.asString(row['flow_mode']),
        'payment_stage': V2SyncUtils.asString(row['payment_stage']),
        'status': V2SyncUtils.asString(row['status']),
        'order_type_code': V2SyncUtils.asString(row['order_type']),
        'current_order_remote_id': currentOrderRemoteId,
        'current_id_pos': currentIdPos,
        'feedback_url': V2SyncUtils.asString(row['feedback_url']),
        'resume_url': V2SyncUtils.asString(row['resume_url']),
        'metadata_json': row['metadata_json'] is String
            ? row['metadata_json']
            : V2SyncUtils.encodeJson(row['metadata_json']),
        'created_by_staff_remote_id': createdByStaffRemoteId,
        'updated_by_staff_remote_id': updatedByStaffRemoteId,
        'last_activity_at': V2SyncUtils.asString(row['last_activity_at']),
        'raw_payload_json': V2SyncUtils.encodeJson(row),
        'last_synced_at': now,
        'updated_at': now,
        'deleted_at': null,
      },
    );

    return true;
  }

  Map<String, dynamic>? _singleQueryEntry(String key, String? value) {
    if (value == null) {
      return null;
    }
    return <String, dynamic>{key: value};
  }
}
