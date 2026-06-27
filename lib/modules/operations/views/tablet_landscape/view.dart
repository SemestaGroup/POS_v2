import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../master_data/customers/views/customer_list/tablet_landscape/view.dart';
import '../../shift/views/shift_open/tablet_landscape/view.dart';
import '../../shift/views/shift_close/tablet_landscape/view.dart';
import '../../recap/views/tablet_landscape/view.dart';
import '../../cash_flow/views/tablet_landscape/view.dart';
import '../../kitchen/views/tablet_landscape/view.dart';
import '../../shift/views/shift_history/tablet_landscape/view.dart';
import '../../../../app/role_access/role_manager.dart';

class _SubMenuDefinition {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget view;
  final List<AppRole> allowedRoles;

  _SubMenuDefinition({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.view,
    required this.allowedRoles,
  });
}

class OperationsShellView extends StatefulWidget {
  const OperationsShellView({super.key});

  @override
  State<OperationsShellView> createState() => _OperationsShellViewState();
}

class _OperationsShellViewState extends State<OperationsShellView> {
  int _selectedSubMenuIndex = 0;

  List<_SubMenuDefinition> get _allSubMenus {
    final l10n = AppLocalizations.of(context)!;
    return [
      _SubMenuDefinition(
        title: l10n.shiftMenu,
        subtitle: 'Buka shift kasir',
        icon: Icons.access_time_rounded,
        view: const ShiftOpenView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor, AppRole.cashier],
      ),
      _SubMenuDefinition(
        title: 'Tutup Shift',
        subtitle: 'Tutup dan rekonsiliasi shift',
        icon: Icons.lock_clock_outlined,
        view: const ShiftCloseView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor, AppRole.cashier],
      ),
      _SubMenuDefinition(
        title: l10n.recapMenu,
        subtitle: 'Shift and daily recaps',
        icon: Icons.receipt_long_rounded,
        view: const RecapView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: 'Riwayat Shift',
        subtitle: 'Histori shift dari database lokal',
        icon: Icons.history_toggle_off_rounded,
        view: const ShiftHistoryView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor, AppRole.cashier],
      ),
      _SubMenuDefinition(
        title: l10n.cashFlowMenu,
        subtitle: 'Cash in & out',
        icon: Icons.account_balance_wallet_rounded,
        view: const CashFlowView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor, AppRole.cashier],
      ),
      _SubMenuDefinition(
        title: l10n.kitchenMonitorMenu,
        subtitle: 'Live kitchen orders',
        icon: Icons.restaurant_rounded,
        view: const KitchenMonitorView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor, AppRole.kitchen],
      ),
      _SubMenuDefinition(
        title: l10n.customerListMenu,
        subtitle: 'Customer database',
        icon: Icons.people_rounded,
        view: const CustomerListView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor, AppRole.cashier],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ValueListenableBuilder<AppRole>(
        valueListenable: RoleManager.roleNotifier,
        builder: (context, activeRole, _) {
          final filteredSubMenus = _allSubMenus
              .where((menu) => menu.allowedRoles.contains(activeRole))
              .toList();

          if (filteredSubMenus.isEmpty) {
            return Center(child: Text(l10n.operationsUnavailableMessage));
          }

          if (_selectedSubMenuIndex >= filteredSubMenus.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedSubMenuIndex = 0;
                });
              }
            });
          }
          final safeIndex = _selectedSubMenuIndex < filteredSubMenus.length
              ? _selectedSubMenuIndex
              : 0;

          final selectedCategory = filteredSubMenus[safeIndex];

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Page Header (outside card) ──────────────────────────────
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

                // ── Main Card (sidebar + content) ────────────────────────────
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F2FF), // Soft greyish blue
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
                            // ── Sidebar ─────────────────────────────────────────
                            _buildSidebar(
                              theme,
                              primaryColor,
                              filteredSubMenus,
                              safeIndex,
                            ),

                            // ── Divider ─────────────────────────────────────────
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Colors.grey.shade100,
                            ),

                            // ── Content ─────────────────────────────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      layoutBuilder: (currentChild, previousChildren) {
                                        return Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ...previousChildren,
                                            ...[currentChild].whereType<Widget>(),
                                          ],
                                        );
                                      },
                                      child: selectedCategory.view,
                                    ),
                                  ),
                                ],
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
    ThemeData theme,
    Color primaryColor,
    List<_SubMenuDefinition> filteredCategories,
    int safeIndex,
  ) {
    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: filteredCategories.length,
          itemBuilder: (context, index) {
            final isSelected = safeIndex == index;
            final category = filteredCategories[index];

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedSubMenuIndex = index;
                });
              },
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
