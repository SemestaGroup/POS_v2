import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_constants.dart';

import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../core/services/sync/pos_v2_sync_queue_processor.dart';
import '../../../operations/stores/operations_read_stores.dart';
import 'order_type_resolver.dart';
import 'pos_order_type_store.dart';

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
    this.fallbackSubtotalAmount,
    this.fallbackTotalAmount,
    this.taxAmount = 0,
    this.taxName,
    this.taxPercentage = 0.0,
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
  final int? fallbackSubtotalAmount;
  final int? fallbackTotalAmount;
  final int taxAmount;
  final String? taxName;
  final double taxPercentage;

  int get itemDiscountTotal => items.fold<int>(
    0,
    (sum, item) =>
        sum +
        ((item.isDiscountEnabled && item.discountedUnitPrice != null)
            ? (item.regularUnitPrice - item.discountedUnitPrice!).clamp(
                    0,
                    1 << 31,
                  ) *
                  item.quantity
            : 0),
  );

  int get totalDiscountAmount => itemDiscountTotal + orderLevelDiscountAmount;

  int get subtotalAmount => items.isNotEmpty
      ? items.fold<int>(
          0,
          (sum, item) => sum + (item.regularUnitPrice * item.quantity),
        )
      : (fallbackSubtotalAmount ?? 0);

  int get totalAmount => items.isNotEmpty
      ? (subtotalAmount - totalDiscountAmount + taxAmount).clamp(0, 1 << 31)
      : (fallbackTotalAmount ?? 0);

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}

class SalesPaymentModeOption {
  const SalesPaymentModeOption({
    required this.remoteId,
    required this.name,
    this.description,
    this.selectedByDefault = false,
  });

  final String remoteId;
  final String name;
  final String? description;
  final bool selectedByDefault;
}

class SalesPaymentModeSnapshot {
  const SalesPaymentModeSnapshot({
    required this.options,
    this.preselectedRemoteId,
    this.matchedByOrderType = false,
  });

  final List<SalesPaymentModeOption> options;
  final String? preselectedRemoteId;
  final bool matchedByOrderType;
}

class _PaymentModeResolution {
  const _PaymentModeResolution({
    required this.options,
    required this.allowedRemoteIds,
    this.selectedRemoteId,
    this.selectedName,
    this.matchedByOrderType = false,
  });

