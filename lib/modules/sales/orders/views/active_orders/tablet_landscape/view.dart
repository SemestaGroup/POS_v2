import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../../app/shell/widgets/sub_menu_sidebar_widget.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../shared/order_status_presenter.dart';
import '../../../shared/orders_history_sync_service.dart';
import '../../../shared/order_sync_status_chip.dart';
import '../../../../shared/models/sales_order_store.dart';
import '../../history_lite/tablet_landscape/view.dart';
import '../../parked_orders/tablet_landscape/view.dart';

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
    final primaryColor = Theme.of(context).colorScheme.primary;

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

        final content = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(widget.embedded ? 0.9 : 0.96),
          ),
          child: _buildContent(
            context,
            primaryColor,
            activeOrders,
            activeCount,
            closedCount,
            issueCount,
          ),
        );

        if (widget.embedded) {
          return ColoredBox(color: Colors.white, child: content);
        }

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.white,
          body: Row(
            children: [
              SubMenuSidebarWidget(
                items: _getMenuItems(context),
                selectedIndex: 1,
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
    List<SalesOrderRecord> activeOrders,
    int activeCount,
    int closedCount,
    int issueCount,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 12 : 10,
        widget.embedded ? 6 : 8,
        widget.embedded ? 12 : 10,
        widget.embedded ? 12 : 10,
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
                  Icons.assignment_outlined,
                  color: primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.activeOrdersTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(
                      context,
                    )!.ordersFound(activeOrders.length),
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
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: AppLocalizations.of(context)!.searchPlaceholder,
                    hintStyle: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
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
                  label: AppLocalizations.of(context)!.orderStatusActive,
                  value: '$activeCount',
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryTile(
                  label: AppLocalizations.of(context)!.orderStatusClosed,
                  value: '$closedCount',
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryTile(
                  label: AppLocalizations.of(context)!.orderStatusVoid,
                  value: '$issueCount',
                  color: const Color(0xFFD84315),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: activeOrders.isEmpty
                ? _buildEmptyState(context)
                : Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: widget.embedded ? 220 : 240,
                        mainAxisExtent: widget.embedded ? 150 : 165,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: activeOrders.length,
                      itemBuilder: (context, index) {
                        return _buildOrderCard(
                          activeOrders[index],
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

  Widget _buildSummaryTile({
    required String label,
    required String value,
    required Color color,
  }) {
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
              label,
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
          Icon(Icons.inbox_rounded, size: 42, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.activeOrdersTitle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.emptyActiveOrdersMessage,
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

  Widget _buildOrderCard(SalesOrderRecord order, Color primaryColor) {
    final status = presentOrderStatus(context, order.statusCode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          SalesOrderStore.instance.resumeOrder(order);
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(order.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: status.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                order.id,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.orderSummary(order.totalQuantity, order.orderType),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade700),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatCurrency(order.totalAmount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      order.token,
                      style: TextStyle(
                        fontSize: 9,
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
