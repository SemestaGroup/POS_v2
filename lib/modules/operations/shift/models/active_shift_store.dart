import 'package:flutter/foundation.dart';

import '../../../../app/role_access/role_manager.dart';
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
    this.registerId,
    this.deviceId,
  });

  final int id;
  final String shiftName;
  final String staffName;
  final String locationId;
  final DateTime openedAt;
  final int openingBalance;
  final String? registerId;
  final String? deviceId;
}

class ShiftPaymentMethodRecapRecord {
  const ShiftPaymentMethodRecapRecord({
    required this.remoteId,
    required this.name,
    int? estimatedAmount,
    int? actualAmount,
    int? amount,
  }) : estimatedAmount = estimatedAmount ?? amount ?? 0,
       actualAmount = actualAmount ?? amount ?? estimatedAmount ?? 0;

  final String remoteId;
  final String name;
  final int estimatedAmount;
  final int actualAmount;
}

class ActiveShiftStore {
  ActiveShiftStore._() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(refresh);
  }

  static final ActiveShiftStore instance = ActiveShiftStore._();

  final ValueNotifier<ActiveShiftRecord?> activeShiftNotifier =
      ValueNotifier<ActiveShiftRecord?>(null);

  /// True when a non-cashier user has chosen to enter without opening a shift.
  final ValueNotifier<bool> readOnlyModeNotifier = ValueNotifier<bool>(false);

  /// Expose a convenient getter.
  bool get isReadOnly => readOnlyModeNotifier.value;

  /// Non-cashier: enter the app without opening a shift (read-only).
  void enterReadOnlyMode() {
    readOnlyModeNotifier.value = true;
  }

  /// Clear read-only mode (e.g. when user logs out or opens a shift).
  void exitReadOnlyMode() {
    readOnlyModeNotifier.value = false;
  }

  final PosV2SyncOrchestrator _syncOrchestrator = PosV2SyncOrchestrator();

  Future<void> refresh() async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      activeShiftNotifier.value = null;
      return;
    }

    final role = RoleManager.fromCode(session.staffRoleCode);
    final isCashier = role == AppRole.cashier;
    final staffId = session.staffId;
    final registerId = session.registerId;
    final deviceId = session.deviceId;
    final rows = await DatabaseService.instance.rawQuery(
      isCashier
          ? '''
            SELECT id, shift_name, pos_staff_name_snapshot, location_id,
                   opened_at, opening_balance, source_device_id, register_id
            FROM shift_session
            WHERE tenant_id = ?
              AND status = 'open'
              AND deleted_at IS NULL
              AND (? IS NULL OR pos_staff_remote_id = ?)
            ORDER BY opened_at DESC, id DESC
            LIMIT 1
            '''
          : '''
            SELECT id, shift_name, pos_staff_name_snapshot, location_id,
                   opened_at, opening_balance, source_device_id, register_id
            FROM shift_session
            WHERE tenant_id = ?
              AND status = 'open'
              AND deleted_at IS NULL
              AND (
                (? IS NOT NULL AND register_id = ?)
                OR (? IS NOT NULL AND source_device_id = ?)
                OR (? IS NOT NULL AND location_id = ?)
              )
            ORDER BY opened_at DESC, id DESC
            LIMIT 1
            ''',
      isCashier
          ? <Object?>[session.tenantId, staffId, staffId]
          : <Object?>[
              session.tenantId,
              registerId,
              registerId,
              deviceId,
              deviceId,
              session.locationId,
              session.locationId,
            ],
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
      registerId: row['register_id']?.toString(),
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

    final locationId = int.tryParse(session.locationId);
    if (locationId == null || locationId <= 0) {
      throw Exception(
        'This session does not have a valid location_id yet. Login/bootstrap must complete before opening a shift.',
      );
    }

    try {
      await _syncOrchestrator.openShift(
        session.toSyncContext(),
        locationId: locationId,
        staffId: staffId,
        staffName: session.staffFullName ?? session.staffEmail ?? 'Staff',
        shiftName: shiftName,
        openingBalance: openingBalance,
        deviceId: session.deviceId,
        registerId: session.registerId,
      );
    } catch (e) {
      if (e.toString().toLowerCase().contains(
        'active shift session already exists',
      )) {
        await _syncOrchestrator.syncActiveShift(session.toSyncContext());
      } else {
        rethrow;
      }
    }
    await refresh();
    exitReadOnlyMode();
  }

  String _formatSqlDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  /// Returns estimated cash from local SQLite (payments with cash mode in this shift).
  /// This is an estimate; server is authoritative for final expected_cash.
  Future<int> getEstimatedCashFromSqlite() async {
    final shift = activeShiftNotifier.value;
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (shift == null || session == null) {
      return 0;
    }

    try {
      final openedAtText = _formatSqlDateTime(shift.openedAt);
      final openedAtMs = shift.openedAt.millisecondsSinceEpoch;
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT COALESCE(SUM(p.amount), 0) AS total_cash
        FROM pos_order_payment p
        LEFT JOIN pos_order o ON o.id = p.order_id
        LEFT JOIN payment_mode pm ON pm.remote_id = p.payment_mode_remote_id AND pm.tenant_id = p.tenant_id
        WHERE p.tenant_id = ?
          AND p.deleted_at IS NULL
          AND p.is_refund = 0
          AND (p.payment_date >= ? OR CAST(SUBSTR(p.id_pos, 5) AS INTEGER) >= ?)
          AND (
            (? IS NOT NULL AND ? != '' AND o.register_id = ?)
            OR o.location_id = ?
          )
          AND (
            p.payment_mode_remote_id IS NULL
            OR p.payment_mode_remote_id = ''
            OR LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, '')) LIKE '%cash%'
            OR LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, '')) LIKE '%tunai%'
          )
        ''',
        <Object?>[
          session.tenantId,
          openedAtText,
          openedAtMs,
          shift.registerId,
          shift.registerId,
          shift.registerId,
          shift.locationId,
        ],
      );
      if (rows.isEmpty) return 0;
      final val = rows.first['total_cash'];
      return _asInt(val) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<ShiftPaymentMethodRecapRecord>>
  getNonCashRecapFromSqlite() async {
    final shift = activeShiftNotifier.value;
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (shift == null || session == null) {
      return const <ShiftPaymentMethodRecapRecord>[];
    }

    try {
      final openedAtText = _formatSqlDateTime(shift.openedAt);
      final openedAtMs = shift.openedAt.millisecondsSinceEpoch;
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT
          COALESCE(p.payment_mode_remote_id, '') as payment_mode_remote_id,
          COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, 'Payment') as payment_mode_name,
          COALESCE(SUM(p.amount), 0) as total_amount
        FROM pos_order_payment p
        LEFT JOIN pos_order o ON o.id = p.order_id
        LEFT JOIN payment_mode pm ON pm.remote_id = p.payment_mode_remote_id AND pm.tenant_id = p.tenant_id
        WHERE p.tenant_id = ?
          AND p.deleted_at IS NULL
          AND p.is_refund = 0
          AND (p.payment_date >= ? OR CAST(SUBSTR(p.id_pos, 5) AS INTEGER) >= ?)
          AND (
            (? IS NOT NULL AND ? != '' AND o.register_id = ?)
            OR o.location_id = ?
          )
          AND NOT (
            LOWER(COALESCE(p.payment_method, '')) LIKE '%cash%'
            OR LOWER(COALESCE(p.payment_method, '')) = 'tunai'
            OR LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, '')) LIKE '%cash%'
            OR LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, '')) LIKE '%tunai%'
          )
        GROUP BY p.payment_mode_remote_id, COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name)
        ORDER BY payment_mode_name ASC
        ''',
        <Object?>[
          session.tenantId,
          openedAtText,
          openedAtMs,
          shift.registerId,
          shift.registerId,
          shift.registerId,
          shift.locationId,
        ],
      );

      return rows
          .map(
            (row) => ShiftPaymentMethodRecapRecord(
              remoteId: row['payment_mode_remote_id']?.toString() ?? '',
              name: row['payment_mode_name']?.toString() ?? 'Payment',
              estimatedAmount: _asInt(row['total_amount']) ?? 0,
              actualAmount: _asInt(row['total_amount']) ?? 0,
            ),
          )
          .where((record) => record.name.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <ShiftPaymentMethodRecapRecord>[];
    }
  }

  Future<List<ShiftPaymentMethodRecapRecord>>
  getAvailableNonCashPaymentModes() async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      return const <ShiftPaymentMethodRecapRecord>[];
    }

    final rows = await DatabaseService.instance.query(
      'payment_mode',
      columns: const <String>['remote_id', 'name'],
      where: 'tenant_id = ? AND deleted_at IS NULL AND is_active = 1',
      whereArgs: <Object?>[session.tenantId],
      orderBy: 'selected_by_default DESC, name ASC',
    );

    return rows
        .map(
          (row) => ShiftPaymentMethodRecapRecord(
            remoteId: row['remote_id']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
            estimatedAmount: 0,
            actualAmount: 0,
          ),
        )
        .where(
          (record) =>
              record.remoteId.trim().isNotEmpty &&
              record.name.trim().isNotEmpty &&
              !_isCashLike(record.name),
        )
        .toList(growable: false);
  }

  Future<void> closeShift({
    required int actualCash,
    int? expectedCash,
    int? totalNonCash,
    Map<String, dynamic>? reconciliationJson,
  }) async {
    final shift = activeShiftNotifier.value;
    if (shift == null) {
      throw Exception('Tidak ada shift aktif untuk ditutup.');
    }

    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      throw Exception('Session tidak ditemukan. Login ulang diperlukan.');
    }

    await _syncOrchestrator.closeShift(
      session.toSyncContext(),
      shiftRemoteId: shift.id,
      actualCash: actualCash,
      expectedCash: expectedCash,
      totalNonCash: totalNonCash,
      reconciliationJson: reconciliationJson,
    );
    await refresh();
  }

  bool _isCashLike(String name) {
    final lower = name.trim().toLowerCase();
    return lower.contains('cash') || lower.contains('tunai');
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
