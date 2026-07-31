import 'package:flutter/material.dart';

import '../../../../../core/widgets/responsive/responsive_context.dart';
import '../../../shared/models/sales_order_store.dart';
import '../history_lite/history_lite_view.dart';
import '../parked_orders/parked_orders_view.dart';
import 'active_orders_presentation.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

/// Stateful Coordinator & Router untuk ActiveOrdersView
class ActiveOrdersView extends StatefulWidget {
  const ActiveOrdersView({
    super.key,
    this.embedded = false,
    this.onSectionSelected,
  });

  final bool embedded;
  final ValueChanged<int>? onSectionSelected;

  @override
  State<ActiveOrdersView> createState() => _ActiveOrdersViewState();
}

class _ActiveOrdersViewState extends State<ActiveOrdersView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()..addListener(_onSearchChanged);
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
      case 2:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ParkedOrdersView()),
        );
        return;
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HistoryLiteView()),
        );
        return;
      case 1:
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
        final activeOrders = allOrders
            .where((order) => order.statusCode == 1)
            .where((order) {
              if (query.isEmpty) {
                return true;
              }

              return order.id.toLowerCase().contains(query) ||
                  order.customerName.toLowerCase().contains(query) ||
                  order.token.toLowerCase().contains(query);
            })
            .toList();

        final activeCount = allOrders
            .where((order) => order.statusCode == 1)
            .length;
        final closedCount = allOrders
            .where((order) => order.statusCode == 2)
            .length;
        final issueCount = allOrders
            .where((order) => order.statusCode == 4 || order.statusCode == 5)
            .length;

        final presentation = ActiveOrdersPresentation(
          searchController: _searchController,
          activeOrders: activeOrders,
          activeCount: activeCount,
          closedCount: closedCount,
          issueCount: issueCount,
          onMenuSelected: _handleMenuSelection,
          onSectionSelected: widget.onSectionSelected,
        );

        return context.isMobile
            ? ActiveOrdersMobileView(
                embedded: widget.embedded,
                presentation: presentation,
              )
            : ActiveOrdersTabletLandscapeView(
                embedded: widget.embedded,
                presentation: presentation,
              );
      },
    );
  }
}
