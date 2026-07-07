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

  /// Flush only the queue items belonging to a specific [idPos].
  /// Used by the payment flow so that a single checkout only sends its own
  /// order + payment, not leftover queue items from other sessions.
  Future<void> flushForOrder(String idPos) async {
    if (_isRunning) {
      return;
    }

    _isRunning = true;
    try {
      // Find queue rows whose request_body_json contains the target id_pos.
      // We rely on a JSON text-search since SQLite has no native JSON query.
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT *
        FROM sync_queue
        WHERE (status = 'pending' OR status = 'failed')
          AND (
            request_body_json LIKE ?
            OR entity_remote_id = ?
          )
        ORDER BY priority ASC, created_at ASC
        LIMIT 10
        ''',
        <Object?>['%"id_pos":"$idPos"%', idPos],
      );

      for (final row in rows) {
        await _processQueueRow(row);
      }
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _processQueueRow(Map<String, Object?> row) async {
    row = await _prepareQueueRowForDispatch(row) ?? row;
    final queueId = _asInt(row['id']);
    if (queueId == null) {
      return;
    }

    if (row['status']?.toString() == 'deferred') {
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

  Future<Map<String, Object?>?> _prepareQueueRowForDispatch(
    Map<String, Object?> row,
  ) async {
    final entityType = row['entity_type']?.toString();
    final method = row['method']?.toString().toUpperCase();
    if (entityType != 'pos_transaction' || method != 'POST') {
      return row;
    }

    final tenantId = _asInt(row['tenant_id']);
    final queueId = _asInt(row['id']);
    if (tenantId == null || queueId == null) {
      return row;
    }

    final requestBody = _decodeBody(row['request_body_json']);
    final invoiceId = requestBody['invoiceid']?.toString().trim() ?? '';
    if (_isPositiveInt(invoiceId)) {
      return row;
    }

    final resolvedInvoiceId = await _resolveRemoteInvoiceId(
      tenantId: tenantId,
      entityLocalId: _asInt(row['entity_local_id']),
      idPos: requestBody['id_pos']?.toString(),
    );
    if (resolvedInvoiceId == null) {
      return <String, Object?>{...row, 'status': 'deferred'};
    }

    requestBody['invoiceid'] = resolvedInvoiceId;
    final now = _now();
    await DatabaseService.instance.transaction((txn) async {
      await txn.update(
        'sync_queue',
        <String, Object?>{
          'request_body_json': jsonEncode(requestBody),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[queueId],
      );
      await txn.update(
        'pos_order_payment',
        <String, Object?>{
          'invoice_remote_id': resolvedInvoiceId,
          'updated_at': now,
        },
        where: 'tenant_id = ? AND id_pos = ?',
        whereArgs: <Object?>[tenantId, requestBody['id_pos']?.toString()],
      );
    });

    return <String, Object?>{
      ...row,
      'request_body_json': jsonEncode(requestBody),
    };
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

    if ((method == 'POST' || method == 'PUT') &&
        endpoint.contains('api/v2/pos-order')) {
      requestBody.remove('number');
      requestBody.remove('formatted_number');
      if (method == 'POST') {
        requestBody.remove('status');
      }
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
        final remoteInvoiceId = responseData['id']?.toString();
        if (idPos == null || idPos.isEmpty) {
          return;
        }
        final existingOrderRows = await txn.query(
          'pos_order',
          columns: const <String>[
            'status_code',
            'amount_received',
            'total_amount',
          ],
          where: 'tenant_id = ? AND id_pos = ?',
          whereArgs: <Object?>[tenantId, idPos],
          limit: 1,
        );
        final existingStatusCode = existingOrderRows.isEmpty
            ? null
            : existingOrderRows.first['status_code']?.toString();
        final existingAmountReceived = existingOrderRows.isEmpty
            ? 0
            : _money(existingOrderRows.first['amount_received']);
        final existingTotalAmount = existingOrderRows.isEmpty
            ? 0
            : _money(existingOrderRows.first['total_amount']);
        final isAlreadyFullyPaid =
            existingTotalAmount > 0 &&
            existingAmountReceived >= existingTotalAmount;
        final nextStatusCode = existingStatusCode == '2' || isAlreadyFullyPaid
            ? '2'
            : (responseData['status']?.toString() ??
                  requestBody['status']?.toString());
        await txn.update(
          'pos_order',
          <String, Object?>{
            'remote_id': responseData['id']?.toString(),
            'invoice_number': responseData['number']?.toString(),
            'formatted_number': _formattedNumber(responseData) ?? idPos,
            'status_code': nextStatusCode,
            'status_text': nextStatusCode,
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
        if (remoteInvoiceId != null && remoteInvoiceId.isNotEmpty) {
          await txn.update(
            'pos_order_payment',
            <String, Object?>{
              'invoice_remote_id': remoteInvoiceId,
              'updated_at': now,
            },
            where: 'tenant_id = ? AND id_pos = ?',
            whereArgs: <Object?>[tenantId, idPos],
          );

          final dependentQueueRows = await txn.query(
            'sync_queue',
            columns: const <String>['id', 'request_body_json'],
            where:
                'tenant_id = ? AND entity_type = ? AND status IN (?, ?, ?) AND request_body_json LIKE ?',
            whereArgs: <Object?>[
              tenantId,
              'pos_transaction',
              'pending',
              'failed',
              'syncing',
              '%"id_pos":"$idPos"%',
            ],
          );
          for (final dependentRow in dependentQueueRows) {
            final dependentQueueId = _asInt(dependentRow['id']);
            if (dependentQueueId == null) {
              continue;
            }
            final dependentBody = _decodeBody(
              dependentRow['request_body_json'],
            );
            dependentBody['invoiceid'] = remoteInvoiceId;
            await txn.update(
              'sync_queue',
              <String, Object?>{
                'request_body_json': jsonEncode(dependentBody),
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: <Object?>[dependentQueueId],
            );
          }
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
        await _refreshLocalOrderPaymentState(
          txn,
          tenantId: tenantId,
          idPos: idPos,
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

  Future<String?> _resolveRemoteInvoiceId({
    required int tenantId,
    required int? entityLocalId,
    required String? idPos,
  }) async {
    if (entityLocalId != null) {
      final orderRows = await DatabaseService.instance.query(
        'pos_order',
        columns: const <String>['remote_id'],
        where: 'tenant_id = ? AND id = ?',
        whereArgs: <Object?>[tenantId, entityLocalId],
        limit: 1,
      );
      final remoteId = orderRows.isEmpty
          ? null
          : orderRows.first['remote_id']?.toString().trim();
      if (_isPositiveInt(remoteId)) {
        return remoteId;
      }
    }

    final normalizedIdPos = idPos?.trim();
    if (normalizedIdPos == null || normalizedIdPos.isEmpty) {
      return null;
    }

    final orderRows = await DatabaseService.instance.query(
      'pos_order',
      columns: const <String>['remote_id'],
      where: 'tenant_id = ? AND id_pos = ?',
      whereArgs: <Object?>[tenantId, normalizedIdPos],
      limit: 1,
    );
    final remoteId = orderRows.isEmpty
        ? null
        : orderRows.first['remote_id']?.toString().trim();
    if (_isPositiveInt(remoteId)) {
      return remoteId;
    }
    return null;
  }

  bool _isPositiveInt(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }
    final parsed = int.tryParse(value);
    return parsed != null && parsed > 0;
  }

  Future<void> _refreshLocalOrderPaymentState(
    dynamic txn, {
    required int tenantId,
    required String idPos,
  }) async {
    final orderRows = await txn.query(
      'pos_order',
      columns: const <String>['id', 'total_amount', 'status_code'],
      where: 'tenant_id = ? AND id_pos = ?',
      whereArgs: <Object?>[tenantId, idPos],
      limit: 1,
    );
    if (orderRows.isEmpty) {
      return;
    }

    final orderLocalId = _asInt(orderRows.first['id']);
    final totalAmount = _money(orderRows.first['total_amount']);
    if (orderLocalId == null) {
      return;
    }

    final paymentRows = await txn.query(
      'pos_order_payment',
      columns: const <String>['SUM(amount) AS total_paid'],
      where: 'tenant_id = ? AND id_pos = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[tenantId, idPos],
      limit: 1,
    );
    final totalPaid = paymentRows.isEmpty
        ? 0
        : _money(paymentRows.first['total_paid']);
    final totalLeftToPay = totalAmount > totalPaid
        ? totalAmount - totalPaid
        : 0;
    final changeAmount = totalPaid > totalAmount ? totalPaid - totalAmount : 0;
    final isFullyPaid = totalAmount > 0 && totalPaid >= totalAmount;
    final statusCode = isFullyPaid
        ? '2'
        : (orderRows.first['status_code']?.toString() ?? '1');
    final now = _now();

    await txn.update(
      'pos_order',
      <String, Object?>{
        'amount_received': totalPaid,
        'change_amount': changeAmount,
        'total_left_to_pay_amount': totalLeftToPay,
        'status_code': statusCode,
        'status_text': statusCode,
        'updated_at': now,
      },
      where: 'tenant_id = ? AND id = ?',
      whereArgs: <Object?>[tenantId, orderLocalId],
    );
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
