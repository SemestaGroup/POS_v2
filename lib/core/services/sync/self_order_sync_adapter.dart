import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class SelfOrderSyncAdapter extends BaseV2SyncAdapter {
  SelfOrderSyncAdapter({super.databaseService});

  Future<V2SyncResult> open(
    V2SyncContext context, {
    required int locationId,
    String? tableQrToken,
    String? sourceChannel,
    String? businessDate,
    String? tableCode,
    String? orderType,
    int? createdByStaffId,
    int? queueNumber,
    String? customerName,
    String? paymentStage,
    String? status,
    Map<String, dynamic>? metadataJson,
  }) async {
    final envelope = await buildClient(context).postEnvelope(
      'api/v2/pos-self-order-sessions/open',
      body: <String, dynamic>{
        'location_id': locationId,
        if (tableQrToken != null && tableQrToken.isNotEmpty)
          'table_qr_token': tableQrToken,
        if (sourceChannel != null && sourceChannel.isNotEmpty)
          'source_channel': sourceChannel,
        if (businessDate != null && businessDate.isNotEmpty)
          'business_date': businessDate,
        if (tableCode != null && tableCode.isNotEmpty) 'table_code': tableCode,
        if (orderType != null && orderType.isNotEmpty) 'order_type': orderType,
        ...?_singleQueryEntry('created_by_staff_id', createdByStaffId),
        ...?_singleQueryEntry('queue_number', queueNumber),
        if (customerName != null && customerName.isNotEmpty)
          'customer_name': customerName,
        if (paymentStage != null && paymentStage.isNotEmpty)
          'payment_stage': paymentStage,
        if (status != null && status.isNotEmpty) 'status': status,
        ...?_singleQueryEntry('metadata_json', metadataJson),
      },
    );

    final data = V2SyncUtils.asMap(envelope['data']);
    return _storeSessionPayload(
      context,
      data,
      endpointName: 'pos-self-order-sessions/open',
      scopeKey: 'open',
      eventType: 'opened',
      actorSource: _actorSourceFromChannel(sourceChannel),
      actorStaffRemoteId: createdByStaffId?.toString(),
      eventPayload: V2SyncUtils.asMap(data?['qr_payloads']) ?? metadataJson,
      eventNote: 'Self order session opened locally.',
    );
  }

  Future<V2SyncResult> linkOrder(
    V2SyncContext context, {
    required int sessionRemoteId,
    int? invoiceId,
    String? idPos,
    int? queueNumber,
    String? orderType,
    String? paymentStage,
    String? status,
    int? updatedByStaffId,
  }) async {
    final envelope = await buildClient(context).postEnvelope(
      'api/v2/pos-self-order-sessions/$sessionRemoteId/link-order',
      body: <String, dynamic>{
        ...?_singleQueryEntry('invoice_id', invoiceId),
        if (idPos != null && idPos.isNotEmpty) 'id_pos': idPos,
        ...?_singleQueryEntry('queue_number', queueNumber),
        if (orderType != null && orderType.isNotEmpty) 'order_type': orderType,
        if (paymentStage != null && paymentStage.isNotEmpty)
          'payment_stage': paymentStage,
        if (status != null && status.isNotEmpty) 'status': status,
        ...?_singleQueryEntry('updated_by_staff_id', updatedByStaffId),
      },
    );

    return _storeSessionPayload(
      context,
      envelope['data'],
      endpointName: 'pos-self-order-sessions/link-order',
      scopeKey: sessionRemoteId.toString(),
      eventType: 'order_linked',
      actorSource: updatedByStaffId != null ? 'cashier' : 'system',
      actorStaffRemoteId: updatedByStaffId?.toString(),
      eventPayload: <String, dynamic>{
        ...?_singleQueryEntry('invoice_id', invoiceId),
        if (idPos != null && idPos.isNotEmpty) 'id_pos': idPos,
        ...?_singleQueryEntry('queue_number', queueNumber),
        if (orderType != null && orderType.isNotEmpty) 'order_type': orderType,
        if (paymentStage != null && paymentStage.isNotEmpty)
          'payment_stage': paymentStage,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      eventNote: 'Self order session linked to order locally.',
    );
  }

  Future<V2SyncResult> closeSession(
    V2SyncContext context, {
    required int sessionRemoteId,
    int? updatedByStaffId,
    String? status,
    String? paymentStage,
    String? reason,
  }) async {
    final envelope = await buildClient(context).postEnvelope(
      'api/v2/pos-self-order-sessions/$sessionRemoteId/close',
      body: <String, dynamic>{
        ...?_singleQueryEntry('updated_by_staff_id', updatedByStaffId),
        if (status != null && status.isNotEmpty) 'status': status,
        if (paymentStage != null && paymentStage.isNotEmpty)
          'payment_stage': paymentStage,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );

    return _storeSessionPayload(
      context,
      envelope['data'],
      endpointName: 'pos-self-order-sessions/close',
      scopeKey: sessionRemoteId.toString(),
      eventType: 'closed',
      actorSource: updatedByStaffId != null ? 'cashier' : 'system',
      actorStaffRemoteId: updatedByStaffId?.toString(),
      eventPayload: <String, dynamic>{
        if (status != null && status.isNotEmpty) 'status': status,
        if (paymentStage != null && paymentStage.isNotEmpty)
          'payment_stage': paymentStage,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
      eventNote: reason ?? 'Self order session closed locally.',
    );
  }

  Future<V2SyncResult> syncSessions(
    V2SyncContext context, {
    Map<String, dynamic>? query,
    String path = 'api/v2/pos-self-order-sessions',
  }) async {
    final envelope = await buildClient(context).getEnvelope(path, query: query);
    final scopeKey = query == null || query.isEmpty ? path : '$path::$query';

    return _storeSessionPayload(
      context,
      envelope['data'],
      endpointName: path.replaceFirst('api/v2/', ''),
      scopeKey: scopeKey,
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

  Future<V2SyncResult> _storeSessionPayload(
    V2SyncContext context,
    dynamic data, {
    required String endpointName,
    required String scopeKey,
    String? eventType,
    String? actorSource,
    String? actorStaffRemoteId,
    Map<String, dynamic>? eventPayload,
    String? eventNote,
  }) async {
    final rows = _extractSessionRows(data);

    var upsertedCount = 0;
    var eventCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      for (final row in rows) {
        final sessionLocalId = await _upsertSession(txn, tenantId, row);
        if (sessionLocalId == null) {
          continue;
        }

        upsertedCount += 1;
        if (eventType != null) {
          await _appendLocalEvent(
            txn,
            tenantId,
            sessionLocalId,
            row,
            eventType: eventType,
            actorSource: actorSource,
            actorStaffRemoteId: actorStaffRemoteId,
            payload: eventPayload,
            note: eventNote,
          );
          eventCount += 1;
        }
      }

      await touchCheckpoint(
        txn,
        tenantId,
        endpointName: endpointName,
        scopeKey: scopeKey,
        notes: 'Self-order sessions synced locally.',
      );
    });

    return V2SyncResult(
      endpointName: endpointName,
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
      meta: <String, Object?>{
        'scopeKey': scopeKey,
        ...?_singleQueryEntry('eventType', eventType),
        ...?_singleQueryEntry('eventCount', eventCount > 0 ? eventCount : null),
      },
    );
  }

  List<Map<String, dynamic>> _extractSessionRows(dynamic data) {
    final wrapper = V2SyncUtils.asMap(data);
    final nestedSession = V2SyncUtils.asMap(wrapper?['session']);
    if (nestedSession != null) {
      return <Map<String, dynamic>>[nestedSession];
    }
    if (wrapper != null) {
      return <Map<String, dynamic>>[wrapper];
    }
    return V2SyncUtils.asMapList(data);
  }

  Future<int?> _upsertSession(
    dynamic executor,
    int tenantId,
    Map<String, dynamic> row,
  ) async {
    final remoteId = V2SyncUtils.asString(row['id']);
    final sessionCode = V2SyncUtils.asString(row['session_code']);
    if (remoteId == null && sessionCode == null) {
      return null;
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

    return databaseService.upsertByUnique(
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
  }

  Future<void> _appendLocalEvent(
    dynamic executor,
    int tenantId,
    int sessionLocalId,
    Map<String, dynamic> row, {
    required String eventType,
    String? actorSource,
    String? actorStaffRemoteId,
    Map<String, dynamic>? payload,
    String? note,
  }) async {
    final resolvedActorStaffRemoteId =
        actorStaffRemoteId ??
        V2SyncUtils.asString(row['updated_by_staff_id']) ??
        V2SyncUtils.asString(row['created_by_staff_id']);
    final actorStaffId = await findLocalIdByRemoteId(
      executor,
      'staff',
      tenantId,
      resolvedActorStaffRemoteId,
    );
    final now = V2SyncUtils.nowIso();

    await executor.insert('self_order_event', <String, Object?>{
      'tenant_id': tenantId,
      'self_order_session_id': sessionLocalId,
      'actor_staff_id': actorStaffId,
      'self_order_session_remote_id': V2SyncUtils.asString(row['id']),
      'actor_staff_remote_id': resolvedActorStaffRemoteId,
      'event_type': eventType,
      'actor_source': actorSource,
      'note': note,
      'payload_json': V2SyncUtils.encodeJson(payload),
      'occurred_at':
          V2SyncUtils.asString(row['last_activity_at']) ??
          V2SyncUtils.asString(row['updated_at']) ??
          V2SyncUtils.asString(row['created_at']) ??
          now,
      'last_synced_at': now,
      'created_at': now,
      'updated_at': now,
    });
  }

  Map<String, dynamic>? _singleQueryEntry(String key, Object? value) {
    if (value == null) {
      return null;
    }
    return <String, dynamic>{key: value};
  }

  String _actorSourceFromChannel(String? channel) {
    final normalized = (channel ?? '').trim().toLowerCase();
    if (normalized == 'kiosk' ||
        normalized == 'table_qr' ||
        normalized == 'online') {
      return 'customer';
    }
    return 'system';
  }
}
