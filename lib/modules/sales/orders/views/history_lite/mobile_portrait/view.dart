import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../shared/mobile_orders_section_menu.dart';
import '../../../shared/order_details_dialog.dart';
import '../../../shared/orders_history_sync_service.dart';
import '../../../shared/order_sync_status_chip.dart';
import '../../../shared/order_status_presenter.dart';
import '../../../../shared/models/sales_order_store.dart';
import '../history_lite_presentation.dart';

/// Pure Mobile Presentation View untuk History Lite
class HistoryLiteMobileView extends StatelessWidget {
  const HistoryLiteMobileView({
    super.key,
    required this.embedded,
    required this.presentation,
  });

  final bool embedded;
  final HistoryLitePresentation presentation;

  void _handleDeleteOrder(BuildContext context, SalesOrderRecord order) {
    SalesOrderStore.instance.deleteOrder(order.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pesanan #${order.token.isEmpty ? order.id : order.token} berhasil dihapus',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final content = _buildContent(context, primaryColor);

    if (embedded) {
      return ColoredBox(color: Colors.white, child: content);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: content),
    );
  }

  Widget _buildContent(BuildContext context, Color primaryColor) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(12.0),
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
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: primaryColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.historyTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      l10n.ordersFound(presentation.historyOrders.length),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              MobileOrdersSectionMenu(
                selectedIndex: 3,
                onSelected: presentation.onMenuSelected,
              ),
              const OrderSyncStatusChip(),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => unawaited(
                  OrdersHistorySyncService.instance.ensureSynced(force: true),
                ),
                tooltip: l10n.syncDataAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: TextField(
              controller: presentation.searchController,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.searchPlaceholder,
                hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
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
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricChip(
                  context: context,
                  label: l10n.orderStatusClosed,
                  count: presentation.closedCount,
                  color: Colors.green.shade700,
                  bg: Colors.green.shade50,
                ),
                const SizedBox(width: 6),
                _buildMetricChip(
                  context: context,
                  label: 'Bermasalah',
                  count: presentation.voidCount,
                  color: Colors.orange.shade700,
                  bg: Colors.orange.shade50,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: presentation.historyOrders.isEmpty
                ? Center(
                    child: Text(
                      l10n.emptyActiveOrdersMessage,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: presentation.historyOrders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = presentation.historyOrders[index];
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
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
    final statusPresentation = presentOrderStatus(context, order.statusCode);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showOrderDetailsDialog(
          context,
          order: order,
          onResumeOrder: () {},
          onDeleteOrder: () => _handleDeleteOrder(context, order),
          allowEdit: false,
        ),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#${order.token.isEmpty ? order.id : order.token}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (localizedOrderType.isNotEmpty &&
                      localizedOrderType != '—' &&
                      localizedOrderType != '-') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        localizedOrderType,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: statusPresentation.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusPresentation.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusPresentation.color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    order.customerName.isEmpty
                        ? 'Pelanggan Umum'
                        : order.customerName,
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                const SizedBox(width: 6),
                Text(
                  '• ${OrderStatusPresenter.formatTime(order.createdAt)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black45,
                  ),
                ),
                  const Spacer(),
                  Text(
                    OrderStatusPresenter.formatRupiah(order.totalAmount),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              if (order.note != null && order.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.sticky_note_2_outlined,
                      size: 11,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.note!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
