import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../operations_menu.dart';

class OperationsTabletLandscapeView extends StatefulWidget {
  const OperationsTabletLandscapeView({required this.subMenus, super.key});

  final List<OperationsMenuDefinition> subMenus;

  @override
  State<OperationsTabletLandscapeView> createState() =>
      _OperationsTabletLandscapeViewState();
}

class _OperationsTabletLandscapeViewState
    extends State<OperationsTabletLandscapeView> {
  int _selectedSubMenuIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Builder(
        builder: (context) {
          if (_selectedSubMenuIndex >= widget.subMenus.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _selectedSubMenuIndex = 0);
              }
            });
          }
          final safeIndex = _selectedSubMenuIndex < widget.subMenus.length
              ? _selectedSubMenuIndex
              : 0;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.sync_alt_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.operationsHeader,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1D2E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.operationsSubtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F2FF),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSidebar(
                              primaryColor,
                              widget.subMenus,
                              safeIndex,
                            ),
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Colors.grey.shade100,
                            ),
                            Expanded(
                              child: IndexedStack(
                                index: safeIndex,
                                children: widget.subMenus
                                    .map((menu) => menu.view)
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(
    Color primaryColor,
    List<OperationsMenuDefinition> categories,
    int safeIndex,
  ) {
    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final isSelected = safeIndex == index;
            final category = categories[index];

            return InkWell(
              onTap: () => setState(() => _selectedSubMenuIndex = index),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      category.icon,
                      size: 18,
                      color: isSelected ? primaryColor : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? primaryColor
                              : Colors.grey.shade600,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: primaryColor,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
