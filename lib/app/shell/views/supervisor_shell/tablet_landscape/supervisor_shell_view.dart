import 'package:flutter/material.dart';

import '../../../../../modules/overview/views/supervisor_overview/tablet_landscape/view.dart';
import '../../../../../modules/sales/pos/views/pos_workspace/tablet_landscape/view.dart';
import '../../../../../modules/operations/views/operations_shell_view.dart';
import '../../../../../modules/reports/views/reports_shell_view.dart';
import '../../../../../modules/master_data/views/master_data_shell_view.dart';
import '../../../widgets/sidebar_widget.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../modules/operations/shift/models/active_shift_store.dart';

class SupervisorShellView extends StatefulWidget {
  const SupervisorShellView({super.key});

  @override
  State<SupervisorShellView> createState() => _SupervisorShellViewState();
}

class _SupervisorShellViewState extends State<SupervisorShellView> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  bool _hasConfiguredInitialSidebar = false;
  double _maxScreenHeight = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasConfiguredInitialSidebar) return;

    _isSidebarCollapsed = MediaQuery.sizeOf(context).shortestSide < 600;
    _hasConfiguredInitialSidebar = true;
  }

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
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                SidebarWidget(
                  items: _menuItems,
                  selectedIndex: _selectedIndex,
                  onItemSelected: _selectSection,
                  isCollapsed: _isSidebarCollapsed,
                  onToggle: () {
                    setState(() {
                      _isSidebarCollapsed = !_isSidebarCollapsed;
                    });
                  },
                ),
                Expanded(child: _buildAnimatedBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectSection(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _isSidebarCollapsed = true;
      }
    });
  }

  Widget _buildAnimatedBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 120),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.9, end: 1).animate(animation),
          child: child,
        );
      },
      layoutBuilder: (currentChild, _) => currentChild ?? const SizedBox(),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const SupervisorOverviewView(key: ValueKey('spv_overview'));
      case 1:
        return PosWorkspaceView(
          key: const ValueKey('spv_sales'),
          isReadOnly: ActiveShiftStore.instance.isReadOnly,
        );
      case 2:
        return const OperationsShellView(key: ValueKey('spv_operations'));
      case 3:
        return const ReportsShellView(key: ValueKey('spv_reports'));
      case 4:
        return const MasterDataShellView(key: ValueKey('spv_master_data'));
      default:
        return const SupervisorOverviewView();
    }
  }
}
