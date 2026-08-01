import 'package:flutter/material.dart';

import '../../../../core/widgets/navigation/mobile_section_menu_page.dart';
import '../../../../l10n/app_localizations.dart';
import '../master_data_menu.dart';

class MasterDataMobileView extends StatelessWidget {
  const MasterDataMobileView({super.key, required this.items});

  final List<MasterDataMenuDefinition> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MobileMenuListPage(
      title: l10n.masterData,
      groups: [
        MobileMenuGroup(
          label: l10n.mobileSectionCatalogAndStore,
          items: items.map(_toMobileMenuItem).toList(),
        ),
      ],
    );
  }

  MobileMenuItem _toMobileMenuItem(MasterDataMenuDefinition menu) {
    return MobileMenuItem(
      title: menu.title,
      subtitle: menu.subtitle,
      icon: menu.icon,
      iconBackground: _backgroundColor(menu.id),
      iconColor: _iconColor(menu.id),
      view: menu.view,
    );
  }

  Color _backgroundColor(MasterDataMenuId id) {
    switch (id) {
      case MasterDataMenuId.products:
        return const Color(0xFFEFF6FF);
      case MasterDataMenuId.categories:
        return const Color(0xFFF5F3FF);
      case MasterDataMenuId.brands:
        return const Color(0xFFF0FDF4);
      case MasterDataMenuId.promos:
        return const Color(0xFFFFFBEB);
      case MasterDataMenuId.customers:
        return const Color(0xFFFDF2F8);
      case MasterDataMenuId.staff:
        return const Color(0xFFECFDF5);
      case MasterDataMenuId.staffRoles:
        return const Color(0xFFFAF5FF);
    }
  }

  Color _iconColor(MasterDataMenuId id) {
    switch (id) {
      case MasterDataMenuId.products:
        return const Color(0xFF1D4ED8);
      case MasterDataMenuId.categories:
        return const Color(0xFF7C3AED);
      case MasterDataMenuId.brands:
        return const Color(0xFF16A34A);
      case MasterDataMenuId.promos:
        return const Color(0xFFD97706);
      case MasterDataMenuId.customers:
        return const Color(0xFFDB2777);
      case MasterDataMenuId.staff:
        return const Color(0xFF059669);
      case MasterDataMenuId.staffRoles:
        return const Color(0xFF8B5CF6);
    }
  }
}
