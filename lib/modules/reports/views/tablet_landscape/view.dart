import 'package:flutter/material.dart';

import '../../../../core/widgets/navigation/mobile_section_menu_page.dart';
import '../../../../l10n/app_localizations.dart';
import '../report_summary/tablet_landscape/view.dart';
import '../sales_report/tablet_landscape/view.dart';
import '../product_report/tablet_landscape/view.dart';
import '../staff_report/tablet_landscape/view.dart';
import '../cashier_report_lite/tablet_landscape/view.dart';
import '../mobile_portrait/view.dart';
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

class ReportsShellView extends StatefulWidget {
  const ReportsShellView({super.key});

  @override
  State<ReportsShellView> createState() => _ReportsShellViewState();
}

class _ReportsShellViewState extends State<ReportsShellView> {
  int _selectedSubMenuIndex = 0;

  List<_SubMenuDefinition> get _allSubMenus {
    final l10n = AppLocalizations.of(context)!;
    return [
      _SubMenuDefinition(
        title: l10n.reportSummaryMenu,
        subtitle: 'Ikhtisar performa penjualan toko',
        icon: Icons.summarize_rounded,
        view: const ReportSummaryView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.salesReportMenu,
        subtitle: 'Analisis omzet & grafik harian',
        icon: Icons.trending_up_rounded,
        view: const SalesReportView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.productReportMenu,
        subtitle: 'Performa & kontribusi produk terlaris',
        icon: Icons.inventory_2_rounded,
        view: const ProductReportView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.staffReportMenu,
        subtitle: 'Performa staf & riwayat transaksi',
        icon: Icons.people_outline_rounded,
        view: const StaffReportView(),
        allowedRoles: [AppRole.owner],
      ),
      _SubMenuDefinition(
        title: l10n.cashierReportLiteMenu,
        subtitle: 'Laporan per kasir & setoran uang',
        icon: Icons.point_of_sale_rounded,
        view: const CashierReportLiteView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
    ];
  }

  Color getReportBgColor(Type viewType) {
    if (viewType == ReportSummaryView) return const Color(0xFFEEF2FF);
    if (viewType == SalesReportView) return const Color(0xFFECFDF5);
    if (viewType == ProductReportView) return const Color(0xFFFFFBEB);
    if (viewType == StaffReportView) return const Color(0xFFF5F3FF);
    if (viewType == CashierReportLiteView) return const Color(0xFFF0FDFA);
    return const Color(0xFFF1F5F9);
  }

  Color getReportIconColor(Type viewType) {
    if (viewType == ReportSummaryView) return const Color(0xFF4F46E5);
    if (viewType == SalesReportView) return const Color(0xFF059669);
    if (viewType == ProductReportView) return const Color(0xFFD97706);
    if (viewType == StaffReportView) return const Color(0xFF7C3AED);
    if (viewType == CashierReportLiteView) return const Color(0xFF0D9488);
    return const Color(0xFF475569);
  }

  Widget _buildMobileReports(List<_SubMenuDefinition> subMenus) {
    return ReportsMobileView(
      items: subMenus
          .map(
            (menu) => MobileMenuItem(
              title: menu.title,
              subtitle: menu.subtitle,
              icon: menu.icon,
              iconBackground: getReportBgColor(menu.view.runtimeType),
              iconColor: getReportIconColor(menu.view.runtimeType),
              view: menu.view,
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final isMobile = MediaQuery.of(context).size.shortestSide < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ValueListenableBuilder<AppRole>(
        valueListenable: RoleManager.roleNotifier,
        builder: (context, activeRole, _) {
          final filteredSubMenus = _allSubMenus
              .where((menu) => menu.allowedRoles.contains(activeRole))
              .toList();

          if (filteredSubMenus.isEmpty) {
            return Center(child: Text(l10n.reportsUnavailableMessage));
          }

          if (isMobile) {
            return _buildMobileReports(filteredSubMenus);
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

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildReportsSidebar(
                theme,
                primaryColor,
                filteredSubMenus,
                safeIndex,
                l10n,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: filteredSubMenus[safeIndex].view,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportsSidebar(
    ThemeData theme,
    Color primaryColor,
    List<_SubMenuDefinition> filteredSubMenus,
    int safeIndex,
    AppLocalizations l10n,
  ) {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    size: 18,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reports,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.reportsSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: filteredSubMenus.length,
              itemBuilder: (context, index) {
                final isSelected = safeIndex == index;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSubMenuIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor.withValues(alpha: 0.08)
                          : const Color(0xFFF8F9FD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? primaryColor.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor
                                : Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            filteredSubMenus[index].title,
                            style: TextStyle(
                              color: isSelected
                                  ? primaryColor
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: isSelected
                              ? primaryColor
                              : Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
