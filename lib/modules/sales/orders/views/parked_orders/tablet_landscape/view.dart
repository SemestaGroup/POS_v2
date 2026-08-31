import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../../app/shell/widgets/sub_menu_sidebar_widget.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../shared/models/sales_order_store.dart';
import '../../../shared/order_details_dialog.dart';
import '../../../shared/orders_history_sync_service.dart';
import '../../../shared/order_sync_status_chip.dart';
import '../../../shared/order_status_presenter.dart';
import '../parked_orders_presentation.dart';

/// Pure Tablet Presentation View untuk Parked Orders
class ParkedOrdersTabletLandscapeView extends StatelessWidget {
  const ParkedOrdersTabletLandscapeView({
    super.key,
    required this.embedded,
    required this.presentation,
  });

  final bool embedded;
  final ParkedOrdersPresentation presentation;

  List<String> _getMenuItems(BuildContext context) => [
    AppLocalizations.of(context)!.posTitle,
    AppLocalizations.of(context)!.activeOrdersTitle,
    AppLocalizations.of(context)!.resumeOrderTitle,
    AppLocalizations.of(context)!.historyTitle,
  ];

  void _handleResumeOrder(BuildContext context, SalesOrderRecord order) {
    SalesOrderStore.instance.resumeOrder(order);
    presentation.onMenuSelected(0);
  }

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

  void _confirmDeleteOrder(BuildContext context, SalesOrderRecord order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade700,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Hapus Pesanan?'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus pesanan #${order.token.isEmpty ? order.id : order.token} (${order.customerName})?\n\nTindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      _handleDeleteOrder(context, order);
    }
  }

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
      backgroundColor: Colors.white,
      body: Row(
        children: [
          SubMenuSidebarWidget(
            items: _getMenuItems(context),
            selectedIndex: 2,
            onItemSelected: presentation.onMenuSelected,
          ),
          Expanded(child: SafeArea(child: content)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color primaryColor) {
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
                    )!.ordersFound(presentation.parkedOrders.length),
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
                width: embedded ? 250 : 300,
                height: 36,
                child: TextField(
                  controller: presentation.searchController,
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
                label: 'Pesanan Meja',
                count: presentation.tableCount,
                color: Colors.indigo.shade700,
                bg: Colors.indigo.shade50,
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                context: context,
                label: 'Pesanan Online',
                count: presentation.onlineCount,
                color: Colors.teal.shade700,
                bg: Colors.teal.shade50,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: presentation.parkedOrders.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context)!.emptyParkedOrdersMessage,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: presentation.parkedOrders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = presentation.parkedOrders[index];
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showOrderDetailsDialog(
          context,
          order: order,
          onResumeOrder: () => _handleResumeOrder(context, order),
          onDeleteOrder: () => _handleDeleteOrder(context, order),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${order.token.isEmpty ? order.id : order.token}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            localizedOrderType,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            localizedStatusCode,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${order.totalQuantity} item',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 13,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.customerName.isEmpty
                              ? 'Pelanggan Umum'
                              : order.customerName,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (order.note != null &&
                            order.note!.trim().isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Text(
                            '(${order.note!})',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rp ${order.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _confirmDeleteOrder(context, order),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        color: Colors.red.shade600,
                        tooltip: 'Hapus Pesanan',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _handleResumeOrder(context, order),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: const Text(
                          'Lanjutkan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
