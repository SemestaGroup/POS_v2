import 'package:flutter/material.dart';
import '../../../shared/models/sales_order_store.dart';

/// Presentation model berisi data dan callback bersama untuk HistoryLiteView
class HistoryLitePresentation {
  const HistoryLitePresentation({
    required this.searchController,
    required this.historyOrders,
    required this.closedCount,
    required this.overdueCount,
    required this.voidCount,
    required this.onMenuSelected,
    this.onSectionSelected,
  });

  final TextEditingController searchController;
  final List<SalesOrderRecord> historyOrders;
  final int closedCount;
  final int overdueCount;
  final int voidCount;
  final ValueChanged<int> onMenuSelected;
  final ValueChanged<int>? onSectionSelected;
}
