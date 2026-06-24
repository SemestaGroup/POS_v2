import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../network/v2_api_client.dart';
import '../local/database_service.dart';
import 'v2_sync_context.dart';
import 'v2_sync_utils.dart';

abstract class BaseV2SyncAdapter {
  BaseV2SyncAdapter({DatabaseService? databaseService})
    : databaseService = databaseService ?? DatabaseService.instance;

  final DatabaseService databaseService;

  @protected
  V2ApiClient buildClient(V2SyncContext context) {
    return V2ApiClient(
      baseUrl: context.normalizedBaseUrl,
      authToken: context.authToken,
    );
  }

  @protected
  Future<int> ensureTenantId(
    DatabaseExecutor executor,
    V2SyncContext context, {
    String? tenantCode,
    String? tenantName,
    String? roleCode,
  }) async {
    final now = V2SyncUtils.nowIso();
    return databaseService.upsertByUnique(
      executor,
      'app_tenant',
      where: 'tenant_key = ?',
      whereArgs: <Object?>[context.tenantKey],
      insertValues: <String, Object?>{
        'tenant_key': context.tenantKey,
        'tenant_code': tenantCode ?? context.tenantCode,
        'tenant_name': tenantName ?? context.tenantName,
        'location_id': context.locationId,
        'base_url': context.normalizedBaseUrl,
        'role_code': roleCode,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      updateValues: <String, Object?>{
        'tenant_code': tenantCode ?? context.tenantCode,
        'tenant_name': tenantName ?? context.tenantName,
        'location_id': context.locationId,
        'base_url': context.normalizedBaseUrl,
        'role_code': roleCode,
        'is_active': 1,
        'updated_at': now,
      },
    );
  }

  @protected
  Future<int?> findLocalIdByRemoteId(
    DatabaseExecutor executor,
    String table,
    int tenantId,
    String? remoteId,
  ) {
    if (remoteId == null || remoteId.isEmpty) {
      return Future<int?>.value(null);
    }
    return databaseService.findLocalId(
      executor,
      table,
      where: 'tenant_id = ? AND remote_id = ?',
      whereArgs: <Object?>[tenantId, remoteId],
    );
  }

  @protected
  Future<int?> findOrderLocalId(
    DatabaseExecutor executor,
    int tenantId, {
    String? remoteId,
    String? idPos,
  }) async {
    if (idPos != null && idPos.isNotEmpty) {
      final byBusinessKey = await databaseService.findLocalId(
        executor,
        'pos_order',
        where: 'tenant_id = ? AND id_pos = ?',
        whereArgs: <Object?>[tenantId, idPos],
      );
      if (byBusinessKey != null) {
        return byBusinessKey;
      }
    }

    if (remoteId != null && remoteId.isNotEmpty) {
      return databaseService.findLocalId(
        executor,
        'pos_order',
        where: 'tenant_id = ? AND remote_id = ?',
        whereArgs: <Object?>[tenantId, remoteId],
      );
    }

    return null;
  }

  @protected
  Future<void> touchCheckpoint(
    DatabaseExecutor executor,
    int tenantId, {
    required String endpointName,
    required String scopeKey,
    String? notes,
  }) async {
    final now = V2SyncUtils.nowIso();
    await databaseService.upsertByUnique(
      executor,
      'sync_checkpoint',
      where: 'tenant_id = ? AND endpoint_name = ? AND scope_key = ?',
      whereArgs: <Object?>[tenantId, endpointName, scopeKey],
      insertValues: <String, Object?>{
        'tenant_id': tenantId,
        'endpoint_name': endpointName,
        'scope_key': scopeKey,
        'last_success_at': now,
        'last_attempt_at': now,
        'notes': notes,
      },
      updateValues: <String, Object?>{
        'last_success_at': now,
        'last_attempt_at': now,
        'notes': notes,
      },
    );
  }
}
