import 'package:flutter/material.dart';

/// Small building blocks shared by the customer and promo report tabs.

class ReportPeriodChip extends StatelessWidget {
  const ReportPeriodChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primary : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isActive ? primary : Colors.grey.shade200),
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
}

/// Today / 7 days / this month chips plus a refresh button. Scrolls sideways
/// instead of wrapping so the header height never grows on narrow screens.
class ReportPeriodBar extends StatelessWidget {
  const ReportPeriodBar({
    required this.period,
    required this.onPeriodChanged,
    required this.onRefresh,
    this.trailing,
    super.key,
  });

  final String period;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onRefresh;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const options = <(String, String)>[
      ('Hari Ini', 'today'),
      ('7 Hari', 'week'),
      ('Bulan Ini', 'month'),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (label, value) in options) ...[
                    ReportPeriodChip(
                      label: label,
                      isActive: period == value,
                      onTap: () => onPeriodChanged(value),
                    ),
                    const SizedBox(width: 6),
                  ],
                  ?trailing,
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: primary,
            tooltip: 'Muat ulang',
          ),
        ],
      ),
    );
  }
}

class ReportStripItem {
  const ReportStripItem(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}

class ReportSummaryStrip extends StatelessWidget {
  const ReportSummaryStrip({required this.items, super.key});

  final List<ReportStripItem> items;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFFE5E7EB),
          ),
        );
      }
      final item = items[i];
      children.add(
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                item.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: item.color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: primary.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: children),
    );
  }
}

class ReportColumn {
  const ReportColumn(this.label, this.flex, {this.alignEnd = false});

  final String label;
  final int flex;
  final bool alignEnd;
}

class ReportTableHeader extends StatelessWidget {
  const ReportTableHeader({required this.columns, super.key});

  final List<ReportColumn> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: [
          for (final column in columns)
            Expanded(
              flex: column.flex,
              child: Text(
                column.label,
                textAlign: column.alignEnd ? TextAlign.end : TextAlign.start,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ReportCell extends StatelessWidget {
  const ReportCell(
    this.value,
    this.flex, {
    this.bold = false,
    this.muted = false,
    this.alignEnd = false,
    this.color,
    super.key,
  });

  final String value;
  final int flex;
  final bool bold;
  final bool muted;
  final bool alignEnd;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color:
              color ?? (muted ? Colors.grey.shade400 : const Color(0xFF374151)),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
