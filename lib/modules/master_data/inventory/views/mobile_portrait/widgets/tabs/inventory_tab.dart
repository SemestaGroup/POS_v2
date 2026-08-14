import 'package:flutter/material.dart';

import '../../../../../stores/master_data_read_stores.dart';
import '../../../../models/marketplace_item.dart';
import '../../../../stores/inventory_read_stores.dart';
import '../inventory_card.dart';
import '../inventory_common_widgets.dart';
import '../inventory_search_filter_bar.dart';

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final _inventoryStore = InventoryListStore.instance;
  final _categoryStore = CategoryListStore.instance;
  final _brandStore = BrandListStore.instance;
  final TextEditingController _stockSearchController = TextEditingController();
  StockFilter _stockFilter = StockFilter.all;

  @override
  void dispose() {
    _stockSearchController.dispose();
    super.dispose();
  }

  Future<void> _showInventoryFilters() async {
    var categoryId = _inventoryStore.categoryId;
    var brandId = _inventoryStore.brandId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final scheme = Theme.of(context).colorScheme;
          final categories = _categoryStore.snapshotNotifier.value.records;
          final brands = _brandStore.snapshotNotifier.value.records;
          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Filter stok',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  InventoryFilterDropdown(
                    label: 'Kategori',
                    value: categoryId,
                    hint: 'Semua kategori',
                    items: categories
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setSheetState(() => categoryId = value),
                  ),
                  const SizedBox(height: 12),
                  InventoryFilterDropdown(
                    label: 'Merek',
                    value: brandId,
                    hint: 'Semua merek',
                    items: brands
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setSheetState(() => brandId = value),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setSheetState(() {
                          categoryId = null;
                          brandId = null;
                        }),
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          _inventoryStore.setFilter(
                            categoryId: categoryId,
                            brandId: brandId,
                            clearCategory: categoryId == null,
                            clearBrand: brandId == null,
                          );
                          setState(() {});
                          Navigator.pop(context);
                        },
                        child: const Text('Terapkan filter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MasterDataListSnapshot<InventoryItemRecord>>(
      valueListenable: _inventoryStore.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.records.isEmpty) {
          return ErrorStateWidget(
            message: snapshot.errorMessage!,
            onRetry: _inventoryStore.refresh,
          );
        }
        final lowStock =
            snapshot.records.where((item) => item.isLowStock).length;
        final query = _stockSearchController.text.trim().toLowerCase();
        final hasActiveFilter = _stockFilter != StockFilter.all ||
            query.isNotEmpty ||
            _inventoryStore.categoryId != null ||
            _inventoryStore.brandId != null;

        final records = snapshot.records
            .where((item) {
              final matchesQuery = query.isEmpty ||
                  item.displayName.toLowerCase().contains(query) ||
                  item.sku.toLowerCase().contains(query) ||
                  item.categoryName.toLowerCase().contains(query);
              final matchesFilter = switch (_stockFilter) {
                StockFilter.all => true,
                StockFilter.needsAttention => item.isLowStock,
                StockFilter.outOfStock => item.isOutOfStock,
              };
              return matchesQuery && matchesFilter;
            })
            .toList(growable: false);

        return RefreshIndicator(
          onRefresh: _inventoryStore.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: MobileSearchField(
                      controller: _stockSearchController,
                      hintText: 'Cari barang, SKU, atau kategori',
                      onChanged: (_) => setState(() {}),
                      onClear: () {
                        _stockSearchController.clear();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  InventoryFilterButton(
                    activeCount: [
                      _inventoryStore.categoryId,
                      _inventoryStore.brandId,
                    ].whereType<int>().length,
                    onPressed: _showInventoryFilters,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StockFilterBar(
                      selected: _stockFilter,
                      attentionCount: lowStock,
                      onChanged: (value) =>
                          setState(() => _stockFilter = value),
                    ),
                  ),
                  if (hasActiveFilter) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        _stockSearchController.clear();
                        _inventoryStore.setFilter(
                          clearCategory: true,
                          clearBrand: true,
                        );
                        setState(() => _stockFilter = StockFilter.all);
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
                  '${records.length} barang',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (records.isEmpty)
                InventoryEmptyState(
                  hasFilter: hasActiveFilter,
                )
              else
                ...records.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InventoryCard(item: item),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
