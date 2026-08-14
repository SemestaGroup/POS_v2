import 'package:flutter/material.dart';

import '../../../stores/inventory_read_stores.dart';
import 'inventory_common_widgets.dart';

class PurchaseOrderStatus {
  const PurchaseOrderStatus(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

PurchaseOrderStatus getPurchaseOrderStatus(String status) => switch (status) {
      'processing' => const PurchaseOrderStatus(
          'Diproses',
          Color(0xFF2563EB),
          Icons.sync_rounded,
        ),
      'completed' => const PurchaseOrderStatus(
          'Selesai',
          Color(0xFF10B981),
          Icons.check_circle_rounded,
        ),
      'failed' => const PurchaseOrderStatus(
          'Gagal',
          Color(0xFFEF4444),
          Icons.cancel_rounded,
        ),
      _ => const PurchaseOrderStatus(
          'Dipesan',
          Color(0xFFD97706),
          Icons.hourglass_top_rounded,
        ),
    };

class PurchaseOrderOverview extends StatelessWidget {
  const PurchaseOrderOverview({
    super.key,
    required this.orderCount,
    required this.pendingCount,
    required this.processingCount,
  });

  final int orderCount;
  final int pendingCount;
  final int processingCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$orderCount Purchase Order',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  pendingCount == 0 && processingCount == 0
                      ? 'Semua pengajuan telah diproses'
                      : '$pendingCount dipesan • $processingCount diproses',
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
            height: 32,
            color: scheme.onPrimary.withValues(alpha: .2),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pendingCount',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Menunggu',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: .75),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PurchaseOrderCard extends StatelessWidget {
  const PurchaseOrderCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  final PurchaseOrderRecord order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = getPurchaseOrderStatus(order.status);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: cardDecoration(context),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  status.icon,
                  color: status.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.poCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        PillWidget(label: status.label, color: status.color),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          formatRequestDate(order.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        Text(
                          '${order.itemCount} unit',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rupiah(order.totalAmount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
