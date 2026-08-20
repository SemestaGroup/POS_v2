import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/shift_report_calculations.dart';

class ShiftHistoryItem {
  final int id;
  final String shiftName;
  final String staffName;
  final String? registerId;
  final String status;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int openingBalance;

  /// Expected cash captured when the shift was closed. Kept for audit only;
  /// card and detail reconciliation use [expectedCash] from transactions.
  final int storedExpectedCash;
  final int expectedCash;
  final int actualCash;
  final int totalNonCash;
  final int cashSales;
  final int totalCashIn;
  final int totalCashOut;
  final dynamic rawData;

  const ShiftHistoryItem({
    required this.id,
    required this.shiftName,
    required this.staffName,
    this.registerId,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.openingBalance,
    required this.storedExpectedCash,
    required this.expectedCash,
    required this.actualCash,
    required this.totalNonCash,
    required this.cashSales,
    this.totalCashIn = 0,
    this.totalCashOut = 0,
    this.rawData,
  });

  bool get isClosed => status == 'closed' || closedAt != null;

  int get variance => isClosed
      ? ShiftReportCalculations.cashVariance(
          actualCash: actualCash,
          expectedCash: expectedCash,
        )
      : 0;

  int get transactionVariance => variance;

  int get totalShiftSales => cashSales + totalNonCash;

  String formatVariance(NumberFormat fmt) {
    if (!isClosed) return 'Shift Berjalan';
    if (transactionVariance == 0) return 'Pas (Rp 0)';
    if (transactionVariance < 0) {
      return 'Kurang Rp ${fmt.format(transactionVariance.abs())}';
    }
    return 'Lebih Rp ${fmt.format(transactionVariance)}';
  }

  Color get varianceColor => getVarianceColor();

  Color getVarianceColor() {
    if (!isClosed) return const Color(0xFF0284C7);
    if (transactionVariance == 0) return const Color(0xFF15803D);
    if (transactionVariance < 0) return const Color(0xFFB91C1C);
    return const Color(0xFFB45309);
  }
}
