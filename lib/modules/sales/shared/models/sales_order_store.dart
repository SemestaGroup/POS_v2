import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/sync/pos_v2_sync_queue_processor.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';

class SalesOrderLineItem {
  const SalesOrderLineItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.regularUnitPrice,
    required this.quantity,
    this.productRemoteId,
    this.discountedUnitPrice,
    this.promoLabel,
    this.isDiscountEnabled = false,
    this.orderType,
    this.note,
  });

  final String id;
  final String name;
  final String imageUrl;
  final int regularUnitPrice;
  final int quantity;
  final String? productRemoteId;
  final int? discountedUnitPrice;
  final String? promoLabel;
  final bool isDiscountEnabled;
  final String? orderType;
  final String? note;

  int get activeUnitPrice => isDiscountEnabled && discountedUnitPrice != null
      ? discountedUnitPrice!
      : regularUnitPrice;

  int get totalPrice => activeUnitPrice * quantity;
}

class SalesOrderRecord {
  const SalesOrderRecord({
    required this.id,
    required this.token,
    required this.createdAt,
    required this.statusCode,
    required this.customerName,
    required this.customerRemoteId,
    required this.orderType,
    required this.items,
    this.note,
    this.orderLevelDiscountAmount = 0,
    this.customerLocalId,
    this.customerPhone,
    this.customerAddress,
    this.appliedPromotionRemoteId,
    this.appliedPromotionName,
    this.appliedPromotionType,
    this.appliedPromotionSummary,
  });

  final String id;
  final String token;
  final DateTime createdAt;
  final int statusCode;
  final String customerName;
  final String customerRemoteId;
  final int? customerLocalId;
  final String? customerPhone;
  final String? customerAddress;
  final String? appliedPromotionRemoteId;
  final String? appliedPromotionName;
  final String? appliedPromotionType;
  final String? appliedPromotionSummary;
  final String orderType;
  final String? note;
  final List<SalesOrderLineItem> items;
  final int orderLevelDiscountAmount;

  int get subtotalAmount => items.fold(0, (sum, item) => sum + item.totalPrice);
  int get totalAmount =>
      (subtotalAmount - orderLevelDiscountAmount).clamp(0, 1 << 31);
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}

class SalesOrderStore {
  static const int defaultCurrencyId = 3;
  static const String defaultCurrencyCode = 'IDR';

