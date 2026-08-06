import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../stores/overview_store.dart';

/// Shared customer summary layout. The information stays identical on every
/// device, while the composition changes to suit a narrow phone or a tablet.
class CustomerMetricsContent extends StatelessWidget {
  const CustomerMetricsContent({
    super.key,
    required this.snapshot,
    required this.compact,
    required this.includeWalkIns,
    required this.onIncludeWalkInsChanged,
  });

  final OverviewSnapshot snapshot;
  final bool compact;
  final bool includeWalkIns;
  final ValueChanged<bool> onIncludeWalkInsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final totalCustomers = includeWalkIns
        ? snapshot.totalCustomersIncludingWalkIns
        : snapshot.totalCustomers;
    final newCustomers = includeWalkIns
        ? snapshot.newCustomersIncludingWalkIns
        : snapshot.newCustomers;
    final activeCustomers = includeWalkIns
        ? snapshot.activeCustomersIncludingWalkIns
        : snapshot.activeCustomers;
    final returningCustomers = includeWalkIns
        ? snapshot.returningCustomersIncludingWalkIns
        : snapshot.returningCustomers;
    final customerTrend = includeWalkIns
        ? snapshot.customerTrendIncludingWalkIns
        : snapshot.customerTrend;
    final topCustomers = includeWalkIns
        ? snapshot.topCustomersIncludingWalkIns
        : snapshot.topCustomers;

