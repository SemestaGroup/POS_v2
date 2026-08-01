import 'package:flutter/material.dart';

import '../../../../core/widgets/navigation/mobile_section_menu_page.dart';
import '../../../../l10n/app_localizations.dart';
import '../operations_menu.dart';

class OperationsMobileView extends StatelessWidget {
  const OperationsMobileView({
    super.key,
    required this.shiftItems,
    required this.managementItems,
  });

  final List<OperationsMenuDefinition> shiftItems;
  final List<OperationsMenuDefinition> managementItems;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MobileMenuListPage(
      title: l10n.operationsHeader,
      groups: [
        MobileMenuGroup(
          label: l10n.mobileSectionTransactionsAndShift,
          items: shiftItems.map(_toMobileMenuItem).toList(),
        ),
        MobileMenuGroup(
          label: l10n.mobileSectionManagementAndMonitoring,
          items: managementItems.map(_toMobileMenuItem).toList(),
        ),
      ],
    );
  }

  MobileMenuItem _toMobileMenuItem(OperationsMenuDefinition menu) {
    return MobileMenuItem(
      title: menu.title,
      subtitle: menu.subtitle,
      icon: menu.icon,
      iconBackground: _menuBackgroundColor(menu.id),
      iconColor: _menuIconColor(menu.id),
      view: menu.view,
    );
  }

  Color _menuBackgroundColor(OperationsMenuId id) {
    switch (id) {
      case OperationsMenuId.openShift:
        return const Color(0xFFECFDF5);
      case OperationsMenuId.closeShift:
        return const Color(0xFFFEF2F2);
      case OperationsMenuId.recap:
        return const Color(0xFFEEF2FF);
      case OperationsMenuId.shiftHistory:
        return const Color(0xFFF1F5F9);
      case OperationsMenuId.cashFlow:
        return const Color(0xFFFFFBEB);
      case OperationsMenuId.kitchenMonitor:
        return const Color(0xFFF5F3FF);
      case OperationsMenuId.customers:
        return const Color(0xFFF0FDFA);
    }
  }

  Color _menuIconColor(OperationsMenuId id) {
    switch (id) {
      case OperationsMenuId.openShift:
        return const Color(0xFF059669);
      case OperationsMenuId.closeShift:
        return const Color(0xFFDC2626);
      case OperationsMenuId.recap:
        return const Color(0xFF4F46E5);
      case OperationsMenuId.shiftHistory:
        return const Color(0xFF475569);
      case OperationsMenuId.cashFlow:
        return const Color(0xFFD97706);
      case OperationsMenuId.kitchenMonitor:
        return const Color(0xFF7C3AED);
      case OperationsMenuId.customers:
        return const Color(0xFF0D9488);
    }
  }
}