  SalesOrderStore._() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(
      _handleSessionChanged,
    );
    unawaited(refreshFromPersistence());
  }

  static final SalesOrderStore instance = SalesOrderStore._();

  final ValueNotifier<List<SalesOrderRecord>> recordsNotifier =
      ValueNotifier<List<SalesOrderRecord>>(const []);
  final ValueNotifier<SalesOrderRecord?> resumeOrderNotifier =
      ValueNotifier<SalesOrderRecord?>(null);

  int _sequence = 1;
  bool _isRefreshing = false;

  void _handleSessionChanged() {
    unawaited(refreshFromPersistence());
  }

  Future<void> refreshFromPersistence() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    try {
      final session =
          PosV2RuntimeSessionStore.instance.currentSession ??
          await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
      if (session == null) {
        _recalculateSequence(recordsNotifier.value);
        return;
      }

      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT
          pos_order.id,
          pos_order.id_pos,
          pos_order.formatted_number,
          pos_order.order_date,
          pos_order.created_at,
          pos_order.status_code,
          pos_order.customer_id,
          pos_order.customer_remote_id,
          pos_order.order_type_code,
          pos_order.order_note,
          pos_order.custom_fields_json,
          pos_order.manual_discount_value,
          pos_order.billing_street,
          customer.display_name AS customer_name,
          customer.phone_number AS customer_phone,
          customer.address_line1 AS customer_address
        FROM pos_order
        LEFT JOIN customer ON customer.id = pos_order.customer_id
        WHERE pos_order.tenant_id = ?
          AND pos_order.deleted_at IS NULL
        ORDER BY COALESCE(pos_order.updated_at, pos_order.created_at, pos_order.order_date) DESC
        ''',
        <Object?>[session.tenantId],
      );

      final orderLocalIds = rows
          .map((row) => _asInt(row['id']))
          .whereType<int>()
          .toSet();

      final itemsByOrderId = <int, List<Map<String, Object?>>>{};

      if (orderLocalIds.isNotEmpty) {
        final itemRows = await DatabaseService.instance.rawQuery(
          '''
          SELECT
            pos_order_item.id,
            pos_order_item.order_id,
            pos_order_item.product_remote_id,
            pos_order_item.product_name_snapshot,
            pos_order_item.base_price_amount,
            pos_order_item.price_amount,
            pos_order_item.qty,
            pos_order_item.order_type_code,
            pos_order_item.note,
            product.image_url,
            pos_order_item.raw_payload_json
          FROM pos_order_item
          LEFT JOIN product ON product.id = pos_order_item.product_id
          WHERE pos_order_item.tenant_id = ?
            AND pos_order_item.deleted_at IS NULL
          ORDER BY pos_order_item.sort_order ASC, pos_order_item.id ASC
          ''',
          <Object?>[session.tenantId],
        );

        for (final itemRow in itemRows) {
          final orderId = _asInt(itemRow['order_id']);
          if (orderId != null) {
            itemsByOrderId.putIfAbsent(orderId, () => []).add(itemRow);
          }
        }
      }

      final records = <SalesOrderRecord>[];
      for (final row in rows) {
        final orderLocalId = _asInt(row['id']);
        if (orderLocalId == null) {
          continue;
        }

        final itemRows = itemsByOrderId[orderLocalId] ?? [];

        final items = itemRows
            .map((itemRow) {
              final basePrice =
                  _asInt(itemRow['base_price_amount']) ??
                  (_asInt(itemRow['price_amount']) ?? 0);
              final activePrice = _asInt(itemRow['price_amount']) ?? 0;
              final discountedPrice = activePrice < basePrice
                  ? activePrice
                  : null;
              final quantity = (_asDouble(itemRow['qty']) ?? 0).round();

              String imageUrl = _resolveProductImageUrl(
                itemRow['image_url']?.toString(),
              );
              if (imageUrl.isEmpty) {
                final payloadString = itemRow['raw_payload_json']?.toString();
                if (payloadString != null && payloadString.isNotEmpty) {
                  try {
                    final payload =
                        jsonDecode(payloadString) as Map<String, dynamic>;
                    // raw_payload_json stores the already-resolved URL
                    imageUrl = payload['image_url']?.toString() ?? '';
                  } catch (_) {}
                }
              }

              return SalesOrderLineItem(
                id: 'line-${itemRow['id']}',
                name: itemRow['product_name_snapshot']?.toString() ?? '',
                imageUrl: imageUrl,
                regularUnitPrice: basePrice,
                quantity: quantity,
                productRemoteId: itemRow['product_remote_id']?.toString(),
                discountedUnitPrice: discountedPrice,
                promoLabel: discountedPrice != null ? 'Promo' : null,
                isDiscountEnabled: discountedPrice != null,
                orderType: itemRow['order_type_code']?.toString(),
                note: itemRow['note']?.toString(),
              );
            })
            .toList(growable: false);

        records.add(
          SalesOrderRecord(
            id: row['id_pos']?.toString() ?? 'POS-$orderLocalId',
            token: row['formatted_number']?.toString() ?? '#$orderLocalId',
            createdAt: _parseDateTime(
              row['created_at']?.toString() ?? row['order_date']?.toString(),
            ),
            statusCode: int.tryParse(row['status_code']?.toString() ?? '') ?? 1,
            customerName:
                row['customer_name']?.toString() ??
                row['billing_street']?.toString() ??
                'Walk-in Customer',
            customerRemoteId: row['customer_remote_id']?.toString() ?? '',
            customerLocalId: _asInt(row['customer_id']),
            customerPhone: row['customer_phone']?.toString(),
            customerAddress: row['customer_address']?.toString(),
            appliedPromotionRemoteId: _extractPromotionField(
              row['custom_fields_json'],
              'remote_id',
            ),
            appliedPromotionName: _extractPromotionField(
              row['custom_fields_json'],
              'name',
            ),
            appliedPromotionType: _extractPromotionField(
              row['custom_fields_json'],
              'promo_type',
            ),
            appliedPromotionSummary: _extractPromotionField(
              row['custom_fields_json'],
              'summary',
            ),
            orderType: row['order_type_code']?.toString() ?? 'dine_in',
            note: row['order_note']?.toString(),
            orderLevelDiscountAmount: _asInt(row['manual_discount_value']) ?? 0,
            items: items,
          ),
        );
      }

      recordsNotifier.value = records;
      _recalculateSequence(records);
    } catch (_) {
      _recalculateSequence(recordsNotifier.value);
    } finally {
      _isRefreshing = false;
    }
  }

  void createOrder({
    required int statusCode,
    required List<SalesOrderLineItem> items,
    required String customerName,
    required String customerRemoteId,
    required String orderType,
    String? note,
    int orderLevelDiscountAmount = 0,
    int? customerLocalId,
    String? customerPhone,
    String? customerAddress,
    String? appliedPromotionRemoteId,
    String? appliedPromotionName,
    String? appliedPromotionType,
    String? appliedPromotionSummary,
    String? existingOrderId,
    String? existingOrderToken,
    DateTime? existingCreatedAt,
  }) {
    if (items.isEmpty) {
      return;
    }

    final isUpdate =
        existingOrderId != null && existingOrderId.trim().isNotEmpty;
    final record = SalesOrderRecord(
      id: isUpdate
          ? existingOrderId.trim()
          : 'POS-${DateTime.now().millisecondsSinceEpoch}',
      token: isUpdate
          ? (existingOrderToken ?? '#${_sequence.toString().padLeft(3, '0')}')
          : '#${_sequence.toString().padLeft(3, '0')}',
      createdAt: existingCreatedAt ?? DateTime.now(),
      statusCode: statusCode,
      customerName: customerName,
      customerRemoteId: customerRemoteId,
      customerLocalId: customerLocalId,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      appliedPromotionRemoteId: appliedPromotionRemoteId,
      appliedPromotionName: appliedPromotionName,
      appliedPromotionType: appliedPromotionType,
      appliedPromotionSummary: appliedPromotionSummary,
      orderType: orderType,
      note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
      orderLevelDiscountAmount: orderLevelDiscountAmount,
      items: List<SalesOrderLineItem>.from(items),
    );

    if (!isUpdate) {
      _sequence += 1;
    }
    recordsNotifier.value = [
      record,
      ...recordsNotifier.value.where((item) => item.id != record.id),
    ];
    unawaited(_persistOrderRecord(record));
  }

  List<SalesOrderRecord> recordsForStatuses(Set<int> statusCodes) {
    return recordsNotifier.value
        .where((record) => statusCodes.contains(record.statusCode))
        .toList();
  }

  int countForStatuses(Set<int> statusCodes) {
    return recordsNotifier.value
        .where((record) => statusCodes.contains(record.statusCode))
        .length;
  }

  void deleteOrder(String orderId) {
    recordsNotifier.value = recordsNotifier.value
        .where((record) => record.id != orderId)
        .toList();
    unawaited(_markOrderDeleted(orderId));
  }

  void resumeOrder(SalesOrderRecord order) {
    resumeOrderNotifier.value = null;
    resumeOrderNotifier.value = order;
  }

  void clearPendingResumeOrder() {
    resumeOrderNotifier.value = null;
  }

  Future<void> _persistOrderRecord(SalesOrderRecord record) async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      return;
    }

    final now = _formatSqlDateTime(DateTime.now());
    await DatabaseService.instance.transaction((txn) async {
      final existingRows = await txn.query(
        'pos_order',
        columns: const <String>['id', 'remote_id'],
        where: 'tenant_id = ? AND id_pos = ?',
        whereArgs: <Object?>[session.tenantId, record.id],
        limit: 1,
      );
      final existingRemoteId = existingRows.isEmpty
          ? null
          : existingRows.first['remote_id']?.toString();
      final hasRemoteOrder =
          existingRemoteId != null && existingRemoteId.trim().isNotEmpty;
      final syncState = hasRemoteOrder ? 'dirty_update' : 'dirty_create';
      final saleStaffId = await _resolveLocalStaffId(txn, session);
      final posOrderId = await DatabaseService.instance.upsertByUnique(
        txn,
        'pos_order',
        where: 'tenant_id = ? AND id_pos = ?',
        whereArgs: <Object?>[session.tenantId, record.id],
        insertValues: <String, Object?>{
          'tenant_id': session.tenantId,
          'customer_id': record.customerLocalId,
          'sale_staff_id': saleStaffId,
          'id_pos': record.id,
          'customer_remote_id': record.customerRemoteId,
          'sale_staff_remote_id': session.staffId,
          'formatted_number': record.token,
          'order_date': _formatSqlDate(record.createdAt),
          'business_date': _formatSqlDate(record.createdAt),
          'currency_remote_id': defaultCurrencyId.toString(),
          'currency_code': defaultCurrencyCode,
          'billing_street':
              (record.customerAddress != null &&
                  record.customerAddress!.trim().isNotEmpty)
              ? record.customerAddress!.trim()
              : record.customerName,
          'source_channel': 'pos',
          'order_type_code': record.orderType,
          'status_code': record.statusCode.toString(),
          'status_text': record.statusCode.toString(),
          'subtotal_amount': record.subtotalAmount,
          'manual_discount_value': record.orderLevelDiscountAmount,
          'total_amount': record.totalAmount,
          'amount_received': record.statusCode == 2 ? record.totalAmount : 0,
          'total_left_to_pay_amount': record.statusCode == 2
              ? 0
              : record.totalAmount,
          'order_note': record.note,
          'custom_fields_json': jsonEncode(_buildOrderCustomFields(record)),
          'sync_state': syncState,
          'last_synced_at': null,
          'created_at': now,
          'updated_at': now,
        },
        updateValues: <String, Object?>{
          'customer_id': record.customerLocalId,
          'sale_staff_id': saleStaffId,
          'customer_remote_id': record.customerRemoteId,
          'sale_staff_remote_id': session.staffId,
          'formatted_number': record.token,
          'order_date': _formatSqlDate(record.createdAt),
          'business_date': _formatSqlDate(record.createdAt),
          'currency_remote_id': defaultCurrencyId.toString(),
          'currency_code': defaultCurrencyCode,
          'billing_street':
              (record.customerAddress != null &&
                  record.customerAddress!.trim().isNotEmpty)
              ? record.customerAddress!.trim()
              : record.customerName,
          'source_channel': 'pos',
          'order_type_code': record.orderType,
          'status_code': record.statusCode.toString(),
          'status_text': record.statusCode.toString(),
          'subtotal_amount': record.subtotalAmount,
          'manual_discount_value': record.orderLevelDiscountAmount,
          'total_amount': record.totalAmount,
          'amount_received': record.statusCode == 2 ? record.totalAmount : 0,
          'total_left_to_pay_amount': record.statusCode == 2
              ? 0
              : record.totalAmount,
          'order_note': record.note,
          'custom_fields_json': jsonEncode(_buildOrderCustomFields(record)),
          'sync_state': syncState,
          'updated_at': now,
          'deleted_at': null,
        },
      );

      final itemRows = <Map<String, Object?>>[];
      for (var index = 0; index < record.items.length; index++) {
        final item = record.items[index];
        final productLocalId = await _resolveProductLocalId(
          txn,
          session.tenantId,
          item.productRemoteId,
        );
        itemRows.add(<String, Object?>{
          'tenant_id': session.tenantId,
          'order_id': posOrderId,
          'product_id': productLocalId,
          'remote_id': null,
          'order_remote_id': null,
          'order_id_pos': record.id,
          'product_remote_id': item.productRemoteId,
          'product_name_snapshot': item.name,
          'description': item.name,
          'qty': item.quantity,
          'price_amount': item.activeUnitPrice,
          'base_price_amount': item.regularUnitPrice,
          'line_subtotal_amount': item.totalPrice,
          'discount_amount':
              (item.regularUnitPrice - item.activeUnitPrice).clamp(0, 1 << 31) *
              item.quantity,
          'discount_type': item.isDiscountEnabled ? 'item' : null,
          'order_type_code': item.orderType,
          'note': item.note,
          'kitchen_status': record.statusCode == 1 ? 'queued' : null,
          'sort_order': index,
          'raw_payload_json': jsonEncode(<String, Object?>{
            'name': item.name,
            'product_remote_id': item.productRemoteId,
            'qty': item.quantity,
            'price_amount': item.activeUnitPrice,
            'image_url': item.imageUrl,
          }),
          'sync_state': syncState,
          'created_at': now,
          'updated_at': now,
        });
      }
      await DatabaseService.instance.replaceChildren(
        txn,
        'pos_order_item',
        where: 'tenant_id = ? AND order_id = ?',
        whereArgs: <Object?>[session.tenantId, posOrderId],
        rows: itemRows,
      );

      final allowedPaymentModes = await _resolveAllowedPaymentModeRemoteIds(
        txn,
        session.tenantId,
      );

      await _enqueueOrderMutation(
        txn,
        session.tenantId,
        session.baseUrl,
        session.authToken,
        posOrderId,
        existingRemoteId,
        record,
        allowedPaymentModes: allowedPaymentModes,
        operation: hasRemoteOrder ? 'update_order' : 'create_order',
        method: hasRemoteOrder ? 'PUT' : 'POST',
      );

      if (record.statusCode == 2) {
        await _persistOrderPayment(txn, session, posOrderId, record);
      }
    });

    unawaited(PosV2SyncQueueProcessor.instance.flushPending());
    await refreshFromPersistence();
  }

  Future<void> _persistOrderPayment(
    dynamic txn,
    PosV2RuntimeSession session,
    int posOrderId,
    SalesOrderRecord record,
  ) async {
    final now = _formatSqlDateTime(DateTime.now());
    final paymentModeRemoteId = await _resolveDefaultPaymentModeRemoteId(
      txn,
      session.tenantId,
    );
    await DatabaseService.instance.upsertByUnique(
      txn,
      'pos_order_payment',
      where: 'tenant_id = ? AND id_pos = ? AND payment_method = ?',
      whereArgs: <Object?>[session.tenantId, record.id, 'pay_now'],
      insertValues: <String, Object?>{
        'tenant_id': session.tenantId,
        'order_id': posOrderId,
        'remote_id': null,
        'invoice_remote_id': null,
        'id_pos': record.id,
        'payment_mode_remote_id': paymentModeRemoteId,
        'payment_mode_name_snapshot': paymentModeRemoteId,
        'amount': record.totalAmount,
        'payment_method': 'pay_now',
        'payment_date': now,
        'recorded_at': now,
        'note': 'Generated from FlinkPOS V2 Pay Now action',
        'raw_payload_json': jsonEncode(<String, Object?>{
          'id_pos': record.id,
          'amount': record.totalAmount,
          'payment_method': 'pay_now',
        }),
        'sync_state': 'dirty_create',
        'created_at': now,
        'updated_at': now,
      },
      updateValues: <String, Object?>{
        'order_id': posOrderId,
        'payment_mode_remote_id': paymentModeRemoteId,
        'payment_mode_name_snapshot': paymentModeRemoteId,
        'amount': record.totalAmount,
        'payment_date': now,
        'recorded_at': now,
        'note': 'Generated from FlinkPOS V2 Pay Now action',
        'raw_payload_json': jsonEncode(<String, Object?>{
          'id_pos': record.id,
          'amount': record.totalAmount,
          'payment_method': 'pay_now',
        }),
        'sync_state': 'dirty_update',
        'updated_at': now,
        'deleted_at': null,
      },
    );

    final payload = <String, Object?>{
      'id_pos': record.id,
      'amount': record.totalAmount.toString(),
      'paymentmethod': 'pay_now',
      'date': now,
      'note': 'Generated from FlinkPOS V2 Pay Now action',
      ...?_optionalField('paymentmode', paymentModeRemoteId),
    };
    await _enqueueSyncQueue(
      txn,
      tenantId: session.tenantId,
      baseUrl: session.baseUrl,
      authToken: session.authToken,
      entityType: 'pos_transaction',
      entityLocalId: posOrderId,
      entityRemoteId: record.id,
      operation: 'create_payment',
      method: 'POST',
      endpoint: 'api/v2/pos-transaction',
      dedupeKey: 'pos-transaction:pay_now:${record.id}',
      requestBody: payload,
    );
  }

  Future<void> _enqueueOrderMutation(
    dynamic txn,
    int tenantId,
    String baseUrl,
    String authToken,
    int posOrderId,
    String? remoteOrderId,
    SalesOrderRecord record, {
    required List<String> allowedPaymentModes,
    required String operation,
    required String method,
  }) {
    final isCreate = method == 'POST';
    final payload = _buildOrderPayload(
      record,
      allowedPaymentModes,
      isCreate: isCreate,
    );
    return _enqueueSyncQueue(
      txn,
      tenantId: tenantId,
      baseUrl: baseUrl,
      authToken: authToken,
      entityType: 'pos_order',
      entityLocalId: posOrderId,
      entityRemoteId: remoteOrderId,
      operation: operation,
      method: method,
      endpoint: isCreate
          ? 'api/v2/pos-order'
          : 'api/v2/pos-order/$remoteOrderId',
      dedupeKey: 'pos-order:${record.id}',
      requestBody: payload,
    );
  }

  Future<void> _enqueueSyncQueue(
    dynamic txn, {
    required int tenantId,
    required String baseUrl,
    required String authToken,
    required String entityType,
    required int? entityLocalId,
    required String? entityRemoteId,
    required String operation,
    required String method,
    required String endpoint,
    required String dedupeKey,
    required Map<String, Object?> requestBody,
  }) {
    final now = _formatSqlDateTime(DateTime.now());
    return DatabaseService.instance
        .upsertByUnique(
          txn,
          'sync_queue',
          where: 'tenant_id = ? AND dedupe_key = ?',
          whereArgs: <Object?>[tenantId, dedupeKey],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'entity_type': entityType,
            'entity_local_id': entityLocalId,
            'entity_remote_id': entityRemoteId,
            'operation': operation,
            'method': method,
            'endpoint': endpoint,
            'base_url': baseUrl,
            'request_headers_json': jsonEncode(<String, Object?>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'authtoken': authToken,
            }),
            'request_body_json': jsonEncode(requestBody),
            'dedupe_key': dedupeKey,
            'priority': entityType == 'pos_transaction' ? 120 : 100,
            'status': 'pending',
            'retry_count': 0,
            'next_retry_at': null,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'entity_type': entityType,
            'entity_local_id': entityLocalId,
            'entity_remote_id': entityRemoteId,
            'operation': operation,
            'method': method,
            'endpoint': endpoint,
            'base_url': baseUrl,
            'request_headers_json': jsonEncode(<String, Object?>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'authtoken': authToken,
            }),
            'request_body_json': jsonEncode(requestBody),
            'status': 'pending',
            'next_retry_at': null,
            'updated_at': now,
          },
        )
        .then((_) {});
  }

  Map<String, Object?> _buildOrderPayload(
    SalesOrderRecord record,
    List<String> allowedPaymentModes, {
    required bool isCreate,
  }) {
    final saleAgent = int.tryParse(
      PosV2RuntimeSessionStore.instance.currentSession?.staffId ?? '',
    );
    return <String, Object?>{
      'id_pos': record.id,
      'clientid': record.customerRemoteId,
      'date': _formatSqlDate(record.createdAt),
      'duedate': _formatSqlDate(record.createdAt),
      'currency': defaultCurrencyId,
      'billing_street':
          (record.customerAddress != null &&
              record.customerAddress!.trim().isNotEmpty)
          ? record.customerAddress!.trim()
          : record.customerName,
      if (!isCreate) 'status': record.statusCode.toString(),
      'order_type': _toBackendOrderTypeCode(record.orderType),
      'subtotal': record.subtotalAmount.toString(),
      'manual_discount_value': record.orderLevelDiscountAmount.toString(),
      'total': record.totalAmount.toString(),
      'prefix': 'POS-',
      'allowed_payment_modes': allowedPaymentModes,
      if (saleAgent != null && saleAgent > 0) 'sale_agent': saleAgent,
      'order_note': record.note,
      'newitems': record.items
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final item = entry.value;
            return <String, Object?>{
              'itemid': item.productRemoteId,
              'description': item.name,
              'long_description': '',
              'qty': item.quantity,
              'rate': item.activeUnitPrice.toString(),
              'unit': '',
              'taxname': const <String>[],
              'order': index + 1,
            };
          })
          .toList(growable: false),
    };
  }

  Map<String, Object?> _buildOrderCustomFields(SalesOrderRecord record) {
    if ((record.appliedPromotionRemoteId ?? '').isEmpty &&
        (record.appliedPromotionName ?? '').isEmpty &&
        (record.appliedPromotionType ?? '').isEmpty &&
        (record.appliedPromotionSummary ?? '').isEmpty) {
      return const <String, Object?>{};
    }

    return <String, Object?>{
      'order_promotion': <String, Object?>{
        'remote_id': record.appliedPromotionRemoteId,
        'name': record.appliedPromotionName,
        'promo_type': record.appliedPromotionType,
        'summary': record.appliedPromotionSummary,
      },
    };
  }

  String? _extractPromotionField(Object? rawCustomFields, String key) {
    final text = rawCustomFields?.toString();
    if (text == null || text.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final promotion = decoded['order_promotion'];
      if (promotion is! Map<String, dynamic>) {
        return null;
      }
      return promotion[key]?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _markOrderDeleted(String orderId) async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      return;
    }

    final now = _formatSqlDateTime(DateTime.now());
    await DatabaseService.instance.transaction((txn) async {
      await txn.update(
        'pos_order',
        <String, Object?>{'deleted_at': now, 'updated_at': now},
        where: 'tenant_id = ? AND id_pos = ?',
        whereArgs: <Object?>[session.tenantId, orderId],
      );
    });
  }

  Future<int?> _resolveLocalStaffId(
    dynamic txn,
    PosV2RuntimeSession session,
  ) async {
    if ((session.staffId ?? '').isNotEmpty) {
      final byRemote = await DatabaseService.instance.findLocalId(
        txn,
        'staff',
        where: 'tenant_id = ? AND remote_id = ?',
        whereArgs: <Object?>[session.tenantId, session.staffId],
      );
      if (byRemote != null) {
        return byRemote;
      }
    }

    if ((session.staffEmail ?? '').isNotEmpty) {
      return DatabaseService.instance.findLocalId(
        txn,
        'staff',
        where: 'tenant_id = ? AND email = ?',
        whereArgs: <Object?>[session.tenantId, session.staffEmail],
      );
    }

    return null;
  }

  Future<int?> _resolveProductLocalId(
    dynamic txn,
    int tenantId,
    String? productRemoteId,
  ) {
    if (productRemoteId == null || productRemoteId.isEmpty) {
      return Future<int?>.value(null);
    }
    return DatabaseService.instance.findLocalId(
      txn,
      'product',
      where: 'tenant_id = ? AND remote_id = ?',
      whereArgs: <Object?>[tenantId, productRemoteId],
    );
  }

  Future<String?> _resolveDefaultPaymentModeRemoteId(
    dynamic txn,
    int tenantId,
  ) async {
    final rows = await txn.query(
      'payment_mode',
      columns: <String>['remote_id'],
      where: 'tenant_id = ? AND deleted_at IS NULL AND is_active = 1',
      whereArgs: <Object?>[tenantId],
      orderBy: 'selected_by_default DESC, id ASC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['remote_id']?.toString();
  }

  Future<List<String>> _resolveAllowedPaymentModeRemoteIds(
    dynamic txn,
    int tenantId,
  ) async {
    final rows = await txn.query(
      'payment_mode',
      columns: <String>['remote_id'],
      where: 'tenant_id = ? AND deleted_at IS NULL AND is_active = 1',
      whereArgs: <Object?>[tenantId],
      orderBy: 'selected_by_default DESC, id ASC',
    );
    final ids = <String>[];
    for (final row in rows) {
      final value = row['remote_id']?.toString();
      if (value != null && value.isNotEmpty) {
        ids.add(value);
      }
    }
    if (ids.isNotEmpty) {
      return ids;
    }
    return const <String>['1'];
  }

  void _recalculateSequence(List<SalesOrderRecord> records) {
    var maxSequence = 0;
    for (final record in records) {
      final number = _extractSequence(record.token);
      if (number > maxSequence) {
        maxSequence = number;
      }
    }
    _sequence = maxSequence + 1;
  }

  int _extractSequence(String tokenString) {
    final match = RegExp(r'(\d+)$').firstMatch(tokenString);
    if (match == null) {
      return 0;
    }
    return int.tryParse(match.group(1)!) ?? 0;
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

  double? _asDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  DateTime _parseDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return DateTime.now();
    }
    return DateTime.tryParse(raw.replaceFirst(' ', 'T')) ?? DateTime.now();
  }

  String _formatSqlDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatSqlDateTime(DateTime value) {
    final date = _formatSqlDate(value);
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$date $hour:$minute:$second';
  }

  String _toBackendOrderTypeCode(String localOrderType) {
    switch (localOrderType) {
      case 'take_away':
        return 'takeaway';
      case 'shopee_food':
        return 'shopeefood';
      case 'go_food':
        return 'gofood';
      case 'grab_food':
        return 'grabfood';
      case 'dine_in':
      default:
        return 'dinein';
    }
  }

  Map<String, Object?>? _optionalField(String key, Object? value) {
    if (value == null) {
      return null;
    }
    return <String, Object?>{key: value};
  }

  /// Mirrors PosCatalogStore._resolveProductImageUrl.
  /// Converts a raw DB image value (filename or absolute URL) to a
  /// loadable absolute URL, or empty string when there is no image.
  String _resolveProductImageUrl(String? rawImageUrl) {
    final value = rawImageUrl?.trim() ?? '';
    if (value.isEmpty) {
      return '';
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'https://flinkaja.com/uploads/products/$value';
  }
}
