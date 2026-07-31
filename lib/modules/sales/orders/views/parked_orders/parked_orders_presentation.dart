import 'package:flutter/material.dart';
import '../../../shared/models/sales_order_store.dart';

/// Presentation model berisi data dan callback bersama untuk ParkedOrdersView
class ParkedOrdersPresentation {
  const ParkedOrdersPresentation({
    required this.searchController,
    required this.parkedOrders,
    required this.tableCount,
    required this.onlineCount,
    required this.onMenuSelected,
    this.onSectionSelected,
  });

  final TextEditingController searchController;
  final List<SalesOrderRecord> parkedOrders;
  final int tableCount;
  final int onlineCount;
  final ValueChanged<int> onMenuSelected;
  final ValueChanged<int>? onSectionSelected;
}
