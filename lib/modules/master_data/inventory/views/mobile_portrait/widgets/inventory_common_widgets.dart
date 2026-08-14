import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

BoxDecoration cardDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
  );
}

String formatRequestDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value.isEmpty ? '—' : value;
  return DateFormat('d MMM, HH:mm', 'id_ID').format(date);
}

String rupiah(int value) =>
    'Rp ${NumberFormat.decimalPattern('id_ID').format(value)}';

class SummaryStat extends StatelessWidget {
  const SummaryStat({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            color: onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: onPrimary.withValues(alpha: .75),
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.count,
    required this.lowStock,
    required this.outOfStock,
  });

  final int count;
  final int lowStock;
  final int outOfStock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count barang terpantau',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  lowStock == 0
                      ? 'Semua stok aman.'
                      : '$lowStock barang perlu perhatian.',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: .75),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: scheme.onPrimary.withValues(alpha: .18),
          ),
          const SizedBox(width: 14),
          SummaryStat(label: 'Tersisa low', value: '$lowStock'),
        ],
      ),
    );
  }
}

class MetricWidget extends StatelessWidget {
  const MetricWidget({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
}

class PillWidget extends StatelessWidget {
  const PillWidget({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class InventoryEmptyState extends StatelessWidget {
  const InventoryEmptyState({super.key, required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 38),
        decoration: cardDecoration(context),
        child: Column(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 34,
              color: Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 10),
            Text(
              hasFilter ? 'Tidak ada stok yang cocok' : 'Inventaris masih kosong',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              hasFilter
                  ? 'Coba kata kunci atau filter lain.'
                  : 'Barang yang tersedia akan muncul di sini.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
}

class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
}
