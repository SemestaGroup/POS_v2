import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/services/local/database_service.dart';
import '../../../core/services/sync/pos_v2_runtime_session_store.dart';

class ShiftSummaryRecord {
  const ShiftSummaryRecord({
    required this.id,
    required this.shiftName,
    required this.staffName,
    required this.openedAt,
    required this.openingBalance,
    required this.status,
    this.closedAt,
  });

  final int id;
  final String shiftName;
  final String staffName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int openingBalance;
  final String status;
}

class EodArchiveRecord {
  const EodArchiveRecord({
    required this.id,
    required this.eodCode,
    required this.createdAt,
    required this.totalTransactions,
    required this.totalRevenue,
    this.summaryJson,
  });

  final int id;
  final String eodCode;
  final DateTime createdAt;
  final int totalTransactions;
  final int totalRevenue;
  final String? summaryJson;
}

class RecapSnapshot {
  const RecapSnapshot({
    required this.isLoading,
    required this.shifts,
    required this.archivedEods,
    required this.totalTransactions,
    required this.totalRevenue,
    this.errorMessage,
  });

  final bool isLoading;
  final List<ShiftSummaryRecord> shifts;
  final List<EodArchiveRecord> archivedEods;
  final int totalTransactions;
  final int totalRevenue;
  final String? errorMessage;