  final List<SalesPaymentModeOption> options;
  final List<String> allowedRemoteIds;
  final String? selectedRemoteId;
  final String? selectedName;
  final bool matchedByOrderType;
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
          pos_order.subtotal_amount,
          pos_order.total_amount,
          pos_order.billing_street,
          customer.display_name AS customer_name,
          customer.phone_number AS customer_phone,
          customer.address_line1 AS customer_address
        FROM pos_order
        LEFT JOIN customer ON customer.id = pos_order.customer_id
        WHERE pos_order.tenant_id = ?
          AND pos_order.deleted_at IS NULL
        ORDER BY COALESCE(pos_order.created_at, pos_order.order_date, pos_order.updated_at) DESC
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
            createdAt: _resolveOrderCreatedAt(
              orderDateRaw: row['order_date']?.toString(),
              createdAtRaw: row['created_at']?.toString(),
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
            orderType: () {
              final headerCode = row['order_type_code']?.toString()?.trim();
              if (headerCode != null && headerCode.isNotEmpty) {
                return OrderTypeResolver.resolveCode(
                      headerCode,
                      PosOrderTypeStore.instance.snapshot.orderTypes,
                    ) ??
                    headerCode;
              }
              for (final item in items) {
                final itemCode = item.orderType?.trim();
                if (itemCode != null && itemCode.isNotEmpty) {
                  return OrderTypeResolver.resolveCode(
                        itemCode,
                        PosOrderTypeStore.instance.snapshot.orderTypes,
                      ) ??
                      itemCode;
                }
              }
              return '';
            }(),
            note: row['order_note']?.toString(),
            orderLevelDiscountAmount: _asInt(row['manual_discount_value']) ?? 0,
            fallbackSubtotalAmount: _asInt(row['subtotal_amount']),
            fallbackTotalAmount: _asInt(row['total_amount']),
            taxAmount:
                _asInt(
                  _extractCustomField(row['custom_fields_json'], 'tax_amount'),
                ) ??
                0,
            taxName: _extractCustomField(row['custom_fields_json'], 'tax_name'),
            taxPercentage:
                double.tryParse(
                  _extractCustomField(
                        row['custom_fields_json'],
                        'tax_percentage',
                      ) ??
                      '',
                ) ??
                0.0,
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

  Future<SalesOrderRecord?> createOrder({
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
    String? paymentModeRemoteId,
    String? paymentModeName,
    int taxAmount = 0,
    String? taxName,
    double taxPercentage = 0.0,
    int? shiftSessionId,
    bool processQueueNow = false,
  }) async {
    if (items.isEmpty) {
      return null;
    }

    final activeTypes = PosOrderTypeStore.instance.snapshot.orderTypes;
    final resolvedOrderType = OrderTypeResolver.resolveCode(
      orderType,
      activeTypes,
    );
    if (resolvedOrderType == null || resolvedOrderType.isEmpty) {
      debugPrint(
        '[POS_ORDER] Blocked order creation: order_type is empty or not synced.',
      );
      return null;
    }
    final finalOrderType = resolvedOrderType;
    final isUpdate =
        existingOrderId != null && existingOrderId.trim().isNotEmpty;
    final canonicalizedItems = items
        .map((item) {
          final rawItemType = item.orderType;
          final canonicalItemOrderType =
              (rawItemType != null && rawItemType.trim().isNotEmpty)
                  ? (OrderTypeResolver.resolveCode(rawItemType, activeTypes) ??
                      finalOrderType)
                  : finalOrderType;
          return SalesOrderLineItem(
            id: item.id,
            name: item.name,
            imageUrl: item.imageUrl,
            regularUnitPrice: item.regularUnitPrice,
            quantity: item.quantity,
            productRemoteId: item.productRemoteId,
            discountedUnitPrice: item.discountedUnitPrice,
            promoLabel: item.promoLabel,
            isDiscountEnabled: item.isDiscountEnabled,
            orderType: canonicalItemOrderType,
            note: item.note,
          );
        })
        .toList(growable: false);
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
      orderType: finalOrderType,
      note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
      orderLevelDiscountAmount: orderLevelDiscountAmount,
      taxAmount: taxAmount,
      taxName: taxName,
      taxPercentage: taxPercentage,
      items: canonicalizedItems,
    );
    debugPrint(
      '[POS_ORDER_LOG] Order Created: id=${record.id}, subtotal=${record.subtotalAmount}, discount=${record.orderLevelDiscountAmount}, taxAmount=${record.taxAmount}, taxName=${record.taxName}, taxPercentage=${record.taxPercentage}%, totalPay=${record.totalAmount}',
    );

    if (!isUpdate) {
      _sequence += 1;
    }
    recordsNotifier.value = [
      record,
      ...recordsNotifier.value.where((item) => item.id != record.id),
    ];
    await _persistOrderRecord(
      record,
      paymentModeRemoteId: paymentModeRemoteId,
      paymentModeName: paymentModeName,
      shiftSessionId: shiftSessionId,
      processQueueNow: processQueueNow,
    );
    return record;
  }

