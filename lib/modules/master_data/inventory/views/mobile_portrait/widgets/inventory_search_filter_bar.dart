import 'package:flutter/material.dart';

import '../../../models/marketplace_item.dart';

class MobileSearchField extends StatelessWidget {
  const MobileSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(12);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: .65),
      ),
    );
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 13, color: scheme.onSurface),
        decoration: InputDecoration(
          filled: true,
          fillColor: scheme.surface,
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 19,
            color: scheme.onSurfaceVariant,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ),
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.primary, width: 1.3),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

class InventoryFilterButton extends StatelessWidget {
  const InventoryFilterButton({
    super.key,
    required this.activeCount,
    required this.onPressed,
  });

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = activeCount > 0;
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: isActive ? scheme.primary : scheme.onSurfaceVariant,
          side: BorderSide(
            color: isActive ? scheme.primary : scheme.outlineVariant,
            width: isActive ? 1.2 : 1.0,
          ),
          backgroundColor:
              isActive ? scheme.primary.withValues(alpha: .06) : scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 17,
              color: isActive ? scheme.primary : scheme.onSurfaceVariant,
            ),
            if (activeCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$activeCount',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InventoryFilterDropdown extends StatelessWidget {
  const InventoryFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final String hint;
  final List<DropdownMenuItem<int>> items;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return DropdownButtonFormField<int>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: .38),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.3),
        ),
      ),
      hint: Text(hint),
      items: items,
      onChanged: onChanged,
    );
  }
}

class StockFilterBar extends StatelessWidget {
  const StockFilterBar({
    super.key,
    required this.selected,
    required this.attentionCount,
    required this.onChanged,
  });

  final StockFilter selected;
  final int attentionCount;
  final ValueChanged<StockFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = <(StockFilter, String)>[
      (StockFilter.all, 'Semua'),
      (StockFilter.needsAttention, 'Perlu Perhatian'),
      (StockFilter.outOfStock, 'Habis'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final filter = item.$1;
          final label = item.$2;
          final isSelected = selected == filter;
          final badgeCount =
              filter == StockFilter.needsAttention ? attentionCount : 0;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              selected: isSelected,
              onSelected: (_) => onChanged(filter),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              selectedColor: scheme.primary,
              backgroundColor:
                  scheme.surfaceContainerHighest.withValues(alpha: .45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: .5),
                ),
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.onPrimary.withValues(alpha: .25)
                            : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? scheme.onPrimary : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
