import 'package:flutter/material.dart';

import '../../role_access/role_manager.dart';
import '../../../modules/sales/self_order/self_order_inbox_service.dart';
import '../controllers/main_shell_sync_controller.dart';
import '../widgets/self_order_alert_overlay.dart';
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
    SelfOrderInboxService.instance.start();
  }

  @override
  void dispose() {
    SelfOrderInboxService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ValueListenableBuilder<AppRole>(
            valueListenable: RoleManager.roleNotifier,
            builder: (context, activeRole, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _getShellForRole(activeRole),
              );
            },
          ),
        ),
        // Empty space in the overlay lets touches through to the shell below.
        const Positioned.fill(child: SelfOrderAlertOverlay()),
      ],
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
