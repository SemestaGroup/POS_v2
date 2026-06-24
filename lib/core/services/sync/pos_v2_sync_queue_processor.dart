import 'dart:convert';

import '../../network/v2_api_client.dart';
import '../local/database_service.dart';

class PosV2SyncQueueProcessor {
  PosV2SyncQueueProcessor._();

  static final PosV2SyncQueueProcessor instance = PosV2SyncQueueProcessor._();

  bool _isRunning = false;

  Future<void> flushPending({int limit = 20}) async {
    if (_isRunning) {
      return;
    }

    _isRunning = true;
    try {
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT *
        FROM sync_queue
        WHERE status = 'pending'
           OR (
             status = 'failed'
             AND (
               next_retry_at IS NULL OR
               next_retry_at <= ?
             )
           )
        ORDER BY priority ASC, created_at ASC
        LIMIT ?
        ''',
        <Object?>[_now(), limit],
      );

      for (final row in rows) {
        await _processQueueRow(row);
      }
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _processQueueRow(Map<String, Object?> row) async {
    final queueId = _asInt(row['id']);
    if (queueId == null) {
      return;
    }

    final tenantId = _asInt(row['tenant_id']);
    final now = _now();
    await DatabaseService.instance.transaction((txn) async {
      await txn.update(
        'sync_queue',
        <String, Object?>{
          'status': 'syncing',
          'locked_at': now,
          'locked_by': 'local_processor',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[queueId],
      );
    });

    try {
      final response = await _dispatchRequest(row);
      final responseData = response['data'];
      _validateSuccessfulResponse(
        row,
        responseData: responseData is Map<String, dynamic>
            ? responseData
            : <String, dynamic>{},
      );
      await DatabaseService.instance.transaction((txn) async {
        await txn.update(
          'sync_queue',
          <String, Object?>{
            'status': 'processed',
            'response_code': 200,
            'response_body_json': jsonEncode(response),
            'last_error': null,
            'next_retry_at': null,
            'locked_at': null,
            'locked_by': null,
            'processed_at': now,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: <Object?>[queueId],
        );

        if (tenantId != null) {
          await _markBusinessEntitySynced(
            txn,
            tenantId: tenantId,
            entityType: row['entity_type']?.toString(),
            entityRemoteId: row['entity_remote_id']?.toString(),
            requestBody: _decodeBody(row['request_body_json']),
            responseData: responseData is Map<String, dynamic>
                ? responseData
                : <String, dynamic>{},
          );
        }
      });
    } catch (error) {
      final retryCount = (_asInt(row['retry_count']) ?? 0) + 1;
      await DatabaseService.instance.transaction((txn) async {
        await txn.update(
          'sync_queue',
          <String, Object?>{
            'status': 'failed',
            'retry_count': retryCount,
            'next_retry_at': _nextRetryAt(retryCount),
            'last_error': error.toString(),
            'locked_at': null,
            'locked_by': null,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: <Object?>[queueId],
        );
      });
    }
  }

  void _validateSuccessfulResponse(
    Map<String, Object?> row, {
    required Map<String, dynamic> responseData,
  }) {
    final entityType = row['entity_type']?.toString();
    final method = row['method']?.toString().toUpperCase();

    switch (entityType) {
      case 'pos_order':
        if (method == 'POST') {
          final remoteId = responseData['id']?.toString();
          if (remoteId == null || remoteId.isEmpty) {
            throw Exception(
              'Order create response missing canonical invoice id',
            );
          }
        }
        return;
      case 'pos_transaction':
        if (method == 'POST') {
          final remoteId = responseData['id']?.toString();
          if (remoteId == null || remoteId.isEmpty) {
            throw Exception('Payment create response missing payment id');
          }
        }
        return;
      default:
        return;
    }
  }

  Future<Map<String, dynamic>> _dispatchRequest(
    Map<String, Object?> row,
  ) async {
    final baseUrl = row['base_url']?.toString() ?? '';
    final endpoint = row['endpoint']?.toString() ?? '';
    final method = row['method']?.toString().toUpperCase() ?? 'GET';
    final headers = _decodeBody(row['request_headers_json']);
    final requestBody = _decodeBody(row['request_body_json']);
    final authToken = headers['authtoken']?.toString() ?? '';
    final client = V2ApiClient(baseUrl: baseUrl, authToken: authToken);

    if (method == 'POST' && endpoint.endsWith('api/v2/pos-order')) {
      requestBody.remove('status');
      if (!requestBody.containsKey('duedate') &&
          requestBody.containsKey('date')) {
        requestBody['duedate'] = requestBody['date'];
      }
    }

    switch (method) {
      case 'POST':
        return client.postEnvelope(endpoint, body: requestBody);
      case 'PUT':
        return client.putEnvelope(endpoint, body: requestBody);
      case 'DELETE':
        return client.deleteEnvelope(endpoint, body: requestBody);
      case 'GET':
      default:
        return client.getEnvelope(endpoint, query: requestBody);
    }
  }

  Future<void> _markBusinessEntitySynced(
    dynamic txn, {
    required int tenantId,
    required String? entityType,
    required String? entityRemoteId,
    required Map<String, dynamic> requestBody,
    required Map<String, dynamic> responseData,
  }) async {
    final now = _now();
    switch (entityType) {
      case 'pos_order':
        final idPos =
            responseData['id_pos']?.toString() ??
            entityRemoteId ??
            requestBody['id_pos']?.toString();
        if (idPos == null || idPos.isEmpty) {
          return;
        }
        await txn.update(
          'pos_order',
          <String, Object?>{
            'remote_id': responseData['id']?.toString(),
            'invoice_number': responseData['number']?.toString(),
            'formatted_number': _formattedNumber(responseData) ?? idPos,
            'status_code':
                responseData['status']?.toString() ??
                requestBody['status']?.toString(),
            'subtotal_amount': _money(
              responseData['subtotal'] ?? requestBody['subtotal'],
            ),
            'total_amount': _money(
              responseData['total'] ?? requestBody['total'],
            ),
            'sync_state': 'clean',
            'last_synced_at': now,
            'updated_at': now,
          },
          where: 'tenant_id = ? AND id_pos = ?',
          whereArgs: <Object?>[tenantId, idPos],
        );
        final orderRows = await txn.query(
          'pos_order',
          columns: <String>['id'],
          where: 'tenant_id = ? AND id_pos = ?',
          whereArgs: <Object?>[tenantId, idPos],
          limit: 1,
        );
        if (orderRows.isNotEmpty) {
          final orderLocalId = orderRows.first['id'];
          await txn.update(
            'pos_order_item',
            <String, Object?>{
              'sync_state': 'clean',
              'last_synced_at': now,
              'updated_at': now,
            },
            where: 'tenant_id = ? AND order_id = ?',
            whereArgs: <Object?>[tenantId, orderLocalId],
          );
        }
        return;
      case 'pos_transaction':
        final idPos =
            requestBody['id_pos']?.toString() ??
            entityRemoteId ??
            responseData['id_pos']?.toString();
        if (idPos == null || idPos.isEmpty) {
          return;
        }
        await txn.update(
          'pos_order_payment',
          <String, Object?>{
            'remote_id': responseData['id']?.toString(),
            'invoice_remote_id': responseData['invoiceid']?.toString(),
            'payment_mode_remote_id':
                responseData['paymentmode']?.toString() ??
                requestBody['paymentmode']?.toString(),
            'payment_mode_name_snapshot': responseData['name']?.toString(),
            'sync_state': 'clean',
            'last_synced_at': now,
            'updated_at': now,
          },
          where: 'tenant_id = ? AND id_pos = ?',
          whereArgs: <Object?>[tenantId, idPos],
        );
        return;
      default:
        return;
    }
  }

  Map<String, dynamic> _decodeBody(Object? rawValue) {
    final rawText = rawValue?.toString();
    if (rawText == null || rawText.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(rawText);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  int? _asInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse(value.toString());
  }

  int _money(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return num.tryParse(value.toString().replaceAll(',', ''))?.round() ?? 0;
  }

  String _nextRetryAt(int retryCount) {
    final seconds = switch (retryCount) {
      <= 1 => 10,
      2 => 30,
      3 => 60,
      4 => 120,
      _ => 300,
    };
    return DateTime.now()
        .toUtc()
        .add(Duration(seconds: seconds))
        .toIso8601String();
  }

  String? _formattedNumber(Map<String, dynamic> row) {
    final explicit = row['formatted_number']?.toString();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final prefix = row['prefix']?.toString() ?? '';
    final number = row['number']?.toString() ?? '';
    final combined = '$prefix$number'.trim();
    return combined.isEmpty ? null : combined;
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}
