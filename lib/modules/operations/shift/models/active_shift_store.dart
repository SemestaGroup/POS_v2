import 'package:flutter/foundation.dart';

import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../core/services/sync/pos_v2_sync_orchestrator.dart';

class ActiveShiftRecord {
  const ActiveShiftRecord({
    required this.id,
    required this.shiftName,
    required this.staffName,
    required this.locationId,
    required this.openedAt,
    required this.openingBalance,
    this.deviceId,
  });

  final int id;
  final String shiftName;
  final String staffName;
  final String locationId;
  final DateTime openedAt;
  final int openingBalance;
  final String? deviceId;
}

class ActiveShiftStore {
  ActiveShiftStore._() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(refresh);
  }

  static final ActiveShiftStore instance = ActiveShiftStore._();

  final ValueNotifier<ActiveShiftRecord?> activeShiftNotifier =
      ValueNotifier<ActiveShiftRecord?>(null);
  final PosV2SyncOrchestrator _syncOrchestrator = PosV2SyncOrchestrator();

  Future<void> refresh() async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      activeShiftNotifier.value = null;
      return;
    }

    final staffId = session.staffId;
    final deviceId = session.deviceId;
    final rows = await DatabaseService.instance.rawQuery(
      '''
      SELECT id, shift_name, pos_staff_name_snapshot, location_id,
             opened_at, opening_balance, source_device_id
      FROM shift_session
      WHERE tenant_id = ?
        AND status = 'open'
        AND deleted_at IS NULL
        AND (? IS NULL OR pos_staff_remote_id = ?)
        AND (? IS NULL OR source_device_id = ?)
      ORDER BY opened_at DESC, id DESC
      LIMIT 1
      ''',
      <Object?>[session.tenantId, staffId, staffId, deviceId, deviceId],
    );

    if (rows.isEmpty) {
      activeShiftNotifier.value = null;
      return;
    }

    final row = rows.first;
    activeShiftNotifier.value = ActiveShiftRecord(
      id: _asInt(row['id']) ?? 0,
      shiftName: row['shift_name']?.toString() ?? '',
      staffName: row['pos_staff_name_snapshot']?.toString() ?? '',
      locationId: row['location_id']?.toString() ?? '',
      openedAt:
          DateTime.tryParse(
            (row['opened_at']?.toString() ?? '').replaceFirst(' ', 'T'),
          ) ??
          DateTime.now(),
      openingBalance: _asInt(row['opening_balance']) ?? 0,
      deviceId: row['source_device_id']?.toString(),
    );
  }

  Future<void> openShift({
    required String shiftName,
    required int openingBalance,
  }) async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found for opening shift');
    }

    final staffId = int.tryParse(session.staffId ?? '');
    if (staffId == null || staffId <= 0) {
      throw Exception(
        'This account cannot open a shift because no staff_id was returned by the backend.',
      );
    }

    await _syncOrchestrator.openShift(
      session.toSyncContext(),
      locationId: int.tryParse(session.locationId) ?? 0,
      staffId: staffId,
      staffName: session.staffFullName ?? session.staffEmail ?? 'Staff',
      shiftName: shiftName,
      openingBalance: openingBalance,
      deviceId: session.deviceId,
    );
    await refresh();
  }

  int? _asInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse(value.toString().split('.').first);
  }
}
