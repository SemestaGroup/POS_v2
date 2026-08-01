import 'package:flutter/material.dart';

import '../../../app/role_access/role_manager.dart';
import '../../../core/widgets/responsive/responsive_context.dart';
import '../../../l10n/app_localizations.dart';
import 'master_data_menu.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

class MasterDataShellView extends StatelessWidget {
  const MasterDataShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<AppRole>(
      valueListenable: RoleManager.roleNotifier,
      builder: (context, activeRole, _) {
        final menus = buildMasterDataMenus(
          context,
        ).where((menu) => menu.allowedRoles.contains(activeRole)).toList();

        if (menus.isEmpty) {
          return Center(child: Text(l10n.masterDataUnavailableMessage));
        }

        return context.isMobile
            ? MasterDataMobileView(items: menus)
            : MasterDataTabletLandscapeView(subMenus: menus);
      },
    );
  }
}
