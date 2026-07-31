import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/widgets/responsive/responsive_context.dart';
import '../../../shared/models/sales_order_store.dart';
import '../../shared/orders_history_sync_service.dart';
import '../active_orders/active_orders_view.dart';
import '../history_lite/history_lite_view.dart';
import 'mobile_portrait/view.dart';
import 'parked_orders_presentation.dart';
import 'tablet_landscape/view.dart';

/// Stateful Coordinator & Router untuk ParkedOrdersView
class ParkedOrdersView extends StatefulWidget {
  const ParkedOrdersView({
    super.key,
    this.embedded = false,
    this.onSectionSelected,
  });

  final bool embedded;
  final ValueChanged<int>? onSectionSelected;

  @override
  State<ParkedOrdersView> createState() => _ParkedOrdersViewState();
}

class _ParkedOrdersViewState extends State<ParkedOrdersView> {
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
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HistoryLiteView()),
        );
        return;
      case 2:
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
        final parkedOrders = allOrders
            .where((order) => order.statusCode == 6)
            .where((order) {
              if (query.isEmpty) {
                return true;
              }

              return order.id.toLowerCase().contains(query) ||
                  order.customerName.toLowerCase().contains(query) ||
                  order.token.toLowerCase().contains(query);
            })
            .toList();

        final tableCount = parkedOrders
            .where((order) => order.orderType == 'dine_in')
            .length;
        final onlineCount = parkedOrders
            .where(
              (order) =>
                  order.orderType != 'dine_in' &&
                  order.orderType != 'take_away',
            )
            .length;

        final presentation = ParkedOrdersPresentation(
          searchController: _searchController,
          parkedOrders: parkedOrders,
          tableCount: tableCount,
          onlineCount: onlineCount,
          onMenuSelected: _handleMenuSelection,
          onSectionSelected: widget.onSectionSelected,
        );

        return context.isMobile
            ? ParkedOrdersMobileView(
                embedded: widget.embedded,
                presentation: presentation,
              )
            : ParkedOrdersTabletLandscapeView(
                embedded: widget.embedded,
                presentation: presentation,
              );
      },
    );
  }
}
