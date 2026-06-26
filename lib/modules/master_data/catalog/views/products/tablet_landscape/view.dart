import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/master_data_page_widgets.dart';
import '../../../../stores/master_data_read_stores.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  final ProductListStore _store = ProductListStore.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
      CategoryListStore.instance.refresh();
      BrandListStore.instance.refresh();
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
    final strings = _ProductsStrings.of(context);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<MasterDataListSnapshot<ProductListRecord>>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        final records = snapshot.records;
        final activeCount = records
            .where((p) => p.status == 'active' && p.isAvailable)
            .length;

        if (snapshot.isLoading && snapshot.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.records.isEmpty) {
          return MasterDataErrorView(message: snapshot.errorMessage!);
        }

        return Column(
          children: [
            MasterDataSearchHeader(
              searchController: _searchController,
              searchHint: strings.searchHint,
              onSearchChanged: _store.setSearchQuery,
              countText:
                  '${records.length} ${strings.countLabel} • $activeCount ${strings.activeLabel}',
              onRefresh: _store.refresh,
              filterBar: _buildFilterBar(),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: records.isEmpty
                  ? MasterDataEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: strings.emptyState,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = records[index];
                        final isActive =
                            product.status == 'active' && product.isAvailable;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    product.name.isNotEmpty
                                        ? product.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      product.categoryName,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  product.sku.isEmpty ? '—' : product.sku,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: product.sku.isEmpty
                                        ? Colors.grey.shade400
                                        : const Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Rp ${currencyFmt.format(product.priceAmount)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  product.stock.toString(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              MasterDataStatusBadge(
                                label: isActive
                                    ? strings.activeStatus
                                    : strings.inactiveStatus,
                                foreground: isActive
                                    ? const Color(0xFF047857)
                                    : const Color(0xFF6B7280),
                                background: isActive
                                    ? const Color(0xFFD1FAE5)
                                    : const Color(0xFFF3F4F6),
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
      valueListenable: CategoryListStore.instance.snapshotNotifier,
      builder: (context, catSnapshot, _) {
        return ValueListenableBuilder<MasterDataListSnapshot<BrandListRecord>>(
          valueListenable: BrandListStore.instance.snapshotNotifier,
          builder: (context, brandSnapshot, _) {
            final categories = catSnapshot.records;
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
                    setState((){});
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
                    setState((){});
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
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          items: items,
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey.shade600),
          style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
          isDense: true,
        ),
      ),
    );
  }
}

class _ProductsStrings {
  const _ProductsStrings({required this.id});

  final bool id;

  static _ProductsStrings of(BuildContext context) {
    return _ProductsStrings(
      id: Localizations.localeOf(context).languageCode == 'id',
    );
  }

  String get searchHint => id
      ? 'Cari nama produk, SKU, atau kategori...'
      : 'Search product name, SKU, or category...';
  String get countLabel => id ? 'produk' : 'products';
  String get activeLabel => id ? 'aktif' : 'active';
  String get emptyState =>
      id ? 'Tidak ada produk ditemukan.' : 'No products were found.';
  String get activeStatus => id ? 'Aktif' : 'Active';
  String get inactiveStatus => id ? 'Nonaktif' : 'Inactive';
}
