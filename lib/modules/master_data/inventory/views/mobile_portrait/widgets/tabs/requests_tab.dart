import 'package:flutter/material.dart';

import '../../../../../stores/master_data_read_stores.dart';
import '../../../../stores/inventory_read_stores.dart';
import '../inventory_common_widgets.dart';
import '../inventory_search_filter_bar.dart';
import '../purchase_order_card.dart';
import '../purchase_order_details_sheet.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  final _purchaseOrderStore = PurchaseOrderStore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showPurchaseOrderDetails(PurchaseOrderRecord order) async {
    final lines = await _purchaseOrderStore.loadLines(order.id);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          PurchaseOrderDetailsSheet(order: order, lines: lines),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MasterDataListSnapshot<PurchaseOrderRecord>>(
      valueListenable: _purchaseOrderStore.snapshotNotifier,
      builder: (context, snapshot, _) {
        final scheme = Theme.of(context).colorScheme;
        if (snapshot.isLoading && snapshot.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.records.isEmpty) {
          return ErrorStateWidget(
            message: snapshot.errorMessage!,
            onRetry: _purchaseOrderStore.refresh,
          );
        }
        final allOrders = snapshot.records;
        final pendingCount =
            allOrders.where((order) => order.status == 'pending').length;
        final processingCount =
            allOrders.where((order) => order.status == 'processing').length;
        final completedCount =
            allOrders.where((order) => order.status == 'completed').length;
        final failedCount =
            allOrders.where((order) => order.status == 'failed').length;

        final query = _searchController.text.trim().toLowerCase();
        final filteredOrders = allOrders
            .where((order) {
              final matchesQuery = query.isEmpty ||
                  (order.poCode).toLowerCase().contains(query);
              final matchesStatus = _selectedStatus == 'all' ||
                  order.status.toLowerCase() == _selectedStatus;
              return matchesQuery && matchesStatus;
            })
            .toList(growable: false);

        final statusItems = <(String, String, int)>[
          ('all', 'Semua', allOrders.length),
          if (pendingCount > 0 || _selectedStatus == 'pending')
            ('pending', 'Dipesan', pendingCount),
          if (processingCount > 0 || _selectedStatus == 'processing')
            ('processing', 'Diproses', processingCount),
          if (completedCount > 0 || _selectedStatus == 'completed')
            ('completed', 'Selesai', completedCount),
          if (failedCount > 0 || _selectedStatus == 'failed')
            ('failed', 'Gagal', failedCount),
        ];

        final hasFilter = query.isNotEmpty || _selectedStatus != 'all';

        return RefreshIndicator(
          onRefresh: _purchaseOrderStore.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            children: [
              PurchaseOrderOverview(
                orderCount: allOrders.length,
                pendingCount: pendingCount,
                processingCount: processingCount,
              ),
              const SizedBox(height: 10),
              MobileSearchField(
                controller: _searchController,
                hintText: 'Cari nomor purchase order (PO)',
                onChanged: (_) => setState(() {}),
                onClear: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: statusItems.map((item) {
                          final statusKey = item.$1;
                          final label = item.$2;
                          final count = item.$3;
                          final isSelected = _selectedStatus == statusKey;

                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              selected: isSelected,
                              onSelected: (_) => setState(() {
                                _selectedStatus = statusKey;
                              }),
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              labelStyle: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? scheme.onPrimary
                                    : scheme.onSurfaceVariant,
                              ),
                              selectedColor: scheme.primary,
                              backgroundColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: .45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected
                                      ? scheme.primary
                                      : scheme.outlineVariant
                                          .withValues(alpha: .5),
                                ),
                              ),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(label),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? scheme.onPrimary
                                              .withValues(alpha: .25)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? scheme.onPrimary
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ),
                  ),
                  if (hasFilter) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _selectedStatus = 'all');
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restart_alt_rounded,
                              size: 13,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Text(
                  '${filteredOrders.length} PO ditampilkan',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (filteredOrders.isEmpty)
                EmptyStateWidget(
                  icon: Icons.receipt_long_outlined,
                  message: hasFilter
                      ? 'Tidak ada purchase order yang cocok.'
                      : 'Belum ada purchase order.',
                )
              else
                ...filteredOrders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PurchaseOrderCard(
                      order: order,
                      onTap: () => _showPurchaseOrderDetails(order),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
