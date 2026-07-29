import 'package:flutter/material.dart';

import '../../../../core/widgets/navigation/mobile_section_menu_page.dart';
import '../../../../l10n/app_localizations.dart';
import '../models/settings_menu.dart';

class SettingsMobileView extends StatelessWidget {
  const SettingsMobileView({super.key, required this.categories});

  final List<SettingsMenuCategory> categories;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MobileMenuListPage(
      title: l10n.settings,
      groups: [
        MobileMenuGroup(
          label: l10n.mobileSectionSettingsAndDevices,
          items: categories
              .map((category) => _categoryMenuItem(context, category))
              .toList(),
        ),
      ],
    );
  }

  MobileMenuItem _categoryMenuItem(
    BuildContext context,
    SettingsMenuCategory category,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return MobileMenuItem(
      title: category.title,
      subtitle: category.subtitle,
      icon: category.icon,
      iconBackground: _categoryBackground(category.icon),
      iconColor: _categoryIconColor(category.icon),
      trailing: _MenuCountBadge(
        label: l10n.menuCount(category.subMenus.length),
      ),
      onTap: () => _openCategory(context, category),
    );
  }

  void _openCategory(BuildContext context, SettingsMenuCategory category) {
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MobileMenuListPage(
          title: category.title,
          groups: [
            MobileMenuGroup(
              label: l10n.mobileSectionChooseSettings,
              items: category.subMenus
                  .map(
                    (subMenu) => MobileMenuItem(
                      title: subMenu.title,
                      view: subMenu.view,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryBackground(IconData icon) {
    if (icon == Icons.settings_rounded) return const Color(0xFFEFF6FF);
    if (icon == Icons.storefront_rounded) return const Color(0xFFF0FDF4);
    if (icon == Icons.print_rounded) return const Color(0xFFF5F3FF);
    if (icon == Icons.sync_rounded) return const Color(0xFFFFFBEB);
    if (icon == Icons.devices_rounded) return const Color(0xFFF0FDFA);
    return const Color(0xFFF1F5F9);
  }

  Color _categoryIconColor(IconData icon) {
    if (icon == Icons.settings_rounded) return const Color(0xFF1D4ED8);
    if (icon == Icons.storefront_rounded) return const Color(0xFF16A34A);
    if (icon == Icons.print_rounded) return const Color(0xFF7C3AED);
    if (icon == Icons.sync_rounded) return const Color(0xFFD97706);
    if (icon == Icons.devices_rounded) return const Color(0xFF0D9488);
    return const Color(0xFF475569);
  }
}

class _MenuCountBadge extends StatelessWidget {
  const _MenuCountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
      ],
    );
  }
}
