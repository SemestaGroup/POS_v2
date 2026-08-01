import 'package:flutter/material.dart';

import '../../../app/role_access/role_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../master_data/customers/views/customer_list/customer_list_view.dart';
import '../cash_flow/views/cash_flow_view.dart';
import '../kitchen/views/tablet_landscape/view.dart';
import '../recap/views/recap_view.dart';
import '../shift/views/shift_close/tablet_landscape/view.dart';
import '../shift/views/shift_history/tablet_landscape/view.dart';
import '../shift/views/shift_open/tablet_landscape/view.dart';

enum OperationsMenuGroup { shift, management }

enum OperationsMenuId {
  openShift,
  closeShift,
  recap,
  shiftHistory,
  cashFlow,
  kitchenMonitor,
  customers,
}

class OperationsMenuDefinition {
  const OperationsMenuDefinition({
    required this.id,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.view,
    required this.allowedRoles,
  });

  final OperationsMenuId id;
  final OperationsMenuGroup group;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget view;
  final List<AppRole> allowedRoles;
}

List<OperationsMenuDefinition> buildOperationsMenus(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  return [
    OperationsMenuDefinition(
      id: OperationsMenuId.openShift,
      group: OperationsMenuGroup.shift,
      title: l10n.shiftMenu,
      subtitle: 'Buka shift kasir',
      icon: Icons.access_time_rounded,
      view: const ShiftOpenView(),
      allowedRoles: const [AppRole.owner, AppRole.supervisor, AppRole.cashier],
    ),
    const OperationsMenuDefinition(
      id: OperationsMenuId.closeShift,
      group: OperationsMenuGroup.shift,
      title: 'Tutup Shift',
      subtitle: 'Tutup dan rekonsiliasi shift',
      icon: Icons.lock_clock_outlined,
      view: ShiftCloseView(),
      allowedRoles: [AppRole.owner, AppRole.supervisor, AppRole.cashier],
    ),
    OperationsMenuDefinition(
      id: OperationsMenuId.recap,
      group: OperationsMenuGroup.management,
      title: l10n.recapMenu,
      subtitle: 'Shift and daily recaps',
      icon: Icons.receipt_long_rounded,
      view: const RecapView(),
      allowedRoles: const [AppRole.owner, AppRole.supervisor],
    ),
    const OperationsMenuDefinition(
      id: OperationsMenuId.shiftHistory,
      group: OperationsMenuGroup.shift,
      title: 'Riwayat Shift',
      subtitle: 'Histori shift dari database lokal',
      icon: Icons.history_toggle_off_rounded,
      view: ShiftHistoryView(),
      allowedRoles: [AppRole.owner, AppRole.supervisor, AppRole.cashier],
    ),
    OperationsMenuDefinition(
      id: OperationsMenuId.cashFlow,
      group: OperationsMenuGroup.shift,
      title: l10n.cashFlowMenu,
      subtitle: 'Cash in & out',
      icon: Icons.account_balance_wallet_rounded,
      view: const CashFlowView(),
      allowedRoles: const [AppRole.owner, AppRole.supervisor, AppRole.cashier],
    ),
    OperationsMenuDefinition(
      id: OperationsMenuId.kitchenMonitor,
      group: OperationsMenuGroup.management,
      title: l10n.kitchenMonitorMenu,
      subtitle: 'Live kitchen orders',
      icon: Icons.restaurant_rounded,
      view: const KitchenMonitorView(),
      allowedRoles: const [AppRole.owner, AppRole.supervisor, AppRole.kitchen],
    ),
    OperationsMenuDefinition(
      id: OperationsMenuId.customers,
      group: OperationsMenuGroup.management,
      title: l10n.customerListMenu,
      subtitle: 'Customer database',
      icon: Icons.people_rounded,
      view: const CustomerListView(),
      allowedRoles: const [AppRole.owner, AppRole.supervisor, AppRole.cashier],
    ),
  ];
}
