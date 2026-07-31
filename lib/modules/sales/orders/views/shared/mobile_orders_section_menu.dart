import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';

/// Navigasi ringkas Sales Orders untuk presentation view mobile.
///
/// Widget ini tidak memiliki state atau logika navigasi; keputusan navigasi
/// tetap ditangani oleh coordinator melalui [onSelected].
class MobileOrdersSectionMenu extends StatelessWidget {
  const MobileOrdersSectionMenu({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <String>[
      l10n.posTitle,
      l10n.activeOrdersTitle,
      l10n.resumeOrderTitle,
      l10n.historyTitle,
    ];

    return PopupMenuButton<int>(
      tooltip: l10n.posTitle,
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      onSelected: onSelected,
      itemBuilder: (context) => List.generate(
        items.length,
        (index) => PopupMenuItem<int>(
          value: index,
          enabled: index != selectedIndex,
          child: Text(items[index]),
        ),
      ),
    );
  }
}
