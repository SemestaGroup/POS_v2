import 'package:flutter/material.dart';
import '../../../../../../core/widgets/responsive/responsive_context.dart';
import '../../../../../../l10n/app_localizations.dart';

class CustomerMetricsView extends StatelessWidget {
  const CustomerMetricsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isMobile = context.isMobile;

    if (isMobile) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title
            const Text(
              'RINGKASAN PELANGGAN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            // KPI Cards in a Column (beautiful list row style)
            Column(
              children: [
                _buildKpiCard(
                  theme,
                  l10n.totalCustomers,
                  '1,240',
                  l10n.newCustomersToday(25),
                  Icons.people_outline_rounded,
                  isMobile: true,
                  customBg: const Color(0xFFEFF6FF),
                  iconBg: const Color(0xFFDBEAFE),
                  iconColor: const Color(0xFF1D4ED8),
                ),
                const SizedBox(height: 10),
                _buildKpiCard(
                  theme,
                  l10n.activeCustomers,
                  '850',
                  l10n.inLast30Days,
                  Icons.person_pin_circle_outlined,
                  isMobile: true,
                  customBg: const Color(0xFFECFDF5),
                  iconBg: const Color(0xFFD1FAE5),
                  iconColor: const Color(0xFF047857),
                ),
                const SizedBox(height: 10),
                _buildKpiCard(
                  theme,
                  l10n.averageVisits,
                  '2.4',
                  l10n.visitsPerMonth,
                  Icons.repeat_rounded,
                  isMobile: true,
                  customBg: const Color(0xFFFFFBEB),
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFB45309),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Section Title
            const Text(
              'TREN KUNJUNGAN PELANGGAN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            // Placeholder for Customer Chart
            Container(
              height: 210,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade100,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative mini bar chart layout behind text
                  Positioned(
                    bottom: 16,
                    left: 24,
                    right: 24,
                    child: SizedBox(
                      height: 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(12, (index) {
                          final double h = (index * 7 % 30 + 10).toDouble();
                          return Container(
                            width: 14,
                            height: h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            size: 24,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.customerChartNotAvailable,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.waitingForDesignData,
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                        ),
                        const SizedBox(height: 20), // push text above bars
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Cards
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    theme,
                    l10n.totalCustomers,
                    '1,240',
                    l10n.newCustomersToday(25),
                    Icons.people_outline_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKpiCard(
                    theme,
                    l10n.activeCustomers,
                    '850',
                    l10n.inLast30Days,
                    Icons.person_pin_circle_outlined,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildKpiCard(
                    theme,
                    l10n.averageVisits,
                    '2.4',
                    l10n.visitsPerMonth,
                    Icons.repeat_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Placeholder for Customer Chart
          Container(
            height: 400,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.customerChartNotAvailable,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.waitingForDesignData,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
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
    IconData icon, {
    bool isMobile = false,
    Color? customBg,
    Color? iconBg,
    Color? iconColor,
  }) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: customBg ?? Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: customBg != null ? Colors.transparent : theme.dividerColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg ?? theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor ?? theme.colorScheme.primary),
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
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
        ],
      ),
    );
  }
}
