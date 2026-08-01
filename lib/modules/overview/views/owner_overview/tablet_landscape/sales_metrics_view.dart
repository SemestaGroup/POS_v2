import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../stores/overview_store.dart';

class SalesMetricsView extends StatelessWidget {
  const SalesMetricsView({super.key, required this.snapshot});

  final OverviewSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildKpiCard(
                    theme,
                    AppLocalizations.of(context)!.totalSales,
                    currencyFormatter.format(snapshot.salesToday),
                    snapshot.periodLabel,
                    'assets/mockups/dashboard/sales-summary.webp',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    theme,
                    'Penjualan Bulan Ini',
                    currencyFormatter.format(snapshot.salesThisMonth),
                    '',
                    'assets/mockups/dashboard/sales-summary.webp',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    theme,
                    AppLocalizations.of(context)!.transactions,
                    snapshot.transactionsToday.toString(),
                    snapshot.periodLabel,
                    'assets/mockups/dashboard/transactions.webp',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    theme,
                    'Rata-rata Transaksi',
                    snapshot.transactionsToday > 0 
                      ? currencyFormatter.format(snapshot.salesToday / snapshot.transactionsToday)
                      : 'Rp 0',
                    snapshot.periodLabel,
                    'assets/mockups/dashboard/discount.webp',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Middle Charts
          SizedBox(
            height: 400,
            child: Row(
              children: [
                Expanded(flex: 6, child: _buildBarChartCard(context, theme)),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: _buildLineChartCard(context, theme)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Panels
          SizedBox(
            height: 340,
            child: Row(
              children: [
                Expanded(flex: 1, child: _buildTopSellingPanel(context, theme)),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: _buildStatusPanel(context, theme)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTransactionFeedPanel(context, theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    ThemeData theme,
    String title,
    String value,
    String subtitle,
    String imagePath,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(imagePath, width: 20, height: 20, errorBuilder: (context, error, stackTrace) => const Icon(Icons.show_chart, size: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(seconds: 1),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: 0.9 + (scale * 0.1),
                  alignment: Alignment.centerLeft,
                  child: Opacity(
                    opacity: scale,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 22,
                          color: theme.textTheme.headlineMedium?.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            // Padding so even empty subtitles give equivalent space
            if (subtitle.isEmpty) const SizedBox(height: 19),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard(BuildContext context, ThemeData theme) {
    double maxSales = 0;
    for (var h in snapshot.hourlySales) {
      if (h.sales > maxSales) maxSales = h.sales.toDouble();
    }
    if (maxSales == 0) maxSales = 1000000;
    
    // Scale down values to fit chart (e.g. max Y is 6, so divide by (maxSales/6))
    double scaleFactor = maxSales / 6;
    if (scaleFactor == 0) scaleFactor = 1;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Tren Penjualan Per Jam (Hari Ini)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 6.5,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final realVal = rod.toY * scaleFactor;
                        return BarTooltipItem(
                          NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(realVal),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < 0 || value.toInt() >= snapshot.hourlySales.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              snapshot.hourlySales[value.toInt()].label.split(':')[0], // just hour
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value > 6) return const SizedBox.shrink();
                          final realVal = value * scaleFactor;
                          return Text(
                            _formatAxisLabel(realVal),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: snapshot.hourlySales.asMap().entries.map((entry) {
                    final index = entry.key;
                    final val = entry.value.sales / scaleFactor;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: val,
                          color: theme.colorScheme.primary,
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartCard(BuildContext context, ThemeData theme) {
    double maxTrx = 0;
    for (var d in snapshot.dailyTransactions) {
      if (d.count > maxTrx) maxTrx = d.count.toDouble();
    }
    if (maxTrx == 0) maxTrx = 10;
    
    double scaleFactor = maxTrx / 6;
    if (scaleFactor == 0) scaleFactor = 1;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Tren Transaksi (7 Hari Terakhir)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 6.5,
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < 0 || value.toInt() >= snapshot.dailyTransactions.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              snapshot.dailyTransactions[value.toInt()].label,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value > 6) return const SizedBox.shrink();
                          final realVal = value * scaleFactor;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Text(
                              realVal.toInt().toString(),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: snapshot.dailyTransactions.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.count / scaleFactor);
                      }).toList(),
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingPanel(BuildContext context, ThemeData theme) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Top 5 Produk Terlaris (Bulan Ini)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.topProducts.isEmpty)
              const Expanded(child: Center(child: Text('Belum ada data penjualan', style: TextStyle(color: Colors.grey, fontSize: 12))))
            else
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.topProducts.length,
                  separatorBuilder: (_, _) => Divider(color: theme.dividerColor, height: 1),
                  itemBuilder: (context, index) {
                    final p = snapshot.topProducts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${p.quantity}x',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currencyFormatter.format(p.totalSales),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sync, color: snapshot.pendingSyncCount > 0 ? Colors.orange : Colors.green),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Status Sinkronisasi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.pendingSyncCount > 0
                      ? 'Ada ${snapshot.pendingSyncCount} data antrean'
                      : 'Semua data telah tersinkron',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: snapshot.pendingSyncCount > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront, color: snapshot.isShiftOpen ? Colors.green : Colors.grey),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Status Shift Operasional',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.isShiftOpen ? 'Shift Sedang Berjalan' : 'Belum Ada Shift Aktif',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: snapshot.isShiftOpen ? Colors.green.shade800 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionFeedPanel(BuildContext context, ThemeData theme) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Transaksi Terbaru',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.recentTransactions.isEmpty)
              const Expanded(child: Center(child: Text('Belum ada transaksi', style: TextStyle(color: Colors.grey, fontSize: 12))))
            else
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.recentTransactions.length,
                  separatorBuilder: (_, _) => Divider(color: theme.dividerColor, height: 1),
                  itemBuilder: (context, index) {
                    final trx = snapshot.recentTransactions[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              trx.idPos,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              DateFormat('HH:mm').format(trx.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              currencyFormatter.format(trx.total),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  String _formatAxisLabel(double value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}jt";
    } else if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(0)}k";
    }
    return value.toInt().toString();
  }
}
