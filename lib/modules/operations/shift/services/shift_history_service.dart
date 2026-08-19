import 'dart:convert';

import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../models/shift_detail_data.dart';
import '../models/shift_history_item.dart';

class ShiftHistoryService {
  ShiftHistoryService._();
  static final ShiftHistoryService instance = ShiftHistoryService._();

  Future<List<ShiftHistoryItem>> fetchShiftHistory({
    String? tenantKey,
    int limit = 100,
  }) async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) return [];

    final keyToUse = tenantKey ?? session.tenantKey;

    try {
      await PosV2SyncOrchestrator().syncShiftHistory(session.toSyncContext());
    } catch (_) {}

    final db = DatabaseService.instance;
    final tenantRows = await db.rawQuery(
      'SELECT id FROM app_tenant WHERE tenant_key = ? LIMIT 1',
      <Object?>[keyToUse],
    );

    if (tenantRows.isEmpty) {
      return [];
    }

    final tenantId = tenantRows.first['id'] as int;
    return fetchShiftHistoryByTenantId(tenantId, limit: limit);
  }

  Future<List<ShiftHistoryItem>> fetchShiftHistoryByTenantId(
    int tenantId, {
    int limit = 100,
  }) async {
    final db = DatabaseService.instance;
    final raw = await db.rawQuery(
      '''
      SELECT s.id, s.shift_name, s.pos_staff_name_snapshot, s.register_id,
             s.status, s.opened_at, s.closed_at, s.remote_id,
             s.opening_balance, s.expected_cash, s.actual_cash, s.total_non_cash,
             s.reconciliation_json,
             COALESCE((
               SELECT SUM(cf.amount)
               FROM pos_cash_flow cf
               WHERE (cf.tenant_id = s.tenant_id OR cf.tenant_id IS NULL)
                 AND cf.type IN ('in', 'cash_in')
                 AND cf.deleted_at IS NULL
                 AND (
                   cf.shift_session_id = s.id
                   OR (
                     cf.shift_session_id IS NULL
                     AND
                     substr(replace(cf.created_at, 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                     AND (s.closed_at IS NULL OR substr(replace(cf.created_at, 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
                   )
                 )
             ), 0) AS total_cash_in,
             COALESCE((
               SELECT SUM(cf.amount)
               FROM pos_cash_flow cf
               WHERE (cf.tenant_id = s.tenant_id OR cf.tenant_id IS NULL)
                 AND cf.type IN ('out', 'cash_out')
                 AND cf.deleted_at IS NULL
                 AND (
                   cf.shift_session_id = s.id
                   OR (
                     cf.shift_session_id IS NULL
                     AND
                     substr(replace(cf.created_at, 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                     AND (s.closed_at IS NULL OR substr(replace(cf.created_at, 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
                   )
                 )
             ), 0) AS total_cash_out,
             COALESCE((
               SELECT SUM(p.amount)
               FROM pos_order_payment p
               JOIN pos_order o ON p.order_id = o.id
               LEFT JOIN payment_mode pm ON pm.id = p.payment_mode_id OR (p.payment_mode_remote_id IS NOT NULL AND pm.remote_id = p.payment_mode_remote_id)
              WHERE (o.tenant_id = s.tenant_id OR o.tenant_id IS NULL)
                AND (o.status_code IN ('2', '4', 2, 4) OR LOWER(CAST(o.status_code AS TEXT)) IN ('paid', 'completed'))
                AND p.deleted_at IS NULL
                AND p.is_refund = 0
                AND (
                  o.shift_session_id = s.id
                  OR (o.shift_session_remote_id IS NOT NULL AND o.shift_session_remote_id != '' AND s.remote_id IS NOT NULL AND s.remote_id != '' AND o.shift_session_remote_id = s.remote_id)
                  OR (
                    o.shift_session_id IS NULL
                    AND
                    substr(replace(COALESCE(NULLIF(o.created_at, ''), o.order_date), 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                    AND (s.closed_at IS NULL OR substr(replace(COALESCE(NULLIF(o.created_at, ''), o.order_date), 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
                  )
                )
                 AND (
                   LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), '')) LIKE '%cash%'
                   OR LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), '')) LIKE '%tunai%'
                   OR COALESCE(p.payment_mode_name_snapshot, pm.name, p.payment_method, '') = ''
                 )
             ), 0) AS cash_sales,
             COALESCE((
               SELECT SUM(p.amount)
               FROM pos_order_payment p
               JOIN pos_order o ON p.order_id = o.id
               LEFT JOIN payment_mode pm ON pm.id = p.payment_mode_id OR (p.payment_mode_remote_id IS NOT NULL AND pm.remote_id = p.payment_mode_remote_id)
              WHERE (o.tenant_id = s.tenant_id OR o.tenant_id IS NULL)
                AND (o.status_code IN ('2', '4', 2, 4) OR LOWER(CAST(o.status_code AS TEXT)) IN ('paid', 'completed'))
                AND p.deleted_at IS NULL
                AND p.is_refund = 0
                AND (
                  o.shift_session_id = s.id
                  OR (o.shift_session_remote_id IS NOT NULL AND o.shift_session_remote_id != '' AND s.remote_id IS NOT NULL AND s.remote_id != '' AND o.shift_session_remote_id = s.remote_id)
                  OR (
                    o.shift_session_id IS NULL
                    AND
                    substr(replace(COALESCE(NULLIF(o.created_at, ''), o.order_date), 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                    AND (s.closed_at IS NULL OR substr(replace(COALESCE(NULLIF(o.created_at, ''), o.order_date), 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
                  )
                )
                 AND NOT (
                   LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), '')) LIKE '%cash%'
                   OR LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), '')) LIKE '%tunai%'
                 )
             ), 0) AS non_cash_sales
      FROM shift_session s
      WHERE (s.tenant_id = ? OR s.tenant_id IS NULL) AND s.deleted_at IS NULL
      ORDER BY s.opened_at DESC
      LIMIT ?
      ''',
      [tenantId, limit],
    );

    int asInt(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is double) return val.round();
      if (val is String) return (double.tryParse(val) ?? 0).round();
      return 0;
    }

    final items = <ShiftHistoryItem>[];
    for (final r in raw) {
      final id = r['id'] as int;
      final shiftName = (r['shift_name'] ?? '').toString();
      final staffName = (r['pos_staff_name_snapshot'] ?? 'Kasir').toString();
      final registerId = r['register_id']?.toString();
      final status = (r['status'] ?? 'open').toString();
      final openedAtStr = r['opened_at']?.toString() ?? '';
      final closedAtStr = r['closed_at']?.toString();

      final openedAt = DateTime.tryParse(openedAtStr) ?? DateTime.now();
      final closedAt = closedAtStr != null
          ? DateTime.tryParse(closedAtStr)
          : null;

      final openingBalance = asInt(r['opening_balance']);
      int expectedCash = asInt(r['expected_cash']);
      int actualCash = asInt(r['actual_cash']);
      int nonCash = asInt(r['non_cash_sales']);
      if (nonCash == 0) {
        nonCash = asInt(r['total_non_cash']);
      }
      final cashSales = asInt(r['cash_sales']);
      final totalCashIn = asInt(r['total_cash_in']);
      final totalCashOut = asInt(r['total_cash_out']);

      if (r['reconciliation_json'] != null) {
        try {
          final reconc = r['reconciliation_json'] is String
              ? jsonDecode(r['reconciliation_json'] as String)
              : r['reconciliation_json'];
          if (reconc is Map) {
            if (expectedCash == 0) {
              expectedCash = asInt(
                reconc['expected_cash'] ??
                    reconc['expectedCash'] ??
                    reconc['expected_cash_amount'],
              );
            }
            if (actualCash == 0) {
              actualCash = asInt(
                reconc['actual_cash'] ??
                    reconc['actualCash'] ??
                    reconc['actual_cash_amount'] ??
                    reconc['closing_balance'],
              );
            }
            if (nonCash == 0) {
              nonCash = asInt(
                reconc['total_non_cash'] ??
                    reconc['totalNonCash'] ??
                    reconc['total_non_cash_amount'],
              );
              if (nonCash == 0 && reconc['payment_modes'] is List) {
                int sum = 0;
                for (final pm in reconc['payment_modes']) {
                  if (pm is Map) {
                    final modeName =
                        (pm['name'] ?? pm['payment_mode_name'] ?? '')
                            .toString()
                            .toLowerCase();
                    if (!modeName.contains('cash') &&
                        !modeName.contains('tunai')) {
                      sum += asInt(pm['amount'] ?? pm['estimated_amount']);
                    }
                  }
                }
                if (sum > 0) nonCash = sum;
              }
            }
          }
        } catch (_) {}
      }

      items.add(
        ShiftHistoryItem(
          id: id,
          shiftName: shiftName,
          staffName: staffName,
          registerId: registerId,
          status: status,
          openedAt: openedAt,
          closedAt: closedAt,
          openingBalance: openingBalance,
          expectedCash: expectedCash,
          actualCash: actualCash,
          totalNonCash: nonCash,
          cashSales: cashSales,
          totalCashIn: totalCashIn,
          totalCashOut: totalCashOut,
          rawData: r['reconciliation_json'] is String
              ? tryJsonDecode(r['reconciliation_json'] as String)
              : r['reconciliation_json'],
        ),
      );
    }

    return items;
  }

  static dynamic tryJsonDecode(String str) {
    try {
      return jsonDecode(str);
    } catch (_) {
      return null;
    }
  }

  Future<ShiftDetailData> fetchShiftDetailData({
    required int shiftId,
    required DateTime openedAt,
    DateTime? closedAt,
    int? tenantId,
  }) async {
    final db = DatabaseService.instance;

    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();

    int activeTenantId = tenantId ?? (session?.tenantId ?? 1);
    if (session != null) {
      final tenantRows = await db.rawQuery(
        'SELECT id FROM app_tenant WHERE tenant_key = ? LIMIT 1',
        <Object?>[session.tenantKey],
      );
      if (tenantRows.isNotEmpty) {
        activeTenantId = tenantRows.first['id'] as int;
      }
    }

    String fmtSql(DateTime? dt) {
      if (dt == null) return '9999-12-31 23:59:59';
      final local = dt.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    }

    List<Map<String, dynamic>> shiftRemoteRows = [];
    try {
      shiftRemoteRows = await db.rawQuery(
        'SELECT tenant_id, remote_id FROM shift_session WHERE id = ? LIMIT 1',
        <Object?>[shiftId],
      );
    } catch (_) {}

    if (tenantId == null &&
        shiftRemoteRows.isNotEmpty &&
        shiftRemoteRows.first['tenant_id'] != null) {
      activeTenantId = shiftRemoteRows.first['tenant_id'] as int;
    }

    final shiftRemoteIdRaw = shiftRemoteRows.isNotEmpty
        ? shiftRemoteRows.first['remote_id']?.toString()
        : null;
    final shiftRemoteId =
        (shiftRemoteIdRaw != null && shiftRemoteIdRaw.trim().isNotEmpty)
        ? shiftRemoteIdRaw.trim()
        : null;

    final startStr = fmtSql(openedAt);
    final endStr = fmtSql(closedAt);

    final sessionTenantId = session?.tenantId ?? 1;
    List<Object?> orderArgs = [
      activeTenantId,
      sessionTenantId,
      shiftId,
      shiftId.toString(),
      shiftRemoteId,
      shiftRemoteId,
      startStr,
      endStr,
    ];

    // History sync intentionally fetches order headers first.  Product rows
    // live in the order-detail response, so hydrate only the selected shift's
    // completed orders which have not stored their item rows yet.
    if (session != null) {
      final missingItemOrderRows = await db.rawQuery('''
        SELECT o.remote_id
        FROM pos_order o
        WHERE (o.tenant_id = ? OR o.tenant_id = ? OR o.tenant_id IS NULL OR o.tenant_id = 0)
          AND (o.deleted_at IS NULL OR o.deleted_at = '' OR o.deleted_at = '0')
          AND (o.status_code IN ('2', '4', 2, 4) OR LOWER(CAST(o.status_code AS TEXT)) IN ('paid', 'completed'))
          AND o.remote_id IS NOT NULL
          AND o.remote_id != ''
          AND NOT EXISTS (
            SELECT 1
            FROM pos_order_item i
            WHERE i.order_id = o.id
              AND (i.deleted_at IS NULL OR i.deleted_at = '' OR i.deleted_at = '0')
          )
          AND (
            o.shift_session_id = ?
            OR CAST(o.shift_session_id AS TEXT) = ?
            OR (? IS NOT NULL AND o.shift_session_remote_id = ?)
            OR (
              (CASE WHEN length(trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19))) <= 10
                    THEN trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 10)) || ' 00:00:00'
                    ELSE substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19) END) >= ?
              AND
              (CASE WHEN length(trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19))) <= 10
                    THEN trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 10)) || ' 23:59:59'
                    ELSE substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19) END) <= ?
            )
          )
        LIMIT 100
        ''', orderArgs);

      for (final row in missingItemOrderRows) {
        final remoteOrderId = row['remote_id']?.toString().trim() ?? '';
        if (remoteOrderId.isEmpty) continue;
        try {
          await PosV2SyncOrchestrator().syncOrderDetail(
            session.toSyncContext(),
            remoteOrderId,
          );
        } catch (_) {
          // Keep loading other order details if one historical order is gone.
        }
      }
    }

    final orderSummaryRows = await db.rawQuery('''
      SELECT subtotal_amount, discount_total_amount, manual_discount_value, total_amount, custom_fields_json
      FROM pos_order o
      WHERE (o.tenant_id = ? OR o.tenant_id = ? OR o.tenant_id IS NULL OR o.tenant_id = 0)
        AND (o.deleted_at IS NULL OR o.deleted_at = '' OR o.deleted_at = '0')
        AND (o.status_code IS NULL OR o.status_code = '' OR o.status_code NOT IN ('5', '6', 'void', 'refunded', 'cancelled', 'canceled'))
        AND (
          o.shift_session_id = ?
          OR CAST(o.shift_session_id AS TEXT) = ?
          OR (? IS NOT NULL AND o.shift_session_remote_id = ?)
          OR (
            (CASE WHEN length(trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19))) <= 10 
                  THEN trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 10)) || ' 00:00:00' 
                  ELSE substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19) END) >= ?
            AND
            (CASE WHEN length(trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19))) <= 10 
                  THEN trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 10)) || ' 23:59:59' 
                  ELSE substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19) END) <= ?
          )
        )
      ''', orderArgs);

    int grossSales = 0;
    int totalDiscount = 0;
    int totalTax = 0;
    int totalServiceCharge = 0;

    for (final row in orderSummaryRows) {
      final sub = int.tryParse(row['subtotal_amount']?.toString() ?? '0') ?? 0;
      final disc =
          int.tryParse(row['discount_total_amount']?.toString() ?? '0') ??
          int.tryParse(row['manual_discount_value']?.toString() ?? '0') ??
          0;
      final tot = int.tryParse(row['total_amount']?.toString() ?? '0') ?? 0;

      grossSales += sub;
      totalDiscount += disc;

      int rowTax = 0;
      if (row['custom_fields_json'] != null) {
        try {
          final decoded = row['custom_fields_json'] is String
              ? jsonDecode(row['custom_fields_json'] as String)
              : row['custom_fields_json'];
          if (decoded is Map) {
            rowTax =
                int.tryParse(decoded['tax_amount']?.toString() ?? '0') ??
                int.tryParse(decoded['tax']?.toString() ?? '0') ??
                0;
            final svc =
                int.tryParse(
                  decoded['service_charge_amount']?.toString() ?? '0',
                ) ??
                int.tryParse(decoded['service_charge']?.toString() ?? '0') ??
                0;
            totalServiceCharge += svc;
          }
        } catch (_) {}
      }
      if (rowTax == 0 && sub > 0 && tot > (sub - disc)) {
        rowTax = tot - (sub - disc);
      }
      totalTax += rowTax;
    }

    final cashFlowRows = await db.rawQuery(
      '''
      SELECT type, amount FROM pos_cash_flow
      WHERE (tenant_id = ? OR tenant_id IS NULL)
        AND deleted_at IS NULL
        AND (
          shift_session_id = ?
          OR (
            shift_session_id IS NULL
            AND substr(replace(created_at, 'T', ' '), 1, 19) >= ?
            AND substr(replace(created_at, 'T', ' '), 1, 19) <= ?
          )
        )
      ''',
      [activeTenantId, shiftId, startStr, endStr],
    );

    int totalCashIn = 0;
    int totalCashOut = 0;
    for (final cf in cashFlowRows) {
      final type = cf['type']?.toString().toLowerCase() ?? '';
      final amt = int.tryParse(cf['amount']?.toString() ?? '0') ?? 0;
      if (type == 'in' || type == 'cash_in') {
        totalCashIn += amt;
      } else if (type == 'out' || type == 'cash_out') {
        totalCashOut += amt;
      }
    }

    final paymentRows = await db.rawQuery('''
      SELECT COALESCE(NULLIF(pm.name, ''), NULLIF(p.payment_mode_name_snapshot, ''), NULLIF(p.payment_method, ''), 'Lainnya') as name,
             COUNT(DISTINCT o.id) as qty,
             SUM(p.amount) as amount
      FROM pos_order_payment p
      INNER JOIN pos_order o ON o.id = p.order_id OR (p.invoice_remote_id IS NOT NULL AND p.invoice_remote_id != '' AND o.remote_id IS NOT NULL AND o.remote_id != '' AND p.invoice_remote_id = o.remote_id)
      LEFT JOIN payment_mode pm ON pm.id = p.payment_mode_id OR (p.payment_mode_remote_id IS NOT NULL AND pm.remote_id = p.payment_mode_remote_id)
      WHERE (o.tenant_id = ? OR o.tenant_id = ? OR o.tenant_id IS NULL OR o.tenant_id = 0)
        AND (p.deleted_at IS NULL OR p.deleted_at = '' OR p.deleted_at = '0')
        AND (o.deleted_at IS NULL OR o.deleted_at = '' OR o.deleted_at = '0')
        AND (p.is_refund IS NULL OR p.is_refund = 0)
        AND (o.status_code IS NULL OR o.status_code = '' OR o.status_code NOT IN ('5', '6', 'void', 'refunded', 'cancelled', 'canceled'))
        AND (
          o.shift_session_id = ?
          OR CAST(o.shift_session_id AS TEXT) = ?
          OR (? IS NOT NULL AND o.shift_session_remote_id = ?)
          OR (
            (CASE WHEN length(trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19))) <= 10 
                  THEN trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 10)) || ' 00:00:00' 
                  ELSE substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19) END) >= ?
            AND
            (CASE WHEN length(trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19))) <= 10 
                  THEN trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 10)) || ' 23:59:59' 
                  ELSE substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19) END) <= ?
          )
        )
      GROUP BY COALESCE(NULLIF(pm.name, ''), NULLIF(p.payment_mode_name_snapshot, ''), NULLIF(p.payment_method, ''), 'Lainnya')
      ''', orderArgs);

    int totalRevenue = 0;
    final payments = <ShiftDetailPaymentMode>[];
    for (final row in paymentRows) {
      final name = row['name']?.toString() ?? 'Lainnya';
      final amount = int.tryParse(row['amount']?.toString() ?? '0') ?? 0;
      final qty = (double.tryParse(row['qty']?.toString() ?? '0') ?? 0).round();
      totalRevenue += amount;
      payments.add(
        ShiftDetailPaymentMode(name: name, qty: qty, amount: amount),
      );
    }

    final itemRows = await db.rawQuery('''
      SELECT COALESCE(NULLIF(i.product_name_snapshot, ''), NULLIF(i.description, ''), 'Produk') as name,
             SUM(CAST(i.qty AS REAL)) as qty
      FROM pos_order_item i
      INNER JOIN pos_order o ON o.id = i.order_id
      WHERE (i.deleted_at IS NULL OR i.deleted_at = '' OR i.deleted_at = '0')
        AND (o.tenant_id = ? OR o.tenant_id = ? OR o.tenant_id IS NULL OR o.tenant_id = 0)
        AND (o.deleted_at IS NULL OR o.deleted_at = '' OR o.deleted_at = '0')
        AND (o.status_code IN ('2', '4', 2, 4) OR LOWER(CAST(o.status_code AS TEXT)) IN ('paid', 'completed'))
        AND (
          o.shift_session_id = ?
          OR CAST(o.shift_session_id AS TEXT) = ?
          OR (? IS NOT NULL AND o.shift_session_remote_id = ?)
          OR (
            (CASE WHEN length(trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19))) <= 10 
                  THEN trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 10)) || ' 00:00:00' 
                  ELSE substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19) END) >= ?
            AND
            (CASE WHEN length(trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19))) <= 10 
                  THEN trim(substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 10)) || ' 23:59:59' 
                  ELSE substr(replace(COALESCE(NULLIF(o.order_date, ''), NULLIF(o.created_at, ''), ''), 'T', ' '), 1, 19) END) <= ?
          )
        )
      GROUP BY COALESCE(NULLIF(i.product_name_snapshot, ''), NULLIF(i.description, ''), 'Produk')
      ORDER BY SUM(CAST(i.qty AS REAL)) DESC
      ''', orderArgs);
    final topItems = <ShiftDetailItemSold>[];
    for (final row in itemRows) {
      final name = row['name']?.toString() ?? 'Produk';
      final qty = (row['qty'] is num)
          ? (row['qty'] as num).toDouble()
          : (double.tryParse(row['qty']?.toString() ?? '0') ?? 0.0);
      topItems.add(ShiftDetailItemSold(name: name, qty: qty));
    }
    return ShiftDetailData(
      totalRevenue: totalRevenue,
      totalTransactions: orderSummaryRows.length,
      grossSales: grossSales,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      totalServiceCharge: totalServiceCharge,
      totalCashIn: totalCashIn,
      totalCashOut: totalCashOut,
      payments: payments,
      topItems: topItems,
    );
  }
}
