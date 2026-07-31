import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../stores/report_read_stores.dart';

/// Mobile-specific presentation for the report summary.
///
/// The parent view owns loading and error state; this widget is deliberately
/// limited to the portrait information hierarchy and refresh interaction.
class ReportSummaryMobileView extends StatelessWidget {
  const ReportSummaryMobileView({
    required this.snapshot,
    required this.primaryColor,
    required this.currencyFmt,
    required this.onRefresh,
    super.key,
  });

  final ReportSummarySnapshot snapshot;
  final Color primaryColor;
  final NumberFormat currencyFmt;
  final Future<void> Function() onRefresh;

  int get _averageTransaction => snapshot.todayTransactions > 0
      ? snapshot.todaySales ~/ snapshot.todayTransactions
      : 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildTodayCard(l10n),
          const SizedBox(height: 16),
          _buildPeriodOverview(l10n),
          const SizedBox(height: 20),
          _buildTopProducts(l10n),
        ],
      ),
    );
  }

  Widget _buildTodayCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5)),
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
                  color: primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  color: primaryColor,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.reportTodaySales,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Rp ${currencyFmt.format(snapshot.todaySales)}',
              style: TextStyle(
                color: primaryColor,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTodayMetric(
                    label: l10n.transactions,
                    value: '${snapshot.todayTransactions}',
                  ),
                ),
                Container(width: 1, height: 27, color: const Color(0xFFDCE5F3)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _buildTodayMetric(
                      label: l10n.reportAverage,
                      value: 'Rp ${currencyFmt.format(_averageTransaction)}',
                    ),
                  ),
                ),
                Container(width: 1, height: 27, color: const Color(0xFFDCE5F3)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _buildTodayMetric(
                      label: l10n.discount,
                      value: 'Rp ${currencyFmt.format(snapshot.todayDiscount)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 16,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodOverview(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 13, 14, 10),
            child: Text(
              l10n.reportSalesAccumulation,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: _buildPeriodColumn(
                    label: l10n.reportLastSevenDays,
                    sales: snapshot.weekSales,
                    transactions: snapshot.weekTransactions,
                    l10n: l10n,
                  ),
                ),
                Container(width: 1, height: 54, color: const Color(0xFFE8EDF5)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: _buildPeriodColumn(
                      label: l10n.reportCurrentMonth,
                      sales: snapshot.monthSales,
                      transactions: snapshot.monthTransactions,
                      l10n: l10n,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodColumn({
    required String label,
    required int sales,
    required int transactions,
    required AppLocalizations l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Rp ${currencyFmt.format(sales)}',
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.reportTransactionsCount(transactions),
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
        ),
      ],
    );
  }

  Widget _buildTopProducts(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8EDF5)),
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
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: Color(0xFFB45309),
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.reportTopProductsCurrentMonth,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          if (snapshot.topProducts.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  l10n.reportNoTopProducts,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ),
            )
          else
            for (final entry in snapshot.topProducts.asMap().entries)
              _buildTopProductRow(
                rank: entry.key + 1,
                product: entry.value,
                l10n: l10n,
                showDivider: entry.key < snapshot.topProducts.length - 1,
              ),
        ],
      ),
    );
  }

  Widget _buildTopProductRow({
    required int rank,
    required ReportSummaryTopProductRecord product,
    required AppLocalizations l10n,
    required bool showDivider,
  }) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.reportItemsCount(product.quantity),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 104,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Rp ${currencyFmt.format(product.revenue)}',
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 36, color: Color(0xFFF1F5F9)),
      ],
    );
  }
}
