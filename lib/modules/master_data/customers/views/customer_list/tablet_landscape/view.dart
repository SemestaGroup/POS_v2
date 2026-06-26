import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/master_data_page_widgets.dart';
import '../../../../stores/master_data_read_stores.dart';

class CustomerListView extends StatefulWidget {
  const CustomerListView({super.key});

  @override
  State<CustomerListView> createState() => _CustomerListViewState();
}

class _CustomerListViewState extends State<CustomerListView> {
  final CustomerListStore _store = CustomerListStore.instance;
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
    final strings = _CustomerStrings.of(context);
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<MasterDataListSnapshot<CustomerListRecord>>(
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
                      icon: Icons.people_outline_rounded,
                      title: strings.emptyState,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: records.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final customer = records[index];
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
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    customer.displayName.isNotEmpty
                                        ? customer.displayName[0].toUpperCase()
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
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.displayName,
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
                                      (customer.city ?? '').trim().isEmpty
                                          ? '—'
                                          : customer.city!,
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
                                  (customer.phoneNumber ?? '').trim().isEmpty
                                      ? '—'
                                      : customer.phoneNumber!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  (customer.email ?? '').trim().isEmpty
                                      ? '—'
                                      : customer.email!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF374151),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              MasterDataStatusBadge(
                                label:
                                    '${currencyFmt.format(customer.pointsBalance)} ${strings.pointsLabel}',
                                foreground: const Color(0xFF7C3AED),
                                background: const Color(0xFFEDE9FE),
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

class _CustomerStrings {
  const _CustomerStrings({required this.id});

  final bool id;

  static _CustomerStrings of(BuildContext context) {
    return _CustomerStrings(
      id: Localizations.localeOf(context).languageCode == 'id',
    );
  }

  String get searchHint => id
      ? 'Cari nama pelanggan, nomor telepon, email...'
      : 'Search customer name, phone, email...';
  String get countLabel => id ? 'pelanggan' : 'customers';
  String get pointsLabel => id ? 'poin' : 'pts';
  String get emptyState =>
      id ? 'Tidak ada data pelanggan.' : 'No customer data available.';
}
