import 'package:flutter/material.dart';

import '../../../stores/inventory_read_stores.dart';
import 'inventory_common_widgets.dart';
import 'marketplace_item_row.dart';

class InventoryCard extends StatelessWidget {
  const InventoryCard({super.key, required this.item});
  final InventoryItemRecord item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final low = item.isLowStock;
    final color = item.isOutOfStock
        ? const Color(0xFFEF4444)
        : low
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);
    return Container(
      decoration: cardDecoration(context),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProductThumbnail(
                imageUrl: item.imageUrl,
                label: item.displayName,
                size: 42,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.categoryName} • ${item.sku}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              PillWidget(
                label: item.isOutOfStock
                    ? 'Habis'
                    : low
                        ? 'Menipis'
                        : 'Aman',
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                MetricWidget(
                  label: 'Stok',
                  value: item.stockQuantity.toStringAsFixed(0),
                ),
                MetricWidget(
                  label: 'Minimum',
                  value: item.minStockLevel.toStringAsFixed(0),
                ),
                MetricWidget(
                  label: 'Harga Beli',
                  value: rupiah(item.costAmount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
