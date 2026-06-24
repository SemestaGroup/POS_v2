import 'package:flutter/material.dart';

import '../../../../../modules/overview/views/owner_overview/tablet_landscape/view.dart';
import '../../../../../modules/sales/pos/views/pos_workspace/tablet_landscape/view.dart';
import '../../../../../modules/operations/views/tablet_landscape/view.dart';
import '../../../../../modules/reports/views/tablet_landscape/view.dart';
import '../../../../../modules/master_data/views/tablet_landscape/view.dart';
import '../../../../../modules/settings/views/tablet_landscape/view.dart';
import '../../../widgets/sidebar_widget.dart';
import '../../../../../l10n/app_localizations.dart';

class OwnerShellView extends StatefulWidget {
  const OwnerShellView({super.key});

  @override
  State<OwnerShellView> createState() => _OwnerShellViewState();
}

class _OwnerShellViewState extends State<OwnerShellView> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  double _maxScreenHeight = 0;

  List<SidebarItem> get _menuItems {
    final l10n = AppLocalizations.of(context)!;
    return [
      SidebarItem(
        title: l10n.overview,
        icon: Icons.dashboard_rounded,
        sectionLabel: 'OVERVIEW',
      ),
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
      SidebarItem(
        title: l10n.reports,
        icon: Icons.bar_chart_rounded,
        sectionLabel: 'REPORTS',
      ),
      SidebarItem(
        title: l10n.masterData,
        icon: Icons.folder_open_rounded,
        sectionLabel: 'MASTER DATA',
      ),
      SidebarItem(
        title: l10n.settings,
        icon: Icons.settings_rounded,
        sectionLabel: 'SETTINGS',
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
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          height: _maxScreenHeight > 0 ? _maxScreenHeight : currentHeight,
          child: SafeArea(
            child: Row(
              children: [
                SidebarWidget(
                  items: _menuItems,
                  selectedIndex: _selectedIndex,
                  onItemSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                      // Auto collapse on sales
                      if (index == 1) {
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
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
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
        return const OwnerOverviewView(key: ValueKey('owner_overview'));
      case 1:
        return const PosWorkspaceView(key: ValueKey('owner_sales'));
      case 2:
        return const OperationsShellView(key: ValueKey('owner_operations'));
      case 3:
        return const ReportsShellView(key: ValueKey('owner_reports'));
      case 4:
        return const MasterDataShellView(key: ValueKey('owner_master_data'));
      case 5:
        return const SettingsShellView(key: ValueKey('owner_settings'));
      default:
        return const OwnerOverviewView();
    }
  }
}
