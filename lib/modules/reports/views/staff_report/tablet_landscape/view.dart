import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../stores/report_read_stores.dart';

class StaffReportView extends StatefulWidget {
  const StaffReportView({super.key});

  @override
  State<StaffReportView> createState() => _StaffReportViewState();
}

class _StaffReportViewState extends State<StaffReportView> {
  final StaffReportStore _store = StaffReportStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh(period: _store.snapshotNotifier.value.period);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<StaffReportSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.stats.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.stats.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  _chip('Hari Ini', 'today', primaryColor, snapshot),
                  const SizedBox(width: 6),
                  _chip('7 Hari', 'week', primaryColor, snapshot),
                  const SizedBox(width: 6),
                  _chip('Bulan Ini', 'month', primaryColor, snapshot),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _store.refresh(period: snapshot.period),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    color: primaryColor,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF9FAFB),
              child: const Row(
                children: [
                  _StaffHeader('Staf', 4),
                  _StaffHeader('Shift', 1),
                  _StaffHeader('Transaksi', 2),
                  _StaffHeader('Diskon', 2),
                  _StaffHeader('Total Penjualan', 3),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: snapshot.stats.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada data staf pada periode ini.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    )
                  : ListView.separated(
                      itemCount: snapshot.stats.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final stat = snapshot.stats[index];
                        final isTop = index == 0;
                        return Container(
                          color: isTop
                              ? primaryColor.withValues(alpha: 0.03)
                              : index.isOdd
                                  ? Colors.transparent
                                  : const Color(0xFFFAFAFB),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: primaryColor.withValues(alpha: 0.12),
                                      child: Text(
                                        stat.staffName.isNotEmpty ? stat.staffName[0].toUpperCase() : '?',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryColor),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              stat.staffName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isTop ? FontWeight.w800 : FontWeight.w600,
                                                color: const Color(0xFF111827),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isTop)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Icon(
                                                Icons.emoji_events_rounded,
                                                color: Color(0xFFF59E0B),
                                                size: 14,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _StaffCell('${stat.shiftsCount}', 1),
                              _StaffCell('${stat.totalOrders} tx', 2),
                              _StaffCell(
                                stat.totalDiscount > 0
                                    ? 'Rp ${currencyFmt.format(stat.totalDiscount)}'
                                    : '—',
                                2,
                                muted: stat.totalDiscount == 0,
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Rp ${currencyFmt.format(stat.totalRevenue)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isTop ? FontWeight.w800 : FontWeight.w700,
                                    color: isTop ? primaryColor : const Color(0xFF111827),
                                  ),
                                ),
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

  Widget _chip(String label, String value, Color color, StaffReportSnapshot snapshot) {
    final active = snapshot.period == value;
    return InkWell(
      onTap: () => _store.refresh(period: value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color : Colors.grey.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _StaffHeader extends StatelessWidget {
  const _StaffHeader(this.label, this.flex);

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
      ),
    );
  }
}

class _StaffCell extends StatelessWidget {
  const _StaffCell(this.value, this.flex, {this.muted = false});

  final String value;
  final int flex;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          color: muted ? Colors.grey.shade400 : const Color(0xFF374151),
        ),
      ),
    );
  }
}
