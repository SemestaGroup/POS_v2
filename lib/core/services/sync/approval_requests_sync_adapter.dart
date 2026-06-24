import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class ApprovalRequestsSyncAdapter extends BaseV2SyncAdapter {
  ApprovalRequestsSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(
    V2SyncContext context, {
    Map<String, dynamic>? query,
    String path = 'api/v2/pos-approval-requests',
  }) async {
    final envelope = await buildClient(context).getEnvelope(path, query: query);
    final rows = V2SyncUtils.asMapList(envelope['data']);
    final scopeKey = query == null || query.isEmpty ? path : '$path::$query';

    var upsertedCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      final now = V2SyncUtils.nowIso();
      for (final row in rows) {
        final remoteId = V2SyncUtils.asString(
          row['id'] ?? row['approval_request_id'],
        );
        final requestCode = V2SyncUtils.asString(row['request_code']);
        if (remoteId == null && requestCode == null) {
          continue;
        }
        final requesterRemoteId = V2SyncUtils.asString(
          row['requester_staff_id'],
        );
        final approverRemoteId = V2SyncUtils.asString(
          row['approved_by_staff_id'],
        );
        final requesterLocalId = await findLocalIdByRemoteId(
          txn,
          'staff',
          tenantId,
          requesterRemoteId,
        );
        final approverLocalId = await findLocalIdByRemoteId(
          txn,
          'staff',
          tenantId,
          approverRemoteId,
        );
        await databaseService.upsertByUnique(
          txn,
          'approval_request',
          where: requestCode != null
              ? 'tenant_id = ? AND request_code = ?'
              : 'tenant_id = ? AND remote_id = ?',
          whereArgs: requestCode != null
              ? <Object?>[tenantId, requestCode]
              : <Object?>[tenantId, remoteId],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'requester_staff_id': requesterLocalId,
            'approved_by_staff_id': approverLocalId,
            'remote_id': remoteId,
            'request_code': requestCode,
            'request_type': V2SyncUtils.asString(row['request_type']),
            'reference_type': V2SyncUtils.asString(row['reference_type']),
            'reference_remote_id': V2SyncUtils.asString(row['reference_id']),
            'reference_number': V2SyncUtils.asString(row['reference_number']),
            'draft_id_pos': V2SyncUtils.asString(row['draft_id_pos']),
            'location_id': V2SyncUtils.asString(row['location_id']),
            'requester_staff_remote_id': requesterRemoteId,
            'requester_name_snapshot': V2SyncUtils.asString(
              row['requester_name'],
            ),
            'requester_role': V2SyncUtils.asString(row['requester_role']),
            'requester_device_id': V2SyncUtils.asString(
              row['requester_device_id'],
            ),
            'shift_session_remote_id': V2SyncUtils.asString(
              row['shift_session_id'],
            ),
            'reason': V2SyncUtils.asString(row['reason']),
            'requested_payload_json': row['requested_payload'] is String
                ? row['requested_payload']
                : V2SyncUtils.encodeJson(row['requested_payload']),
            'status': V2SyncUtils.asString(row['status']),
            'approved_by_staff_remote_id': approverRemoteId,
            'approver_name_snapshot': V2SyncUtils.asString(
              row['approver_name'],
            ),
            'approved_at': V2SyncUtils.asString(row['approved_at']),
            'approval_note': V2SyncUtils.asString(row['approval_note']),
            'rejection_note': V2SyncUtils.asString(row['rejection_note']),
            'expires_at': V2SyncUtils.asString(row['expires_at']),
            'applied_at': V2SyncUtils.asString(row['applied_at']),
            'resolved_reference_type': V2SyncUtils.asString(
              row['resolved_reference_type'],
            ),
            'resolved_reference_remote_id': V2SyncUtils.asString(
              row['resolved_reference_id'],
            ),
            'resolved_reference_number': V2SyncUtils.asString(
              row['resolved_reference_number'],
            ),
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'requester_staff_id': requesterLocalId,
            'approved_by_staff_id': approverLocalId,
            'remote_id': remoteId,
            'request_type': V2SyncUtils.asString(row['request_type']),
            'reference_type': V2SyncUtils.asString(row['reference_type']),
            'reference_remote_id': V2SyncUtils.asString(row['reference_id']),
            'reference_number': V2SyncUtils.asString(row['reference_number']),
            'draft_id_pos': V2SyncUtils.asString(row['draft_id_pos']),
            'location_id': V2SyncUtils.asString(row['location_id']),
            'requester_staff_remote_id': requesterRemoteId,
            'requester_name_snapshot': V2SyncUtils.asString(
              row['requester_name'],
            ),
            'requester_role': V2SyncUtils.asString(row['requester_role']),
            'requester_device_id': V2SyncUtils.asString(
              row['requester_device_id'],
            ),
            'shift_session_remote_id': V2SyncUtils.asString(
              row['shift_session_id'],
            ),
            'reason': V2SyncUtils.asString(row['reason']),
            'requested_payload_json': row['requested_payload'] is String
                ? row['requested_payload']
                : V2SyncUtils.encodeJson(row['requested_payload']),
            'status': V2SyncUtils.asString(row['status']),
            'approved_by_staff_remote_id': approverRemoteId,
            'approver_name_snapshot': V2SyncUtils.asString(
              row['approver_name'],
            ),
            'approved_at': V2SyncUtils.asString(row['approved_at']),
            'approval_note': V2SyncUtils.asString(row['approval_note']),
            'rejection_note': V2SyncUtils.asString(row['rejection_note']),
            'expires_at': V2SyncUtils.asString(row['expires_at']),
            'applied_at': V2SyncUtils.asString(row['applied_at']),
            'resolved_reference_type': V2SyncUtils.asString(
              row['resolved_reference_type'],
            ),
            'resolved_reference_remote_id': V2SyncUtils.asString(
              row['resolved_reference_id'],
            ),
            'resolved_reference_number': V2SyncUtils.asString(
              row['resolved_reference_number'],
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
        endpointName: path.replaceFirst('api/v2/', ''),
        scopeKey: scopeKey,
        notes: 'Approval requests synced locally.',
      );
    });

    return V2SyncResult(
      endpointName: path.replaceFirst('api/v2/', ''),
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
      meta: <String, Object?>{'scopeKey': scopeKey},
    );
  }
}
