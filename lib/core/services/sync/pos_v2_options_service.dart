import 'package:flutter/foundation.dart';
import '../../constants/app_constants.dart';
import 'base_v2_sync_adapter.dart';
import 'pos_v2_runtime_session_store.dart';
import 'v2_sync_utils.dart';

class PosV2OptionsService extends BaseV2SyncAdapter {
  PosV2OptionsService({super.databaseService});

  static final PosV2OptionsService instance = PosV2OptionsService();

  /// Fetch options from API and store in SQLite
  Future<void> fetchAndSaveOptions() async {
    try {
      final session = PosV2RuntimeSessionStore.instance.currentSession;
      if (session == null) return;

      final client = buildClient(session.toSyncContext());
      final envelope = await client.getEnvelope('api/v2/pos-options');
      final data = V2SyncUtils.asMap(envelope['data']);
      if (data == null || data.isEmpty) return;

      final now = V2SyncUtils.nowIso();

      await databaseService.transaction((txn) async {
        for (final entry in data.entries) {
          final optionName = entry.key;
          final rawValue = entry.value;

          final parsedValue = rawValue is String
              ? V2SyncUtils.decodeLooseJson(rawValue)
              : rawValue;

          final optionJson = parsedValue is Map || parsedValue is List
              ? V2SyncUtils.encodeJson(parsedValue)
              : null;
          final optionText = rawValue is String
              ? rawValue
              : V2SyncUtils.encodeJson(rawValue) ?? '';

          final valueKind = optionJson == null ? 'text' : 'json';

          await databaseService.upsertByUnique(
            txn,
            'pos_option',
            where: 'tenant_id = ? AND option_name = ?',
            whereArgs: <Object?>[session.tenantId, optionName],
            insertValues: <String, Object?>{
              'tenant_id': session.tenantId,
              'option_name': optionName,
              'option_value_text': optionText,
              'option_value_json': optionJson,
              'value_kind': valueKind,
              'autoload': 1,
              'source_endpoint': 'pos-options',
              'last_synced_at': now,
              'created_at': now,
              'updated_at': now,
            },
            updateValues: <String, Object?>{
              'option_value_text': optionText,
              'option_value_json': optionJson,
              'value_kind': valueKind,
              'source_endpoint': 'pos-options',
              'last_synced_at': now,
              'updated_at': now,
              'deleted_at': null,
            },
          );
        }
      });
    } catch (e, stack) {
      debugPrint('Error fetchAndSaveOptions: $e\n$stack');
    }
  }

  /// Get local options from SQLite
  Future<Map<String, dynamic>> getLocalOptions() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return {};

    final rows = await databaseService.query(
      'pos_option',
      where: 'tenant_id = ?',
      whereArgs: [session.tenantId],
    );

    final result = <String, dynamic>{};
    for (final row in rows) {
      final name = row['option_name'] as String;
      final kind = row['value_kind'] as String?;
      final textVal = row['option_value_text'] as String?;
      final jsonVal = row['option_value_json'] as String?;

      if (kind == 'json' && jsonVal != null && jsonVal.isNotEmpty) {
        result[name] = V2SyncUtils.decodeLooseJson(jsonVal);
      } else {
        // Fallback to text
        result[name] = textVal ?? '';
      }
    }

    if (result['version'] != AppConstants.appVersion) {
      result['version'] = AppConstants.appVersion;
      // Fire and forget: update database and backend if out of sync
      updateOption('version', AppConstants.appVersion);
    }

    return result;
  }

  /// Update single option via PUT and update SQLite
  Future<bool> updateOption(String key, dynamic value) async {
    try {
      final session = PosV2RuntimeSessionStore.instance.currentSession;
      if (session == null) return false;

      final payload = {
        "options": {
          key: value,
        }
      };

      final client = buildClient(session.toSyncContext());
      final respData = await client.putEnvelope(
        'api/v2/pos-options',
        body: payload,
      );
      final isSuccess = respData['status'] == true;

      if (isSuccess) {
        // Convert value to text/json
        final parsedValue = value is String
            ? V2SyncUtils.decodeLooseJson(value)
            : value;

        final optionJson = parsedValue is Map || parsedValue is List
            ? V2SyncUtils.encodeJson(parsedValue)
            : null;
        final optionText = value is String
            ? value
            : V2SyncUtils.encodeJson(value) ?? '';

        final valueKind = optionJson == null ? 'text' : 'json';
        final now = V2SyncUtils.nowIso();

        await databaseService.transaction((txn) async {
          await databaseService.upsertByUnique(
            txn,
            'pos_option',
            where: 'tenant_id = ? AND option_name = ?',
            whereArgs: <Object?>[session.tenantId, key],
            insertValues: <String, Object?>{
              'tenant_id': session.tenantId,
              'option_name': key,
              'option_value_text': optionText,
              'option_value_json': optionJson,
              'value_kind': valueKind,
              'autoload': 1,
              'source_endpoint': 'pos-options',
              'last_synced_at': now,
              'created_at': now,
              'updated_at': now,
            },
            updateValues: <String, Object?>{
              'option_value_text': optionText,
              'option_value_json': optionJson,
              'value_kind': valueKind,
              'source_endpoint': 'pos-options',
              'last_synced_at': now,
              'updated_at': now,
              'deleted_at': null,
            },
          );
        });

        return true;
      }
      return false;
    } catch (e, stack) {
      debugPrint('Error updateOption: $e\n$stack');
      return false;
    }
  }

  /// Update multiple options via PUT and update SQLite in a single transaction
  Future<bool> updateMultipleOptions(Map<String, dynamic> options) async {
    try {
      final session = PosV2RuntimeSessionStore.instance.currentSession;
      if (session == null) return false;

      final payload = {
        "options": options,
      };

      final client = buildClient(session.toSyncContext());
      final respData = await client.putEnvelope(
        'api/v2/pos-options',
        body: payload,
      );
      final isSuccess = respData['status'] == true;

      if (isSuccess) {
        final now = V2SyncUtils.nowIso();

        await databaseService.transaction((txn) async {
          for (final entry in options.entries) {
            final key = entry.key;
            final value = entry.value;
            
            final parsedValue = value is String
                ? V2SyncUtils.decodeLooseJson(value)
                : value;

            final optionJson = parsedValue is Map || parsedValue is List
                ? V2SyncUtils.encodeJson(parsedValue)
                : null;
            final optionText = value is String
                ? value
                : V2SyncUtils.encodeJson(value) ?? '';

            final valueKind = optionJson == null ? 'text' : 'json';

            await databaseService.upsertByUnique(
              txn,
              'pos_option',
              where: 'tenant_id = ? AND option_name = ?',
              whereArgs: <Object?>[session.tenantId, key],
              insertValues: <String, Object?>{
                'tenant_id': session.tenantId,
                'option_name': key,
                'option_value_text': optionText,
                'option_value_json': optionJson,
                'value_kind': valueKind,
                'autoload': 1,
                'source_endpoint': 'pos-options',
                'last_synced_at': now,
                'created_at': now,
                'updated_at': now,
              },
              updateValues: <String, Object?>{
                'option_value_text': optionText,
                'option_value_json': optionJson,
                'value_kind': valueKind,
                'source_endpoint': 'pos-options',
                'last_synced_at': now,
                'updated_at': now,
                'deleted_at': null,
              },
            );
          }
        });

        return true;
      }
      return false;
    } catch (e, stack) {
      debugPrint('Error updateMultipleOptions: $e\n$stack');
      return false;
    }
  }
}
