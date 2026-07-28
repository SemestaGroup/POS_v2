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
    final isMobile = MediaQuery.of(context).size.shortestSide < 600;

    if (isMobile) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Ringkasan
            _buildSectionTitle(context, theme, 'Ringkasan'),
            const SizedBox(height: 8),
            // KPI Cards stacked vertically (pastel premium style)
            Column(
              children: [
                _buildKpiCard(
                  theme,
                  AppLocalizations.of(context)!.totalSales,
                  currencyFormatter.format(snapshot.salesToday),
                  snapshot.periodLabel,
                  'assets/mockups/dashboard/sales-summary.webp',
                  isMobile: true,
                  customBg: const Color(0xFFF0F9FF),
                  iconBg: const Color(0xFFE0F2FE),
                  iconColor: const Color(0xFF0284C7),
                ),
                const SizedBox(height: 10),
                _buildKpiCard(
                  theme,
                  'Penjualan Bulan Ini',
                  currencyFormatter.format(snapshot.salesThisMonth),
                  '',
                  'assets/mockups/dashboard/sales-summary.webp',
                  isMobile: true,
                  customBg: const Color(0xFFF0FDF4),
                  iconBg: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF16A34A),
                ),
                const SizedBox(height: 10),
                _buildKpiCard(
                  theme,
                  AppLocalizations.of(context)!.transactions,
                  snapshot.transactionsToday.toString(),
                  snapshot.periodLabel,
                  'assets/mockups/dashboard/transactions.webp',
                  isMobile: true,
                  customBg: const Color(0xFFFFFBEB),
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                ),
                const SizedBox(height: 10),
                _buildKpiCard(
                  theme,
                  'Rata-rata Transaksi',
                  snapshot.transactionsToday > 0
                    ? currencyFormatter.format(snapshot.salesToday / snapshot.transactionsToday)
                    : 'Rp 0',
                  snapshot.periodLabel,
                  'assets/mockups/dashboard/discount.webp',
                  isMobile: true,
                  customBg: const Color(0xFFFAF5FF),
                  iconBg: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF9333EA),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Section: Tren Penjualan
            _buildSectionTitle(context, theme, 'Tren Penjualan'),
            const SizedBox(height: 8),
            // Charts Stacked Vertically (Height 210 is perfect & compact for mobile)
            SizedBox(
              height: 216,
              child: _buildBarChartCard(context, theme),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 216,
              child: _buildLineChartCard(context, theme),
            ),
            const SizedBox(height: 18),

            // Section: Aktivitas
            _buildSectionTitle(context, theme, 'Aktivitas'),
            const SizedBox(height: 8),
            // Bottom Panels Stacked Vertically (Flexible heights, fully scrollable)
            _buildTopSellingPanel(context, theme),
            const SizedBox(height: 12),
            _buildStatusPanel(context, theme),
            const SizedBox(height: 12),
            _buildTransactionFeedPanel(context, theme),
            const SizedBox(height: 20),
          ],
        ),
      );
    }

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

  Widget _buildSectionTitle(BuildContext context, ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2.0),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Themed section card carrying the same pastel language as the KPI cards
  /// so charts and panels feel like one cohesive system.
  Widget _buildThemedCard({
    required ThemeData theme,
    required Color accent,
    required Widget child,
    double radius = 16,
    EdgeInsets padding = const EdgeInsets.all(16.0),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  Widget _buildPanelHeader({
    required IconData icon,
    required Color accent,
    required String title,
    String? subtitle,
  }) {
    return Row(
      children: [
        // Left accent bar indicator
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Small status chip used for sync / shift states, following the project
  /// UI guideline ("badge/chip kecil untuk status", soft color backgrounds).
  Widget _buildStatusChip({
    required Color color,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
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
    String imagePath, {
    bool isMobile = false,
    Color? customBg,
    Color? iconBg,
    Color? iconColor,
  }) {
    if (isMobile) {
      return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: customBg ?? Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: customBg != null
                ? Colors.transparent
                : theme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg ?? theme.colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  imagePath,
                  width: 20,
                  height: 20,
                  color: iconColor,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.show_chart, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade400,
                  ),
                ),
            ],
          ),
        ),
      );
    }

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
            const SizedBox(height: 8),
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
              child: ExcludeSemantics(
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
              child: ExcludeSemantics(
                child: LineChart(
                  LineChartData(
                    lineTouchData: const LineTouchData(
                      enabled: true,
                    ),
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
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingPanel(BuildContext context, ThemeData theme) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final accent = const Color(0xFF8B5CF6);
    final maxQty = snapshot.topProducts.isNotEmpty ? snapshot.topProducts.first.quantity : 1;

    return _buildThemedCard(
      theme: theme,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            icon: Icons.star_rounded,
            accent: accent,
            title: 'Top 5 Produk Terlaris',
            subtitle: 'Bulan ini',
          ),
          const SizedBox(height: 12),
          if (snapshot.topProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: Text('Belum ada data penjualan', style: TextStyle(color: Colors.grey, fontSize: 11))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.topProducts.length > 5 ? 5 : snapshot.topProducts.length,
              itemBuilder: (context, index) {
                final p = snapshot.topProducts[index];
                
                Color rankColor;
                if (index == 0) {
                  rankColor = const Color(0xFFD4AF37);
                } else if (index == 1) {
                  rankColor = const Color(0xFFC0C0C0);
                } else if (index == 2) {
                  rankColor = const Color(0xFFCD7F32);
                } else {
                  rankColor = Colors.grey.shade400;
                }

                final double progress = p.quantity / maxQty;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: rankColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: rankColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${p.quantity}x',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            currencyFormatter.format(p.totalSales),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 26.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(accent.withValues(alpha: 0.6)),
                            minHeight: 3.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel(BuildContext context, ThemeData theme) {
    final hasPendingSync = snapshot.pendingSyncCount > 0;
    final isShiftOpen = snapshot.isShiftOpen;
    final isMobile = MediaQuery.of(context).size.shortestSide < 600;

    Widget syncCard = _buildThemedCard(
      theme: theme,
      accent: hasPendingSync ? Colors.orange : Colors.green,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _buildPanelHeader(
              icon: Icons.sync_rounded,
              accent: hasPendingSync ? Colors.orange : Colors.green,
              title: 'Status Sinkronisasi',
              subtitle: hasPendingSync ? 'Ada data tertunda' : 'Semua aman',
            ),
          ),
          _buildStatusChip(
            color: hasPendingSync ? Colors.orange.shade800 : Colors.green.shade700,
            label: hasPendingSync ? '${snapshot.pendingSyncCount} Antrean' : 'Tersinkron',
            icon: hasPendingSync ? Icons.sync_problem_rounded : Icons.check_circle_rounded,
          ),
        ],
      ),
    );

    Widget shiftCard = _buildThemedCard(
      theme: theme,
      accent: isShiftOpen ? const Color(0xFF10B981) : Colors.blueGrey,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _buildPanelHeader(
              icon: Icons.storefront_rounded,
              accent: isShiftOpen ? const Color(0xFF10B981) : Colors.blueGrey,
              title: 'Shift Operasional',
              subtitle: isShiftOpen ? 'Sedang berjalan' : 'Shift tutup',
            ),
          ),
          _buildStatusChip(
            color: isShiftOpen ? const Color(0xFF047857) : Colors.blueGrey.shade700,
            label: isShiftOpen ? 'Shift Aktif' : 'Tutup',
            icon: isShiftOpen ? Icons.play_arrow_rounded : Icons.stop_rounded,
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          syncCard,
          const SizedBox(height: 10),
          shiftCard,
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: syncCard),
        const SizedBox(height: 10),
        Expanded(child: shiftCard),
      ],
    );
  }

  Widget _buildTransactionFeedPanel(BuildContext context, ThemeData theme) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final accent = const Color(0xFF3B82F6);

    return _buildThemedCard(
      theme: theme,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(
            icon: Icons.receipt_long_rounded,
            accent: accent,
            title: 'Transaksi Terbaru',
            subtitle: 'Aktivitas kasir hari ini',
          ),
          const SizedBox(height: 16),
          if (snapshot.recentTransactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: Text('Belum ada transaksi', style: TextStyle(color: Colors.grey, fontSize: 11))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.recentTransactions.length > 5 ? 5 : snapshot.recentTransactions.length,
              separatorBuilder: (_, _) => Divider(color: Colors.grey.shade100, height: 16),
              itemBuilder: (context, index) {
                final trx = snapshot.recentTransactions[index];
                final bool isSuccess = trx.status == 'success' || trx.status == 'paid' || trx.status == 'completed';

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 16,
                        color: isSuccess ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trx.idPos,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('HH:mm').format(trx.createdAt),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    // Value (Total Sales)
                    Text(
                      currencyFormatter.format(trx.total),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
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
