import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flinkpos_v2/modules/master_data/shared/widgets/master_data_page_widgets.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/stores/inventory_read_stores.dart';
import 'package:flinkpos_v2/modules/master_data/stores/master_data_read_stores.dart';

class InventoryItemsView extends StatefulWidget {
  const InventoryItemsView({super.key});

  @override
  State<InventoryItemsView> createState() => _InventoryItemsViewState();
}

class _InventoryItemsViewState extends State<InventoryItemsView> {
  final InventoryListStore _store = InventoryListStore.instance;
  final CategoryListStore _categoryStore = CategoryListStore.instance;
  final BrandListStore _brandStore = BrandListStore.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
      _categoryStore.refresh();
      _brandStore.refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<MasterDataListSnapshot<InventoryItemRecord>>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        final records = snapshot.records;
        final lowStockCount = records.where((item) => item.isLowStock).length;

        if (snapshot.isLoading && records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.errorMessage != null && records.isEmpty) {
          return MasterDataErrorView(message: snapshot.errorMessage!);
        }

        return Column(
          children: [
            MasterDataSearchHeader(
              searchController: _searchController,
              searchHint: 'Cari inventory item...',
              onSearchChanged: _store.setSearchQuery,
              countText:
                  '${records.length} items • $lowStockCount low stock',
              onRefresh: _store.refresh,
              filterBar: _buildFilterBar(),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: records.isEmpty
                  ? const MasterDataEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Inventory kosong',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = records[index];
                        final statusLabel = item.isOutOfStock
                            ? 'Out of Stock'
                            : item.isLowStock
                                ? 'Low Stock'
                                : 'Normal';
                        final statusColor = item.isOutOfStock
                            ? const Color(0xFFDC2626)
                            : item.isLowStock
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF22C55E);
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    item.displayName.isNotEmpty
                                        ? item.displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.displayName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF111827),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: statusColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.categoryName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Stock',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.stockQuantity.toStringAsFixed(0),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Harga Beli',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Rp ${currencyFmt.format(item.costAmount)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Reorder',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.minStockLevel.toStringAsFixed(0),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: primaryColor.withValues(alpha: 0.08),
                                  foregroundColor: primaryColor,
                                ),
                                child: const Text('Detail'),
                              ),
                            ],
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

  Widget _buildFilterBar() {
    return ValueListenableBuilder<MasterDataListSnapshot<CategoryListRecord>>(
      valueListenable: _categoryStore.snapshotNotifier,
      builder: (context, categorySnapshot, _) {
        return ValueListenableBuilder<MasterDataListSnapshot<BrandListRecord>>(
          valueListenable: _brandStore.snapshotNotifier,
          builder: (context, brandSnapshot, _) {
            final categories = categorySnapshot.records;
            final brands = brandSnapshot.records;
            return Row(
              children: [
                _buildDropdown<int>(
                  hint: 'Semua Kategori',
                  value: _store.categoryId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                    ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (val) {
                    _store.setFilter(categoryId: val, clearCategory: val == null);
                    setState(() {});
                  },
                ),
                const SizedBox(width: 12),
                _buildDropdown<int>(
                  hint: 'Semua Merek',
                  value: _store.brandId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Merek')),
                    ...brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                  ],
                  onChanged: (val) {
                    _store.setFilter(brandId: val, clearBrand: val == null);
                    setState(() {});
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown<T>({
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Expanded(
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: Text(
              hint,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            icon: const Icon(Icons.expand_more, size: 18),
            style: const TextStyle(fontSize: 11, color: Color(0xFF111827)),
          ),
        ),
      ),
    );
  }
}
