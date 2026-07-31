import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../../app/shell/widgets/sub_menu_sidebar_widget.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../shared/order_status_presenter.dart';
import '../../../shared/orders_history_sync_service.dart';
import '../../../shared/order_sync_status_chip.dart';
import '../../../../shared/models/sales_order_store.dart';
import '../active_orders_presentation.dart';

/// Pure Tablet Presentation View untuk Active Orders
class ActiveOrdersTabletLandscapeView extends StatelessWidget {
  const ActiveOrdersTabletLandscapeView({
    super.key,
    required this.embedded,
    required this.presentation,
  });

  final bool embedded;
  final ActiveOrdersPresentation presentation;

  List<String> _getMenuItems(BuildContext context) => [
    AppLocalizations.of(context)!.posTitle,
    AppLocalizations.of(context)!.activeOrdersTitle,
    AppLocalizations.of(context)!.resumeOrderTitle,
    AppLocalizations.of(context)!.historyTitle,
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final content = MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(embedded ? 0.9 : 0.96)),
      child: _buildContent(context, primaryColor),
    );

    if (embedded) {
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
            onItemSelected: presentation.onMenuSelected,
          ),
          Expanded(child: SafeArea(child: content)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        embedded ? 12 : 10,
        embedded ? 6 : 8,
        embedded ? 12 : 10,
        embedded ? 12 : 10,
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (!embedded) ...[
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
                    l10n.activeOrdersTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.ordersFound(presentation.activeOrders.length),
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
                tooltip: l10n.syncDataAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: embedded ? 250 : 300,
                height: 36,
                child: TextField(
                  controller: presentation.searchController,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.searchPlaceholder,
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
                        presentation.searchController.clear();
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildMetricChip(
                context: context,
                label: l10n.orderStatusActive,
                count: presentation.activeCount,
                color: Colors.blue.shade700,
                bg: Colors.blue.shade50,
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                context: context,
                label: l10n.orderStatusClosed,
                count: presentation.closedCount,
                color: Colors.green.shade700,
                bg: Colors.green.shade50,
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                context: context,
                label: 'Bermasalah',
                count: presentation.issueCount,
                color: Colors.orange.shade700,
                bg: Colors.orange.shade50,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: presentation.activeOrders.isEmpty
                ? Center(
                    child: Text(
                      l10n.emptyActiveOrdersMessage,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: presentation.activeOrders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = presentation.activeOrders[index];
                      return _buildOrderCard(context, primaryColor, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required BuildContext context,
    required String label,
    required int count,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    Color primaryColor,
    SalesOrderRecord order,
  ) {
    final localizedOrderType = OrderStatusPresenter.getLocalizedOrderType(
      context,
      order.orderType,
    );
    final localizedStatusCode = OrderStatusPresenter.getLocalizedStatusCode(
      context,
      order.statusCode,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${order.token.isEmpty ? order.id : order.token}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  localizedOrderType,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  localizedStatusCode,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 12,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                order.customerName.isEmpty
                    ? 'Pelanggan Umum'
                    : order.customerName,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
              const Spacer(),
              Text(
                'Rp ${order.totalAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
