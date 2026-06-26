import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/master_data_page_widgets.dart';
import '../../../../stores/master_data_read_stores.dart';

class PromosView extends StatefulWidget {
  const PromosView({super.key});

  @override
  State<PromosView> createState() => _PromosViewState();
}

class _PromosViewState extends State<PromosView> {
  final PromoListStore _store = PromoListStore.instance;
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
    final strings = _PromosStrings.of(context);
    final dateFmt = DateFormat('dd MMM yyyy', 'id_ID');

    return ValueListenableBuilder<MasterDataListSnapshot<PromoListRecord>>(
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
                      icon: Icons.local_offer_outlined,
                      title: strings.emptyState,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final promo = records[index];
                        final now = DateTime.now();
                        final isActive =
                            (promo.status ?? '').toLowerCase() == 'active';
                        final isOngoing = isActive &&
                            (promo.startAt == null ||
                                !promo.startAt!.isAfter(now)) &&
                            (promo.endAt == null || promo.endAt!.isAfter(now));

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      promo.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if ((promo.description ?? '').trim().isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        promo.description!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF6B7280),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  promo.promoType ?? strings.otherType,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  promo.startAt != null
                                      ? dateFmt.format(promo.startAt!)
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  promo.endAt != null
                                      ? dateFmt.format(promo.endAt!)
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              MasterDataStatusBadge(
                                label: isOngoing
                                    ? strings.ongoingStatus
                                    : (isActive
                                        ? strings.activeStatus
                                        : strings.inactiveStatus),
                                foreground: isOngoing
                                    ? const Color(0xFF047857)
                                    : (isActive
                                        ? const Color(0xFF1D4ED8)
                                        : const Color(0xFF6B7280)),
                                background: isOngoing
                                    ? const Color(0xFFD1FAE5)
                                    : (isActive
                                        ? const Color(0xFFDBEAFE)
                                        : const Color(0xFFF3F4F6)),
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
}

class _PromosStrings {
  const _PromosStrings({required this.id});

  final bool id;

  static _PromosStrings of(BuildContext context) {
    return _PromosStrings(
      id: Localizations.localeOf(context).languageCode == 'id',
    );
  }

  String get searchHint => id ? 'Cari promo atau diskon...' : 'Search promo or discount...';
  String get countLabel => id ? 'promo' : 'promos';
  String get emptyState => id ? 'Tidak ada data promosi.' : 'No promotion data available.';
  String get otherType => id ? 'Lainnya' : 'Other';
  String get ongoingStatus => id ? 'Berjalan' : 'Ongoing';
  String get activeStatus => id ? 'Aktif' : 'Active';
  String get inactiveStatus => id ? 'Nonaktif' : 'Inactive';
}
