import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../stores/report_read_stores.dart';

class SalesReportView extends StatefulWidget {
  const SalesReportView({super.key});

  @override
  State<SalesReportView> createState() => _SalesReportViewState();
}

class _SalesReportViewState extends State<SalesReportView> {
  final SalesReportStore _store = SalesReportStore.instance;

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
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<SalesReportSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.rows.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.rows.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  _buildPeriodChip('Hari Ini', 'today', primaryColor, snapshot),
                  const SizedBox(width: 6),
                  _buildPeriodChip('7 Hari', 'week', primaryColor, snapshot),
                  const SizedBox(width: 6),
                  _buildPeriodChip('Bulan Ini', 'month', primaryColor, snapshot),
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
              color: primaryColor.withValues(alpha: 0.04),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _buildStrip(
                    'Total Penjualan',
                    'Rp ${currencyFmt.format(snapshot.totalRevenue)}',
                    primaryColor,
                  ),
                  _buildStripDivider(),
                  _buildStrip(
                    'Transaksi',
                    '${snapshot.totalTransactions}',
                    const Color(0xFF8B5CF6),
                  ),
                  _buildStripDivider(),
                  _buildStrip(
                    'Total Diskon',
                    'Rp ${currencyFmt.format(snapshot.totalDiscount)}',
                    const Color(0xFFF59E0B),
                  ),
                  _buildStripDivider(),
                  _buildStrip(
                    'Rata-rata',
                    snapshot.totalTransactions > 0
                        ? 'Rp ${currencyFmt.format(snapshot.totalRevenue ~/ snapshot.totalTransactions)}'
                        : 'Rp 0',
                    const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF9FAFB),
              child: Row(
                children: const [
                  _HeaderCell('ID Order', 2),
                  _HeaderCell('Label', 2),
                  _HeaderCell('Waktu', 2),
                  _HeaderCell('Metode Bayar', 2),
                  _HeaderCell('Diskon', 2),
                  _HeaderCell('Total', 2),
                  _HeaderCell('Status', 1),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: snapshot.rows.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada transaksi pada periode ini.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    )
                  : ListView.separated(
                      itemCount: snapshot.rows.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final row = snapshot.rows[index];
                        final shortId = row.idPos.length > 12
                            ? '...${row.idPos.substring(row.idPos.length - 10)}'
                            : row.idPos;
                        return Container(
                          color: index.isOdd
                              ? Colors.transparent
                              : const Color(0xFFFAFAFB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              _DataCell(shortId, 2, monospace: true),
                              _DataCell(row.label.isEmpty ? 'Walk-in' : row.label, 2),
                              _DataCell(dateFmt.format(row.createdAt), 2),
                              _DataCell(row.paymentMethods, 2),
                              _DataCell(
                                row.discountAmount > 0
                                    ? 'Rp ${currencyFmt.format(row.discountAmount)}'
                                    : '—',
                                2,
                                muted: row.discountAmount == 0,
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Rp ${currencyFmt.format(row.totalAmount)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Lunas',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
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

  Widget _buildPeriodChip(
    String label,
    String value,
    Color primaryColor,
    SalesReportSnapshot snapshot,
  ) {
    final isActive = snapshot.period == value;
    return InkWell(
      onTap: () => _store.refresh(period: value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? primaryColor : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildStrip(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStripDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: const Color(0xFFE5E7EB),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, this.flex);

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell(this.value, this.flex, {this.muted = false, this.monospace = false});

  final String value;
  final int flex;
  final bool muted;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          color: muted ? Colors.grey.shade400 : const Color(0xFF374151),
          fontFamily: monospace ? 'monospace' : null,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
