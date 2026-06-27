import 'package:flutter/foundation.dart';

import '../../../../../core/services/local/database_service.dart';
import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../../../../../core/services/sync/pos_v2_sync_queue_processor.dart';
import '../../../../../core/services/sync/pos_v2_sync_status_store.dart';
import '../models/sync_settings_state.dart';

class SyncCenterController {
  SyncCenterController._() {
    PosV2SyncStatusStore.instance.statusNotifier.addListener(_handleStatusChanged);
  }

  static final SyncCenterController instance = SyncCenterController._();

  final ValueNotifier<SyncCenterState> stateNotifier =
      ValueNotifier<SyncCenterState>(
    SyncCenterState(
      isLoading: false,
      pendingCount: 0,
      failedCount: 0,
      processedCount: 0,
      errorCount: 0,
      status: PosV2SyncStatusStore.instance.statusNotifier.value,
    ),
  );

  void _handleStatusChanged() {
    stateNotifier.value = stateNotifier.value.copyWith(
      status: PosV2SyncStatusStore.instance.statusNotifier.value,
    );
  }

  Future<void> refresh() async {
    stateNotifier.value = stateNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );
    try {
      final session = await _requireSession();
      final pending = await DatabaseService.instance.rawQuery(
        'SELECT COUNT(*) as total FROM sync_queue WHERE tenant_id = ? AND status = ?',
        <Object?>[session.tenantId, 'pending'],
      );
      final failed = await DatabaseService.instance.rawQuery(
        'SELECT COUNT(*) as total FROM sync_queue WHERE tenant_id = ? AND status = ?',
        <Object?>[session.tenantId, 'failed'],
      );
      final processed = await DatabaseService.instance.rawQuery(
        'SELECT COUNT(*) as total FROM sync_queue WHERE tenant_id = ? AND status = ?',
        <Object?>[session.tenantId, 'processed'],
      );
      final errors = await DatabaseService.instance.rawQuery(
        'SELECT COUNT(*) as total FROM error_log WHERE tenant_id = ? AND status = ?',
        <Object?>[session.tenantId, 'new'],
      );

      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        pendingCount: _firstInt(pending),
        failedCount: _firstInt(failed),
        processedCount: _firstInt(processed),
        errorCount: _firstInt(errors),
        status: PosV2SyncStatusStore.instance.statusNotifier.value,
      );
    } catch (error) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> flushQueue() async {
    await PosV2SyncQueueProcessor.instance.flushPending();
    await refresh();
  }

  Future<void> refreshBootstrap() async {
    final session = await _requireSession();
    await PosV2SyncOrchestrator().syncBootstrap(session.toSyncContext());
    await refresh();
  }
}

class SyncHistoryController {
  SyncHistoryController._();

  static final SyncHistoryController instance = SyncHistoryController._();

  final ValueNotifier<SyncHistoryState> stateNotifier =
      ValueNotifier<SyncHistoryState>(
    const SyncHistoryState(
      isLoading: false,
      queueEntries: <SyncHistoryEntry>[],
      errorEntries: <SyncErrorEntry>[],
    ),
  );

  Future<void> refresh() async {
    stateNotifier.value = stateNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );
    try {
      final session = await _requireSession();
      final queueRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT id, entity_type, operation, endpoint, status, retry_count, last_error, created_at, processed_at
        FROM sync_queue
        WHERE tenant_id = ?
        ORDER BY id DESC
        LIMIT 30
        ''',
        <Object?>[session.tenantId],
      );
      final errorRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT id, category, message, status, error_code, created_at
        FROM error_log
        WHERE tenant_id = ?
        ORDER BY id DESC
        LIMIT 20
        ''',
        <Object?>[session.tenantId],
      );

      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        queueEntries: queueRows
            .map(
              (row) => SyncHistoryEntry(
                id: _asInt(row['id']) ?? 0,
                entityType: row['entity_type']?.toString() ?? '-',
                operation: row['operation']?.toString() ?? '-',
                endpoint: row['endpoint']?.toString() ?? '-',
                status: row['status']?.toString() ?? '-',
                retryCount: _asInt(row['retry_count']) ?? 0,
                lastError: row['last_error']?.toString(),
                createdAt: row['created_at']?.toString(),
                processedAt: row['processed_at']?.toString(),
              ),
            )
            .toList(growable: false),
        errorEntries: errorRows
            .map(
              (row) => SyncErrorEntry(
                id: _asInt(row['id']) ?? 0,
                category: row['category']?.toString() ?? '-',
                message: row['message']?.toString() ?? '-',
                status: row['status']?.toString() ?? '-',
                errorCode: row['error_code']?.toString(),
                createdAt: row['created_at']?.toString(),
              ),
            )
            .toList(growable: false),
      );
    } catch (error) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

Future<PosV2RuntimeSession> _requireSession() async {
  final session = PosV2RuntimeSessionStore.instance.currentSession ??
      await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
  if (session == null) {
    throw Exception('No active session found.');
  }
  return session;
}

int _firstInt(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return 0;
  return _asInt(rows.first['total']) ?? 0;
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString().split('.').first);
}
