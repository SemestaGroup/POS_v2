import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../core/services/sync/pos_v2_sync_queue_processor.dart';

class TopProductRecord {
  final String name;
  final int quantity;
  final int totalSales;

  TopProductRecord({
    required this.name,
    required this.quantity,
    required this.totalSales,
  });
}

class RecentTransactionRecord {
  final String idPos;
  final DateTime createdAt;
  final int total;
  final String status;

  RecentTransactionRecord({
    required this.idPos,
    required this.createdAt,
    required this.total,
    required this.status,
  });
}

class HourlySalesRecord {
  final String label;
  final int sales;

  HourlySalesRecord(this.label, this.sales);
}

class DailyTransactionRecord {
  final String label;
  final int count;

  DailyTransactionRecord(this.label, this.count);
}

class OverviewSnapshot {
  final bool isLoading;
  final int salesToday;
  final int salesThisMonth;
  final int transactionsToday;
  final int pendingSyncCount;
  final bool isShiftOpen;
  final List<TopProductRecord> topProducts;
  final List<RecentTransactionRecord> recentTransactions;
  final List<HourlySalesRecord> hourlySales;
  final List<DailyTransactionRecord> dailyTransactions;
  final String? errorMessage;
  final String periodLabel;

  const OverviewSnapshot({
    required this.isLoading,
    this.salesToday = 0,
    this.salesThisMonth = 0,
    this.transactionsToday = 0,
    this.pendingSyncCount = 0,
    this.isShiftOpen = false,
    this.topProducts = const [],
    this.recentTransactions = const [],
    this.hourlySales = const [],
    this.dailyTransactions = const [],
    this.errorMessage,
    this.periodLabel = 'Hari Ini',
  });

  OverviewSnapshot copyWith({
    bool? isLoading,
    int? salesToday,
    int? salesThisMonth,
    int? transactionsToday,
    int? pendingSyncCount,
    bool? isShiftOpen,
    List<TopProductRecord>? topProducts,
    List<RecentTransactionRecord>? recentTransactions,
    List<HourlySalesRecord>? hourlySales,
    List<DailyTransactionRecord>? dailyTransactions,
    String? errorMessage,
    String? periodLabel,
    bool clearError = false,
  }) {
    return OverviewSnapshot(
      isLoading: isLoading ?? this.isLoading,
      salesToday: salesToday ?? this.salesToday,
      salesThisMonth: salesThisMonth ?? this.salesThisMonth,
      transactionsToday: transactionsToday ?? this.transactionsToday,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      isShiftOpen: isShiftOpen ?? this.isShiftOpen,
      topProducts: topProducts ?? this.topProducts,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      hourlySales: hourlySales ?? this.hourlySales,
      dailyTransactions: dailyTransactions ?? this.dailyTransactions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      periodLabel: periodLabel ?? this.periodLabel,
    );
  }
}

class OverviewStore {
  OverviewStore._();
  static final OverviewStore instance = OverviewStore._();

  final ValueNotifier<OverviewSnapshot> snapshotNotifier =
      ValueNotifier<OverviewSnapshot>(const OverviewSnapshot(isLoading: false));

