import 'package:flutter/material.dart';

import '../../../../app/role_access/role_manager.dart';
import '../../../../l10n/app_localizations.dart';
import '../../catalog/views/brands/tablet_landscape/view.dart';
import '../../catalog/views/categories/tablet_landscape/view.dart';
import '../../catalog/views/products/tablet_landscape/view.dart';
import '../../catalog/views/promos/tablet_landscape/view.dart';
import '../../customers/views/customer_list/tablet_landscape/view.dart';
import '../../staff/views/staff_list/tablet_landscape/view.dart';
import '../../staff/views/staff_roles/tablet_landscape/view.dart';

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
        subtitle: 'Kelola daftar produk & varian harga',
        icon: Icons.shopping_bag_rounded,
        view: const ProductsView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.categoriesMenu,
        subtitle: 'Pengelompokan kategori produk katalog',
        icon: Icons.category_rounded,
        view: const CategoriesView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.brandsMenu,
        subtitle: 'Kelola merek dagang produk toko',
        icon: Icons.branding_watermark_rounded,
        view: const BrandsView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.promosMenu,
        subtitle: 'Pengaturan diskon & bundling promo',
        icon: Icons.local_offer_rounded,
        view: const PromosView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.customerListMenu,
        subtitle: 'Database informasi pelanggan setia',
        icon: Icons.people_rounded,
        view: const CustomerListView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.staffListMenu,
        subtitle: 'Kelola akun kasir & otorisasi staf',
        icon: Icons.badge_rounded,
        view: const StaffListView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
      _SubMenuDefinition(
        title: l10n.staffRolesMenu,
        subtitle: 'Pengaturan hak akses peran (role)',
        icon: Icons.admin_panel_settings_rounded,
        view: const StaffRolesView(),
        allowedRoles: [AppRole.owner, AppRole.supervisor],
      ),
    ];
  }

  Color getMasterDataBgColor(Type viewType) {
    if (viewType == ProductsView) return const Color(0xFFEFF6FF);
    if (viewType == CategoriesView) return const Color(0xFFF5F3FF);
    if (viewType == BrandsView) return const Color(0xFFF0FDF4);
    if (viewType == PromosView) return const Color(0xFFFFFBEB);
    if (viewType == CustomerListView) return const Color(0xFFFDF2F8);
    if (viewType == StaffListView) return const Color(0xFFECFDF5);
    if (viewType == StaffRolesView) return const Color(0xFFFAF5FF);
    return const Color(0xFFF1F5F9);
  }

  Color getMasterDataIconColor(Type viewType) {
    if (viewType == ProductsView) return const Color(0xFF1D4ED8);
    if (viewType == CategoriesView) return const Color(0xFF7C3AED);
    if (viewType == BrandsView) return const Color(0xFF16A34A);
    if (viewType == PromosView) return const Color(0xFFD97706);
    if (viewType == CustomerListView) return const Color(0xFFDB2777);
    if (viewType == StaffListView) return const Color(0xFF059669);
    if (viewType == StaffRolesView) return const Color(0xFF8B5CF6);
    return const Color(0xFF475569);
  }

  Widget _buildMobileMasterData(
    BuildContext context,
    List<_SubMenuDefinition> subMenus,
    ThemeData theme,
    Color primaryColor,
    AppLocalizations l10n,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.masterData,
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
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10, top: 4),
            child: Text(
              'KATALOG & PERANGKAT TOKO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8E8E93),
                letterSpacing: 1.0,
              ),
            ),
          ),
          ...subMenus.map((menu) {
            final bgColor = getMasterDataBgColor(menu.view.runtimeType);
            final iconColor = getMasterDataIconColor(menu.view.runtimeType);

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
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
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
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
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
          }),
        ],
      ),
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
            return Center(child: Text(l10n.masterDataUnavailableMessage));
          }

          if (isMobile) {
            return _buildMobileMasterData(
              context,
              filteredSubMenus,
              theme,
              primaryColor,
              l10n,
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
