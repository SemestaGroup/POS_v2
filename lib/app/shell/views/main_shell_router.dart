import 'package:flutter/material.dart';

import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../../../../core/services/sync/pos_v2_sync_queue_processor.dart';
import '../../../../core/services/sync/pos_v2_sync_status_store.dart';

import '../../../../modules/sales/shared/models/pos_catalog_store.dart';
import '../../../../modules/sales/shared/models/sales_order_store.dart';
import '../../role_access/role_manager.dart';
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
  final PosV2SyncOrchestrator _syncOrchestrator = PosV2SyncOrchestrator();
  bool _didStartBackgroundSync = false;

  @override
  void initState() {
    super.initState();
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(
      _handleSessionChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(
        const Duration(milliseconds: 1200),
        _startBackgroundSync,
      );
    });
  }

  @override
  void dispose() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.removeListener(
      _handleSessionChanged,
    );
    super.dispose();
  }

  void _handleSessionChanged() {
    _didStartBackgroundSync = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(
        const Duration(milliseconds: 1200),
        _startBackgroundSync,
      );
    });
  }

  Future<void> _startBackgroundSync() async {
    if (_didStartBackgroundSync) {
      return;
    }
    _didStartBackgroundSync = true;

    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      return;
    }

    final syncContext = session.toSyncContext();
    try {
      PosV2SyncStatusStore.instance.start(
        blocking: false,
        stage: 'background',
        progress: 0.1,
      );
      final isRecentBootstrap =
          session.lastBootstrapAt != null &&
          DateTime.tryParse(session.lastBootstrapAt!)?.isAfter(
                DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
              ) ==
              true;
      if (!isRecentBootstrap) {
        await _syncOrchestrator.syncEssentialStartup(syncContext);
      }
      PosV2SyncStatusStore.instance.update(
        stage: 'refresh_cache',
        progress: 0.45,
      );
      await PosCatalogStore.instance.refresh();
      await SalesOrderStore.instance.refreshFromPersistence();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      PosV2SyncStatusStore.instance.update(
        stage: 'background_payloads',
        progress: 0.7,
      );
      await _syncOrchestrator.syncDeferredStartup(syncContext);
      await PosCatalogStore.instance.refresh();
      await SalesOrderStore.instance.refreshFromPersistence();
      PosV2SyncStatusStore.instance.update(stage: 'flush_queue', progress: 0.9);
      await PosV2SyncQueueProcessor.instance.flushPending();
      PosV2SyncStatusStore.instance.succeed(stage: 'background_ready');
    } catch (_) {
      // Keep the app usable even if startup sync fails.
      PosV2SyncStatusStore.instance.fail('Background sync failed');
    }
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
