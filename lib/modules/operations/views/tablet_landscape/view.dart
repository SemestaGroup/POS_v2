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
          final isMobile = MediaQuery.of(context).size.shortestSide < 600;
          final filteredSubMenus = _allSubMenus
              .where((menu) => menu.allowedRoles.contains(activeRole))
              .toList();

          if (filteredSubMenus.isEmpty) {
            return Center(child: Text(l10n.operationsUnavailableMessage));
          }

          if (isMobile) {
            final shiftTypes = [
              ShiftOpenView,
              ShiftCloseView,
              CashFlowView,
              ShiftHistoryView,
            ];

            final shiftMenus = filteredSubMenus.where((menu) {
              return shiftTypes.contains(menu.view.runtimeType);
            }).toList();

            final managementMenus = filteredSubMenus.where((menu) {
              return !shiftTypes.contains(menu.view.runtimeType);
            }).toList();

            return Scaffold(
              backgroundColor: const Color(0xFFF8F9FD),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                title: Text(
                  l10n.operationsHeader,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
                centerTitle: false,
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (shiftMenus.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10, top: 4),
                      child: Text(
                        'TRANSAKSI & SHIFT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    ...shiftMenus.map(
                      (menu) => _buildMobileMenuCard(context, menu),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (managementMenus.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'MANAJEMEN & MONITORING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    ...managementMenus.map(
                      (menu) => _buildMobileMenuCard(context, menu),
                    ),
                  ],
                ],
              ),
            );
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
                                    child: IndexedStack(
                                      index: safeIndex,
                                      children: filteredSubMenus
                                          .map((m) => m.view)
                                          .toList(),
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

  Color getMenuBgColor(Type viewType) {
    if (viewType == ShiftOpenView) return const Color(0xFFECFDF5);
    if (viewType == ShiftCloseView) return const Color(0xFFFEF2F2);
    if (viewType == RecapView) return const Color(0xFFEEF2FF);
    if (viewType == ShiftHistoryView) return const Color(0xFFF1F5F9);
    if (viewType == CashFlowView) return const Color(0xFFFFFBEB);
    if (viewType == KitchenMonitorView) return const Color(0xFFF5F3FF);
    return const Color(0xFFF0FDFA);
  }

  Color getMenuIconColor(Type viewType) {
    if (viewType == ShiftOpenView) return const Color(0xFF059669);
    if (viewType == ShiftCloseView) return const Color(0xFFDC2626);
    if (viewType == RecapView) return const Color(0xFF4F46E5);
    if (viewType == ShiftHistoryView) return const Color(0xFF475569);
    if (viewType == CashFlowView) return const Color(0xFFD97706);
    if (viewType == KitchenMonitorView) return const Color(0xFF7C3AED);
    return const Color(0xFF0D9488);
  }

  Widget _buildMobileMenuCard(BuildContext context, _SubMenuDefinition menu) {
    final bgColor = getMenuBgColor(menu.view.runtimeType);
    final iconColor = getMenuIconColor(menu.view.runtimeType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(menu.icon, color: iconColor, size: 22),
          ),
          title: Text(
            menu.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1D2E),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              menu.subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey.shade400,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: Color(0xFF1A1D2E),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Text(
                      menu.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    centerTitle: true,
                  ),
                  body: menu.view,
                ),
              ),
            );
          },
        ),
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