    if (snapshot.isLoading &&
        snapshot.totalCustomers == 0 &&
        snapshot.activeCustomers == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: compact
          ? const EdgeInsets.fromLTRB(14, 12, 14, 28)
          : const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            _SectionHeader(title: l10n.customerSummaryTitle),
            const SizedBox(height: 10),
          ],
          if (snapshot.errorMessage != null) ...[
            _LoadError(theme: theme, message: l10n.customerMetricsLoadError),
            const SizedBox(height: 10),
          ],
          CustomerOverviewScopeToggle(
            value: includeWalkIns,
            onChanged: onIncludeWalkInsChanged,
            compact: compact,
          ),
          const SizedBox(height: 12),
          if (compact) ...[
            _PrimaryMetricCard(
              activeCustomers: activeCustomers,
              totalCustomers: totalCustomers,
              compact: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SupportingMetricCard(
                    label: l10n.newCustomers,
                    value: newCustomers,
                    hint: l10n.customerNewPeriodHint,
                    icon: Icons.person_add_alt_1_outlined,
                    accent: theme.colorScheme.tertiary,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SupportingMetricCard(
                    label: l10n.returningCustomers,
                    value: returningCustomers,
                    hint: l10n.customerReturningPeriodHint,
                    icon: Icons.autorenew_rounded,
                    accent: const Color(0xFF0F766E),
                    compact: true,
                  ),
                ),
              ],
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _PrimaryMetricCard(
                    activeCustomers: activeCustomers,
                    totalCustomers: totalCustomers,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SupportingMetricCard(
                    label: l10n.newCustomers,
                    value: newCustomers,
                    hint: l10n.customerNewPeriodHint,
                    icon: Icons.person_add_alt_1_outlined,
                    accent: theme.colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SupportingMetricCard(
                    label: l10n.returningCustomers,
                    value: returningCustomers,
                    hint: l10n.customerReturningPeriodHint,
                    icon: Icons.autorenew_rounded,
                    accent: const Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          SizedBox(height: compact ? 18 : 20),
          _SectionHeader(title: l10n.customerTrendTitle),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              l10n.customerTrendSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _CustomerTrendCard(records: customerTrend, showCompactChart: compact),
          if (compact) ...[
            const SizedBox(height: 18),
            TopCustomersPanel(records: topCustomers, compact: true),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade800,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _PrimaryMetricCard extends StatelessWidget {
  const _PrimaryMetricCard({
    required this.activeCustomers,
    required this.totalCustomers,
    this.compact = false,
  });

  final int activeCustomers;
  final int totalCustomers;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      label:
          '${l10n.activeCustomers}: $activeCustomers. ${l10n.registeredCustomers}: $totalCustomers',
      child: compact
          ? Container(
              height: 132,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.people_alt_outlined,
                          size: 20,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.activeCustomers,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF1E3A5F),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.customerActivePeriodHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF476A91),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$activeCustomers',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: const Color(0xFF0F3D78),
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Divider(height: 1, color: Color(0xFFBFDBFE)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.registeredCustomers,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF476A91),
                        ),
                      ),
                      Text(
                        '$totalCustomers',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF0F3D78),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Container(
              constraints: const BoxConstraints(minHeight: 164),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.activeCustomers,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.people_alt_outlined,
                        color: scheme.onPrimaryContainer.withValues(
                          alpha: 0.78,
                        ),
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$activeCustomers',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.customerActivePeriodHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.18),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.registeredCustomers,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
                      Text(
                        '$totalCustomers',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _SupportingMetricCard extends StatelessWidget {
  const _SupportingMetricCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.accent,
    this.compact = false,
  });

  final String label;
  final int value;
  final String hint;
  final IconData icon;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: '$label: $value. $hint',
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 116 : 164),
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: compact ? accent.withValues(alpha: 0.055) : scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: compact
                ? accent.withValues(alpha: 0.2)
                : scheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [Icon(icon, size: compact ? 19 : 21, color: accent)],
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1,
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              hint,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: compact ? 10 : 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTrendCard extends StatelessWidget {
  const _CustomerTrendCard({
    required this.records,
    required this.showCompactChart,
  });

  final List<CustomerTrendRecord> records;
  final bool showCompactChart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasData = records.any(
      (record) => record.activeCustomers > 0 || record.newCustomers > 0,
    );

    return Container(
      height: showCompactChart ? 206 : 300,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _LegendItem(
                      color: theme.colorScheme.primary,
                      label: l10n.activeCustomers,
                    ),
                    _LegendItem(
                      color: const Color(0xFF0F766E),
                      label: l10n.newCustomers,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(child: _CustomerLineChart(records: records)),
              ],
            )
          : _CustomerTrendEmpty(
              title: l10n.customerMetricsEmptyTitle,
              message: l10n.customerMetricsEmptyMessage,
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
    final highest = records.fold<int>(0, (current, record) {
      return math.max(
        current,
        math.max(record.activeCustomers, record.newCustomers),
      );
    });
    final maxY = math.max(4, (highest * 1.25).ceil()).toDouble();
    final labelInterval = math.max(1, (records.length / 5).ceil());
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 10,
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(1, records.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(1, maxY / 4),
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: math.max(1, maxY / 4),
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: labelStyle,
                textAlign: TextAlign.right,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: labelInterval.toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= records.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(records[index].label, style: labelStyle),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < records.length; index++)
                FlSpot(
                  index.toDouble(),
                  records[index].activeCustomers.toDouble(),
                ),
            ],
            isCurved: true,
            curveSmoothness: 0.24,
            color: theme.colorScheme.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.09),
            ),
          ),
          LineChartBarData(
            spots: [
              for (var index = 0; index < records.length; index++)
                FlSpot(
                  index.toDouble(),
                  records[index].newCustomers.toDouble(),
                ),
            ],
            isCurved: true,
            curveSmoothness: 0.24,
            color: const Color(0xFF0F766E),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CustomerTrendEmpty extends StatelessWidget {
  const _CustomerTrendEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 30,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.theme, required this.message});

  final ThemeData theme;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class CustomerOverviewScopeToggle extends StatelessWidget {
  const CustomerOverviewScopeToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.compact,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: '${l10n.includeWalkIn}. ${l10n.walkInScopeDescription}',
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 19,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.includeWalkIn,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class TopCustomersPanel extends StatelessWidget {
  const TopCustomersPanel({
    super.key,
    required this.records,
    required this.compact,
    this.fillHeight = false,
  });

  final List<TopCustomerRecord> records;
  final bool compact;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 21,
                color: const Color(0xFFB45309),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.topCustomersTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            l10n.topCustomersSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (fillHeight)
            Expanded(
              child: _buildRecordsList(theme, l10n, currency, scrollable: true),
            )
          else if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  l10n.topCustomersEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            _buildRecordsList(theme, l10n, currency),
        ],
      ),
    );
  }

  Widget _buildRecordsList(
    ThemeData theme,
    AppLocalizations l10n,
    NumberFormat currency, {
    bool scrollable = false,
  }) {
    if (records.isEmpty) {
      return Center(
        child: Text(
          l10n.topCustomersEmpty,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: !scrollable,
      primary: false,
      physics: scrollable
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, _) => Divider(
        height: compact ? 14 : 16,
        color: theme.dividerColor.withValues(alpha: 0.65),
      ),
      itemBuilder: (context, index) {
        final record = records[index];
        final name = record.isWalkIn
            ? l10n.walkIn
            : (record.name.isEmpty ? l10n.customer : record.name);
        final rankColor = switch (index) {
          0 => const Color(0xFFB45309),
          1 => const Color(0xFF64748B),
          2 => const Color(0xFF9A3412),
          _ => theme.colorScheme.primary,
        };
        return Semantics(
          label:
              '${index + 1}. $name, ${l10n.customerTransactionCount(record.transactionCount)}, ${currency.format(record.totalSales)}',
          child: Row(
            children: [
              Container(
                width: compact ? 28 : 30,
                height: compact ? 28 : 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: rankColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.customerTransactionCount(record.transactionCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: compact ? 11 : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  currency.format(record.totalSales),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
