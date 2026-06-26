import 'package:flutter/foundation.dart';

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
    required this.idPos,
    required this.label,
    required this.statusCode,
    required this.totalAmount,
    required this.discountAmount,
    required this.paymentMethods,
    required this.createdAt,
  });

  final String idPos;
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
    required this.shiftName,
    required this.openingBalance,
    required this.hasActiveShift,
    required this.totalCash,
    required this.totalNonCash,
    required this.totalTransactions,
    required this.paymentBreakdown,
    this.shiftOpenedAt,
    this.errorMessage,
  });

  final bool isLoading;
  final String shiftName;
  final DateTime? shiftOpenedAt;
  final int openingBalance;
  final bool hasActiveShift;
  final int totalCash;
  final int totalNonCash;
  final int totalTransactions;
  final List<CashierPaymentBreakdownRecord> paymentBreakdown;
  final String? errorMessage;

  CashierReportLiteSnapshot copyWith({
    bool? isLoading,
    String? shiftName,
    DateTime? shiftOpenedAt,
    bool useShiftOpenedAt = false,
    int? openingBalance,
    bool? hasActiveShift,
    int? totalCash,
    int? totalNonCash,
    int? totalTransactions,
    List<CashierPaymentBreakdownRecord>? paymentBreakdown,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CashierReportLiteSnapshot(
      isLoading: isLoading ?? this.isLoading,
      shiftName: shiftName ?? this.shiftName,
      shiftOpenedAt:
          useShiftOpenedAt ? shiftOpenedAt : (shiftOpenedAt ?? this.shiftOpenedAt),
      openingBalance: openingBalance ?? this.openingBalance,
      hasActiveShift: hasActiveShift ?? this.hasActiveShift,
      totalCash: totalCash ?? this.totalCash,
      totalNonCash: totalNonCash ?? this.totalNonCash,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      paymentBreakdown: paymentBreakdown ?? this.paymentBreakdown,
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
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final weekStart = now.subtract(const Duration(days: 7)).toIso8601String();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

      final todayRow = await DatabaseService.instance.rawQuery(
        '''
        SELECT COALESCE(SUM(total_amount),0) as total,
               COUNT(*) as tx_count,
               COALESCE(SUM(discount_total_amount),0) as disc_total
        FROM pos_order
        WHERE tenant_id = ?
          AND status_code IN ('paid','posted')
          AND deleted_at IS NULL
          AND created_at >= ?
        ''',
        <Object?>[session.tenantId, todayStart],
      );
      final weekRow = await DatabaseService.instance.rawQuery(
        '''
        SELECT COALESCE(SUM(total_amount),0) as total,
               COUNT(*) as tx_count
        FROM pos_order
        WHERE tenant_id = ?
          AND status_code IN ('paid','posted')
          AND deleted_at IS NULL
          AND created_at >= ?
        ''',
        <Object?>[session.tenantId, weekStart],
      );
      final monthRow = await DatabaseService.instance.rawQuery(
        '''
        SELECT COALESCE(SUM(total_amount),0) as total,
               COUNT(*) as tx_count
        FROM pos_order
        WHERE tenant_id = ?
          AND status_code IN ('paid','posted')
          AND deleted_at IS NULL
          AND created_at >= ?
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
          AND o.status_code IN ('paid','posted')
          AND o.deleted_at IS NULL
          AND oi.deleted_at IS NULL
          AND o.created_at >= ?
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
      final startDate = _startDateForPeriod(nextPeriod).toIso8601String();
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT o.id_pos, o.label, o.status_code, o.total_amount,
               o.discount_total_amount, o.created_at,
               COALESCE(pm.methods, '-') as payment_methods
        FROM pos_order o
        LEFT JOIN (
          SELECT order_id,
                 GROUP_CONCAT(COALESCE(payment_mode_name_snapshot, ''), ', ') as methods
          FROM pos_order_payment
          WHERE deleted_at IS NULL
            AND is_refund = 0
          GROUP BY order_id
        ) pm ON pm.order_id = o.id
        WHERE o.tenant_id = ?
          AND o.deleted_at IS NULL
          AND o.status_code IN ('paid','posted')
          AND o.created_at >= ?
        ORDER BY o.created_at DESC
        LIMIT 100
        ''',
        <Object?>[session.tenantId, startDate],
      );

      final mapped = rows
          .map(
            (row) => SalesReportRowRecord(
              idPos: row['id_pos']?.toString() ?? '-',
              label: row['label']?.toString() ?? 'Walk-in',
              statusCode: row['status_code']?.toString() ?? 'unknown',
              totalAmount: _asInt(row['total_amount']) ?? 0,
              discountAmount: _asInt(row['discount_total_amount']) ?? 0,
              paymentMethods: row['payment_methods']?.toString() ?? '-',
              createdAt: _parseDateTime(row['created_at']) ?? DateTime.now(),
            ),
          )
          .toList(growable: false);

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        rows: mapped,
        totalRevenue: mapped.fold<int>(0, (sum, row) => sum + row.totalAmount),
        totalTransactions: mapped.length,
        totalDiscount:
            mapped.fold<int>(0, (sum, row) => sum + row.discountAmount),
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
      final startDate = _startDateForPeriod(nextPeriod).toIso8601String();
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT oi.product_name_snapshot as product_name,
               CAST(SUM(oi.qty) AS INTEGER) as total_qty,
               COALESCE(SUM(oi.line_subtotal_amount), 0) as total_revenue,
               COALESCE(AVG(oi.price_amount), 0) as avg_price
        FROM pos_order_item oi
        INNER JOIN pos_order o ON o.id = oi.order_id
        WHERE o.tenant_id = ?
          AND o.status_code IN ('paid','posted')
          AND o.deleted_at IS NULL
          AND oi.deleted_at IS NULL
          AND o.created_at >= ?
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
      final startDate = _startDateForPeriod(nextPeriod).toIso8601String();
      final orderRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT s.full_name as staff_name,
               COUNT(*) as total_orders,
               COALESCE(SUM(o.total_amount),0) as total_revenue,
               COALESCE(SUM(o.discount_total_amount),0) as total_discount
        FROM pos_order o
        LEFT JOIN staff s ON s.id = o.sale_staff_id
        WHERE o.tenant_id = ?
          AND o.status_code IN ('paid','posted')
          AND o.deleted_at IS NULL
          AND o.created_at >= ?
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
            .map(
              (row) {
                final name = row['staff_name']?.toString() ?? 'Unknown';
                return StaffReportStatRecord(
                  staffName: name,
                  totalOrders: _asInt(row['total_orders']) ?? 0,
                  totalRevenue: _asInt(row['total_revenue']) ?? 0,
                  totalDiscount: _asInt(row['total_discount']) ?? 0,
                  shiftsCount: shiftCountByStaff[name] ?? 0,
                );
              },
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

class CashierReportLiteStore {
  CashierReportLiteStore._();

  static final CashierReportLiteStore instance = CashierReportLiteStore._();

  final ValueNotifier<CashierReportLiteSnapshot> snapshotNotifier =
      ValueNotifier<CashierReportLiteSnapshot>(
    const CashierReportLiteSnapshot(
      isLoading: false,
      shiftName: '-',
      openingBalance: 0,
      hasActiveShift: false,
      totalCash: 0,
      totalNonCash: 0,
      totalTransactions: 0,
      paymentBreakdown: <CashierPaymentBreakdownRecord>[],
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
      var shiftName = '-';
      DateTime? shiftOpenedAt;
      var openingBalance = 0;
      if (shiftRows.isNotEmpty) {
        final shiftRow = shiftRows.first;
        hasActiveShift = true;
        shiftName = shiftRow['shift_name']?.toString() ?? '-';
        shiftOpenedAt = _parseDateTime(shiftRow['opened_at']);
        openingBalance = _asInt(shiftRow['opening_balance']) ?? 0;
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final txRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT COUNT(*) as tx_count
        FROM pos_order
        WHERE tenant_id = ?
          AND status_code IN ('paid','posted')
          AND deleted_at IS NULL
          AND created_at >= ?
        ''',
        <Object?>[session.tenantId, todayStart],
      );
      final paymentRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT p.payment_mode_name_snapshot as pm_name,
               COUNT(*) as tx_count,
               COALESCE(SUM(p.amount),0) as total_amount
        FROM pos_order_payment p
        INNER JOIN pos_order o ON o.id = p.order_id
        WHERE o.tenant_id = ?
          AND o.status_code IN ('paid','posted')
          AND o.deleted_at IS NULL
          AND p.deleted_at IS NULL
          AND p.is_refund = 0
          AND o.created_at >= ?
        GROUP BY p.payment_mode_name_snapshot, p.payment_mode_id
        ORDER BY total_amount DESC
        ''',
        <Object?>[session.tenantId, todayStart],
      );

      var totalCash = 0;
      var totalNonCash = 0;
      final breakdown = <CashierPaymentBreakdownRecord>[];
      for (final row in paymentRows) {
        final amount = _asInt(row['total_amount']) ?? 0;
        final pmName = (row['pm_name']?.toString() ?? '').toLowerCase();
        final isCash =
            pmName.contains('tunai') || pmName.contains('cash') || pmName.contains('uang');
        if (isCash) {
          totalCash += amount;
        } else {
          totalNonCash += amount;
        }
        breakdown.add(
          CashierPaymentBreakdownRecord(
            name: row['pm_name']?.toString() ?? '-',
            count: _asInt(row['tx_count']) ?? 0,
            amount: amount,
            isCash: isCash,
          ),
        );
      }

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        shiftName: shiftName,
        shiftOpenedAt: shiftOpenedAt,
        useShiftOpenedAt: true,
        openingBalance: openingBalance,
        hasActiveShift: hasActiveShift,
        totalCash: totalCash,
        totalNonCash: totalNonCash,
        totalTransactions: _firstInt(txRows, 'tx_count'),
        paymentBreakdown: breakdown,
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
  final session = PosV2RuntimeSessionStore.instance.currentSession ??
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
