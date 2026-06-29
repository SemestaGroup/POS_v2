import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/main_shell_sync_state.dart';
import '../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../../../core/services/sync/pos_v2_sync_queue_processor.dart';
import '../../../core/services/sync/pos_v2_sync_status_store.dart';
import '../../../modules/sales/shared/models/pos_catalog_store.dart';
import '../../../modules/sales/shared/models/sales_order_store.dart';

class MainShellSyncController {
  MainShellSyncController._();

  static final MainShellSyncController instance = MainShellSyncController._();

  final PosV2SyncOrchestrator _syncOrchestrator = PosV2SyncOrchestrator();

  final ValueNotifier<MainShellSyncState> stateNotifier =
      ValueNotifier<MainShellSyncState>(
    const MainShellSyncState(
      started: false,
      didStartForCurrentSession: false,
    ),
  );

  bool _isRunning = false;

  void ensureStarted() {
    if (stateNotifier.value.started) {
      return;
    }

    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(
      _handleSessionChanged,
    );
    stateNotifier.value = stateNotifier.value.copyWith(started: true);
    Future<void>.delayed(
      const Duration(milliseconds: 1200),
      _startBackgroundSync,
    );
  }

  void _handleSessionChanged() {
    stateNotifier.value = stateNotifier.value.copyWith(
      didStartForCurrentSession: false,
      clearSessionKey: true,
    );
    Future<void>.delayed(
      const Duration(milliseconds: 1200),
      _startBackgroundSync,
    );
  }

  Future<void> _startBackgroundSync() async {
    if (_isRunning) {
      return;
    }

    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) {
      return;
    }

    final sessionKey =
        '${session.tenantId}:${session.staffId}:${session.deviceId}:${session.registerId}:${session.lastBootstrapAt}';
    final currentState = stateNotifier.value;
    if (currentState.didStartForCurrentSession &&
        currentState.lastSessionKey == sessionKey) {
      return;
    }

    _isRunning = true;
    stateNotifier.value = stateNotifier.value.copyWith(
      didStartForCurrentSession: true,
      lastSessionKey: sessionKey,
    );

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
        // Only run partial startup (settings, active orders, active products, promos, categories)
        await _syncOrchestrator.syncPartialStartup(syncContext);
      }
      
      PosV2SyncStatusStore.instance.update(
        stage: 'refresh_cache',
        progress: 0.6,
      );
      await PosCatalogStore.instance.refresh();
      await SalesOrderStore.instance.refreshFromPersistence();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      
      PosV2SyncStatusStore.instance.update(stage: 'flush_queue', progress: 0.9);
      await PosV2SyncQueueProcessor.instance.flushPending();
      
      // Mark as partial synced if we didn't just bootstrap
      if (!isRecentBootstrap) {
        PosV2SyncStatusStore.instance.succeed(stage: 'partial_synced');
      } else {
        PosV2SyncStatusStore.instance.succeed(stage: 'background_ready');
      }
    } catch (_) {
      PosV2SyncStatusStore.instance.fail('Background sync failed');
    } finally {
      _isRunning = false;
    }
  }

  Future<void> triggerManualMasterDataSync() async {
    if (_isRunning) return;

    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return;

    _isRunning = true;
    final syncContext = session.toSyncContext();

    try {
      PosV2SyncStatusStore.instance.start(
        blocking: false,
        stage: 'syncing_master',
        progress: 0.1,
      );
      
      // Optional: fast check for essentials just in case
      await _syncOrchestrator.syncPartialStartup(syncContext, initialCatalogPages: 1);
      
      PosV2SyncStatusStore.instance.update(
        stage: 'syncing_master_data',
        progress: 0.5,
      );
      
      // Pull remaining heavy master data (brands, customers, staff, history, etc)
      await _syncOrchestrator.syncRemainingMasterData(syncContext);

      PosV2SyncStatusStore.instance.update(stage: 'refresh_cache', progress: 0.9);
      await PosCatalogStore.instance.refresh();
      await SalesOrderStore.instance.refreshFromPersistence();
      
      PosV2SyncStatusStore.instance.succeed(stage: 'synced');
    } catch (_) {
      PosV2SyncStatusStore.instance.fail('Manual sync failed');
    } finally {
      _isRunning = false;
    }
  }
}
