import 'dart:convert';

import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class ShiftSyncAdapter extends BaseV2SyncAdapter {
  ShiftSyncAdapter({super.databaseService});

  /// Opens a shift remotely and mirrors it locally.
  ///
  /// [localShiftId] identifies an existing local `shift_session` row that was
  /// created offline and is now being retried (e.g. from
  /// [syncPendingLocalShifts]). When set, a successful remote call attaches
  /// the returned `remote_id` to that SAME row (by id) instead of going
  /// through [_upsertShiftRow] — which keys its upsert on `remote_id` and
  /// would otherwise insert a brand-new row (since this row has no
  /// `remote_id` yet), leaving the original pending row orphaned and causing
  /// a duplicate shift to be opened on every retry. Likewise, while still
  /// offline, a retry must not insert another fresh local row for the same
  /// shift.
  Future<V2SyncResult> openShift(
    V2SyncContext context, {
    required int locationId,
    required int staffId,
    required String staffName,
    required String shiftName,
    required int openingBalance,
    String? deviceId,
    String? registerId,
    int? localShiftId,
  }) async {
    Map<String, dynamic> row = {};
    bool isOffline = false;

    try {
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
      ).timeout(const Duration(seconds: 8));
      row = V2SyncUtils.asMap(envelope['data']) ?? const <String, dynamic>{};
    } catch (e) {
      if (e.toString().toLowerCase().contains('active shift session already exists')) {
        rethrow;
      }
      isOffline = true;
    }

    var upsertedCount = 0;
    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      final now = V2SyncUtils.nowIso();

      if (isOffline || row.isEmpty) {
        if (localShiftId != null) {
          // Still offline on retry: the pending row already represents this
          // shift, so there is nothing new to persist.
          return;
        }
        final staffLocalId = await findLocalIdByRemoteId(txn, 'staff', tenantId, staffId.toString());
        await txn.insert('shift_session', <String, Object?>{
          'tenant_id': tenantId,
          'remote_id': null,
          'location_id': locationId.toString(),
          'pos_staff_id': staffLocalId,
          'pos_staff_remote_id': staffId.toString(),
          'pos_staff_name_snapshot': staffName,
          'shift_name': shiftName,
          'source_device_id': deviceId,
          'register_id': registerId ?? context.registerId,
          'business_date': now.substring(0, 10),
          'opened_at': now,
          'opening_balance': openingBalance,
          'status': 'open',
          'sync_state': 'pending',
          'created_at': now,
          'updated_at': now,
        });
        upsertedCount = 1;
        await touchCheckpoint(
          txn,
          tenantId,
          endpointName: 'pos-shift-sessions/open',
          scopeKey: 'local',
          notes: 'Shift opened offline and stored locally.',
        );
      } else if (localShiftId != null) {
        final staffLocalId = await findLocalIdByRemoteId(txn, 'staff', tenantId, staffId.toString());
        await txn.update(
          'shift_session',
          <String, Object?>{
            'remote_id': V2SyncUtils.asString(row['id']),
            'pos_staff_id': staffLocalId,
            'status': V2SyncUtils.asString(row['status']) ?? 'open',
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'sync_state': 'clean',
            'last_synced_at': now,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: <Object?>[localShiftId],
        );
        upsertedCount = 1;
        await touchCheckpoint(
          txn,
          tenantId,
          endpointName: 'pos-shift-sessions/open',
          scopeKey: row['id']?.toString() ?? 'new',
          notes: 'Offline shift attached to remote session on retry.',
        );
      } else {
        upsertedCount += await _upsertShiftRow(txn, tenantId, row);
        await touchCheckpoint(
          txn,
          tenantId,
          endpointName: 'pos-shift-sessions/open',
          scopeKey: row['id']?.toString() ?? 'new',
          notes: 'Shift opened online and stored locally.',
        );
      }
    });

    return V2SyncResult(
      endpointName: 'pos-shift-sessions/open',
      fetchedCount: 1,
      upsertedCount: upsertedCount,
    );
  }

  Future<V2SyncResult> closeShift(
    V2SyncContext context, {
    required int shiftLocalId,
    required int actualCash,
    int? expectedCash,
    int? totalNonCash,
    Map<String, dynamic>? reconciliationJson,
  }) async {
    final now = DateTime.now();
    final closedAt =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    var upsertedCount = 0;
    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);

      final rows = await txn.query(
        'shift_session',
        columns: ['remote_id', 'status', 'sync_state'],
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [shiftLocalId, tenantId],
      );
      if (rows.isEmpty) {
        throw Exception('Shift session not found locally.');
      }
      final remoteId = V2SyncUtils.asString(rows.first['remote_id']);

      // Idempotency guard: if this shift is already closed AND confirmed
      // synced with the server, do not fire another close call. Without
      // this, a retry from syncPendingLocalShifts (e.g. triggered again
      // after a slow response that actually succeeded server-side) would
      // re-POST close indefinitely, risking the backend treating each retry
      // as a fresh close and overwriting the original reconciliation.
      final currentStatus = V2SyncUtils.asString(rows.first['status']);
      final currentSyncState = V2SyncUtils.asString(rows.first['sync_state']);
      if (currentStatus == 'closed' && currentSyncState == 'clean') {
        return;
      }

      Map<String, dynamic> row = {};
      bool isOffline = false;

      if (remoteId != null && remoteId.isNotEmpty) {
        try {
          final envelope = await buildClient(context).postEnvelope(
            'api/v2/pos-shift-sessions/$remoteId/close',
            body: <String, dynamic>{
              'closed_at': closedAt,
              'actual_cash': actualCash,
              'expected_cash': expectedCash ?? 0,
              'closing_balance': actualCash,
              'total_non_cash': totalNonCash ?? 0,
              'reconciliation_json': reconciliationJson ?? <String, dynamic>{},
            },
          ).timeout(const Duration(seconds: 8));
          row = V2SyncUtils.asMap(envelope['data']) ?? const <String, dynamic>{};
        } catch (_) {
          isOffline = true;
        }
      } else {
        isOffline = true;
      }

      if (isOffline || row.isEmpty) {
        await txn.update(
          'shift_session',
          <String, Object?>{
            'status': 'closed',
            'closed_at': closedAt,
            'actual_cash': actualCash,
            'expected_cash': expectedCash ?? 0,
            'closing_balance': actualCash,
            'total_non_cash': totalNonCash ?? 0,
            'sync_state': 'pending',
            'updated_at': V2SyncUtils.nowIso(),
          },
          where: 'id = ?',
          whereArgs: <Object?>[shiftLocalId],
        );
        upsertedCount = 1;
        await touchCheckpoint(
          txn,
          tenantId,
          endpointName: 'pos-shift-sessions/close',
          scopeKey: 'local_$shiftLocalId',
          notes: 'Shift closed offline.',
        );
      } else {
        upsertedCount += await _upsertShiftRow(txn, tenantId, row);
        await touchCheckpoint(
          txn,
          tenantId,
          endpointName: 'pos-shift-sessions/close',
          scopeKey: remoteId.toString(),
          notes: 'Shift closed online.',
        );
      }
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

    final closedAtStr = V2SyncUtils.asString(row['closed_at']);
    final rawStatus = V2SyncUtils.asString(row['status']);
    final resolvedStatus = (closedAtStr != null && closedAtStr.isNotEmpty)
        ? 'closed'
        : (rawStatus ?? 'open');

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
        'closed_at': closedAtStr,
        'opening_balance': V2SyncUtils.moneyToMinor(row['opening_balance']),
        'closing_balance': V2SyncUtils.moneyToMinor(row['closing_balance']),
        'expected_cash': V2SyncUtils.moneyToMinor(row['expected_cash']),
        'actual_cash': V2SyncUtils.moneyToMinor(row['actual_cash']),
        'total_non_cash': V2SyncUtils.moneyToMinor(row['total_non_cash']),
        'status': resolvedStatus,
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
        'closed_at': closedAtStr,
        'opening_balance': V2SyncUtils.moneyToMinor(row['opening_balance']),
        'closing_balance': V2SyncUtils.moneyToMinor(row['closing_balance']),
        'expected_cash': V2SyncUtils.moneyToMinor(row['expected_cash']),
        'actual_cash': V2SyncUtils.moneyToMinor(row['actual_cash']),
        'total_non_cash': V2SyncUtils.moneyToMinor(row['total_non_cash']),
        'status': resolvedStatus,
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

  /// Pushes any shift opened and/or closed while offline up to the server.
  ///
  /// Deliberately does NOT wrap this loop in a single `databaseService
  /// .transaction`: [openShift] and [closeShift] each open their own
  /// transaction, and sqflite cannot start a nested transaction on the same
  /// connection — doing so previously deadlocked this method whenever there
  /// were pending rows to push, since the outer transaction's callback can
  /// never complete while awaiting an inner transaction that is queued
  /// behind it.
  Future<void> syncPendingLocalShifts(V2SyncContext context) async {
    final db = await databaseService.database;
    final tenantId = await ensureTenantId(db, context);
    final rows = await db.query(
      'shift_session',
      where: 'tenant_id = ? AND sync_state = ?',
      whereArgs: [tenantId, 'pending'],
    );
    if (rows.isEmpty) return;

    for (final row in rows) {
      final status = row['status']?.toString();
      final localId = V2SyncUtils.asInt(row['id']);
      var remoteId = row['remote_id']?.toString();

      try {
        if ((remoteId == null || remoteId.isEmpty) &&
            (status == 'open' || status == 'closed')) {
          // Covers both a shift still open offline and one that was opened
          // AND closed entirely offline (no remote_id ever assigned) — the
          // latter used to be silently skipped here and stayed stuck locally
          // forever, since only the 'open' branch used to retry openShift.
          await openShift(
            context,
            locationId: V2SyncUtils.asInt(row['location_id']),
            staffId: V2SyncUtils.asInt(row['pos_staff_remote_id']),
            staffName: row['pos_staff_name_snapshot']?.toString() ?? '',
            shiftName: row['shift_name']?.toString() ?? '',
            openingBalance: V2SyncUtils.asInt(row['opening_balance']),
            deviceId: row['source_device_id']?.toString(),
            registerId: row['register_id']?.toString(),
            localShiftId: localId,
          );
          final refreshed = await db.query(
            'shift_session',
            columns: ['remote_id'],
            where: 'id = ?',
            whereArgs: <Object?>[localId],
          );
          remoteId = refreshed.isNotEmpty
              ? V2SyncUtils.asString(refreshed.first['remote_id'])
              : null;
        }

        if (status == 'closed' && remoteId != null && remoteId.isNotEmpty) {
          await closeShift(
            context,
            shiftLocalId: localId,
            actualCash: V2SyncUtils.asInt(row['actual_cash']),
            expectedCash: V2SyncUtils.asInt(row['expected_cash']),
            totalNonCash: V2SyncUtils.asInt(row['total_non_cash']),
            reconciliationJson: V2SyncUtils.asMap(row['reconciliation_json'] != null ? jsonDecode(row['reconciliation_json'].toString()) : null),
          );
        }
      } catch (_) {}
    }
  }
}
