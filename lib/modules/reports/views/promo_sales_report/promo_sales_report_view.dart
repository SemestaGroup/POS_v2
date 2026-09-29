import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../sales/orders/shared/orders_history_sync_service.dart';
import '../../stores/report_read_stores.dart';
import '../shared/report_view_widgets.dart';

class PromoSalesReportView extends StatefulWidget {
  const PromoSalesReportView({super.key});

  @override
  State<PromoSalesReportView> createState() => _PromoSalesReportViewState();
}

class _PromoSalesReportViewState extends State<PromoSalesReportView> {
  final PromoSalesReportStore _store = PromoSalesReportStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncAndRefresh());
    });
  }

  Future<void> _syncAndRefresh({String? period}) async {
    await OrdersHistorySyncService.instance.ensureSynced();
    if (mounted) {
      await _store.refresh(
        period: period ?? _store.snapshotNotifier.value.period,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final primary = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder<PromoSalesSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.promos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.promos.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        return Column(
          children: [
            ReportPeriodBar(
              period: snapshot.period,
              onPeriodChanged: (value) => _syncAndRefresh(period: value),
              onRefresh: () => _syncAndRefresh(period: snapshot.period),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            ReportSummaryStrip(
              items: [
                ReportStripItem(
                  'Transaksi Promo',
                  '${snapshot.promoOrderCount}',
                  primary,
                ),
                ReportStripItem(
                  'Total Potongan',
                  'Rp ${currencyFmt.format(snapshot.totalDiscount)}',
                  const Color(0xFFEF4444),
                ),
                ReportStripItem(
                  'Omset Promo',
                  'Rp ${currencyFmt.format(snapshot.promoNetSales)}',
                  const Color(0xFF10B981),
                ),
              ],
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            const ReportTableHeader(
              columns: [
                ReportColumn('#', 1),
                ReportColumn('Promo', 5),
                ReportColumn('Transaksi', 2),
                ReportColumn('Potongan', 3, alignEnd: true),
                ReportColumn('Omset', 3, alignEnd: true),
              ],
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: snapshot.promos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Belum ada transaksi yang memakai promo pada '
                          'periode ini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: snapshot.promos.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final promo = snapshot.promos[index];
                        return InkWell(
                          onTap: () => _showDetail(context, promo),
                          child: Container(
                            color: index.isOdd
                                ? Colors.transparent
                                : const Color(0xFFFAFAFB),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                ReportCell('${index + 1}', 1, muted: true),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        promo.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                      if (promo.type.isNotEmpty)
                                        Text(
                                          promo.type,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                ReportCell('${promo.orderCount}x', 2),
                                ReportCell(
                                  'Rp ${currencyFmt.format(promo.totalDiscount)}',
                                  3,
                                  alignEnd: true,
                                  color: const Color(0xFFDC2626),
                                ),
                                ReportCell(
                                  'Rp ${currencyFmt.format(promo.netSales)}',
                                  3,
                                  bold: true,
                                  alignEnd: true,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showDetail(BuildContext context, PromoSalesRecord promo) {
    showDialog<void>(
      context: context,
      builder: (_) => _PromoDetailDialog(promo: promo, store: _store),
    );
  }
}

class _PromoDetailDialog extends StatelessWidget {
  const _PromoDetailDialog({required this.promo, required this.store});

  final PromoSalesRecord promo;
  final PromoSalesReportStore store;

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      promo.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            ReportSummaryStrip(
              items: [
                ReportStripItem(
                  'Transaksi',
                  '${promo.orderCount}',
                  Theme.of(context).colorScheme.primary,
                ),
                ReportStripItem(
                  'Total Potongan',
                  'Rp ${currencyFmt.format(promo.totalDiscount)}',
                  const Color(0xFFEF4444),
                ),
                ReportStripItem(
                  'Omset Promo',
                  'Rp ${currencyFmt.format(promo.netSales)}',
                  const Color(0xFF10B981),
                ),
              ],
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: promo.orders.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, index) {
                  final order = promo.orders[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              'Rp ${currencyFmt.format(order.totalAmount)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.orderedAt == null
                                    ? '-'
                                    : dateFmt.format(order.orderedAt!),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            Text(
                              'Potongan Rp ${currencyFmt.format(order.discountAmount)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _OrderItemChips(orderId: order.orderId, store: store),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemChips extends StatelessWidget {
  const _OrderItemChips({required this.orderId, required this.store});

  final int orderId;
  final PromoSalesReportStore store;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: store.loadOrderItems(orderId),
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null || items.isEmpty) {
          return const SizedBox.shrink();
        }
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final item in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
