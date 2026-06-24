import 'package:flutter/material.dart';

import '../../../../app/role_access/role_manager.dart';
import '../../../../l10n/app_localizations.dart';
import '../../catalog/views/brands/tablet_landscape/view.dart';
import '../../catalog/views/categories/tablet_landscape/view.dart';
import '../../catalog/views/products/tablet_landscape/view.dart';
import '../../catalog/views/promos/tablet_landscape/view.dart';
import '../../customers/views/customer_detail/tablet_landscape/view.dart';
import '../../customers/views/customer_list/tablet_landscape/view.dart';
import '../../staff/views/staff_list/tablet_landscape/view.dart';
import '../../staff/views/staff_roles/tablet_landscape/view.dart';

class _SubMenuDefinition {
  final String title;
  final Widget view;
  final List<AppRole> allowedRoles;

  _SubMenuDefinition({
    required this.title,
    required this.view,
    required this.allowedRoles,
  });
}

class MasterDataShellView extends StatefulWidget {
  const MasterDataShellView({super.key});

  @override
  State<MasterDataShellView> createState() => _MasterDataShellViewState();
}

class _MasterDataShellViewState extends State<MasterDataShellView> {
  int _selectedSubMenuIndex = 0;

  List<_SubMenuDefinition> get _allSubMenus {
    final l10n = AppLocalizations.of(context)!;
    return [
      _SubMenuDefinition(
        title: l10n.productsMenu,
        view: const ProductsView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.categoriesMenu,
        view: const CategoriesView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.brandsMenu,
        view: const BrandsView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.promosMenu,
        view: const PromosView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.customerListMenu,
        view: const CustomerListView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.customerDetailMenu,
        view: const CustomerDetailView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.staffListMenu,
        view: const StaffListView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.staffRolesMenu,
        view: const StaffRolesView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ValueListenableBuilder<AppRole>(
        valueListenable: RoleManager.roleNotifier,
        builder: (context, activeRole, _) {
          final filteredSubMenus = _allSubMenus
              .where((menu) => menu.allowedRoles.contains(activeRole))
              .toList();

          if (filteredSubMenus.isEmpty) {
            return Center(child: Text(l10n.masterDataUnavailableMessage));
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
              _buildSidebar(
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

  Widget _buildSidebar(
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
                    Icons.folder_open_rounded,
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
                        l10n.masterData,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.masterDataSubtitle,
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
