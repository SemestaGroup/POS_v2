import 'package:flutter/material.dart';

import '../../../../../stores/master_data_read_stores.dart';
import '../../../../controllers/inventory_cart_controller.dart';
import '../../../../models/marketplace_item.dart';
import '../../../../stores/inventory_read_stores.dart';
import '../inventory_search_filter_bar.dart';
import '../marketplace_item_row.dart';

class MarketplaceTab extends StatefulWidget {
  const MarketplaceTab({
    super.key,
    required this.remoteItems,
    required this.isLoading,
    required this.cartController,
    required this.onRefresh,
  });

  final List<MarketplaceItem> remoteItems;
  final bool isLoading;
  final InventoryCartController cartController;
  final Future<void> Function() onRefresh;

  @override
  State<MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<MarketplaceTab> {
  final _inventoryStore = InventoryListStore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Semua';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CartEntry _entryFromRemote(MarketplaceItem item) {
    return CartEntry(
      key: 'r:${item.itemId}',
      name: item.displayName,
      sku: item.commodityCode ?? item.skuCode ?? '',
      remoteId: item.itemId,
      unitCost: item.rateCents,
      imageUrl: item.imageUrl,
      group: item.groupName,
    );
  }

  CartEntry _entryFromLocal(InventoryItemRecord item) {
    return CartEntry(
      key: 'l:${item.id}',
      name: item.name,
      sku: item.sku,
      productId: item.id,
      remoteId: item.remoteId,
      unitCost: item.costAmount,
      group: item.displayName,
    );
  }

  Widget _buildEmptySearchState() {
    final isFiltering =
        _searchController.text.isNotEmpty || _selectedCategory != 'Semua';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFiltering
                ? Icons.search_off_rounded
                : Icons.shopping_bag_outlined,
            size: 34,
            color: const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 10),
          Text(
            isFiltering
                ? 'Tidak ada produk yang cocok'
                : 'Marketplace belum memiliki barang',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isFiltering
                ? 'Coba kata kunci atau filter vendor lain.'
                : 'Barang dari supplier akan ditampilkan di sini.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasRemote = widget.remoteItems.isNotEmpty;
    final query = _searchController.text.trim().toLowerCase();

    return ValueListenableBuilder<MasterDataListSnapshot<InventoryItemRecord>>(
      valueListenable: _inventoryStore.snapshotNotifier,
      builder: (context, snapshot, _) {
        final List<CartEntry> allEntries = [];
        if (hasRemote) {
          for (final item in widget.remoteItems) {
            allEntries.add(_entryFromRemote(item));
          }
        } else {
          for (final item in snapshot.records) {
            allEntries.add(_entryFromLocal(item));
          }
        }

        final Set<String> groupSet = {};
        for (final entry in allEntries) {
          if (entry.group != null && entry.group!.trim().isNotEmpty) {
            groupSet.add(entry.group!.trim());
          }
        }
        final List<String> categories = ['Semua', ...groupSet.toList()..sort()];

        final List<CartEntry> filteredEntries = allEntries
            .where((entry) {
              final matchesCategory = _selectedCategory == 'Semua' ||
                  (entry.group != null &&
                      entry.group!.trim() == _selectedCategory);
              if (!matchesCategory) return false;

              if (query.isEmpty) return true;
              return entry.name.toLowerCase().contains(query) ||
                  entry.sku.toLowerCase().contains(query) ||
                  (entry.group?.toLowerCase().contains(query) ?? false);
            })
            .toList(growable: false);

        return ListenableBuilder(
          listenable: widget.cartController,
          builder: (context, _) {
            final cartQty = widget.cartController.totalQty;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: MobileSearchField(
                    controller: _searchController,
                    hintText: hasRemote
                        ? 'Cari item marketplace atau SKU'
                        : 'Cari stok inventory atau SKU',
                    onChanged: (_) => setState(() {}),
                    onClear: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
                ),
                if (!hasRemote)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 14,
                          color: Color(0xFFB45309),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Marketplace offline. Menggunakan katalog lokal.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (categories.length > 1)
                  Container(
                    height: 32,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, idx) {
                        final cat = categories[idx];
                        final isSelected = cat == _selectedCategory;
                        final count = cat == 'Semua'
                            ? allEntries.length
                            : allEntries
                                .where((e) => e.group?.trim() == cat)
                                .length;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.20)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: filteredEntries.isEmpty
                      ? _buildEmptySearchState()
                      : RefreshIndicator(
                          onRefresh: widget.onRefresh,
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              2,
                              16,
                              cartQty > 0 ? 84 : 24,
                            ),
                            itemCount: filteredEntries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final entry = filteredEntries[index];
                              return MarketplaceItemRow(
                                entry: entry,
                                qty: widget.cartController.qtyFor(entry.key),
                                primaryColor: primaryColor,
                                onAdd: () =>
                                    widget.cartController.addToCart(entry),
                                onIncrement: () =>
                                    widget.cartController.increment(entry.key),
                                onDecrement: () =>
                                    widget.cartController.decrement(entry.key),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
