import 'package:flutter/material.dart';

import '../../../shared/widgets/master_data_page_widgets.dart';
import '../../../shared/widgets/master_data_screen_coordinator.dart';
import '../../../stores/master_data_read_stores.dart';

class CategoriesContent extends StatelessWidget {
  const CategoriesContent({
    super.key,
    required this.presentation,
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  final MasterDataScreenPresentation<CategoryListRecord> presentation;
  final int crossAxisCount;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    final strings = _CategoriesStrings.of(context);
    final records = presentation.snapshot.records;
    if (presentation.snapshot.isLoading && records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (presentation.snapshot.errorMessage != null && records.isEmpty) {
      return MasterDataErrorView(message: presentation.snapshot.errorMessage!);
    }

    return Column(
      children: [
        MasterDataSearchHeader(
          searchController: presentation.searchController,
          searchHint: strings.searchHint,
          onSearchChanged: presentation.onSearchChanged,
          countText: '${records.length} ${strings.countLabel}',
          onRefresh: presentation.onRefresh,
        ),
        Divider(height: 1, color: Colors.grey.shade100),
        Expanded(
          child: records.isEmpty
              ? MasterDataEmptyState(
                  icon: Icons.category_outlined,
                  title: strings.emptyState,
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final category = records[index];
                      final hue = (category.name.hashCode % 12) * 30.0 % 360;
                      final color = HSLColor.fromAHSL(
                        1,
                        hue,
                        0.58,
                        0.46,
                      ).toColor();
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.category_rounded,
                                    size: 16,
                                    color: color,
                                  ),
                                ),
                                const Spacer(),
                                MasterDataStatusBadge(
                                  label:
                                      '${category.productCount} ${strings.productsLabel}',
                                  foreground: const Color(0xFF4338CA),
                                  background: const Color(0xFFEDE9FE),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              category.name,
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
                              (category.brandName ?? '').trim().isEmpty
                                  ? (category.code ?? '—')
                                  : category.brandName!,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _CategoriesStrings {
  const _CategoriesStrings({required this.id});

  final bool id;

  static _CategoriesStrings of(BuildContext context) => _CategoriesStrings(
    id: Localizations.localeOf(context).languageCode == 'id',
  );

  String get searchHint =>
      id ? 'Cari kategori atau brand...' : 'Search category or brand...';
  String get countLabel => id ? 'kategori' : 'categories';
  String get productsLabel => id ? 'produk' : 'products';
  String get emptyState =>
      id ? 'Tidak ada kategori.' : 'No categories available.';
}
