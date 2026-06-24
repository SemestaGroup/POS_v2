import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../../app/shell/widgets/sub_menu_sidebar_widget.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../shared/models/sales_order_store.dart';
import '../../../shared/orders_history_sync_service.dart';
import '../../../shared/order_sync_status_chip.dart';
import '../../../shared/order_status_presenter.dart';
import '../../active_orders/tablet_landscape/view.dart';
import '../../history_lite/tablet_landscape/view.dart';

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
    final primaryColor = Theme.of(context).colorScheme.primary;

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

        final content = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(widget.embedded ? 0.9 : 0.96),
          ),
          child: _buildContent(
            context,
            primaryColor,
            parkedOrders,
            tableCount,
            onlineCount,
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
                selectedIndex: 2,
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
    List<SalesOrderRecord> parkedOrders,
    int tableCount,
    int onlineCount,
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
                  Icons.pause_circle_outline_rounded,
                  color: primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.resumeOrderTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.ordersFound(parkedOrders.length),
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
                  title: AppLocalizations.of(context)!.orderStatusParked,
                  value: '${parkedOrders.length}',
                  icon: Icons.inventory_2_outlined,
                  primaryColor: primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryTile(
                  title: AppLocalizations.of(context)!.table,
                  value: '$tableCount',
                  icon: Icons.table_restaurant_rounded,
                  primaryColor: const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryTile(
                  title: AppLocalizations.of(context)!.online,
                  value: '$onlineCount',
                  icon: Icons.storefront_outlined,
                  primaryColor: const Color(0xFF6A1B9A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: parkedOrders.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    itemCount: parkedOrders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildParkedOrderCard(
                        parkedOrders[index],
                        primaryColor,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile({
    required String title,
    required String value,
    required IconData icon,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: primaryColor),
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
              color: primaryColor,
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
            Icons.inventory_2_outlined,
            size: 42,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.resumeOrderTitle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.emptyParkedOrdersMessage,
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

  Widget _buildParkedOrderCard(SalesOrderRecord order, Color primaryColor) {
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
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(order.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  order.customerName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaChip(
                      Icons.receipt_long_rounded,
                      AppLocalizations.of(
                        context,
                      )!.itemsCount(order.totalQuantity),
                    ),
                    _buildMetaChip(
                      Icons.confirmation_number_outlined,
                      order.id,
                    ),
                    _buildMetaChip(
                      Icons.local_mall_outlined,
                      _orderTypeLabel(context, order.orderType),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(order.totalAmount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        SalesOrderStore.instance.deleteOrder(order.id);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.deleteAction,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        SalesOrderStore.instance.resumeOrder(order);
                        if (mounted && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.resumeAction,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.black54),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
