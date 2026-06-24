import 'dart:async';

import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../../../../core/services/sync/pos_v2_sync_status_store.dart';
import '../../shared/models/sales_order_store.dart';

class OrdersHistorySyncService {
  OrdersHistorySyncService._();

  static final OrdersHistorySyncService instance = OrdersHistorySyncService._();

  final PosV2SyncOrchestrator _syncOrchestrator = PosV2SyncOrchestrator();
  bool _isRunning = false;
  DateTime? _lastRunAt;

  Future<void> ensureSynced({bool force = false}) async {
    if (_isRunning) {
      return;
    }

    if (!force && _lastRunAt != null) {
      final elapsed = DateTime.now().difference(_lastRunAt!);
      if (elapsed < const Duration(minutes: 2)) {
        return;
      }
    }

    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      return;
    }

    _isRunning = true;
    try {
      PosV2SyncStatusStore.instance.start(
        blocking: false,
        stage: 'history_on_demand',
        progress: 0.2,
      );
      await _syncOrchestrator.syncHistoryOnDemand(session.toSyncContext());
      await SalesOrderStore.instance.refreshFromPersistence();
      _lastRunAt = DateTime.now();
      PosV2SyncStatusStore.instance.succeed(stage: 'history_ready');
    } catch (_) {
      PosV2SyncStatusStore.instance.fail('Order history sync failed');
    } finally {
      _isRunning = false;
    }
  }
}
