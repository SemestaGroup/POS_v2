import 'package:flutter/material.dart';

import '../../../../../modules/sales/pos/views/pos_workspace/tablet_landscape/view.dart';
import '../../../../../modules/operations/views/tablet_landscape/view.dart';
import '../../../widgets/sidebar_widget.dart';
import '../../../../../l10n/app_localizations.dart';

class CashierShellView extends StatefulWidget {
  const CashierShellView({super.key});

  @override
  State<CashierShellView> createState() => _CashierShellViewState();
}

class _CashierShellViewState extends State<CashierShellView> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = true;
  double _maxScreenHeight = 0;

  List<SidebarItem> get _menuItems {
    final l10n = AppLocalizations.of(context)!;
    return [
      SidebarItem(
        title: l10n.sales,
        icon: Icons.shopping_bag_rounded,
        sectionLabel: 'SALES',
      ),
      SidebarItem(
        title: l10n.operations,
        icon: Icons.sync_alt_rounded,
        sectionLabel: 'OPERATIONS',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentHeight = MediaQuery.of(context).size.height;
    if (currentHeight > _maxScreenHeight) {
      _maxScreenHeight = currentHeight;
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: _maxScreenHeight > 0 ? _maxScreenHeight : currentHeight,
          child: DecoratedBox(
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
                      // Auto collapse on sales (index 0 for cashier)
                      if (index == 0) {
                        _isSidebarCollapsed = true;
                      }
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
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const PosWorkspaceView(key: ValueKey('cashier_sales'));
      case 1:
        return const OperationsShellView(key: ValueKey('cashier_operations'));
      default:
        return const PosWorkspaceView();
    }
  }
}
