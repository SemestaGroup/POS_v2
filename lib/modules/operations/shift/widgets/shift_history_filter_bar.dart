import 'package:flutter/material.dart';

class ShiftHistoryFilterBar extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final int totalCount;
  final int openCount;
  final int closedCount;

  const ShiftHistoryFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.totalCount,
    required this.openCount,
    required this.closedCount,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final filterOptions = [
      ('all', 'Semua Sesi ($totalCount)'),
      ('open', 'Shift Aktif ($openCount)'),
      ('closed', 'Selesai ($closedCount)'),
    ];

    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filterOptions.map((option) {
          final filterKey = option.$1;
          final label = option.$2;
          final isSelected = selectedFilter == filterKey;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              selected: isSelected,
              onSelected: (val) {
                if (val) onFilterSelected(filterKey);
              },
              selectedColor: primaryColor,
              backgroundColor: const Color(0xFFF1F5F9),
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}
