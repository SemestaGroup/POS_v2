import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SubMenuSidebarWidget extends StatelessWidget {
  const SubMenuSidebarWidget({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: const BoxDecoration(
        color: AppColors.primary,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 44), // To align with the top spacing of main sidebar
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final isSelected = selectedIndex == index;
                  return InkWell(
                    onTap: () => onItemSelected(index),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        items[index],
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.78),
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
