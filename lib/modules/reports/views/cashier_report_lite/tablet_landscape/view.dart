import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../stores/report_read_stores.dart';

class CashierReportLiteView extends StatefulWidget {
  const CashierReportLiteView({super.key});

  @override
  State<CashierReportLiteView> createState() => _CashierReportLiteViewState();
}

class _CashierReportLiteViewState extends State<CashierReportLiteView> {
  final CashierReportLiteStore _store = CashierReportLiteStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _store.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.sizeOf(context).shortestSide < 600;
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return ValueListenableBuilder<CashierReportLiteSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.paymentBreakdown.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null &&
            snapshot.paymentBreakdown.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          );
        }

        final totalRevenue = snapshot.totalCash + snapshot.totalNonCash;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 20,
            12,
            isMobile ? 16 : 20,
            28,
          ),
          child: isMobile
              ? _buildMobileReport(
                  context: context,
                  snapshot: snapshot,
                  totalRevenue: totalRevenue,
                  currencyFmt: currencyFmt,
                  dateFmt: dateFmt,
                )
              : _buildDesktopReport(
                  context: context,
                  snapshot: snapshot,
                  totalRevenue: totalRevenue,
                  currencyFmt: currencyFmt,
                  dateFmt: dateFmt,
                ),
        );
      },
    );
  }

  Widget _buildMobileReport({
    required BuildContext context,
    required CashierReportLiteSnapshot snapshot,
    required int totalRevenue,
    required NumberFormat currencyFmt,
    required DateFormat dateFmt,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMobileShiftStatus(
          context: context,
          snapshot: snapshot,
          currencyFmt: currencyFmt,
          dateFmt: dateFmt,
        ),
        const SizedBox(height: 12),
        _buildMobileRevenueSummary(
          context: context,
          totalRevenue: totalRevenue,
          transactionCount: snapshot.totalTransactions,
          currencyFmt: currencyFmt,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMobileBalanceMetric(
                label: 'Tunai',
                value: snapshot.totalCash,
                icon: Icons.payments_outlined,
                color: const Color(0xFF059669),
                currencyFmt: currencyFmt,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMobileBalanceMetric(
                label: 'Non-tunai',
                value: snapshot.totalNonCash,
                icon: Icons.credit_card_outlined,
                color: primary,
                currencyFmt: currencyFmt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildMobilePaymentBreakdown(
          context: context,
          snapshot: snapshot,
          totalRevenue: totalRevenue,
          currencyFmt: currencyFmt,
        ),
      ],
    );
  }

  Widget _buildMobileShiftStatus({
    required BuildContext context,
    required CashierReportLiteSnapshot snapshot,
    required NumberFormat currencyFmt,
    required DateFormat dateFmt,
  }) {
    final theme = Theme.of(context);
    final isActive = snapshot.hasActiveShift;
    final stateColor = isActive
        ? const Color(0xFF059669)
        : const Color(0xFF64748B);
    final title = isActive ? 'Shift aktif' : 'Tidak ada shift aktif';
    final detail = isActive
        ? snapshot.shiftName
        : 'Buka shift untuk mulai merekap penjualan.';

    return Semantics(
      label: title,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _surfaceDecoration(
          color: isActive ? const Color(0xFFF0FDF7) : Colors.white,
          borderColor: stateColor.withValues(alpha: isActive ? 0.16 : 0.10),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isActive ? Icons.badge_outlined : Icons.schedule_outlined,
                    color: stateColor,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: stateColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _store.refresh,
                  tooltip: 'Muat ulang laporan',
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  color: theme.colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
            if (isActive) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 11),
                child: Divider(height: 1, color: Color(0xFFDDF1E8)),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      snapshot.shiftOpenedAt == null
                          ? 'Shift sedang berjalan'
                          : 'Dibuka ${dateFmt.format(snapshot.shiftOpenedAt!)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Saldo awal  Rp ${currencyFmt.format(snapshot.openingBalance)}',
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRevenueSummary({
    required BuildContext context,
    required int totalRevenue,
    required int transactionCount,
    required NumberFormat currencyFmt,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      label:
          'Total penjualan Rp ${currencyFmt.format(totalRevenue)}, $transactionCount transaksi',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _surfaceDecoration(
          color: primary.withValues(alpha: 0.075),
          borderColor: primary.withValues(alpha: 0.16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Total penjualan hari ini',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$transactionCount transaksi',
                    style: TextStyle(
                      color: primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Rp ${currencyFmt.format(totalRevenue)}',
              style: const TextStyle(
                color: Color(0xFF172554),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBalanceMetric({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
    required NumberFormat currencyFmt,
  }) {
    return Semantics(
      label: '$label Rp ${currencyFmt.format(value)}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _surfaceDecoration(),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rp ${currencyFmt.format(value)}',
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePaymentBreakdown({
    required BuildContext context,
    required CashierReportLiteSnapshot snapshot,
    required int totalRevenue,
    required NumberFormat currencyFmt,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final rows = snapshot.paymentBreakdown;

    return Container(
      decoration: _surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Metode pembayaran',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ringkasan transaksi hari ini',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${rows.length} metode',
                    style: TextStyle(
                      color: primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDF5)),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Belum ada pembayaran yang tercatat hari ini.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: Color(0xFFF0F3F8),
              ),
              itemBuilder: (context, index) => _buildMobilePaymentRow(
                row: rows[index],
                totalRevenue: totalRevenue,
                currencyFmt: currencyFmt,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobilePaymentRow({
    required CashierPaymentBreakdownRecord row,
    required int totalRevenue,
    required NumberFormat currencyFmt,
  }) {
    final color = row.isCash
        ? const Color(0xFF059669)
        : const Color(0xFF2563EB);
    final percentage = totalRevenue == 0 ? 0.0 : row.amount / totalRevenue;
    final percentLabel = '${(percentage * 100).round()}% dari penjualan';

    return Semantics(
      label:
          '${row.name}, ${row.count} transaksi, Rp ${currencyFmt.format(row.amount)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.name,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rp ${currencyFmt.format(row.amount)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  '${row.count} transaksi',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  percentLabel,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: percentage.clamp(0.0, 1.0).toDouble(),
                minHeight: 3,
                color: color,
                backgroundColor: color.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopReport({
    required BuildContext context,
    required CashierReportLiteSnapshot snapshot,
    required int totalRevenue,
    required NumberFormat currencyFmt,
    required DateFormat dateFmt,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _surfaceDecoration(),
          child: Row(
            children: [
              Icon(
                Icons.badge_outlined,
                color: snapshot.hasActiveShift
                    ? const Color(0xFF059669)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot.hasActiveShift
                          ? snapshot.shiftName
                          : 'Tidak Ada Shift Aktif',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (snapshot.hasActiveShift &&
                        snapshot.shiftOpenedAt != null)
                      Text(
                        'Dibuka ${dateFmt.format(snapshot.shiftOpenedAt!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              if (snapshot.hasActiveShift)
                Text(
                  'Saldo awal  Rp ${currencyFmt.format(snapshot.openingBalance)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: _store.refresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildDesktopMetric(
                'Total Penjualan',
                totalRevenue,
                Icons.account_balance_wallet_outlined,
                primary,
                currencyFmt,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDesktopMetric(
                'Transaksi',
                snapshot.totalTransactions,
                Icons.receipt_long_outlined,
                const Color(0xFF7C3AED),
                currencyFmt,
                currency: false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDesktopMetric(
                'Tunai',
                snapshot.totalCash,
                Icons.payments_outlined,
                const Color(0xFF059669),
                currencyFmt,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDesktopMetric(
                'Non-tunai',
                snapshot.totalNonCash,
                Icons.credit_card_outlined,
                primary,
                currencyFmt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildMobilePaymentBreakdown(
          context: context,
          snapshot: snapshot,
          totalRevenue: totalRevenue,
          currencyFmt: currencyFmt,
        ),
      ],
    );
  }

  Widget _buildDesktopMetric(
    String label,
    int value,
    IconData icon,
    Color color,
    NumberFormat currencyFmt, {
    bool currency = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _surfaceDecoration(),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currency ? 'Rp ${currencyFmt.format(value)}' : '$value',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _surfaceDecoration({
    Color color = Colors.white,
    Color borderColor = const Color(0xFFE6ECF5),
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
    );
  }
}