  Future<SalesPaymentModeSnapshot> loadPaymentModeSnapshot({
    required Iterable<String> orderTypes,
  }) async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      return const SalesPaymentModeSnapshot(
        options: <SalesPaymentModeOption>[],
      );
    }

    final database = await DatabaseService.instance.database;
    final resolution = await _resolvePaymentModeResolution(
      database,
      session.tenantId,
      orderTypes: orderTypes,
    );
    return SalesPaymentModeSnapshot(
      options: resolution.options,
      preselectedRemoteId: resolution.selectedRemoteId,
      matchedByOrderType: resolution.matchedByOrderType,
    );
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

  Future<void> _persistOrderRecord(
    SalesOrderRecord record, {
    String? paymentModeRemoteId,
    String? paymentModeName,
    int? shiftSessionId,
    bool processQueueNow = false,
  }) async {
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
          'shift_session_id': shiftSessionId,
          'location_id': session.locationId,
          'register_id': session.registerId,
          'customer_remote_id': record.customerRemoteId,
          'sale_staff_remote_id': session.staffId,
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
          'discount_total_amount': record.totalDiscountAmount,
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
          'created_at': _formatSqlDateTime(record.createdAt),
          'updated_at': now,
        },
        updateValues: <String, Object?>{
          'customer_id': record.customerLocalId,
          'sale_staff_id': saleStaffId,
          'shift_session_id': shiftSessionId,
          'location_id': session.locationId,
          'register_id': session.registerId,
          'customer_remote_id': record.customerRemoteId,
          'sale_staff_remote_id': session.staffId,
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
          'discount_total_amount': record.totalDiscountAmount,
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

      final paymentModeResolution = await _resolvePaymentModeResolution(
        txn,
        session.tenantId,
        orderTypes: record.items
            .map((item) => item.orderType ?? record.orderType)
            .followedBy(<String>[record.orderType]),
        preferredPaymentModeRemoteId: paymentModeRemoteId,
      );

      await _enqueueOrderMutation(
        txn,
        session.tenantId,
        session.baseUrl,
        session.authToken,
        posOrderId,
        existingRemoteId,
        record,
        allowedPaymentModes: paymentModeResolution.allowedRemoteIds,
        operation: hasRemoteOrder ? 'update_order' : 'create_order',
        method: hasRemoteOrder ? 'PUT' : 'POST',
      );

      if (record.statusCode == 2) {
        await _persistOrderPayment(
          txn,
          session,
          posOrderId,
          record,
          paymentModeRemoteId:
              paymentModeResolution.selectedRemoteId ?? paymentModeRemoteId,
          paymentModeName:
              paymentModeResolution.selectedName ?? paymentModeName,
        );
      }
    });

    if (processQueueNow) {
      // Flush only this order's queue items so we don't accidentally send
      // unrelated pending orders from other sessions at the same time.
      unawaited(PosV2SyncQueueProcessor.instance.flushForOrder(record.id));
      // Then flush any remaining items (e.g. leftover from prior sessions)
      // in the background so the UI is not blocked.
      unawaited(PosV2SyncQueueProcessor.instance.flushPending());
    } else {
      unawaited(PosV2SyncQueueProcessor.instance.flushPending());
    }
    await refreshFromPersistence();
    unawaited(RecapStore.instance.refresh());
    unawaited(CashFlowStore.instance.refresh());
  }

  Future<void> _persistOrderPayment(
    dynamic txn,
    PosV2RuntimeSession session,
    int posOrderId,
    SalesOrderRecord record, {
    String? paymentModeRemoteId,
    String? paymentModeName,
  }) async {
    final now = _formatSqlDateTime(DateTime.now());
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
        'payment_mode_name_snapshot': paymentModeName ?? paymentModeRemoteId,
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
        'payment_mode_name_snapshot': paymentModeName ?? paymentModeRemoteId,
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
      dependencyEntityType: 'pos_order',
      dependencyLocalId: posOrderId,
      operation: 'create_payment',
      method: 'POST',
      endpoint: 'api/v2/pos-transaction',
      dedupeKey: 'pos-transaction:pay_now:${record.id}',
      requestBody: payload,
    );
  }

  Future<_PaymentModeResolution> _resolvePaymentModeResolution(
    dynamic executor,
    int tenantId, {
    required Iterable<String> orderTypes,
    String? preferredPaymentModeRemoteId,
  }) async {
    final paymentModeRows = await executor.query(
      'payment_mode',
      columns: <String>[
        'remote_id',
        'name',
        'description',
        'selected_by_default',
      ],
      where: 'tenant_id = ? AND deleted_at IS NULL AND is_active = 1',
      whereArgs: <Object?>[tenantId],
      orderBy: 'selected_by_default DESC, id ASC',
    );
    final orderTypeRows = await executor.query(
      'order_type',
      columns: <String>['code', 'name'],
      where: 'tenant_id = ? AND deleted_at IS NULL AND is_active = 1',
      whereArgs: <Object?>[tenantId],
      orderBy: 'id ASC',
    );

    final allOptions = <SalesPaymentModeOption>[];
    for (final row in paymentModeRows) {
      final remoteId = row['remote_id']?.toString().trim() ?? '';
      final name = row['name']?.toString().trim() ?? '';
      if (remoteId.isEmpty || name.isEmpty) {
        continue;
      }
      allOptions.add(
        SalesPaymentModeOption(
          remoteId: remoteId,
          name: name,
          description: row['description']?.toString(),
          selectedByDefault:
              (row['selected_by_default']?.toString() ?? '').trim() == '1',
        ),
      );
    }

    if (allOptions.isEmpty) {
      return const _PaymentModeResolution(
        options: <SalesPaymentModeOption>[],
        allowedRemoteIds: <String>['1'],
      );
    }

    final requestedTokens = orderTypes
        .map(_normalizeNameToken)
        .where((token) => token.isNotEmpty)
        .toSet();
    final activeOrderTypeTokens = <String>{...requestedTokens};
    final knownOrderTypeTokens = <String>{};
    for (final row in orderTypeRows) {
      final codeToken = _normalizeNameToken(row['code']?.toString());
      final nameToken = _normalizeNameToken(row['name']?.toString());
      if (codeToken.isNotEmpty) {
        knownOrderTypeTokens.add(codeToken);
      }
      if (nameToken.isNotEmpty) {
        knownOrderTypeTokens.add(nameToken);
      }
      if (requestedTokens.contains(codeToken) ||
          requestedTokens.contains(nameToken)) {
        if (codeToken.isNotEmpty) {
          activeOrderTypeTokens.add(codeToken);
        }
        if (nameToken.isNotEmpty) {
          activeOrderTypeTokens.add(nameToken);
        }
      }
    }

    final duplicatedModeTokens = allOptions
        .map((option) => _normalizeNameToken(option.name))
        .where(knownOrderTypeTokens.contains)
        .toSet();
    final matchedOptions = allOptions
        .where(
          (option) =>
              activeOrderTypeTokens.contains(_normalizeNameToken(option.name)),
        )
        .toList(growable: false);
    final matchedByOrderType = matchedOptions.isNotEmpty;

    var filteredOptions = matchedOptions;

    if (filteredOptions.isEmpty) {
      filteredOptions = allOptions
          .where(
            (option) => !duplicatedModeTokens.contains(
              _normalizeNameToken(option.name),
            ),
          )
          .toList(growable: false);
    }

    if (filteredOptions.isEmpty) {
      filteredOptions = allOptions;
    }

    // Cash remains a valid cashier-controlled settlement even when the active
    // order type resolves to a merchant payment method (for example GoFood).
    // Keep it available alongside the matched merchant methods on every POS
    // workspace, matching the tablet payment flow.
    final cashOptions = allOptions.where((option) {
      final name = option.name.toLowerCase();
      return name.contains('cash') || name.contains('tunai');
    });
    for (final cashOption in cashOptions) {
      if (!filteredOptions.any(
        (option) => option.remoteId == cashOption.remoteId,
      )) {
        filteredOptions = [...filteredOptions, cashOption];
      }
    }

    SalesPaymentModeOption? selectedOption;
    if (preferredPaymentModeRemoteId != null &&
        preferredPaymentModeRemoteId.trim().isNotEmpty) {
      selectedOption = filteredOptions.firstWhere(
        (option) => option.remoteId == preferredPaymentModeRemoteId.trim(),
        orElse: () => const SalesPaymentModeOption(remoteId: '', name: ''),
      );
      if (selectedOption.remoteId.isEmpty) {
        selectedOption = null;
      }
    }
    selectedOption ??= filteredOptions.firstWhere(
      (option) => option.selectedByDefault,
      orElse: () => filteredOptions.first,
    );

    final allowedRemoteIds = filteredOptions
        .map((option) => option.remoteId)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return _PaymentModeResolution(
      options: filteredOptions,
      allowedRemoteIds: allowedRemoteIds.isNotEmpty
          ? allowedRemoteIds
          : const <String>['1'],
      selectedRemoteId: selectedOption.remoteId,
      selectedName: selectedOption.name,
      matchedByOrderType: matchedByOrderType,
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
    String? dependencyEntityType,
    int? dependencyLocalId,
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
            'dependency_entity_type': dependencyEntityType,
            'dependency_local_id': dependencyLocalId,
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
            'dependency_entity_type': dependencyEntityType,
            'dependency_local_id': dependencyLocalId,
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

  @visibleForTesting
  Map<String, Object?> buildOrderPayload(
    SalesOrderRecord record,
    List<String> allowedPaymentModes, {
    bool isCreate = true,
  }) =>
      _buildOrderPayload(record, allowedPaymentModes, isCreate: isCreate);

  Map<String, Object?> _buildOrderPayload(
    SalesOrderRecord record,
    List<String> allowedPaymentModes, {
    required bool isCreate,
  }) {
    final saleAgent = int.tryParse(
      PosV2RuntimeSessionStore.instance.currentSession?.staffId ?? '',
    );
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    final itemTaxArr =
        (record.taxAmount > 0 &&
            (record.taxName ?? '').isNotEmpty &&
            record.taxPercentage > 0)
        ? ['${record.taxName}|${record.taxPercentage.toStringAsFixed(2)}']
        : [];
    debugPrint(
      '[POS_ORDER_PAYLOAD_LOG] Order API Payload taxname: $itemTaxArr, total: ${record.totalAmount}',
    );

    return <String, Object?>{
      'id_pos': record.id,
      'clientid': int.tryParse(record.customerRemoteId) ?? 0,
      if ((session?.locationId ?? '').isNotEmpty)
        'location_id': session!.locationId,
      if ((session?.registerId ?? '').isNotEmpty)
        'register_id': session!.registerId,
      if ((session?.deviceId ?? '').isNotEmpty) 'device_id': session!.deviceId,
      'date': _formatSqlDate(record.createdAt),
      'duedate': _formatSqlDate(record.createdAt),
      'currency': defaultCurrencyId,
      'billing_street':
          (record.customerAddress != null &&
              record.customerAddress!.trim().isNotEmpty)
          ? record.customerAddress!.trim()
          : record.customerName,
      'status': record.statusCode.toString(),
      'order_type': record.orderType,
      'subtotal': record.subtotalAmount,
      'manual_discount_value': record.orderLevelDiscountAmount,
      'total': record.totalAmount,
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
            final itemOrderType =
                (item.orderType != null && item.orderType!.trim().isNotEmpty)
                    ? item.orderType!.trim()
                    : record.orderType;
            return <String, Object?>{
              'itemid': item.productRemoteId,
              'description': item.name,
              'unit': '',
              'long_description': '',
              'qty': item.quantity,
              'rate': item.activeUnitPrice,
              if (itemOrderType.isNotEmpty) 'order_type': itemOrderType,
              if (item.note != null && item.note!.trim().isNotEmpty)
                'note': item.note!.trim(),
              'taxname':
                  (record.taxAmount > 0 &&
                      (record.taxName ?? '').isNotEmpty &&
                      record.taxPercentage > 0)
                  ? <String>[
                      '${record.taxName}|${record.taxPercentage.toStringAsFixed(2)}',
                    ]
                  : const <String>[],
              'order': index + 1,
            };
          })
          .toList(growable: false),
    };
  }

  Map<String, Object?> _buildOrderCustomFields(SalesOrderRecord record) {
    final fields = <String, dynamic>{};
    if ((record.appliedPromotionRemoteId ?? '').isNotEmpty ||
        (record.appliedPromotionName ?? '').isNotEmpty ||
        (record.appliedPromotionType ?? '').isNotEmpty ||
        (record.appliedPromotionSummary ?? '').isNotEmpty) {
      fields['order_promotion'] = <String, Object?>{
        'remote_id': record.appliedPromotionRemoteId,
        'name': record.appliedPromotionName,
        'promo_type': record.appliedPromotionType,
        'summary': record.appliedPromotionSummary,
      };
    }
    if (record.taxAmount > 0) {
      fields['tax_amount'] = record.taxAmount.toString();
      if (record.taxName != null) {
        fields['tax_name'] = record.taxName;
      }
      if (record.taxPercentage > 0) {
        fields['tax_percentage'] = record.taxPercentage.toString();
      }
    }
    return fields;
  }

  String? _extractCustomField(Object? rawCustomFields, String key) {
    final text = rawCustomFields?.toString();
    if (text == null || text.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return decoded[key]?.toString();
    } catch (_) {
      return null;
    }
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
      int? localPk;
      if (orderId.startsWith('POS-')) {
        localPk = int.tryParse(orderId.substring(4));
      } else {
        localPk = int.tryParse(orderId);
      }

      final whereClause = localPk != null
          ? 'tenant_id = ? AND (id_pos = ? OR remote_id = ? OR id = ?)'
          : 'tenant_id = ? AND (id_pos = ? OR remote_id = ?)';
      final whereArgs = <Object?>[
        session.tenantId,
        orderId,
        orderId,
        ?localPk,
      ];

      final matchingRows = await txn.query(
        'pos_order',
        columns: const <String>['id', 'id_pos', 'remote_id'],
        where: whereClause,
        whereArgs: whereArgs,
      );

      await txn.update(
        'pos_order',
        <String, Object?>{'deleted_at': now, 'updated_at': now},
        where: whereClause,
        whereArgs: whereArgs,
      );

      for (final row in matchingRows) {
        final orderPk = row['id'];
        final rowIdPos = row['id_pos']?.toString();
        final rowRemoteId = row['remote_id']?.toString();

        if (orderPk != null) {
          await txn.update(
            'pos_order_item',
            <String, Object?>{'deleted_at': now, 'updated_at': now},
            where: 'tenant_id = ? AND order_id = ?',
            whereArgs: <Object?>[session.tenantId, orderPk],
          );
        }

        await txn.delete(
          'sync_queue',
          where:
              'tenant_id = ? AND entity_type = ? AND (entity_local_id = ? OR entity_remote_id = ? OR dedupe_key LIKE ?)',
          whereArgs: <Object?>[
            session.tenantId,
            'pos_order',
            orderPk,
            rowRemoteId ?? orderId,
            '%${rowIdPos ?? orderId}%',
          ],
        );

        if (rowRemoteId != null &&
            rowRemoteId.isNotEmpty &&
            session.authToken.isNotEmpty) {
          await _enqueueSyncQueue(
            txn,
            tenantId: session.tenantId,
            baseUrl: session.baseUrl,
            authToken: session.authToken,
            entityType: 'pos_order',
            entityLocalId:
                orderPk is int ? orderPk : int.tryParse(orderPk.toString()),
            entityRemoteId: rowRemoteId,
            operation: 'delete',
            method: 'DELETE',
            endpoint: 'api/v2/pos-order/$rowRemoteId',
            dedupeKey: 'pos-order-delete:$rowRemoteId',
            requestBody: <String, Object?>{
              'id': rowRemoteId,
              ...?rowIdPos == null ? null : {'id_pos': rowIdPos},
              'reason': 'Deleted by cashier',
            },
          );
        }
      }
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
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed == null) {
      return DateTime.now();
    }
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }
  DateTime _resolveOrderCreatedAt({
    required String? orderDateRaw,
    required String? createdAtRaw,
  }) {
    final orderDate = orderDateRaw?.trim();
    final createdAt = createdAtRaw?.trim();
    if (orderDate != null && orderDate.isNotEmpty && orderDate.contains(':')) {
      return _parseDateTime(orderDate);
    }
    if (createdAt != null && createdAt.isNotEmpty) {
      return _parseDateTime(createdAt);
    }
    if (orderDate != null && orderDate.isNotEmpty) {
      return _parseDateTime(orderDate);
    }
    return DateTime.now();
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


  String _normalizeNameToken(String? value) {
    if (value == null) {
      return '';
    }
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
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
    return AppConstants.getProductImageUrl(value);
  }
}
