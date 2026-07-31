import 'package:flutter/material.dart';
import '../../../shared/models/sales_order_store.dart';

/// Presentation model berisi data dan callback bersama untuk ActiveOrdersView
class ActiveOrdersPresentation {
  const ActiveOrdersPresentation({
    required this.searchController,
    required this.activeOrders,
    required this.activeCount,
    required this.closedCount,
    required this.issueCount,
    required this.onMenuSelected,
    this.onSectionSelected,
  });

  final TextEditingController searchController;
  final List<SalesOrderRecord> activeOrders;
  final int activeCount;
  final int closedCount;
  final int issueCount;
  final ValueChanged<int> onMenuSelected;
  final ValueChanged<int>? onSectionSelected;
}