  RecapSnapshot copyWith({
    bool? isLoading,
    List<ShiftSummaryRecord>? shifts,
    List<EodArchiveRecord>? archivedEods,
    int? totalTransactions,
    int? totalRevenue,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecapSnapshot(
      isLoading: isLoading ?? this.isLoading,
      shifts: shifts ?? this.shifts,
      archivedEods: archivedEods ?? this.archivedEods,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class CashFlowEntryRecord {
  const CashFlowEntryRecord({
    required this.type,
    required this.description,
    required this.amount,
    required this.createdAt,
  });

  final String type;
  final String description;
  final int amount;
  final DateTime createdAt;
}

class CashFlowSnapshot {
  const CashFlowSnapshot({
    required this.isLoading,
    required this.entries,
    required this.totalIn,
    required this.totalOut,
    this.errorMessage,
  });

  final bool isLoading;
  final List<CashFlowEntryRecord> entries;
  final int totalIn;
  final int totalOut;
  final String? errorMessage;

  CashFlowSnapshot copyWith({
    bool? isLoading,
    List<CashFlowEntryRecord>? entries,
    int? totalIn,
    int? totalOut,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CashFlowSnapshot(
      isLoading: isLoading ?? this.isLoading,
      entries: entries ?? this.entries,
      totalIn: totalIn ?? this.totalIn,
      totalOut: totalOut ?? this.totalOut,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class KitchenItemRecord {
  const KitchenItemRecord({
    required this.productName,
    required this.quantity,
    this.note,
  });

  final String productName;
  final int quantity;
  final String? note;
}

class KitchenOrderRecord {
  const KitchenOrderRecord({
    required this.id,
    required this.idPos,
    required this.orderTypeCode,
    required this.statusCode,
    required this.createdAt,
    required this.items,
    this.tableCode,
  });

  final int id;
  final String idPos;
  final String orderTypeCode;
  final String statusCode;
  final DateTime createdAt;
  final String? tableCode;
  final List<KitchenItemRecord> items;
}

class KitchenSnapshot {
  const KitchenSnapshot({
    required this.isLoading,
    required this.filter,
    required this.orders,
    this.errorMessage,
  });

  final bool isLoading;
  final String filter;
  final List<KitchenOrderRecord> orders;
  final String? errorMessage;

  KitchenSnapshot copyWith({
    bool? isLoading,
    String? filter,
    List<KitchenOrderRecord>? orders,
    String? errorMessage,
    bool clearError = false,
  }) {
    return KitchenSnapshot(
      isLoading: isLoading ?? this.isLoading,
      filter: filter ?? this.filter,
      orders: orders ?? this.orders,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class RecapStore {
  RecapStore._();

  static final RecapStore instance = RecapStore._();

  final ValueNotifier<RecapSnapshot> snapshotNotifier =
      ValueNotifier<RecapSnapshot>(
        const RecapSnapshot(
          isLoading: false,
          shifts: <ShiftSummaryRecord>[],
          archivedEods: <EodArchiveRecord>[],
          totalTransactions: 0,
          totalRevenue: 0,
        ),
      );

  Future<void> refresh() async {
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final shiftRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT id, shift_name, pos_staff_name_snapshot, opened_at,
               closed_at, opening_balance, status
        FROM shift_session
        WHERE tenant_id = ?
          AND deleted_at IS NULL
          AND eod_group_id IS NULL
          AND status = 'closed'
        ORDER BY opened_at ASC
        ''',
        <Object?>[session.tenantId],
      );

      final openShiftRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT id
        FROM shift_session
        WHERE tenant_id = ?
          AND deleted_at IS NULL
          AND eod_group_id IS NULL
          AND status = 'open'
        LIMIT 1
        ''',
        <Object?>[session.tenantId],
      );

      // Construct a list of shift IDs to filter pos_order_payment accurately.
      // Usually recap uses all unarchived closed shifts. 
      // If there are none, we fallback to returning 0 for total revenue.
      int totalRevenue = 0;
      int totalTransactions = 0;
      
      if (shiftRows.isNotEmpty) {
         // Gather the shift registers or timeframes to get accurate aggregate revenue.
         // Wait, the simplest way is to sum the expected/actual cash and non-cash of these shifts!
         // Wait, recap actually wants all payments in those shifts.
         // We can just sum them up directly from the shift_session!
         totalRevenue = shiftRows.fold<int>(
            0,
            (sum, row) =>
                sum + (_asInt(row['actual_cash']) ?? 0) + (_asInt(row['total_non_cash']) ?? 0)
         );
         // For total transactions, we might need a separate query if shift_session doesn't have it.
         // But for recap overview, totalRevenue is the main thing. We'll set transactions to 0 if not needed, 
         // or keep the old broad query if it doesn't hurt.
      }

      final recapRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT
          COUNT(DISTINCT COALESCE(NULLIF(p.id_pos, ''), CAST(p.order_id AS TEXT))) as total_orders,
          COALESCE(SUM(p.amount), 0) as total_revenue
        FROM pos_order_payment p
        WHERE p.tenant_id = ?
          AND p.deleted_at IS NULL
          AND p.is_refund = 0
          AND p.sync_state IN ('clean', 'dirty_create', 'dirty_update', 'syncing')
          AND EXISTS (
             SELECT 1 FROM shift_session s
             WHERE s.tenant_id = p.tenant_id
               AND s.deleted_at IS NULL
               AND s.eod_group_id IS NULL
               AND s.status = 'closed'
               AND (p.payment_date >= s.opened_at AND p.payment_date <= COALESCE(s.closed_at, '9999-12-31'))
          )
        ''',
        <Object?>[session.tenantId],
      );

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        shifts: shiftRows
            .map(
              (row) => ShiftSummaryRecord(
                id: _asInt(row['id']) ?? 0,
                shiftName: row['shift_name']?.toString() ?? '-',
                staffName: row['pos_staff_name_snapshot']?.toString() ?? '-',
                openedAt: _parseDateTime(row['opened_at']) ?? DateTime.now(),
                closedAt: _parseDateTime(row['closed_at']),
                openingBalance: _asInt(row['opening_balance']) ?? 0,
                status: row['status']?.toString() ?? 'unknown',
              ),
            )
            .toList(growable: false),
        totalTransactions: _firstInt(recapRows, 'total_orders'),
        totalRevenue: _firstInt(recapRows, 'total_revenue'),
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> fetchArchives(DateTime date) async {
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      // the date is used to filter created_at
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT id, eod_code, created_at, total_transactions, total_revenue, summary_json
        FROM shift_eod_archive
        WHERE tenant_id = ?
          AND date(created_at) = ?
        ORDER BY created_at DESC
        ''',
        <Object?>[session.tenantId, dateStr],
      );

      final archives = rows.map((row) => EodArchiveRecord(
        id: _asInt(row['id']) ?? 0,
        eodCode: row['eod_code']?.toString() ?? '',
        createdAt: _parseDateTime(row['created_at']) ?? DateTime.now(),
        totalTransactions: _asInt(row['total_transactions']) ?? 0,
        totalRevenue: _asInt(row['total_revenue']) ?? 0,
        summaryJson: row['summary_json']?.toString(),
      )).toList(growable: false);

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        archivedEods: archives,
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> executeEndOfDay() async {
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );
    try {
      final session = await _requireSession();
      
      // 1. Ensure no open shifts
      final openShiftRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT id FROM shift_session 
        WHERE tenant_id = ? AND deleted_at IS NULL AND eod_group_id IS NULL AND status = 'open'
        LIMIT 1
        ''',
        <Object?>[session.tenantId],
      );
      if (openShiftRows.isNotEmpty) {
        throw Exception('Masih ada shift yang belum ditutup. Harap tutup semua shift terlebih dahulu.');
      }

      // 2. Fetch all unarchived closed shifts
      final shiftRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT id, opened_at, closed_at 
        FROM shift_session 
        WHERE tenant_id = ? AND deleted_at IS NULL AND eod_group_id IS NULL AND status = 'closed'
        ''',
        <Object?>[session.tenantId],
      );
      
      if (shiftRows.isEmpty) {
        throw Exception('Tidak ada shift tertutup yang bisa direkap.');
      }

      final shiftIds = shiftRows.map((r) => r['id'].toString()).toList();
      
      // 3. Gather payment data
      final paymentRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT
          COALESCE(NULLIF(pm.name, ''), NULLIF(p.payment_mode_name_snapshot, ''), NULLIF(p.payment_method, ''), 'Lainnya') as payment_name,
          COUNT(DISTINCT COALESCE(NULLIF(p.id_pos, ''), CAST(p.order_id AS TEXT))) as qty,
          SUM(p.amount) as amount
        FROM pos_order_payment p
        LEFT JOIN payment_mode pm ON pm.id = p.payment_mode_id OR (p.payment_mode_remote_id IS NOT NULL AND pm.remote_id = p.payment_mode_remote_id)
        WHERE p.tenant_id = ?
          AND p.deleted_at IS NULL
          AND p.is_refund = 0
          AND p.sync_state IN ('clean', 'dirty_create', 'dirty_update', 'syncing')
          AND EXISTS (
             SELECT 1 FROM shift_session s
             WHERE s.tenant_id = p.tenant_id
               AND s.deleted_at IS NULL
               AND s.eod_group_id IS NULL
               AND (REPLACE(p.created_at, 'T', ' ') >= REPLACE(s.opened_at, 'T', ' ') AND REPLACE(p.created_at, 'T', ' ') <= COALESCE(REPLACE(s.closed_at, 'T', ' '), '9999-12-31 23:59:59'))
          )
        GROUP BY COALESCE(NULLIF(pm.name, ''), NULLIF(p.payment_mode_name_snapshot, ''), NULLIF(p.payment_method, ''), 'Lainnya')
        ''',
        <Object?>[session.tenantId],
      );

      final modeRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT name FROM payment_mode 
        WHERE tenant_id = ? AND deleted_at IS NULL AND is_active = 1
        ''',
        <Object?>[session.tenantId],
      );
      final allModeNames = modeRows.map((r) => r['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();

      int totalTransactions = 0;
      int totalRevenue = 0;
      final paymentSummary = <Map<String, dynamic>>[];
      
      for (final mode in allModeNames) {
        paymentSummary.add({'name': mode, 'qty': 0, 'amount': 0});
      }

      for (final row in paymentRows) {
        final name = row['payment_name']?.toString() ?? 'Lainnya';
        final amount = _asInt(row['amount']) ?? 0;
        final qty = (double.tryParse(row['qty']?.toString() ?? '0') ?? 0).round();
        
        totalRevenue += amount;
        totalTransactions += qty;
        
        final existingIdx = paymentSummary.indexWhere((p) => p['name'] == name);
        if (existingIdx != -1) {
          paymentSummary[existingIdx]['amount'] = (paymentSummary[existingIdx]['amount'] as int) + amount;
          paymentSummary[existingIdx]['qty'] = (paymentSummary[existingIdx]['qty'] as int) + qty;
        } else {
          paymentSummary.add({'name': name, 'qty': qty, 'amount': amount});
        }
      }

      paymentSummary.removeWhere((p) => p['qty'] == 0 && p['amount'] == 0);

      // 4. Gather items sold data
      final itemRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT
          i.product_name_snapshot as item_name,
          SUM(i.qty) as qty
        FROM pos_order_item i
        INNER JOIN pos_order o ON o.id = i.order_id
        WHERE i.tenant_id = ?
          AND i.deleted_at IS NULL
          AND o.deleted_at IS NULL
          AND EXISTS (
             SELECT 1 FROM shift_session s
             WHERE s.tenant_id = o.tenant_id
               AND s.deleted_at IS NULL
               AND s.eod_group_id IS NULL
               AND (REPLACE(o.created_at, 'T', ' ') >= REPLACE(s.opened_at, 'T', ' ') AND REPLACE(o.created_at, 'T', ' ') <= COALESCE(REPLACE(s.closed_at, 'T', ' '), '9999-12-31 23:59:59'))
          )
        GROUP BY i.product_name_snapshot
        ''',
        <Object?>[session.tenantId],
      );

      final itemSummary = itemRows.map((row) => {
        'name': row['item_name']?.toString() ?? 'Produk',
        'qty': (double.tryParse(row['qty']?.toString() ?? '0') ?? 0).round(),
      }).toList();

      final summaryJson = jsonEncode({
        'payments': paymentSummary,
        'items': itemSummary,
        'gross_sales': totalRevenue, // simplified for now
        'discount': 0, // placeholder
        'net_sales': totalRevenue,
      });

      // 5. Generate EOD Group Code
      final now = DateTime.now();
      final eodCode = 'EOD-${DateFormat('yyyyMMdd-HHmmss').format(now)}';
      final createdAt = now.toIso8601String();

      // 6. Transaction to save archive and update shifts
      await DatabaseService.instance.transaction((txn) async {
        await txn.rawInsert(
          '''
          INSERT INTO shift_eod_archive (tenant_id, eod_code, created_at, total_transactions, total_revenue, summary_json)
          VALUES (?, ?, ?, ?, ?, ?)
          ''',
          <Object?>[session.tenantId, eodCode, createdAt, totalTransactions, totalRevenue, summaryJson],
        );

        await txn.rawUpdate(
          '''
          UPDATE shift_session 
          SET eod_group_id = ?
          WHERE tenant_id = ? AND deleted_at IS NULL AND eod_group_id IS NULL AND status = 'closed'
          ''',
          <Object?>[eodCode, session.tenantId],
        );
      });

      // TODO: Printer integration (Skipped for now per user comment)

      await refresh();
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class CashFlowStore {
  CashFlowStore._();

  static final CashFlowStore instance = CashFlowStore._();

  final ValueNotifier<CashFlowSnapshot> snapshotNotifier =
      ValueNotifier<CashFlowSnapshot>(
        const CashFlowSnapshot(
          isLoading: false,
          entries: <CashFlowEntryRecord>[],
          totalIn: 0,
          totalOut: 0,
        ),
      );

  Future<void> refresh({DateTime? startDate, DateTime? endDate}) async {
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      
      String dateFilter = '';
      List<Object?> dateArgs = [];
      if (startDate != null && endDate != null) {
        // format to ISO8601 string for sqlite comparison
        dateFilter = ' AND p.created_at >= ? AND p.created_at <= ?';
        dateArgs = [
          startDate.toIso8601String(),
          endDate.add(const Duration(days: 1)).toIso8601String(),
        ];
      }

      final paymentRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT p.amount, p.payment_mode_name_snapshot, p.created_at,
               o.id_pos as order_ref
        FROM pos_order_payment p
        LEFT JOIN pos_order o ON o.id = p.order_id
        WHERE p.tenant_id = ?
          AND p.deleted_at IS NULL
          AND p.is_refund = 0
          AND p.sync_state IN ('clean', 'dirty_create', 'dirty_update', 'syncing')
          $dateFilter
        ORDER BY p.created_at DESC
        LIMIT 200
        ''',
        <Object?>[session.tenantId, ...dateArgs],
      );

      String cashFlowDateFilter = '';
      if (startDate != null && endDate != null) {
        cashFlowDateFilter = ' AND created_at >= ? AND created_at <= ?';
      }

      final cashFlowRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT amount, note, created_at, type
        FROM pos_cash_flow
        WHERE tenant_id = ?
          AND deleted_at IS NULL
          $cashFlowDateFilter
        ORDER BY created_at DESC
        LIMIT 200
        ''',
        <Object?>[session.tenantId, ...dateArgs],
      );

      final List<CashFlowEntryRecord> entries = [];
      
      entries.addAll(
        paymentRows.map(
          (row) => CashFlowEntryRecord(
            type: 'in',
            description:
                '${row['payment_mode_name_snapshot'] ?? 'Pembayaran'} — ${row['order_ref'] ?? '-'}',
            amount: _asInt(row['amount']) ?? 0,
            createdAt: _parseDateTime(row['created_at']) ?? DateTime.now(),
          ),
        ),
      );

      entries.addAll(
        cashFlowRows.map(
          (row) => CashFlowEntryRecord(
            type: row['type'] as String? ?? 'out',
            description: row['note'] as String? ?? 'Kas Keluar',
            amount: _asInt(row['amount']) ?? 0,
            createdAt: _parseDateTime(row['created_at']) ?? DateTime.now(),
          ),
        ),
      );

      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final totalIn = entries.where((e) => e.type == 'in').fold<int>(0, (sum, e) => sum + e.amount);
      final totalOut = entries.where((e) => e.type == 'out').fold<int>(0, (sum, e) => sum + e.amount);

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        entries: entries,
        totalIn: totalIn,
        totalOut: totalOut,
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class KitchenMonitorStore {
  KitchenMonitorStore._();

  static final KitchenMonitorStore instance = KitchenMonitorStore._();

  final ValueNotifier<KitchenSnapshot> snapshotNotifier =
      ValueNotifier<KitchenSnapshot>(
        const KitchenSnapshot(
          isLoading: false,
          filter: 'active',
          orders: <KitchenOrderRecord>[],
        ),
      );

  Future<void> refresh({String? filter}) async {
    final nextFilter = filter ?? snapshotNotifier.value.filter;
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      filter: nextFilter,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final statusFilter = nextFilter == 'active'
          ? "AND o.status_code IN ('draft', 'hold', 'unpaid')"
          : '';
      final orderRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT o.id, o.id_pos, o.status_code, o.created_at,
               o.table_code, o.order_type_code
        FROM pos_order o
        WHERE o.tenant_id = ?
          AND o.deleted_at IS NULL
          $statusFilter
        ORDER BY o.created_at DESC
        LIMIT 30
        ''',
        <Object?>[session.tenantId],
      );

      final orderIds = orderRows
          .map((row) => _asInt(row['id']))
          .whereType<int>()
          .toList(growable: false);
      final itemsByOrder = <int, List<KitchenItemRecord>>{};
      if (orderIds.isNotEmpty) {
        final placeholders = List.filled(orderIds.length, '?').join(',');
        final itemRows = await DatabaseService.instance.rawQuery('''
          SELECT order_id,
                 product_name_snapshot as product_name,
                 CAST(qty AS INTEGER) as quantity,
                 note
          FROM pos_order_item
          WHERE deleted_at IS NULL
            AND order_id IN ($placeholders)
          ORDER BY order_id ASC, sort_order ASC
          ''', orderIds.cast<Object?>());
        for (final row in itemRows) {
          final orderId = _asInt(row['order_id']);
          if (orderId == null) {
            continue;
          }
          itemsByOrder
              .putIfAbsent(orderId, () => <KitchenItemRecord>[])
              .add(
                KitchenItemRecord(
                  productName: row['product_name']?.toString() ?? '-',
                  quantity: _asInt(row['quantity']) ?? 1,
                  note: row['note']?.toString(),
                ),
              );
        }
      }

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        orders: orderRows
            .map((row) {
              final id = _asInt(row['id']) ?? 0;
              return KitchenOrderRecord(
                id: id,
                idPos: row['id_pos']?.toString() ?? '-',
                orderTypeCode: row['order_type_code']?.toString() ?? 'dine_in',
                statusCode: row['status_code']?.toString() ?? 'draft',
                createdAt: _parseDateTime(row['created_at']) ?? DateTime.now(),
                tableCode: row['table_code']?.toString(),
                items: itemsByOrder[id] ?? const <KitchenItemRecord>[],
              );
            })
            .toList(growable: false),
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

Future<PosV2RuntimeSession> _requireSession() async {
  final session =
      PosV2RuntimeSessionStore.instance.currentSession ??
      await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
  if (session == null) {
    throw Exception('Tidak ada sesi aktif.');
  }
  return session;
}

int _firstInt(List<Map<String, Object?>> rows, String key) {
  if (rows.isEmpty) {
    return 0;
  }
  return _asInt(rows.first[key]) ?? 0;
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString().split('.').first);
}

DateTime? _parseDateTime(Object? raw) {
  final text = raw?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}
