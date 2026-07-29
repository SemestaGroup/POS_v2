import 'package:flutter/material.dart';

import '../../../../core/widgets/navigation/mobile_section_menu_page.dart';
import '../../../../l10n/app_localizations.dart';

class OperationsMobileView extends StatelessWidget {
  const OperationsMobileView({
    super.key,
    required this.shiftItems,
    required this.managementItems,
  });

  final List<MobileMenuItem> shiftItems;
  final List<MobileMenuItem> managementItems;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MobileMenuListPage(
      title: l10n.operationsHeader,
      groups: [
        MobileMenuGroup(
          label: l10n.mobileSectionTransactionsAndShift,
          items: shiftItems,
        ),
        MobileMenuGroup(
          label: l10n.mobileSectionManagementAndMonitoring,
          items: managementItems,
        ),
      ],
    );
  }
}
