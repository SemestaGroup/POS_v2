import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../stores/overview_store.dart';
import '../customer_metrics_content.dart';

class CustomerMetricsView extends StatelessWidget {
  const CustomerMetricsView({
    super.key,
    required this.snapshot,
    required this.includeWalkIns,
    required this.onIncludeWalkInsChanged,
  });

  final OverviewSnapshot snapshot;
  final bool includeWalkIns;
  final ValueChanged<bool> onIncludeWalkInsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (snapshot.isLoading &&
        snapshot.totalCustomers == 0 &&
        snapshot.activeCustomers == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.errorMessage != null) ...[
            _buildLoadError(theme, l10n.customerMetricsLoadError),
            const SizedBox(height: 12),
          ],
          CustomerOverviewScopeToggle(
            value: includeWalkIns,
            onChanged: onIncludeWalkInsChanged,
            compact: false,
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildKpiCard(
                    theme: theme,
                    title: l10n.totalCustomers,
                    value:
                        '${includeWalkIns ? snapshot.totalCustomersIncludingWalkIns : snapshot.totalCustomers}',
                    subtitle: l10n.registeredCustomers,
                    icon: Icons.people_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    theme: theme,
                    title: l10n.activeCustomers,
                    value:
                        '${includeWalkIns ? snapshot.activeCustomersIncludingWalkIns : snapshot.activeCustomers}',
                    subtitle: snapshot.periodLabel,
                    icon: Icons.person_pin_circle_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    theme: theme,
                    title: l10n.newCustomers,
                    value:
                        '${includeWalkIns ? snapshot.newCustomersIncludingWalkIns : snapshot.newCustomers}',
                    subtitle: l10n.customerNewPeriodHint,
                    icon: Icons.person_add_alt_1_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    theme: theme,
                    title: l10n.returningCustomers,
                    value:
                        '${includeWalkIns ? snapshot.returningCustomersIncludingWalkIns : snapshot.returningCustomers}',
                    subtitle: l10n.customerReturningPeriodHint,
                    icon: Icons.repeat_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildActivityChartCard(context, theme),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildNewCustomersChartCard(
                          context,
                          theme,
                          dense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 6,
                        child: TopCustomersPanel(
                          records: includeWalkIns
                              ? snapshot.topCustomersIncludingWalkIns
                              : snapshot.topCustomers,
                          compact: true,
                          fillHeight: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required ThemeData theme,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                  child: Icon(icon, size: 20, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 12,
                    ),
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
              builder: (context, scale, child) => Transform.scale(
                scale: 0.9 + (scale * 0.1),
                alignment: Alignment.centerLeft,
                child: Opacity(opacity: scale, child: child),
              ),
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
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 10,
                color: Colors.grey.shade600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChartCard(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final records = includeWalkIns
        ? snapshot.customerTrendIncludingWalkIns
        : snapshot.customerTrend;
    final hasData = records.any((record) => record.activeCustomers > 0);
    return _buildChartCard(
      theme: theme,
      icon: Icons.bar_chart_rounded,
      title: l10n.activeCustomers,
      child: hasData
          ? _CustomerBarChart(records: records)
          : _CustomerChartEmpty(
              title: l10n.customerMetricsEmptyTitle,
              message: l10n.customerMetricsEmptyMessage,
            ),
    );
  }

  Widget _buildNewCustomersChartCard(
    BuildContext context,
    ThemeData theme, {
    bool dense = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final records = includeWalkIns
        ? snapshot.customerTrendIncludingWalkIns
        : snapshot.customerTrend;
    final hasData = records.any((record) => record.newCustomers > 0);
    return _buildChartCard(
      theme: theme,
      icon: Icons.trending_up_rounded,
      title: l10n.newCustomers,
      dense: dense,
      child: hasData
          ? _CustomerLineChart(records: records)
          : _CustomerChartEmpty(
              title: l10n.customerMetricsEmptyTitle,
              message: l10n.customerMetricsEmptyMessage,
              compact: dense,
            ),
    );
  }

  Widget _buildChartCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required Widget child,
    bool dense = false,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.all(dense ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: dense ? 8 : 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError(ThemeData theme, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CustomerBarChart extends StatelessWidget {
  const _CustomerBarChart({required this.records});

  final List<CustomerTrendRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCustomers = records.fold<int>(
      1,
      (maxValue, record) =>
          record.activeCustomers > maxValue ? record.activeCustomers : maxValue,
    );
    final scaleFactor = maxCustomers / 6;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 6.5,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  '${(rod.toY * scaleFactor).round()} pelanggan',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),
        titlesData: _customerChartTitles(records, scaleFactor),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var index = 0; index < records.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: records[index].activeCustomers / scaleFactor,
                  color: theme.colorScheme.primary,
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CustomerLineChart extends StatelessWidget {
  const _CustomerLineChart({required this.records});

  final List<CustomerTrendRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCustomers = records.fold<int>(
      1,
      (maxValue, record) =>
          record.newCustomers > maxValue ? record.newCustomers : maxValue,
    );
    final scaleFactor = maxCustomers / 6;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 6.5,
        gridData: const FlGridData(show: false),
        titlesData: _customerChartTitles(records, scaleFactor),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < records.length; index++)
                FlSpot(
                  index.toDouble(),
                  records[index].newCustomers / scaleFactor,
                ),
            ],
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
    );
  }
}

FlTitlesData _customerChartTitles(
  List<CustomerTrendRecord> records,
  double scaleFactor,
) {
  return FlTitlesData(
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();
          if (index < 0 || index >= records.length) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              records[index].label,
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
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              (value * scaleFactor).round().toString(),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.right,
            ),
          );
        },
      ),
    ),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  );
}

class _CustomerChartEmpty extends StatelessWidget {
  const _CustomerChartEmpty({
    required this.title,
    required this.message,
    this.compact = false,
  });

  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: compact ? 18 : 24,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: Colors.grey.shade600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
