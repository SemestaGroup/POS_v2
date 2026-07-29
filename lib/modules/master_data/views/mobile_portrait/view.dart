import 'package:flutter/material.dart';

import '../../../../core/widgets/navigation/mobile_section_menu_page.dart';
import '../../../../l10n/app_localizations.dart';

class MasterDataMobileView extends StatelessWidget {
  const MasterDataMobileView({super.key, required this.items});

  final List<MobileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MobileMenuListPage(
      title: l10n.masterData,
      groups: [
        MobileMenuGroup(label: l10n.mobileSectionCatalogAndStore, items: items),
      ],
    );
  }
}
