import 'package:flutter/material.dart';

import '../../../../../modules/operations/views/tablet_landscape/view.dart';
import '../../../widgets/sidebar_widget.dart';
import '../../../../../l10n/app_localizations.dart';

class KitchenShellView extends StatefulWidget {
  const KitchenShellView({super.key});

  @override
  State<KitchenShellView> createState() => _KitchenShellViewState();
}

class _KitchenShellViewState extends State<KitchenShellView> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  List<SidebarItem> get _menuItems {
    final l10n = AppLocalizations.of(context)!;
    return [
      SidebarItem(
        title: l10n.operations,
        icon: Icons.sync_alt_rounded,
        sectionLabel: 'OPERATIONS',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).scaffoldBackgroundColor, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            SidebarWidget(
              items: _menuItems,
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              isCollapsed: _isSidebarCollapsed,
              onToggle: () {
                setState(() {
                  _isSidebarCollapsed = !_isSidebarCollapsed;
                });
              },
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final child in previousChildren)
                        IgnorePointer(child: child),
                      ...[currentChild].whereType<Widget>(),
                    ],
                  );
                },
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const OperationsShellView(key: ValueKey('kitchen_operations'));
      default:
        return const OperationsShellView();
    }
  }
}
