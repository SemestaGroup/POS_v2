import 'package:flutter/material.dart';

import '../../role_access/role_manager.dart';
import '../controllers/main_shell_sync_controller.dart';
import 'owner_shell/tablet_landscape/owner_shell_view.dart';
import 'supervisor_shell/tablet_landscape/supervisor_shell_view.dart';
import 'cashier_shell/tablet_landscape/cashier_shell_view.dart';
import 'kitchen_shell/tablet_landscape/kitchen_shell_view.dart';

class MainShellRouter extends StatefulWidget {
  const MainShellRouter({super.key});

  @override
  State<MainShellRouter> createState() => _MainShellRouterState();
}

class _MainShellRouterState extends State<MainShellRouter> {
  @override
  void initState() {
    super.initState();
    MainShellSyncController.instance.ensureStarted();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppRole>(
      valueListenable: RoleManager.roleNotifier,
      builder: (context, activeRole, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _getShellForRole(activeRole),
        );
      },
    );
  }

  Widget _getShellForRole(AppRole role) {
    switch (role) {
      case AppRole.owner:
        return const OwnerShellView(key: ValueKey('owner_shell'));
      case AppRole.supervisor:
        return const SupervisorShellView(key: ValueKey('supervisor_shell'));
      case AppRole.cashier:
        return const CashierShellView(key: ValueKey('cashier_shell'));
      case AppRole.kitchen:
        return const KitchenShellView(key: ValueKey('kitchen_shell'));
      case AppRole.programmer:
        return const Scaffold(
          body: Center(child: Text('Developer Mode Disabled')),
        );
    }
  }
}
