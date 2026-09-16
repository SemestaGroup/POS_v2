import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flinkpos_v2/modules/operations/shift/models/shift_history_item.dart';
import 'package:flinkpos_v2/modules/reports/stores/report_read_stores.dart';

void main() {
  group('CashierReportRowRecord and CashierReportLiteSnapshot', () {
    test('CashierReportRowRecord proxies ShiftHistoryItem properties properly', () {
      final now = DateTime(2026, 9, 5, 8, 0);
      final closed = DateTime(2026, 9, 5, 16, 0);
      final shift = ShiftHistoryItem(
        id: 101,
        shiftName: 'Pagi',
        staffName: 'Budi Santoso',
        registerId: 'REG-01',
        status: 'closed',
        openedAt: now,
        closedAt: closed,
        openingBalance: 100000,
        storedExpectedCash: 600000,
        expectedCash: 600000,
        actualCash: 600000,
        totalNonCash: 250000,
        cashSales: 500000,
      );

      final row = CashierReportRowRecord(
        shiftItem: shift,
        totalOrders: 15,
        totalSales: 750000,
      );

      expect(row.shiftId, 101);
      expect(row.shiftName, 'Pagi');
      expect(row.staffName, 'Budi Santoso');
      expect(row.status, 'closed');
      expect(row.isOpen, isFalse);
      expect(row.openingBalance, 100000);
      expect(row.cashSales, 500000);
      expect(row.nonCashSales, 250000);
      expect(row.totalSales, 750000);
      expect(row.totalOrders, 15);
      expect(row.variance, 0);
    });

    test('CashierReportLiteSnapshot copyWith updates period, range and aggregates', () {
      const initial = CashierReportLiteSnapshot(
        isLoading: false,
        period: 'today',
        shiftName: '-',
        openingBalance: 0,
        hasActiveShift: false,
        totalCash: 0,
        totalNonCash: 0,
        totalTransactions: 0,
        paymentBreakdown: <CashierPaymentBreakdownRecord>[],
      );

      final customRange = DateTimeRange(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 5),
      );

      final updated = initial.copyWith(
        period: 'custom',
        customDateRange: customRange,
        totalCash: 1200000,
        totalNonCash: 800000,
        totalTransactions: 42,
        totalVariance: -5000,
      );

      expect(updated.period, 'custom');
      expect(updated.customDateRange, customRange);
      expect(updated.totalCash, 1200000);
      expect(updated.totalNonCash, 800000);
      expect(updated.totalTransactions, 42);
      expect(updated.totalVariance, -5000);
    });
  });
}
