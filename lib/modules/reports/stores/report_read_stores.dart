import 'package:flutter/material.dart';

import '../../operations/shift/models/shift_history_item.dart';
import '../../operations/shift/services/shift_report_calculations.dart';
import '../../../core/services/local/database_service.dart';
import '../../../core/services/sync/pos_v2_runtime_session_store.dart';

class ReportSummaryTopProductRecord {
  const ReportSummaryTopProductRecord({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final int quantity;
  final int revenue;
}

class ReportSummarySnapshot {
  const ReportSummarySnapshot({
    required this.isLoading,
    required this.todaySales,
    required this.todayTransactions,
    required this.todayDiscount,
    required this.weekSales,
    required this.weekTransactions,
    required this.monthSales,
    required this.monthTransactions,
    required this.topProducts,
    this.errorMessage,
  });

  final bool isLoading;
  final int todaySales;
  final int todayTransactions;
  final int todayDiscount;
  final int weekSales;
  final int weekTransactions;
  final int monthSales;
  final int monthTransactions;
  final List<ReportSummaryTopProductRecord> topProducts;
  final String? errorMessage;

  ReportSummarySnapshot copyWith({
    bool? isLoading,
    int? todaySales,
    int? todayTransactions,
    int? todayDiscount,
    int? weekSales,
    int? weekTransactions,
    int? monthSales,
    int? monthTransactions,
    List<ReportSummaryTopProductRecord>? topProducts,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReportSummarySnapshot(
      isLoading: isLoading ?? this.isLoading,
      todaySales: todaySales ?? this.todaySales,
      todayTransactions: todayTransactions ?? this.todayTransactions,
      todayDiscount: todayDiscount ?? this.todayDiscount,
      weekSales: weekSales ?? this.weekSales,
      weekTransactions: weekTransactions ?? this.weekTransactions,
      monthSales: monthSales ?? this.monthSales,
      monthTransactions: monthTransactions ?? this.monthTransactions,
      topProducts: topProducts ?? this.topProducts,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SalesReportRowRecord {
  const SalesReportRowRecord({
    required this.token,
    required this.label,
    required this.statusCode,
    required this.totalAmount,
    required this.discountAmount,
    required this.paymentMethods,
    required this.createdAt,
  });

  final String token;
  final String label;
  final String statusCode;
  final int totalAmount;
  final int discountAmount;
  final String paymentMethods;
  final DateTime createdAt;
}

class SalesReportSnapshot {
  const SalesReportSnapshot({
    required this.isLoading,
    required this.period,
    required this.rows,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.totalDiscount,
    this.errorMessage,
  });

  final bool isLoading;
  final String period;
  final List<SalesReportRowRecord> rows;
  final int totalRevenue;
  final int totalTransactions;
  final int totalDiscount;
  final String? errorMessage;

  SalesReportSnapshot copyWith({
    bool? isLoading,
    String? period,
    List<SalesReportRowRecord>? rows,
    int? totalRevenue,
    int? totalTransactions,
    int? totalDiscount,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SalesReportSnapshot(
      isLoading: isLoading ?? this.isLoading,
      period: period ?? this.period,
      rows: rows ?? this.rows,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ProductReportStatRecord {
  const ProductReportStatRecord({
    required this.name,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.averagePrice,
  });

  final String name;
  final int totalQuantity;
  final int totalRevenue;
  final int averagePrice;
}

class ProductReportSnapshot {
  const ProductReportSnapshot({
    required this.isLoading,
    required this.period,
    required this.stats,
    this.errorMessage,
  });

  final bool isLoading;
  final String period;
  final List<ProductReportStatRecord> stats;
  final String? errorMessage;

  ProductReportSnapshot copyWith({
    bool? isLoading,
    String? period,
    List<ProductReportStatRecord>? stats,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProductReportSnapshot(
      isLoading: isLoading ?? this.isLoading,
      period: period ?? this.period,
      stats: stats ?? this.stats,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class StaffReportStatRecord {
  const StaffReportStatRecord({
    required this.staffName,
    required this.totalOrders,
    required this.totalRevenue,
    required this.totalDiscount,
    required this.shiftsCount,
  });

  final String staffName;
  final int totalOrders;
  final int totalRevenue;
  final int totalDiscount;
  final int shiftsCount;
}

class StaffReportSnapshot {
  const StaffReportSnapshot({
    required this.isLoading,
    required this.period,
    required this.stats,
    this.errorMessage,
  });

  final bool isLoading;
  final String period;
  final List<StaffReportStatRecord> stats;
  final String? errorMessage;

  StaffReportSnapshot copyWith({
    bool? isLoading,
    String? period,
    List<StaffReportStatRecord>? stats,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StaffReportSnapshot(
      isLoading: isLoading ?? this.isLoading,
      period: period ?? this.period,
      stats: stats ?? this.stats,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class CashierReportRowRecord {
  const CashierReportRowRecord({
    required this.shiftItem,
    required this.totalOrders,
    required this.totalSales,
  });

  final ShiftHistoryItem shiftItem;
  final int totalOrders;
  final int totalSales;

  int get shiftId => shiftItem.id;
  String get shiftName => shiftItem.shiftName;
  String get staffName => shiftItem.staffName;
  String get status => shiftItem.status;
  DateTime get openedAt => shiftItem.openedAt;
  DateTime? get closedAt => shiftItem.closedAt;
  int get openingBalance => shiftItem.openingBalance;
  int get cashSales => shiftItem.cashSales;
  int get nonCashSales => shiftItem.totalNonCash;
  int get expectedCash => shiftItem.expectedCash;
  int get actualCash => shiftItem.actualCash;
  int get variance => shiftItem.variance;
  bool get isOpen => !shiftItem.isClosed;
}

class CashierPaymentBreakdownRecord {
  const CashierPaymentBreakdownRecord({
    required this.name,
    required this.count,
    required this.amount,
    required this.isCash,
  });

  final String name;
  final int count;
  final int amount;
  final bool isCash;
}

class CashierReportLiteSnapshot {
  const CashierReportLiteSnapshot({
    required this.isLoading,
    this.period = 'today',
    this.customDateRange,
    required this.shiftName,
    required this.openingBalance,
    required this.hasActiveShift,
    required this.totalCash,
    required this.totalNonCash,
    required this.totalTransactions,
    this.totalVariance = 0,
    required this.paymentBreakdown,
    this.rows = const <CashierReportRowRecord>[],
    this.shiftOpenedAt,
    this.errorMessage,
  });

  final bool isLoading;
  final String period;
  final DateTimeRange? customDateRange;
  final String shiftName;
  final DateTime? shiftOpenedAt;
  final int openingBalance;
  final bool hasActiveShift;
  final int totalCash;
  final int totalNonCash;
  final int totalTransactions;
  final int totalVariance;
  final List<CashierPaymentBreakdownRecord> paymentBreakdown;
  final List<CashierReportRowRecord> rows;
  final String? errorMessage;

  CashierReportLiteSnapshot copyWith({
    bool? isLoading,
    String? period,
    DateTimeRange? customDateRange,
    bool clearCustomDateRange = false,
    String? shiftName,
    DateTime? shiftOpenedAt,
    bool useShiftOpenedAt = false,
    int? openingBalance,
    bool? hasActiveShift,
    int? totalCash,
    int? totalNonCash,
    int? totalTransactions,
    int? totalVariance,
    List<CashierPaymentBreakdownRecord>? paymentBreakdown,
    List<CashierReportRowRecord>? rows,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CashierReportLiteSnapshot(
      isLoading: isLoading ?? this.isLoading,
      period: period ?? this.period,
      customDateRange: clearCustomDateRange
          ? null
          : (customDateRange ?? this.customDateRange),
      shiftName: shiftName ?? this.shiftName,
      shiftOpenedAt: useShiftOpenedAt
          ? shiftOpenedAt
          : (shiftOpenedAt ?? this.shiftOpenedAt),
      openingBalance: openingBalance ?? this.openingBalance,
      hasActiveShift: hasActiveShift ?? this.hasActiveShift,
      totalCash: totalCash ?? this.totalCash,
      totalNonCash: totalNonCash ?? this.totalNonCash,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalVariance: totalVariance ?? this.totalVariance,
      paymentBreakdown: paymentBreakdown ?? this.paymentBreakdown,
      rows: rows ?? this.rows,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ReportSummaryStore {
  ReportSummaryStore._();

  static final ReportSummaryStore instance = ReportSummaryStore._();

  final ValueNotifier<ReportSummarySnapshot> snapshotNotifier =
      ValueNotifier<ReportSummarySnapshot>(
        const ReportSummarySnapshot(
          isLoading: false,
          todaySales: 0,
          todayTransactions: 0,
          todayDiscount: 0,
          weekSales: 0,
          weekTransactions: 0,
          monthSales: 0,
          monthTransactions: 0,
          topProducts: <ReportSummaryTopProductRecord>[],
        ),
      );

  Future<void> refresh() async {
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final now = DateTime.now();
      final todayStart = _formatSqlDate(DateTime(now.year, now.month, now.day));
      final weekStart = _formatSqlDate(now.subtract(const Duration(days: 7)));
      final monthStart = _formatSqlDate(DateTime(now.year, now.month, 1));

      final todayRow = await DatabaseService.instance.rawQuery(
        '''
        SELECT COALESCE(SUM(total_amount),0) as total,
               COUNT(*) as tx_count,
               COALESCE(SUM(discount_total_amount),0) as disc_total
        FROM pos_order
        WHERE tenant_id = ?
          AND (status_code IN ('2', '4', 2, 4) OR LOWER(CAST(status_code AS TEXT)) IN ('paid', 'completed'))
          AND deleted_at IS NULL
          AND COALESCE(order_date, created_at) >= ?
        ''',
        <Object?>[session.tenantId, todayStart],
      );
      final weekRow = await DatabaseService.instance.rawQuery(
        '''
        SELECT COALESCE(SUM(total_amount),0) as total,
               COUNT(*) as tx_count
        FROM pos_order
        WHERE tenant_id = ?
          AND (status_code IN ('2', '4', 2, 4) OR LOWER(CAST(status_code AS TEXT)) IN ('paid', 'completed'))
          AND deleted_at IS NULL
          AND COALESCE(order_date, created_at) >= ?
        ''',
        <Object?>[session.tenantId, weekStart],
      );
      final monthRow = await DatabaseService.instance.rawQuery(
        '''
        SELECT COALESCE(SUM(total_amount),0) as total,
               COUNT(*) as tx_count
        FROM pos_order
        WHERE tenant_id = ?
          AND (status_code IN ('2', '4', 2, 4) OR LOWER(CAST(status_code AS TEXT)) IN ('paid', 'completed'))
          AND deleted_at IS NULL
          AND COALESCE(order_date, created_at) >= ?
        ''',
        <Object?>[session.tenantId, monthStart],
      );
      final productRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT oi.product_name_snapshot as product_name,
               SUM(oi.qty) as total_qty,
               COALESCE(SUM(oi.line_subtotal_amount),0) as total_revenue
        FROM pos_order_item oi
        INNER JOIN pos_order o ON o.id = oi.order_id
        WHERE o.tenant_id = ?
          AND (o.status_code IN ('2', '4', 2, 4) OR LOWER(CAST(o.status_code AS TEXT)) IN ('paid', 'completed'))
          AND o.deleted_at IS NULL
          AND oi.deleted_at IS NULL
          AND COALESCE(o.order_date, o.created_at) >= ?
        GROUP BY oi.product_name_snapshot
        ORDER BY total_revenue DESC
        LIMIT 5
        ''',
        <Object?>[session.tenantId, monthStart],
      );

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        todaySales: _firstInt(todayRow, 'total'),
        todayTransactions: _firstInt(todayRow, 'tx_count'),
        todayDiscount: _firstInt(todayRow, 'disc_total'),
        weekSales: _firstInt(weekRow, 'total'),
        weekTransactions: _firstInt(weekRow, 'tx_count'),
        monthSales: _firstInt(monthRow, 'total'),
        monthTransactions: _firstInt(monthRow, 'tx_count'),
        topProducts: productRows
            .map(
              (row) => ReportSummaryTopProductRecord(
                name: row['product_name']?.toString() ?? '-',
                quantity: _asInt(row['total_qty']) ?? 0,
                revenue: _asInt(row['total_revenue']) ?? 0,
              ),
            )
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

class SalesReportStore {
  SalesReportStore._();

  static final SalesReportStore instance = SalesReportStore._();

  final ValueNotifier<SalesReportSnapshot> snapshotNotifier =
      ValueNotifier<SalesReportSnapshot>(
        const SalesReportSnapshot(
          isLoading: false,
          period: 'today',
          rows: <SalesReportRowRecord>[],
          totalRevenue: 0,
          totalTransactions: 0,
          totalDiscount: 0,
        ),
      );

  Future<void> refresh({String? period}) async {
    final nextPeriod = period ?? snapshotNotifier.value.period;
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      period: nextPeriod,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final startDate = _formatSqlDate(_startDateForPeriod(nextPeriod));
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT o.formatted_number as token, o.label, o.status_code, o.total_amount,
               o.discount_total_amount, COALESCE(o.order_date, o.created_at) as transaction_date,
               COALESCE(NULLIF(pm.methods, ''), '-') as payment_methods
        FROM pos_order o
        LEFT JOIN (
          SELECT order_id,
                 GROUP_CONCAT(NULLIF(payment_mode_name_snapshot, ''), ', ') as methods
          FROM pos_order_payment
          WHERE deleted_at IS NULL
            AND is_refund = 0
          GROUP BY order_id
        ) pm ON pm.order_id = o.id
        WHERE o.tenant_id = ?
          AND o.deleted_at IS NULL
          AND (o.status_code IN ('2', '4', 2, 4) OR LOWER(CAST(o.status_code AS TEXT)) IN ('paid', 'completed'))
          AND COALESCE(o.order_date, o.created_at) >= ?
        ORDER BY COALESCE(o.order_date, o.created_at) DESC
        LIMIT 5000
        ''',
        <Object?>[session.tenantId, startDate],
      );

      final mapped = rows
          .map(
            (row) => SalesReportRowRecord(
              token: row['token']?.toString() ?? '-',
              label: row['label']?.toString() ?? 'Walk-in',
              statusCode: row['status_code']?.toString() ?? 'unknown',
              totalAmount: _asInt(row['total_amount']) ?? 0,
              discountAmount: _asInt(row['discount_total_amount']) ?? 0,
              paymentMethods: row['payment_methods']?.toString() ?? '-',
              createdAt:
                  _parseDateTime(row['transaction_date']) ?? DateTime.now(),
            ),
          )
          .toList(growable: false);

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        rows: mapped,
        totalRevenue: mapped.fold<int>(0, (sum, row) => sum + row.totalAmount),
        totalTransactions: mapped.length,
        totalDiscount: mapped.fold<int>(
          0,
          (sum, row) => sum + row.discountAmount,
        ),
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class ProductReportStore {
  ProductReportStore._();

  static final ProductReportStore instance = ProductReportStore._();

  final ValueNotifier<ProductReportSnapshot> snapshotNotifier =
      ValueNotifier<ProductReportSnapshot>(
        const ProductReportSnapshot(
          isLoading: false,
          period: 'month',
          stats: <ProductReportStatRecord>[],
        ),
      );

  Future<void> refresh({String? period}) async {
    final nextPeriod = period ?? snapshotNotifier.value.period;
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      period: nextPeriod,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final startDate = _formatSqlDate(_startDateForPeriod(nextPeriod));
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT oi.product_name_snapshot as product_name,
               CAST(SUM(oi.qty) AS INTEGER) as total_qty,
               COALESCE(SUM(oi.line_subtotal_amount), 0) as total_revenue,
               COALESCE(AVG(oi.price_amount), 0) as avg_price
        FROM pos_order_item oi
        INNER JOIN pos_order o ON o.id = oi.order_id
        WHERE o.tenant_id = ?
          AND (o.status_code IN ('2', '4', 2, 4) OR LOWER(CAST(o.status_code AS TEXT)) IN ('paid', 'completed'))
          AND o.deleted_at IS NULL
          AND oi.deleted_at IS NULL
          AND COALESCE(NULLIF(o.order_date, ''), o.created_at) >= ?
        GROUP BY oi.product_name_snapshot
        ORDER BY total_revenue DESC
        LIMIT 100
        ''',
        <Object?>[session.tenantId, startDate],
      );

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        stats: rows
            .map(
              (row) => ProductReportStatRecord(
                name: row['product_name']?.toString() ?? '-',
                totalQuantity: _asInt(row['total_qty']) ?? 0,
                totalRevenue: _asInt(row['total_revenue']) ?? 0,
                averagePrice: _asInt(row['avg_price']) ?? 0,
              ),
            )
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

class StaffReportStore {
  StaffReportStore._();

  static final StaffReportStore instance = StaffReportStore._();

  final ValueNotifier<StaffReportSnapshot> snapshotNotifier =
      ValueNotifier<StaffReportSnapshot>(
        const StaffReportSnapshot(
          isLoading: false,
          period: 'month',
          stats: <StaffReportStatRecord>[],
        ),
      );

  Future<void> refresh({String? period}) async {
    final nextPeriod = period ?? snapshotNotifier.value.period;
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      period: nextPeriod,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final startDate = _formatSqlDate(_startDateForPeriod(nextPeriod));
      final orderRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT s.full_name as staff_name,
               COUNT(*) as total_orders,
               COALESCE(SUM(o.total_amount),0) as total_revenue,
               COALESCE(SUM(o.discount_total_amount),0) as total_discount
        FROM pos_order o
        LEFT JOIN staff s ON s.id = o.sale_staff_id
        WHERE o.tenant_id = ?
          AND (o.status_code IN ('2', '4', 2, 4) OR LOWER(CAST(o.status_code AS TEXT)) IN ('paid', 'completed'))
          AND o.deleted_at IS NULL
          AND COALESCE(NULLIF(o.order_date, ''), o.created_at) >= ?
        GROUP BY o.sale_staff_id, s.full_name
        ORDER BY total_revenue DESC
        ''',
        <Object?>[session.tenantId, startDate],
      );
      final shiftRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT pos_staff_name_snapshot as staff_name,
               COUNT(*) as shifts_count
        FROM shift_session
        WHERE tenant_id = ?
          AND deleted_at IS NULL
          AND opened_at >= ?
        GROUP BY pos_staff_name_snapshot
        ''',
        <Object?>[session.tenantId, startDate],
      );

      final shiftCountByStaff = <String, int>{
        for (final row in shiftRows)
          row['staff_name']?.toString() ?? '': _asInt(row['shifts_count']) ?? 0,
      };

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        stats: orderRows
            .map((row) {
              final name = row['staff_name']?.toString() ?? 'Unknown';
              return StaffReportStatRecord(
                staffName: name,
                totalOrders: _asInt(row['total_orders']) ?? 0,
                totalRevenue: _asInt(row['total_revenue']) ?? 0,
                totalDiscount: _asInt(row['total_discount']) ?? 0,
                shiftsCount: shiftCountByStaff[name] ?? 0,
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

class CashierReportLiteStore {
  CashierReportLiteStore._();

  static final CashierReportLiteStore instance = CashierReportLiteStore._();

  final ValueNotifier<CashierReportLiteSnapshot> snapshotNotifier =
      ValueNotifier<CashierReportLiteSnapshot>(
        const CashierReportLiteSnapshot(
          isLoading: false,
          period: 'today',
          shiftName: '-',
          openingBalance: 0,
          hasActiveShift: false,
          totalCash: 0,
          totalNonCash: 0,
          totalTransactions: 0,
          totalVariance: 0,
          paymentBreakdown: <CashierPaymentBreakdownRecord>[],
          rows: <CashierReportRowRecord>[],
        ),
      );

  Future<void> refresh({
    String? period,
    DateTimeRange? customDateRange,
  }) async {
    final current = snapshotNotifier.value;
    final nextPeriod = period ?? (customDateRange != null ? 'custom' : current.period);
    final nextCustomRange = customDateRange ?? (period != null ? null : current.customDateRange);

    snapshotNotifier.value = current.copyWith(
      isLoading: true,
      period: nextPeriod,
      customDateRange: nextCustomRange,
      clearCustomDateRange: period != null && customDateRange == null,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final db = DatabaseService.instance;

      final shiftRows = await db.rawQuery(
        '''
        SELECT id, shift_name, opened_at, opening_balance, status
        FROM shift_session
        WHERE tenant_id = ?
          AND status = 'open'
          AND deleted_at IS NULL
          AND (? IS NULL OR register_id = ?)
          AND (? IS NULL OR source_device_id = ?)
        ORDER BY opened_at DESC
        LIMIT 1
        ''',
        <Object?>[
          session.tenantId,
          _nullableEmpty(session.registerId),
          _nullableEmpty(session.registerId),
          _nullableEmpty(session.deviceId),
          _nullableEmpty(session.deviceId),
        ],
      );

      var hasActiveShift = false;
      var activeShiftName = '-';
      DateTime? activeShiftOpenedAt;
      var activeOpeningBalance = 0;
      if (shiftRows.isNotEmpty) {
        final shiftRow = shiftRows.first;
        hasActiveShift = true;
        activeShiftName = shiftRow['shift_name']?.toString() ?? '-';
        activeShiftOpenedAt = _parseDateTime(shiftRow['opened_at']);
        activeOpeningBalance = _asInt(shiftRow['opening_balance']) ?? 0;
      }

      final DateTime startDate;
      final DateTime? endDate;
      if (nextPeriod == 'custom' && nextCustomRange != null) {
        startDate = DateTime(
          nextCustomRange.start.year,
          nextCustomRange.start.month,
          nextCustomRange.start.day,
          0,
          0,
          0,
        );
        endDate = DateTime(
          nextCustomRange.end.year,
          nextCustomRange.end.month,
          nextCustomRange.end.day,
          23,
          59,
          59,
        );
      } else {
        startDate = _startDateForPeriod(nextPeriod);
        endDate = null;
      }

      final startDateStr = _formatSqlDate(startDate);
      final endDateStr = endDate != null ? _formatSqlDate(endDate) : null;
      final filterWhereClause = endDateStr != null
          ? "((s.opened_at >= ? AND s.opened_at <= ?) OR (s.status = 'open' AND s.closed_at IS NULL))"
          : "(s.opened_at >= ? OR (s.status = 'open' AND s.closed_at IS NULL))";
      final filterParams = endDateStr != null
          ? <Object?>[session.tenantId, startDateStr, endDateStr]
          : <Object?>[session.tenantId, startDateStr];

      final rawShifts = await db.rawQuery(
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
                  AND (o.status_code IN ('2', '4', 'paid', 'completed', 'PAID', 'COMPLETED', 2, 4))
                  AND p.deleted_at IS NULL
                  AND p.is_refund = 0
                  AND (
                    o.shift_session_id = s.id
                    OR (o.shift_session_remote_id IS NOT NULL AND o.shift_session_remote_id != '' AND s.remote_id IS NOT NULL AND s.remote_id != '' AND o.shift_session_remote_id = s.remote_id)
                    OR (
                      o.shift_session_id IS NULL
                      AND
                      substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                      AND (s.closed_at IS NULL OR substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
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
                  AND (o.status_code IN ('2', '4', 'paid', 'completed', 'PAID', 'COMPLETED', 2, 4))
                  AND p.deleted_at IS NULL
                  AND p.is_refund = 0
                  AND (
                    o.shift_session_id = s.id
                    OR (o.shift_session_remote_id IS NOT NULL AND o.shift_session_remote_id != '' AND s.remote_id IS NOT NULL AND s.remote_id != '' AND o.shift_session_remote_id = s.remote_id)
                    OR (
                      o.shift_session_id IS NULL
                      AND
                      substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                      AND (s.closed_at IS NULL OR substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
                    )
                  )
                   AND NOT (
                     LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), '')) LIKE '%cash%'
                     OR LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), '')) LIKE '%tunai%'
                   )
               ), 0) AS non_cash_sales,
               COALESCE((
                 SELECT COUNT(DISTINCT o.id)
                 FROM pos_order o
                 WHERE (o.tenant_id = s.tenant_id OR o.tenant_id IS NULL)
                   AND (o.status_code IN ('2', '4', 'paid', 'completed', 'PAID', 'COMPLETED', 2, 4))
                   AND o.deleted_at IS NULL
                   AND (
                     o.shift_session_id = s.id
                     OR (o.shift_session_remote_id IS NOT NULL AND o.shift_session_remote_id != '' AND s.remote_id IS NOT NULL AND s.remote_id != '' AND o.shift_session_remote_id = s.remote_id)
                     OR (
                       o.shift_session_id IS NULL
                       AND
                       substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                       AND (s.closed_at IS NULL OR substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
                     )
                   )
               ), 0) AS total_orders
        FROM shift_session s
        WHERE s.tenant_id = ?
          AND s.deleted_at IS NULL
          AND $filterWhereClause
        ORDER BY s.opened_at DESC
        LIMIT 1000
        ''',
        filterParams,
      );

      final reportRows = <CashierReportRowRecord>[];
      var periodCash = 0;
      var periodNonCash = 0;
      var periodTransactions = 0;
      var periodVariance = 0;

      for (final r in rawShifts) {
        final id = _asInt(r['id']) ?? 0;
        final sName = (r['shift_name'] ?? 'Shift').toString();
        final stName = (r['pos_staff_name_snapshot'] ?? 'Kasir').toString();
        final registerId = r['register_id']?.toString();
        final status = (r['status'] ?? 'open').toString();
        final openedAt = _parseDateTime(r['opened_at']) ?? DateTime.now();
        final closedAt = _parseDateTime(r['closed_at']);

        final openingBalance = _asInt(r['opening_balance']) ?? 0;
        final storedExpectedCash = _asInt(r['expected_cash']) ?? 0;
        final actualCash = _asInt(r['actual_cash']) ?? 0;
        final cashSales = _asInt(r['cash_sales']) ?? 0;
        var nonCashSales = _asInt(r['non_cash_sales']) ?? 0;
        if (nonCashSales == 0) {
          nonCashSales = _asInt(r['total_non_cash']) ?? 0;
        }
        final totalCashIn = _asInt(r['total_cash_in']) ?? 0;
        final totalCashOut = _asInt(r['total_cash_out']) ?? 0;
        final totalOrders = _asInt(r['total_orders']) ?? 0;

        final expectedCash = ShiftReportCalculations.expectedCash(
          openingBalance: openingBalance,
          cashIn: totalCashIn,
          cashOut: totalCashOut,
          cashSales: cashSales,
        );

        final shiftItem = ShiftHistoryItem(
          id: id,
          shiftName: sName,
          staffName: stName,
          registerId: registerId,
          status: status,
          openedAt: openedAt,
          closedAt: closedAt,
          openingBalance: openingBalance,
          storedExpectedCash: storedExpectedCash,
          expectedCash: expectedCash,
          actualCash: actualCash,
          totalNonCash: nonCashSales,
          cashSales: cashSales,
          totalCashIn: totalCashIn,
          totalCashOut: totalCashOut,
          rawData: r['reconciliation_json'],
        );

        final totalSales = cashSales + nonCashSales;
        periodCash += cashSales;
        periodNonCash += nonCashSales;
        periodTransactions += totalOrders;
        if (shiftItem.isClosed) {
          periodVariance += shiftItem.variance;
        }

        reportRows.add(
          CashierReportRowRecord(
            shiftItem: shiftItem,
            totalOrders: totalOrders,
            totalSales: totalSales,
          ),
        );
      }

      final paymentWhereClause = endDateStr != null
          ? "COALESCE(NULLIF(o.order_date, ''), o.created_at) >= ? AND COALESCE(NULLIF(o.order_date, ''), o.created_at) <= ?"
          : "COALESCE(NULLIF(o.order_date, ''), o.created_at) >= ?";
      final paymentParams = endDateStr != null
          ? <Object?>[session.tenantId, startDateStr, endDateStr]
          : <Object?>[session.tenantId, startDateStr];
      final paymentSql = '''
        SELECT p.payment_mode_name_snapshot as pm_name,
               COUNT(*) as tx_count,
               COALESCE(SUM(p.amount), 0) as total_amount
        FROM pos_order_payment p
        INNER JOIN pos_order o ON o.id = p.order_id
        WHERE o.tenant_id = ?
          AND (o.status_code IN ('2', '4', 'paid', 'completed', 'PAID', 'COMPLETED', 2, 4))
          AND o.deleted_at IS NULL
          AND p.deleted_at IS NULL
          AND p.is_refund = 0
          AND $paymentWhereClause
        GROUP BY p.payment_mode_name_snapshot, p.payment_mode_id
        ORDER BY total_amount DESC
        ''';
      final paymentRows = await db.rawQuery(
        paymentSql,
        paymentParams,
      );

      final breakdown = <CashierPaymentBreakdownRecord>[];
      for (final row in paymentRows) {
        final amount = _asInt(row['total_amount']) ?? 0;
        final pmName = (row['pm_name']?.toString() ?? '').toLowerCase();
        final isCash =
            pmName.contains('tunai') ||
            pmName.contains('cash') ||
            pmName.contains('uang');
        breakdown.add(
          CashierPaymentBreakdownRecord(
            name: row['pm_name']?.toString() ?? '-',
            count: _asInt(row['tx_count']) ?? 0,
            amount: amount,
            isCash: isCash,
          ),
        );
      }

      // Fallback: If no shift sessions recorded yet, retrieve direct pos_order counts for period
      if (reportRows.isEmpty) {
        final directTxRows = await db.rawQuery(
          '''
          SELECT COUNT(*) as tx_count
          FROM pos_order o
          WHERE o.tenant_id = ?
            AND (o.status_code IN ('2', '4', 'paid', 'completed', 'PAID', 'COMPLETED', 2, 4))
            AND o.deleted_at IS NULL
            AND $paymentWhereClause
          ''',
          paymentParams,
        );
        periodTransactions = _firstInt(directTxRows, 'tx_count');
        for (final item in breakdown) {
          if (item.isCash) {
            periodCash += item.amount;
          } else {
            periodNonCash += item.amount;
          }
        }
      }

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        shiftName: activeShiftName,
        shiftOpenedAt: activeShiftOpenedAt,
        useShiftOpenedAt: true,
        openingBalance: activeOpeningBalance,
        hasActiveShift: hasActiveShift,
        totalCash: periodCash,
        totalNonCash: periodNonCash,
        totalTransactions: periodTransactions,
        totalVariance: periodVariance,
        paymentBreakdown: breakdown,
        rows: reportRows,
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

DateTime _startDateForPeriod(String period) {
  final now = DateTime.now();
  switch (period) {
    case 'today':
      return DateTime(now.year, now.month, now.day);
    case 'week':
      return now.subtract(const Duration(days: 7));
    case 'month':
    default:
      return DateTime(now.year, now.month, 1);
  }
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

String? _nullableEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _formatSqlDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
