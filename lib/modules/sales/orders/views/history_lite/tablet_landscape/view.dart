import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../../app/shell/widgets/sub_menu_sidebar_widget.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../shared/models/sales_order_store.dart';
import '../../../shared/orders_history_sync_service.dart';
import '../../../shared/order_sync_status_chip.dart';
import '../../../shared/order_status_presenter.dart';
import '../../active_orders/tablet_landscape/view.dart';
import '../../parked_orders/tablet_landscape/view.dart';

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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(OrdersHistorySyncService.instance.ensureSynced());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getMenuItems(BuildContext context) => [
    AppLocalizations.of(context)!.posTitle,
    AppLocalizations.of(context)!.activeOrdersTitle,
    AppLocalizations.of(context)!.resumeOrderTitle,
    AppLocalizations.of(context)!.historyTitle,
  ];

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
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder<List<SalesOrderRecord>>(
      valueListenable: SalesOrderStore.instance.recordsNotifier,
      builder: (context, allOrders, _) {
        final query = _searchController.text.trim().toLowerCase();
        final historyOrders = allOrders
            .where((order) => {2, 4, 5}.contains(order.statusCode))
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
            .where((order) => order.statusCode == 2)
            .length;
        final overdueCount = allOrders
            .where((order) => order.statusCode == 4)
            .length;
        final voidCount = allOrders
            .where((order) => order.statusCode == 5)
            .length;

        final content = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(widget.embedded ? 0.9 : 0.96),
          ),
          child: _buildContent(
            context,
            primaryColor,
            historyOrders,
            closedCount,
            overdueCount,
            voidCount,
          ),
        );

        if (widget.embedded) {
          return ColoredBox(color: Colors.white, child: content);
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: Row(
            children: [
              SubMenuSidebarWidget(
                items: _getMenuItems(context),
                selectedIndex: 3,
                onItemSelected: _handleMenuSelection,
              ),
              Expanded(child: SafeArea(child: content)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    Color primaryColor,
    List<SalesOrderRecord> historyOrders,
    int closedCount,
    int overdueCount,
    int voidCount,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 12 : 16,
        widget.embedded ? 6 : 16,
        widget.embedded ? 12 : 16,
        widget.embedded ? 12 : 16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (!widget.embedded) ...[
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
              ],
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.historyTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.ordersFound(historyOrders.length),
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
              const Spacer(),
              const OrderSyncStatusChip(),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => unawaited(
                  OrdersHistorySyncService.instance.ensureSynced(force: true),
                ),
                tooltip: AppLocalizations.of(context)!.syncDataAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: widget.embedded ? 250 : 300,
                height: 36,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchPlaceholder,
                    hintStyle: const TextStyle(fontSize: 11),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, size: 16),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSummaryTile(
                  AppLocalizations.of(context)!.orderStatusClosed,
                  '$closedCount',
                  const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryTile(
                  AppLocalizations.of(context)!.orderStatusOverdue,
                  '$overdueCount',
                  const Color(0xFFEF6C00),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryTile(
                  AppLocalizations.of(context)!.orderStatusVoid,
                  '$voidCount',
                  const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: historyOrders.isEmpty
                ? _buildEmptyState(context)
                : Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: ListView.separated(
                      itemCount: historyOrders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _buildHistoryCard(
                          historyOrders[index],
                          primaryColor,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 42,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.historyTitle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.emptyHistoryMessage,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _formatCurrency(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final position = digits.length - index;
      buffer.write(digits[index]);
      if (position > 1 && position % 3 == 1) {
        buffer.write('.');
      }
    }
    return 'Rp$buffer';
  }

  String _orderTypeLabel(BuildContext context, String rawValue) {
    switch (rawValue) {
      case 'take_away':
        return AppLocalizations.of(context)!.takeAway;
      case 'shopee_food':
        return 'ShopeeFood';
      case 'go_food':
        return 'GoFood';
      case 'grab_food':
        return 'GrabFood';
      default:
        return AppLocalizations.of(context)!.dineIn;
    }
  }

  Widget _buildHistoryCard(SalesOrderRecord order, Color primaryColor) {
    final status = presentOrderStatus(context, order.statusCode);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  order.id,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              _formatDate(order.createdAt),
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              _orderTypeLabel(context, order.orderType),
              style: const TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: status.color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              _formatCurrency(order.totalAmount),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
