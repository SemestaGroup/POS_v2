import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../sales/orders/shared/orders_history_sync_service.dart';
import '../../stores/report_read_stores.dart';
import '../shared/report_view_widgets.dart';

enum _CustomerSort { totalSpent, visits }

class TopCustomersReportView extends StatefulWidget {
  const TopCustomersReportView({super.key});

  @override
  State<TopCustomersReportView> createState() => _TopCustomersReportViewState();
}

class _TopCustomersReportViewState extends State<TopCustomersReportView> {
  final TopCustomersReportStore _store = TopCustomersReportStore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _CustomerSort _sort = _CustomerSort.totalSpent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncAndRefresh());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncAndRefresh({String? period}) async {
    await OrdersHistorySyncService.instance.ensureSynced();
    if (mounted) {
      await _store.refresh(
        period: period ?? _store.snapshotNotifier.value.period,
      );
    }
  }

  List<TopCustomerRecord> _sorted(List<TopCustomerRecord> customers) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = customers.where((c) {
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          (c.phone ?? '').contains(query);
    }).toList();
    filtered.sort((a, b) {
      final primary = _sort == _CustomerSort.totalSpent
          ? b.totalSpent.compareTo(a.totalSpent)
          : b.visitCount.compareTo(a.visitCount);
      if (primary != 0) return primary;
      return b.totalSpent.compareTo(a.totalSpent);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final dateFmt = DateFormat('dd MMM yyyy', 'id_ID');

    return ValueListenableBuilder<TopCustomersSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.customers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.customers.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        final members = snapshot.customers.where((c) => !c.isWalkIn).toList();
        final walkIn = snapshot.customers.where((c) => c.isWalkIn).toList();
        final memberSpent = members.fold<int>(0, (s, c) => s + c.totalSpent);
        final walkInSpent = walkIn.fold<int>(0, (s, c) => s + c.totalSpent);
        final rows = _sorted(snapshot.customers);

        // Positions are computed up front: the list builds rows lazily and out
        // of order, so a running counter inside itemBuilder would drift.
        var rank = 0;
        final positions = <int?>[
          for (final c in rows) c.isWalkIn ? null : ++rank,
        ];
        return Column(
          children: [
            ReportPeriodBar(
              period: snapshot.period,
              onPeriodChanged: (value) => _syncAndRefresh(period: value),
              onRefresh: () => _syncAndRefresh(period: snapshot.period),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Cari nama atau nomor telepon...',
                          hintStyle: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ReportPeriodChip(
                    label: 'Total Belanja',
                    isActive: _sort == _CustomerSort.totalSpent,
                    onTap: () =>
                        setState(() => _sort = _CustomerSort.totalSpent),
                  ),
                  const SizedBox(width: 6),
                  ReportPeriodChip(
                    label: 'Kunjungan',
                    isActive: _sort == _CustomerSort.visits,
                    onTap: () => setState(() => _sort = _CustomerSort.visits),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            ReportSummaryStrip(
              items: [
                ReportStripItem(
                  'Pelanggan Terdaftar',
                  '${members.length}',
                  Theme.of(context).colorScheme.primary,
                ),
                ReportStripItem(
                  'Belanja Terdaftar',
                  'Rp ${currencyFmt.format(memberSpent)}',
                  const Color(0xFF10B981),
                ),
                ReportStripItem(
                  'Belanja Walk-in',
                  'Rp ${currencyFmt.format(walkInSpent)}',
                  const Color(0xFF8B5CF6),
                ),
              ],
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            const ReportTableHeader(
              columns: [
                ReportColumn('#', 1),
                ReportColumn('Pelanggan', 5),
                ReportColumn('Kunjungan', 2),
                ReportColumn('Rata-rata', 3, alignEnd: true),
                ReportColumn('Total Belanja', 3, alignEnd: true),
                ReportColumn('Terakhir', 3, alignEnd: true),
              ],
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada transaksi pada periode ini.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final customer = rows[index];
                        final position = positions[index];
                        return Container(
                          color: index.isOdd
                              ? Colors.transparent
                              : const Color(0xFFFAFAFB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: _RankBadge(position: position),
                              ),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        fontStyle: customer.isWalkIn
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                        color: const Color(0xFF374151),
                                      ),
                                    ),
                                    if (customer.phone != null)
                                      Text(
                                        customer.phone!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              ReportCell('${customer.visitCount}x', 2),
                              ReportCell(
                                'Rp ${currencyFmt.format(customer.averageSpent)}',
                                3,
                                alignEnd: true,
                              ),
                              ReportCell(
                                'Rp ${currencyFmt.format(customer.totalSpent)}',
                                3,
                                bold: true,
                                alignEnd: true,
                              ),
                              ReportCell(
                                customer.lastOrderAt == null
                                    ? '-'
                                    : dateFmt.format(customer.lastOrderAt!),
                                3,
                                alignEnd: true,
                                muted: true,
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

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.position});

  final int? position;

  static const _medals = <Color>[
    Color(0xFFF59E0B),
    Color(0xFF9CA3AF),
    Color(0xFFB45309),
  ];

  @override
  Widget build(BuildContext context) {
    final p = position;
    if (p == null) {
      return Text('—', style: TextStyle(color: Colors.grey.shade400));
    }
    if (p > _medals.length) {
      return Text(
        '$p',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
      );
    }
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _medals[p - 1].withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$p',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _medals[p - 1],
        ),
      ),
    );
  }
}