  String _dbDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
  }

  void _updateSnapshot(OverviewSnapshot newSnapshot) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        snapshotNotifier.value = newSnapshot;
      });
    } else {
      snapshotNotifier.value = newSnapshot;
    }
  }

  Future<void> refresh({DateTime? startDate, DateTime? endDate}) async {
    _updateSnapshot(
      snapshotNotifier.value.copyWith(isLoading: true, clearError: true),
    );

    try {
      final session = PosV2RuntimeSessionStore.instance.currentSession;
      if (session == null) {
        throw Exception('No active session');
      }

      final tenantId = session.tenantId;
      final now = DateTime.now();

      final effectiveStart =
          startDate ?? DateTime(now.year, now.month, now.day);
      final effectiveEnd =
          endDate ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

      final startRange = DateTime(
        effectiveStart.year,
        effectiveStart.month,
        effectiveStart.day,
        0,
        0,
        0,
      );
      final endRange = DateTime(
        effectiveEnd.year,
        effectiveEnd.month,
        effectiveEnd.day,
        23,
        59,
        59,
      );
      // This KPI is intentionally independent from the selected report range.
      // A range such as 25 Jul–1 Aug must not make “Bulan Ini” include July.
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final currentMoment = now;

      final startStr = _dbDate(startRange);
      final endStr = _dbDate(endRange);
      final currentMonthStartStr = _dbDate(currentMonthStart);
      final currentMomentStr = _dbDate(currentMoment);

      String label = 'Hari Ini';
      final isToday =
          startRange.year == now.year &&
          startRange.month == now.month &&
          startRange.day == now.day &&
          endRange.year == now.year &&
          endRange.month == now.month &&
          endRange.day == now.day;
      if (!isToday) {
        label =
            '${DateFormat('dd/MM').format(startRange)} - ${DateFormat('dd/MM').format(endRange)}';
      }

      final db = DatabaseService.instance;

      // 1. Sales Filtered Period
      final salesTodayResult = await db.rawQuery(
        '''
        SELECT SUM(total_amount) as total, COUNT(id) as count
        FROM pos_order
        WHERE tenant_id = ? 
          AND deleted_at IS NULL 
          AND status_code IN ('2', '4')
          AND REPLACE(COALESCE(NULLIF(order_date, ''), created_at), 'T', ' ') >= ?
          AND REPLACE(COALESCE(NULLIF(order_date, ''), created_at), 'T', ' ') <= ?
        ''',
        [tenantId, startStr, endStr],
      );
      final salesToday =
          (salesTodayResult.first['total'] as num?)?.toInt() ?? 0;
      final transactionsToday =
          (salesTodayResult.first['count'] as num?)?.toInt() ?? 0;

      // 2. Sales This Month
      final salesMonthResult = await db.rawQuery(
        '''
        SELECT SUM(total_amount) as total
        FROM pos_order
        WHERE tenant_id = ? 
          AND deleted_at IS NULL 
          AND status_code IN ('2', '4')
          AND REPLACE(COALESCE(NULLIF(order_date, ''), created_at), 'T', ' ') >= ?
          AND REPLACE(COALESCE(NULLIF(order_date, ''), created_at), 'T', ' ') <= ?
        ''',
        [tenantId, currentMonthStartStr, currentMomentStr],
      );
      final salesThisMonth =
          (salesMonthResult.first['total'] as num?)?.toInt() ?? 0;

      // 3. Top Products (filtered period)
      final topProductsResult = await db.rawQuery(
        '''
        SELECT i.product_name_snapshot as product_name, SUM(i.qty) as qty, SUM(i.line_subtotal_amount) as total
        FROM pos_order_item i
        JOIN pos_order o ON i.order_id = o.id
        WHERE o.tenant_id = ? 
          AND o.deleted_at IS NULL 
          AND o.status_code IN ('2', '4')
          AND REPLACE(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' ') >= ?
          AND REPLACE(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' ') <= ?
        GROUP BY i.product_id, i.product_name_snapshot
        ORDER BY qty DESC
        LIMIT 5
        ''',
        [tenantId, startStr, endStr],
      );
      final topProducts = topProductsResult.map((row) {
        return TopProductRecord(
          name: row['product_name']?.toString() ?? 'Unknown',
          quantity: (row['qty'] as num?)?.toInt() ?? 0,
          totalSales: (row['total'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      // 4. Recent Transactions
      final recentTrxResult = await db.rawQuery(
        '''
        SELECT id_pos, created_at, order_date, total_amount, status_code as status
        FROM pos_order
        WHERE tenant_id = ? 
          AND deleted_at IS NULL
        ORDER BY COALESCE(NULLIF(order_date, ''), created_at) DESC, id DESC
        LIMIT 5
        ''',
        [tenantId],
      );
      final recentTransactions = recentTrxResult.map((row) {
        return RecentTransactionRecord(
          idPos: row['id_pos']?.toString() ?? '',
          createdAt: _parseTrxDate(row['order_date'], row['created_at']),
          total: (row['total_amount'] as num?)?.toInt() ?? 0,
          status: row['status']?.toString() ?? '',
        );
      }).toList();

      // 5. Hourly Sales (Today / Filtered Period) for Bar Chart
      final hourlyResult = await db.rawQuery(
        '''
        SELECT strftime('%H', REPLACE(COALESCE(NULLIF(order_date, ''), created_at), 'T', ' ')) as hour, SUM(total_amount) as total
        FROM pos_order
        WHERE tenant_id = ? 
          AND deleted_at IS NULL 
          AND status_code IN ('2', '4')
          AND REPLACE(COALESCE(NULLIF(order_date, ''), created_at), 'T', ' ') >= ?
          AND REPLACE(COALESCE(NULLIF(order_date, ''), created_at), 'T', ' ') <= ?
        GROUP BY hour
        ORDER BY hour ASC
        ''',
        [tenantId, startStr, endStr],
      );
      Map<String, int> hourMap = {};
      for (var row in hourlyResult) {
        final hour = row['hour']?.toString();
        if (hour != null) {
          hourMap[hour] = (row['total'] as num?)?.toInt() ?? 0;
        }
      }
      List<HourlySalesRecord> hourlySales = [];
      for (int i = 8; i <= 22; i++) {
        final hourStr = i.toString().padLeft(2, '0');
        hourlySales.add(
          HourlySalesRecord('$hourStr:00', hourMap[hourStr] ?? 0),
        );
      }

      // 6. Daily Transactions for Line Chart
      final dailyResult = await db.rawQuery(
        '''
        SELECT date(REPLACE(COALESCE(NULLIF(order_date, ''), created_at), 'T', ' ')) as dayDate, COUNT(id) as count
        FROM pos_order
        WHERE tenant_id = ? 
          AND deleted_at IS NULL
          AND status_code IN ('2', '4')
          AND REPLACE(COALESCE(NULLIF(order_date, ''), created_at), 'T', ' ') >= ?
          AND REPLACE(COALESCE(NULLIF(order_date, ''), created_at), 'T', ' ') <= ?
        GROUP BY dayDate
        ORDER BY dayDate ASC
        ''',
        [tenantId, startStr, endStr],
      );
      Map<String, int> dailyMap = {};
      for (var row in dailyResult) {
        final d = row['dayDate']?.toString();
        if (d != null) {
          dailyMap[d] = (row['count'] as num?)?.toInt() ?? 0;
        }
      }

      List<DailyTransactionRecord> dailyTransactions = [];
      final totalDays = endRange.difference(startRange).inDays;
      for (int i = 0; i <= totalDays; i++) {
        final d = startRange.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(d);
        final displayStr = totalDays <= 7
            ? DateFormat('EEE').format(d)
            : DateFormat('dd/MM').format(d);
        dailyTransactions.add(
          DailyTransactionRecord(displayStr, dailyMap[dateStr] ?? 0),
        );
      }

      // 7. Status Sync
      final pendingCount = await PosV2SyncQueueProcessor.instance
          .getPendingSyncCount();

      // 8. Active Shift
      final openShiftRows = await db.rawQuery(
        '''
        SELECT id FROM shift_session
        WHERE tenant_id = ? AND deleted_at IS NULL AND status = 'open'
        LIMIT 1
        ''',
        [tenantId],
      );

      _updateSnapshot(
        snapshotNotifier.value.copyWith(
          isLoading: false,
          salesToday: salesToday,
          salesThisMonth: salesThisMonth,
          transactionsToday: transactionsToday,
          pendingSyncCount: pendingCount,
          isShiftOpen: openShiftRows.isNotEmpty,
          topProducts: topProducts,
          recentTransactions: recentTransactions,
          hourlySales: hourlySales,
          dailyTransactions: dailyTransactions,
          periodLabel: label,
        ),
      );
    } catch (e, st) {
      debugPrint('OverviewStore refresh error: $e\n$st');
      _updateSnapshot(
        snapshotNotifier.value.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  DateTime _parseTrxDate(Object? orderDateVal, Object? createdAtVal) {
    final raw = (orderDateVal ?? createdAtVal)?.toString().trim() ?? '';
    if (raw.isEmpty) return DateTime.now();
    try {
      var str = raw.replaceAll(' ', 'T');
      if (!str.endsWith('Z') &&
          !str.contains('+') &&
          RegExp(r'T\d{2}:\d{2}:\d{2}').hasMatch(str)) {
        str = '${str}Z';
      }
      return DateTime.parse(str).toLocal();
    } catch (_) {
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }
  }
}
