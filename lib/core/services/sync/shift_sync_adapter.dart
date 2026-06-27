import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class ShiftSyncAdapter extends BaseV2SyncAdapter {
  ShiftSyncAdapter({super.databaseService});

  Future<V2SyncResult> openShift(
    V2SyncContext context, {
    required int locationId,
    required int staffId,
    required String staffName,
    required String shiftName,
    required int openingBalance,
    String? deviceId,
    String? registerId,
  }) async {
    final envelope = await buildClient(context).postEnvelope(
      'api/v2/pos-shift-sessions/open',
      body: <String, dynamic>{
        'location_id': locationId,
        'staff_id': staffId,
        'staff_name': staffName,
        'shift_name': shiftName,
        'opening_balance': openingBalance,
        'device_id': deviceId,
        'register_id': registerId ?? context.registerId,
      },
    );
    final row =
        V2SyncUtils.asMap(envelope['data']) ?? const <String, dynamic>{};
    if (row.isEmpty) {
      return const V2SyncResult(endpointName: 'pos-shift-sessions/open');
    }

    var upsertedCount = 0;
    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      upsertedCount += await _upsertShiftRow(txn, tenantId, row);
      await touchCheckpoint(
        txn,
        tenantId,
        endpointName: 'pos-shift-sessions/open',
        scopeKey: row['id']?.toString() ?? 'new',
        notes: 'Shift opened and stored locally.',
      );
    });

    return V2SyncResult(
      endpointName: 'pos-shift-sessions/open',
      fetchedCount: 1,
      upsertedCount: upsertedCount,
    );
  }

  Future<V2SyncResult> closeShift(
    V2SyncContext context, {
    required int shiftRemoteId,
    required int actualCash,
    int? expectedCash,
    int? totalNonCash,
    Map<String, dynamic>? reconciliationJson,
  }) async {
    final now = DateTime.now();
    final closedAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final envelope = await buildClient(context).postEnvelope(
      'api/v2/pos-shift-sessions/$shiftRemoteId/close',
      body: <String, dynamic>{
        'closed_at': closedAt,
        'actual_cash': actualCash,
        'expected_cash': expectedCash ?? 0,
        'closing_balance': actualCash,
        'total_non_cash': totalNonCash ?? 0,
        'reconciliation_json': reconciliationJson ?? <String, dynamic>{},
      },
    );
    final row =
        V2SyncUtils.asMap(envelope['data']) ?? const <String, dynamic>{};

    var upsertedCount = 0;
    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      if (row.isNotEmpty) {
        upsertedCount += await _upsertShiftRow(txn, tenantId, row);
      } else {
        // Fallback: update locally by remote_id
        await txn.rawUpdate(
          '''
          UPDATE shift_session
          SET status = 'closed',
              closed_at = ?,
              actual_cash = ?,
              expected_cash = ?,
              closing_balance = ?,
              total_non_cash = ?,
              updated_at = ?
          WHERE tenant_id = ? AND remote_id = ?
          ''',
          <Object?>[
            closedAt,
            actualCash,
            expectedCash ?? 0,
            actualCash,
            totalNonCash ?? 0,
            closedAt,
            tenantId,
            shiftRemoteId.toString(),
          ],
        );
        upsertedCount = 1;
      }
      await touchCheckpoint(
        txn,
        tenantId,
        endpointName: 'pos-shift-sessions/close',
        scopeKey: shiftRemoteId.toString(),
        notes: 'Shift closed.',
      );
    });

    return V2SyncResult(
      endpointName: 'pos-shift-sessions/close',
      fetchedCount: 1,
      upsertedCount: upsertedCount,
    );
  }

  Future<V2SyncResult> sync(
    V2SyncContext context, {
    Map<String, dynamic>? query,
    String path = 'api/v2/pos-shift-sessions',
    bool allowNotFoundEmpty = false,
  }) async {
    Map<String, dynamic> envelope;
    try {
      envelope = await buildClient(context).getEnvelope(path, query: query);
    } catch (error) {
      if (allowNotFoundEmpty &&
          error.toString().contains('No active shift session found')) {
        return V2SyncResult(
          endpointName: path.replaceFirst('api/v2/', ''),
          fetchedCount: 0,
          upsertedCount: 0,
          meta: <String, Object?>{
            'scopeKey': query == null || query.isEmpty ? path : '$path::$query',
          },
        );
      }
      rethrow;
    }
    final data = envelope['data'];
    final rows = data is Map<String, dynamic>
        ? <Map<String, dynamic>>[data]
        : V2SyncUtils.asMapList(data);
    final scopeKey = query == null || query.isEmpty ? path : '$path::$query';

    var upsertedCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);

      for (final row in rows) {
        upsertedCount += await _upsertShiftRow(txn, tenantId, row);
      }

      await touchCheckpoint(
        txn,
        tenantId,
        endpointName: path.replaceFirst('api/v2/', ''),
        scopeKey: scopeKey,
        notes: 'Shift session payload stored locally.',
      );
    });

    return V2SyncResult(
      endpointName: path.replaceFirst('api/v2/', ''),
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
      meta: <String, Object?>{'scopeKey': scopeKey},
    );
  }

  Future<int> _upsertShiftRow(
    dynamic txn,
    int tenantId,
    Map<String, dynamic> row,
  ) async {
    final remoteId = V2SyncUtils.asString(row['id']);
    if (remoteId == null) {
      return 0;
    }
    final staffRemoteId = V2SyncUtils.asString(row['pos_staff_id']);
    final staffLocalId = await findLocalIdByRemoteId(
      txn,
      'staff',
      tenantId,
      staffRemoteId,
    );
    final now = V2SyncUtils.nowIso();

    await databaseService.upsertByUnique(
      txn,
      'shift_session',
      where: 'tenant_id = ? AND remote_id = ?',
      whereArgs: <Object?>[tenantId, remoteId],
      insertValues: <String, Object?>{
        'tenant_id': tenantId,
        'remote_id': remoteId,
        'location_id': V2SyncUtils.asString(row['location_id']),
        'pos_staff_id': staffLocalId,
        'pos_staff_remote_id': staffRemoteId,
        'pos_staff_name_snapshot': V2SyncUtils.asString(
          row['pos_staff_name_snapshot'],
        ),
        'shift_name': V2SyncUtils.asString(row['shift_name']),
        'source_device_id': V2SyncUtils.asString(row['source_device_id']),
        'register_id': V2SyncUtils.asString(row['register_id']),
        'business_date': V2SyncUtils.asString(row['business_date']),
        'opened_at': V2SyncUtils.asString(row['opened_at']),
        'closed_at': V2SyncUtils.asString(row['closed_at']),
        'opening_balance': V2SyncUtils.moneyToMinor(row['opening_balance']),
        'closing_balance': V2SyncUtils.moneyToMinor(row['closing_balance']),
        'expected_cash': V2SyncUtils.moneyToMinor(row['expected_cash']),
        'actual_cash': V2SyncUtils.moneyToMinor(row['actual_cash']),
        'total_non_cash': V2SyncUtils.moneyToMinor(row['total_non_cash']),
        'status': V2SyncUtils.asString(row['status']) ?? 'open',
        'reconciliation_json': row['reconciliation_json'] is String
            ? row['reconciliation_json']
            : V2SyncUtils.encodeJson(row['reconciliation_json']),
        'raw_payload_json': V2SyncUtils.encodeJson(row),
        'last_synced_at': now,
        'created_at': now,
        'updated_at': now,
      },
      updateValues: <String, Object?>{
        'location_id': V2SyncUtils.asString(row['location_id']),
        'pos_staff_id': staffLocalId,
        'pos_staff_remote_id': staffRemoteId,
        'pos_staff_name_snapshot': V2SyncUtils.asString(
          row['pos_staff_name_snapshot'],
        ),
        'shift_name': V2SyncUtils.asString(row['shift_name']),
        'source_device_id': V2SyncUtils.asString(row['source_device_id']),
        'register_id': V2SyncUtils.asString(row['register_id']),
        'business_date': V2SyncUtils.asString(row['business_date']),
        'opened_at': V2SyncUtils.asString(row['opened_at']),
        'closed_at': V2SyncUtils.asString(row['closed_at']),
        'opening_balance': V2SyncUtils.moneyToMinor(row['opening_balance']),
        'closing_balance': V2SyncUtils.moneyToMinor(row['closing_balance']),
        'expected_cash': V2SyncUtils.moneyToMinor(row['expected_cash']),
        'actual_cash': V2SyncUtils.moneyToMinor(row['actual_cash']),
        'total_non_cash': V2SyncUtils.moneyToMinor(row['total_non_cash']),
        'status': V2SyncUtils.asString(row['status']) ?? 'open',
        'reconciliation_json': row['reconciliation_json'] is String
            ? row['reconciliation_json']
            : V2SyncUtils.encodeJson(row['reconciliation_json']),
        'raw_payload_json': V2SyncUtils.encodeJson(row),
        'last_synced_at': now,
        'updated_at': now,
        'deleted_at': null,
      },
    );
    return 1;
  }
}
