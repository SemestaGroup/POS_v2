import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/marketplace_item.dart';
import 'inventory_common_widgets.dart';

class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.imageUrl,
    required this.label,
    this.size = 56,
  });

  final String? imageUrl;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final validUrl = (imageUrl ?? '').trim();
    final hasImage = validUrl.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    if (hasImage) {
      return SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: validUrl,
          fit: BoxFit.contain,
          placeholder: (_, _) => Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: scheme.primary.withValues(alpha: .6),
              ),
            ),
          ),
          errorWidget: (_, _, _) => _thumbnailFallback(scheme),
        ),
      );
    }
    return _thumbnailFallback(scheme);
  }

  Widget _thumbnailFallback(ColorScheme scheme) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.inventory_2_outlined,
          size: 21,
          color: scheme.onSurfaceVariant.withValues(alpha: .65),
        ),
      );
}

class MarketplaceItemRow extends StatelessWidget {
  const MarketplaceItemRow({
    super.key,
    required this.entry,
    required this.qty,
    required this.primaryColor,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  final CartEntry entry;
  final int qty;
  final Color primaryColor;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final hasGroup = entry.group != null && entry.group!.trim().isNotEmpty;
    final hasSku = entry.sku.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: .65),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProductThumbnail(
            imageUrl: entry.imageUrl,
            label: entry.name,
            size: 48,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
                if (hasGroup || hasSku) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (hasGroup) ...[
                        Flexible(
                          child: Text(
                            entry.group!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                      if (hasGroup && hasSku)
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
                      if (hasSku)
                        Text(
                          'SKU: ${entry.sku.trim()}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  rupiah(entry.unitCost),
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (qty == 0)
            SizedBox(
              height: 32,
              child: FilledButton.tonal(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor.withValues(alpha: 0.08),
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(0, 32),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14),
                    SizedBox(width: 3),
                    Text(
                      'Pesan',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onDecrement,
                    icon: Icon(
                      Icons.remove_rounded,
                      size: 14,
                      color: primaryColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '$qty',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onIncrement,
                    icon: Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: primaryColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
