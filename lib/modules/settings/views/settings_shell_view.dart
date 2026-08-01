import 'package:flutter/material.dart';

import '../../../app/role_access/role_manager.dart';
import '../../../core/widgets/responsive/responsive_context.dart';
import '../../../l10n/app_localizations.dart';
import 'mobile_portrait/view.dart';
import 'settings_menu_catalog.dart';
import 'tablet_landscape/view.dart';

class SettingsShellView extends StatelessWidget {
  const SettingsShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<AppRole>(
      valueListenable: RoleManager.roleNotifier,
      builder: (context, activeRole, _) {
        final categories = buildSettingsMenuCategories(context)
            .where((category) => category.allowedRoles.contains(activeRole))
            .toList();

        if (categories.isEmpty) {
          return Center(child: Text(l10n.settingsUnavailableMessage));
        }

        return context.isMobile
            ? SettingsMobileView(categories: categories)
            : SettingsTabletLandscapeView(categories: categories);
      },
    );
  }
}
