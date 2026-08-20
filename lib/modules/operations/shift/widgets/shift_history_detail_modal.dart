import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/shift_detail_data.dart';
import '../models/shift_history_item.dart';
import '../services/shift_history_service.dart';

class ShiftHistoryDetailModal extends StatefulWidget {
  final ShiftHistoryItem shift;
  final VoidCallback onPrint;
  final bool isPrinting;

  const ShiftHistoryDetailModal({
    super.key,
    required this.shift,
    required this.onPrint,
    this.isPrinting = false,
  });

  static void show(
    BuildContext context, {
    required ShiftHistoryItem shift,
    required VoidCallback onPrint,
    bool isPrinting = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShiftHistoryDetailModal(
        shift: shift,
        onPrint: onPrint,
        isPrinting: isPrinting,
      ),
    );
  }

  @override
  State<ShiftHistoryDetailModal> createState() =>
      _ShiftHistoryDetailModalState();
}

class _ShiftHistoryDetailModalState extends State<ShiftHistoryDetailModal> {
  ShiftDetailData? _detailData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final data = await ShiftHistoryService.instance.fetchShiftDetailData(
        shiftId: widget.shift.id,
        openedAt: widget.shift.openedAt,
        closedAt: widget.shift.closedAt,
      );

      if (mounted) {
        setState(() {
          _detailData = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final primaryColor = Theme.of(context).colorScheme.primary;
    final shift = widget.shift;

    final staffInitials = shift.staffName.trim().isNotEmpty
        ? shift.staffName
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'KS';

    // Reuse the card's summary values for reconciliation so the displayed
    // components and its variance always come from the same calculation.
    final totalCashIn = shift.totalCashIn;
    final totalCashOut = shift.totalCashOut;
    final totalRevenue = _detailData?.totalRevenue ?? shift.totalShiftSales;
    final totalTransactions = _detailData?.totalTransactions ?? 0;
    final grossSales = _detailData?.grossSales ?? 0;
    final totalDiscount = _detailData?.totalDiscount ?? 0;
    final totalTax = _detailData?.totalTax ?? 0;

    final openingBalance = shift.openingBalance;
    final sisaPettyCash = openingBalance + totalCashIn - totalCashOut;
    final cashSales = shift.cashSales;
    // This is the exact source used by the card's variance, so both surfaces
    // report one reconciliation result for the selected shift.
    final expectedCashFromTransactions = shift.expectedCash;
    final hasStoredCashMismatch =
        shift.isClosed &&
        shift.storedExpectedCash > 0 &&
        shift.storedExpectedCash != expectedCashFromTransactions;
    final transactionCashVariance = shift.variance;

    final netSales = grossSales - totalDiscount;

    return DefaultTabController(
      length: 3,
      child: DraggableScrollableSheet(
        initialChildSize: 0.90,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        expand: true,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              // Header Banner Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: primaryColor.withValues(alpha: 0.12),
                      child: Text(
                        staffInitials,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  shift.staffName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (shift.registerId != null &&
                                  shift.registerId!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Reg ${shift.registerId}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shift.isClosed
                                ? 'Tutup: ${shift.closedAt != null ? dateFmt.format(shift.closedAt!) : "-"}'
                                : 'Buka: ${dateFmt.format(shift.openedAt)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              // TabBar Navigation
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: TabBar(
                  labelColor: primaryColor,
                  unselectedLabelColor: const Color(0xFF64748B),
                  indicatorColor: primaryColor,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Rekonsiliasi & Audit'),
                    Tab(text: 'Metode Pembayaran'),
                    Tab(text: 'Produk Terjual'),
                  ],
                ),
              ),

              // Tab Views Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [
                          // Tab 1: Rekonsiliasi & Audit
                          SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailKpiCard(
                                        label: 'Total Pendapatan',
                                        value:
                                            'Rp ${currencyFmt.format(totalRevenue)}',
                                        icon: Icons.payments_outlined,
                                        color: primaryColor,
                                        bg: const Color(0xFFF0F9FF),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildDetailKpiCard(
                                        label: 'Total Transaksi',
                                        value: '$totalTransactions Transaksi',
                                        icon: Icons.shopping_bag_outlined,
                                        color: const Color(0xFF16A34A),
                                        bg: const Color(0xFFF0FDF4),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Summary Penjualan & Pajak
                                const Text(
                                  'RINGKASAN PENJUALAN & PAJAK',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _recapAmountRow(
                                        'Penjualan kotor (gross)',
                                        'Rp ${currencyFmt.format(grossSales)}',
                                      ),
                                      const SizedBox(height: 8),
                                      _recapAmountRow(
                                        '(-) Diskon & potongan',
                                        '-Rp ${currencyFmt.format(totalDiscount)}',
                                        valueColor: const Color(0xFFDC2626),
                                      ),
                                      const Divider(height: 18),
                                      _recapAmountRow(
                                        'Penjualan bersih (net sales)',
                                        'Rp ${currencyFmt.format(netSales > 0 ? netSales : totalRevenue)}',
                                        emphasis: true,
                                      ),
                                      if (totalTax > 0) ...[
                                        const SizedBox(height: 8),
                                        _recapAmountRow(
                                          '(+) Total pajak (tax)',
                                          '+Rp ${currencyFmt.format(totalTax)}',
                                          valueColor: const Color(0xFF0284C7),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Rekonsiliasi & Audit Kas Card
                                const Text(
                                  'REKONSILIASI & AUDIT KAS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _recapAmountRow(
                                        'Saldo Awal Kas Laci',
                                        'Rp ${currencyFmt.format(openingBalance)}',
                                      ),
                                      const SizedBox(height: 8),
                                      _recapAmountRow(
                                        '(+) Modal masuk (cash in)',
                                        '+Rp ${currencyFmt.format(totalCashIn)}',
                                        valueColor: const Color(0xFF16A34A),
                                      ),
                                      const SizedBox(height: 8),
                                      _recapAmountRow(
                                        '(-) Biaya keluar (cash out)',
                                        '-Rp ${currencyFmt.format(totalCashOut)}',
                                        valueColor: const Color(0xFFDC2626),
                                      ),
                                      const Divider(height: 18),
                                      _recapAmountRow(
                                        'Sisa Modal Kasir (Petty Cash)',
                                        'Rp ${currencyFmt.format(sisaPettyCash)}',
                                        emphasis: true,
                                      ),
                                      const SizedBox(height: 8),
                                      _recapAmountRow(
                                        '(+) Penjualan Tunai Kasir',
                                        '+Rp ${currencyFmt.format(cashSales)}',
                                        valueColor: const Color(0xFF2563EB),
                                      ),
                                      const Divider(height: 18),
                                      _recapAmountRow(
                                        'Ekspektasi Kas dari Transaksi',
                                        'Rp ${currencyFmt.format(expectedCashFromTransactions)}',
                                        emphasis: true,
                                        valueColor: primaryColor,
                                      ),
                                      if (hasStoredCashMismatch) ...[
                                        const SizedBox(height: 8),
                                        _recapAmountRow(
                                          'Ekspektasi Tersimpan Saat Tutup',
                                          'Rp ${currencyFmt.format(shift.storedExpectedCash)}',
                                          valueColor: const Color(0xFFB45309),
                                        ),
                                      ],
                                      if (shift.isClosed) ...[
                                        const SizedBox(height: 8),
                                        _recapAmountRow(
                                          'Kas Fisik Dihitung Kasir',
                                          'Rp ${currencyFmt.format(shift.actualCash)}',
                                          emphasis: true,
                                          valueColor: const Color(0xFF0F172A),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                if (shift.isClosed &&
                                    transactionCashVariance != 0) ...[
                                  const SizedBox(height: 16),
                                  _buildVarianceAuditBanner(
                                    transactionCashVariance,
                                    currencyFmt,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Tab 2: Metode Pembayaran
                          SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'RINCIAN METODE PEMBAYARAN',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _detailData?.payments.isEmpty ?? true
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(32),
                                          child: Text(
                                            'Belum ada transaksi pembayaran',
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Column(
                                        children: _detailData!.payments.map((
                                          pm,
                                        ) {
                                          final double pct = totalRevenue > 0
                                              ? (pm.amount / totalRevenue)
                                              : 0.0;
                                          final pctString = (pct * 100)
                                              .toStringAsFixed(0);

                                          final isCashMode =
                                              pm.name.toLowerCase().contains(
                                                'cash',
                                              ) ||
                                              pm.name.toLowerCase().contains(
                                                'tunai',
                                              );
                                          IconData modeIcon =
                                              Icons.payments_outlined;
                                          if (pm.name.toLowerCase().contains(
                                                'qris',
                                              ) ||
                                              pm.name.toLowerCase().contains(
                                                'qr',
                                              )) {
                                            modeIcon = Icons.qr_code_2_rounded;
                                          } else if (pm.name
                                                  .toLowerCase()
                                                  .contains('edc') ||
                                              pm.name.toLowerCase().contains(
                                                'card',
                                              ) ||
                                              pm.name.toLowerCase().contains(
                                                'debit',
                                              )) {
                                            modeIcon =
                                                Icons.credit_card_outlined;
                                          } else if (isCashMode) {
                                            modeIcon = Icons.payments_outlined;
                                          }

                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: primaryColor
                                                            .withValues(
                                                              alpha: 0.10,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        modeIcon,
                                                        size: 18,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            pm.name,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize:
                                                                      13.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Color(
                                                                    0xFF0F172A,
                                                                  ),
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            '${pm.qty} Transaksi',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 11,
                                                                  color: Color(
                                                                    0xFF64748B,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Text(
                                                          'Rp ${currencyFmt.format(pm.amount)}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color: Color(
                                                                  0xFF0F172A,
                                                                ),
                                                              ),
                                                        ),
                                                        Text(
                                                          '$pctString% dari total',
                                                          style: TextStyle(
                                                            fontSize: 10.5,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: primaryColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: pct,
                                                    minHeight: 5,
                                                    backgroundColor:
                                                        const Color(0xFFF1F5F9),
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(primaryColor),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ],
                            ),
                          ),

                          // Tab 3: Produk Terjual
                          SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            child: _detailData?.topItems.isEmpty ?? true
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Text(
                                        'Belum ada produk terjual pada shift ini',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      children: _detailData!.topItems.map((
                                        item,
                                      ) {
                                        final qtyStr = item.qty % 1 == 0
                                            ? item.qty.toInt().toString()
                                            : item.qty.toStringAsFixed(1);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.shopping_bag_outlined,
                                                size: 16,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item.name,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF1F5F9,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '$qtyStr pcs',
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ),

              // Bottom Action Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: widget.isPrinting
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onPrint();
                          },
                    icon: widget.isPrinting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print_rounded, size: 18),
                    label: const Text(
                      'Cetak Laporan Shift (Struk)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
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

  Widget _recapAmountRow(
    String label,
    String value, {
    bool emphasis = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
            color: emphasis ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasis ? 13.5 : 12.5,
            fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
            color:
                valueColor ??
                (emphasis ? const Color(0xFF0F172A) : const Color(0xFF334155)),
          ),
        ),
      ],
    );
  }

  Widget _buildVarianceAuditBanner(int diff, NumberFormat currencyFmt) {
    final isPas = diff == 0;
    final isMinus = diff < 0;
    final color = isPas
        ? const Color(0xFF15803D)
        : (isMinus ? const Color(0xFFB91C1C) : const Color(0xFFB45309));
    final bg = isPas
        ? const Color(0xFFF0FDF4)
        : (isMinus ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB));

    final title = isPas
        ? 'Kas Sesuai (Pas)'
        : (isMinus
              ? 'Kas Minus / Selisih Kurang'
              : 'Kas Surplus / Selisih Lebih');
    final desc = isPas
        ? 'Jumlah kas fisik sama persis dengan ekspektasi sistem.'
        : (isMinus
              ? 'Jumlah kas fisik kurang Rp ${currencyFmt.format(diff.abs())} dari ekspektasi sistem.'
              : 'Jumlah kas fisik lebih Rp ${currencyFmt.format(diff)} dari ekspektasi sistem.');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(
            isPas
                ? Icons.check_circle_outline_rounded
                : (isMinus
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded),
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.90),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
