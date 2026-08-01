import 'package:flutter/material.dart';

import '../../../app/role_access/role_manager.dart';
import '../../../core/widgets/responsive/responsive_context.dart';
import '../../../l10n/app_localizations.dart';
import 'mobile_portrait/view.dart';
import 'operations_menu.dart';
import 'tablet_landscape/view.dart';

class OperationsShellView extends StatelessWidget {
  const OperationsShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<AppRole>(
      valueListenable: RoleManager.roleNotifier,
      builder: (context, activeRole, _) {
        final menus = buildOperationsMenus(
          context,
        ).where((menu) => menu.allowedRoles.contains(activeRole)).toList();

        if (menus.isEmpty) {
          return Center(child: Text(l10n.operationsUnavailableMessage));
        }

        if (context.isMobile) {
          return OperationsMobileView(
            shiftItems: menus
                .where((menu) => menu.group == OperationsMenuGroup.shift)
                .toList(),
            managementItems: menus
                .where((menu) => menu.group == OperationsMenuGroup.management)
                .toList(),
          );
        }

        return OperationsTabletLandscapeView(subMenus: menus);
      },
    );
  }
}
