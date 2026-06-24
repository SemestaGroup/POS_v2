import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/shell/widgets/sub_menu_sidebar_widget.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../shared/orders_history_sync_service.dart';
import '../active_orders/tablet_landscape/view.dart';
import '../history_lite/tablet_landscape/view.dart';
import '../parked_orders/tablet_landscape/view.dart';

class OrdersShellView extends StatefulWidget {
  const OrdersShellView({super.key, this.initialIndex = 1});

  final int initialIndex;

  @override
  State<OrdersShellView> createState() => _OrdersShellViewState();
}

class _OrdersShellViewState extends State<OrdersShellView> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(1, 3);
    unawaited(OrdersHistorySyncService.instance.ensureSynced());
  }

  List<String> _getMenuItems(BuildContext context) => [
    AppLocalizations.of(context)!.posTitle,
    AppLocalizations.of(context)!.activeOrdersTitle,
    AppLocalizations.of(context)!.resumeOrderTitle,
    AppLocalizations.of(context)!.historyTitle,
  ];

  void _handleMenuSelection(int index) {
    if (index == 0) {
      Navigator.pop(context);
      return;
    }

    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          SubMenuSidebarWidget(
            items: _getMenuItems(context),
            selectedIndex: _selectedIndex,
            onItemSelected: _handleMenuSelection,
          ),
          Expanded(
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey(_selectedIndex),
                  child: _buildBody(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 2:
        return const ParkedOrdersView(embedded: true);
      case 3:
        return const HistoryLiteView(embedded: true);
      case 1:
      default:
        return const ActiveOrdersView(embedded: true);
    }
  }
}
