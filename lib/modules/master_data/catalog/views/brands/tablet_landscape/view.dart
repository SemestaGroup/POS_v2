import 'package:flutter/material.dart';

import '../../../../shared/widgets/master_data_page_widgets.dart';
import '../../../../stores/master_data_read_stores.dart';

class BrandsView extends StatefulWidget {
  const BrandsView({super.key});

  @override
  State<BrandsView> createState() => _BrandsViewState();
}

class _BrandsViewState extends State<BrandsView> {
  final BrandListStore _store = BrandListStore.instance;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _BrandsStrings.of(context);

    return ValueListenableBuilder<MasterDataListSnapshot<BrandListRecord>>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        final records = snapshot.records;

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
              countText: '${records.length} ${strings.countLabel}',
              onRefresh: _store.refresh,
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: records.isEmpty
                  ? MasterDataEmptyState(
                      icon: Icons.branding_watermark_outlined,
                      title: strings.emptyState,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.45,
                        ),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final brand = records[index];
                          final hue = (brand.name.hashCode % 12) * 30.0 % 360;
                          final color =
                              HSLColor.fromAHSL(1, hue, 0.58, 0.46).toColor();
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
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
                                        Icons.branding_watermark_rounded,
                                        size: 16,
                                        color: color,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (brand.displayFlag)
                                      MasterDataStatusBadge(
                                        label: strings.visibleLabel,
                                        foreground: const Color(0xFF047857),
                                        background: const Color(0xFFD1FAE5),
                                      ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  brand.name,
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
                                  (brand.code ?? '').trim().isEmpty
                                      ? '—'
                                      : brand.code!,
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
      },
    );
  }
}

class _BrandsStrings {
  const _BrandsStrings({required this.id});

  final bool id;

  static _BrandsStrings of(BuildContext context) {
    return _BrandsStrings(
      id: Localizations.localeOf(context).languageCode == 'id',
    );
  }

  String get searchHint => id ? 'Cari brand...' : 'Search brand...';
  String get countLabel => id ? 'brand' : 'brands';
  String get visibleLabel => id ? 'Tampil' : 'Visible';
  String get emptyState => id ? 'Tidak ada brand.' : 'No brands available.';
}
