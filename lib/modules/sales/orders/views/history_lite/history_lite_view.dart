import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/widgets/responsive/responsive_context.dart';
import '../../../shared/models/sales_order_store.dart';
import '../../shared/orders_history_sync_service.dart';
import '../active_orders/active_orders_view.dart';
import '../parked_orders/parked_orders_view.dart';
import 'history_lite_presentation.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

/// Stateful Coordinator & Router untuk HistoryLiteView (menjaga kontrak nama asli)
class HistoryLiteView extends StatefulWidget {
  const HistoryLiteView({
    super.key,
    this.embedded = false,
    this.onSectionSelected,
  });

  final bool embedded;
  final ValueChanged<int>? onSectionSelected;

  @override
  State<HistoryLiteView> createState() => _HistoryLiteViewState();
}

class _HistoryLiteViewState extends State<HistoryLiteView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()..addListener(_onSearchChanged);
    unawaited(OrdersHistorySyncService.instance.ensureSynced());
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleMenuSelection(int index) {
    if (widget.onSectionSelected != null) {
      widget.onSectionSelected!(index);
      return;
    }

    switch (index) {
      case 0:
        Navigator.pop(context);
        return;
      case 1:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ActiveOrdersView()),
        );
        return;
      case 2:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ParkedOrdersView()),
        );
        return;
      case 3:
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SalesOrderRecord>>(
      valueListenable: SalesOrderStore.instance.recordsNotifier,
      builder: (context, allOrders, _) {
        final query = _searchController.text.trim().toLowerCase();
        final today = DateTime.now();
        final historyOrders = allOrders
            .where((order) => {2, 4, 5}.contains(order.statusCode))
            .where(
              (order) =>
                  order.createdAt.year == today.year &&
                  order.createdAt.month == today.month &&
                  order.createdAt.day == today.day,
            )
            .where((order) {
              if (query.isEmpty) {
                return true;
              }

              return order.id.toLowerCase().contains(query) ||
                  order.customerName.toLowerCase().contains(query) ||
                  order.token.toLowerCase().contains(query);
            })
            .toList();

        final closedCount = allOrders
            .where(
              (order) =>
                  order.statusCode == 2 &&
                  order.createdAt.year == today.year &&
                  order.createdAt.month == today.month &&
                  order.createdAt.day == today.day,
            )
            .length;
        final overdueCount = allOrders
            .where(
              (order) =>
                  order.statusCode == 4 &&
                  order.createdAt.year == today.year &&
                  order.createdAt.month == today.month &&
                  order.createdAt.day == today.day,
            )
            .length;
        final voidCount = allOrders
            .where(
              (order) =>
                  order.statusCode == 5 &&
                  order.createdAt.year == today.year &&
                  order.createdAt.month == today.month &&
                  order.createdAt.day == today.day,
            )
            .length;

        final presentation = HistoryLitePresentation(
          searchController: _searchController,
          historyOrders: historyOrders,
          closedCount: closedCount,
          overdueCount: overdueCount,
          voidCount: voidCount,
          onMenuSelected: _handleMenuSelection,
          onSectionSelected: widget.onSectionSelected,
        );

        return context.isMobile
            ? HistoryLiteMobileView(
                embedded: widget.embedded,
                presentation: presentation,
              )
            : HistoryLiteTabletLandscapeView(
                embedded: widget.embedded,
                presentation: presentation,
              );
      },
    );
  }
}
