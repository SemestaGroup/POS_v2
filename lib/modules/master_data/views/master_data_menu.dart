import 'package:flutter/material.dart';

import '../../../app/role_access/role_manager.dart';
import '../../../core/widgets/responsive/responsive_context.dart';
import '../../../l10n/app_localizations.dart';
import '../catalog/views/brands/brands_view.dart';
import '../catalog/views/categories/categories_view.dart';
import '../catalog/views/products/products_view.dart';
import '../catalog/views/promos/promos_view.dart';
import '../customers/views/customer_list/customer_list_view.dart';
import '../inventory/views/tablet_landscape/view.dart';
import '../staff/views/staff_list/staff_list_view.dart';
import '../staff/views/staff_roles/staff_roles_view.dart';

enum MasterDataMenuId {
  products,
  categories,
  brands,
  inventory,
  promos,
  customers,
  staff,
  staffRoles,
}

class MasterDataMenuDefinition {
  const MasterDataMenuDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.view,
    required this.allowedRoles,
  });

  final MasterDataMenuId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget view;
  final List<AppRole> allowedRoles;
}

List<MasterDataMenuDefinition> buildMasterDataMenus(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  const allowedRoles = [AppRole.owner, AppRole.supervisor];

  return [
    MasterDataMenuDefinition(
      id: MasterDataMenuId.products,
      title: l10n.productsMenu,
      subtitle: 'Kelola daftar produk & varian harga',
      icon: Icons.shopping_bag_rounded,
      view: const ProductsView(),
      allowedRoles: allowedRoles,
    ),
    MasterDataMenuDefinition(
      id: MasterDataMenuId.categories,
      title: l10n.categoriesMenu,
      subtitle: 'Pengelompokan kategori produk katalog',
      icon: Icons.category_rounded,
      view: const CategoriesView(),
      allowedRoles: allowedRoles,
    ),
    MasterDataMenuDefinition(
      id: MasterDataMenuId.brands,
      title: l10n.brandsMenu,
      subtitle: 'Kelola merek dagang produk toko',
      icon: Icons.branding_watermark_rounded,
      view: const BrandsView(),
      allowedRoles: allowedRoles,
    ),
    if (!context.isMobile)
      MasterDataMenuDefinition(
        id: MasterDataMenuId.inventory,
        title: l10n.inventoryMenu,
        subtitle: 'Kelola stok dan pembelian toko',
        icon: Icons.inventory_2_rounded,
        view: const InventoryShellView(),
        allowedRoles: allowedRoles,
      ),
    MasterDataMenuDefinition(
      id: MasterDataMenuId.promos,
      title: l10n.promosMenu,
      subtitle: 'Pengaturan diskon & bundling promo',
      icon: Icons.local_offer_rounded,
      view: const PromosView(),
      allowedRoles: allowedRoles,
    ),
    MasterDataMenuDefinition(
      id: MasterDataMenuId.customers,
      title: l10n.customerListMenu,
      subtitle: 'Database informasi pelanggan setia',
      icon: Icons.people_rounded,
      view: const CustomerListView(),
      allowedRoles: allowedRoles,
    ),
    MasterDataMenuDefinition(
      id: MasterDataMenuId.staff,
      title: l10n.staffListMenu,
      subtitle: 'Kelola akun kasir & otorisasi staf',
      icon: Icons.badge_rounded,
      view: const StaffListView(),
      allowedRoles: allowedRoles,
    ),
    MasterDataMenuDefinition(
      id: MasterDataMenuId.staffRoles,
      title: l10n.staffRolesMenu,
      subtitle: 'Pengaturan hak akses peran (role)',
      icon: Icons.admin_panel_settings_rounded,
      view: const StaffRolesView(),
      allowedRoles: allowedRoles,
    ),
  ];
}
