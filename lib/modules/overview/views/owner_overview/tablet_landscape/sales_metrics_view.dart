import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../../l10n/app_localizations.dart';

class SalesMetricsView extends StatelessWidget {
  const SalesMetricsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    'Rp 15.564.940',
                    AppLocalizations.of(context)!.transactionsWithCount('202'),
                    'assets/mockups/dashboard/sales-summary.webp',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    theme,
                    AppLocalizations.of(context)!.avgSalesPerTransaction,
                    'Rp 77.054.16',
                    AppLocalizations.of(context)!.transactionsWithCount('202'),
                    'assets/mockups/dashboard/sales-summary.webp',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    theme,
                    AppLocalizations.of(context)!.transactions,
                    '202',
                    '',
                    'assets/mockups/dashboard/transactions.webp',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    theme,
                    AppLocalizations.of(context)!.totalDiscount,
                    'Rp 0',
                    AppLocalizations.of(context)!.transactionsWithCount('202'),
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
                Expanded(flex: 1, child: _buildAlertPanel(context, theme)),
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
                  child: Image.asset(imagePath, width: 20, height: 20),
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
    final l10n = AppLocalizations.of(context)!;
    final weekdayLabels = _weekdayLabels(context);

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
                Image.asset(
                  'assets/mockups/dashboard/multi-brand.webp',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.overviewMultiBrandSales,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  color: const Color(0xFFFFEB3B),
                ),
                const SizedBox(width: 8),
                const Text('Xie-Xie Ice Cream', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 24),
                Container(
                  width: 12,
                  height: 12,
                  color: const Color(0xFF81C784),
                ),
                const SizedBox(width: 8),
                const Text('Ninechicken', style: TextStyle(fontSize: 10)),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 6,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY} ${l10n.millionShort}',
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
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              weekdayLabels[value.toInt()],
                              style: const TextStyle(fontSize: 12),
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
                          return Text(
                            _barChartAxisLabel(context, value),
                            style: const TextStyle(fontSize: 10),
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
                  barGroups: [
                    _makeGroupData(0, 4.2, 5.0),
                    _makeGroupData(1, 4.8, 3.2),
                    _makeGroupData(2, 2.5, 3.0),
                    _makeGroupData(3, 4.2, 3.5),
                    _makeGroupData(4, 3.8, 4.5),
                    _makeGroupData(5, 4.9, 5.8),
                    _makeGroupData(6, 4.7, 4.4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeGroupData(int x, double y1, double y2) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y1,
          color: const Color(0xFFFFF59D),
          width: 14,
          borderRadius: BorderRadius.circular(4),
        ),
        BarChartRodData(
          toY: y2,
          color: const Color(0xFFA5D6A7),
          width: 14,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
      barsSpace: 4,
    );
  }

  Widget _buildLineChartCard(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          top: 16.0,
          bottom: 16.0,
          right: 16.0,
          left: 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                children: [
                  Image.asset(
                    'assets/mockups/dashboard/trend-chart.webp',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.overviewSalesTrendChart,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 32.0),
              child: Text(
                l10n.overviewPeakHours,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildLineChart(
                theme,
                [2, 5, 4, 6, 3, 5, 3],
                ['8', '10', '12', '15', '17', '19', '21'],
                (val) => _peakHoursAxisLabel(context, val),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 32.0),
              child: Text(
                l10n.overviewMonthlySalesTrend,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildLineChart(
                theme,
                [5, 3, 2, 2, 3, 4, 4],
                _monthLabels(context),
                (val) => _monthlySalesAxisLabel(context, val),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(
    ThemeData theme,
    List<double> data,
    List<String> labels,
    String Function(double) formatY,
  ) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      labels[value.toInt()],
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Text(
                    formatY(value),
                    style: const TextStyle(fontSize: 9, color: Colors.black54),
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
            spots: data
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingPanel(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

    final items = [
      {'name': 'Boba Milk Tea', 'price': '250.000'},
      {'name': 'Strawberry Sundae', 'price': '300.000'},
      {'name': 'Ice Cream Matcha', 'price': '220.000'},
      {'name': 'Cookies Sundae', 'price': '150.000'},
      {'name': 'Chicken Fiery', 'price': '320.000'},
      {'name': 'Original Crispy', 'price': '250.000'},
    ];

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
                Image.asset(
                  'assets/mockups/dashboard/best-seller.webp',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.overviewTopFiveBestSelling,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics:
                    const NeverScrollableScrollPhysics(), // Scroll in main view
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    Divider(color: theme.dividerColor, height: 1),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          items[index]['name']!,
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          items[index]['price']!,
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

  Widget _buildAlertPanel(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final stockAlertAt = DateTime(2026, 10, 1, 8, 15);

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
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/mockups/dashboard/alert.webp',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.overviewLowStockAlert,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        l10n.date,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        l10n.status,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('10000106', style: TextStyle(fontSize: 11)),
                        Text(
                          DateFormat.yMMMd(
                            localeName,
                          ).add_Hm().format(stockAlertAt),
                          style: TextStyle(fontSize: 11),
                        ),
                        Text(
                          l10n.overviewLowStatus,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/mockups/dashboard/integration-log.webp',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.overviewSystemIntegrationLogStatus,
                          style: const TextStyle(
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
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.black87, fontSize: 11),
                      children: [
                        TextSpan(text: '${l10n.overviewMekariJurnalSync} : '),
                        TextSpan(
                          text: l10n.overviewSuccess200Ok,
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.black87, fontSize: 11),
                      children: [
                        TextSpan(
                          text: '${l10n.overviewSupabaseConnectivity} : ',
                        ),
                        TextSpan(
                          text: l10n.orderStatusActive,
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
    final l10n = AppLocalizations.of(context)!;
    final transactions = [
      {'id': '10000236', 'type': l10n.overviewCredit, 'amount': '35.000'},
      {'id': '10000235', 'type': l10n.overviewCash, 'amount': '49.000'},
      {'id': '10000235', 'type': l10n.overviewCredit, 'amount': '56.000'},
      {'id': '10000236', 'type': l10n.overviewCash, 'amount': '75.000'},
      {'id': '10000237', 'type': l10n.overviewCash, 'amount': '45.000'},
      {'id': '10000236', 'type': l10n.overviewCredit, 'amount': '82.000'},
      {'id': '10000235', 'type': l10n.overviewCredit, 'amount': '46.000'},
    ];

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
                Image.asset(
                  'assets/mockups/dashboard/transactions.webp',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.overviewLiveTransactionFeed,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics:
                    const NeverScrollableScrollPhysics(), // Scroll in main view
                itemCount: transactions.length,
                separatorBuilder: (_, _) =>
                    Divider(color: theme.dividerColor, height: 1),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            transactions[index]['id']!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            transactions[index]['type']!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            transactions[index]['amount']!,
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

  List<String> _weekdayLabels(BuildContext context) {
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final monday = DateTime(2024, 1, 1);

    return List.generate(
      7,
      (index) =>
          DateFormat.E(localeName).format(monday.add(Duration(days: index))),
    );
  }

  List<String> _monthLabels(BuildContext context) {
    final localeName = Localizations.localeOf(context).toLanguageTag();

    return List.generate(
      7,
      (index) => DateFormat.MMM(localeName).format(DateTime(2024, index + 1)),
    );
  }

  String _barChartAxisLabel(BuildContext context, double value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == 0) {
      return '250 ${l10n.thousandShort}';
    }
    if (value == 1) {
      return '500 ${l10n.thousandShort}';
    }
    if (value == 2) {
      return '1 ${l10n.millionShort}';
    }
    return '${value.toInt()} ${l10n.millionShort}';
  }

  String _peakHoursAxisLabel(BuildContext context, double value) {
    final l10n = AppLocalizations.of(context)!;
    return '${(value * 16.5).toInt()}${l10n.thousandShort}';
  }

  String _monthlySalesAxisLabel(BuildContext context, double value) {
    final l10n = AppLocalizations.of(context)!;
    return '${value.toInt()}0 ${l10n.millionShort}';
  }
}
