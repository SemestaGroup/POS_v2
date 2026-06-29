import 'package:sqflite/sqflite.dart';

import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class OrdersSyncAdapter extends BaseV2SyncAdapter {
  OrdersSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(
    V2SyncContext context, {
    Map<String, dynamic>? query,
    bool pullDetails = false,
    int detailLimit = 25,
  }) async {
    final envelope = await buildClient(
      context,
    ).getEnvelope('api/v2/pos-order', query: query);
    final rows = V2SyncUtils.asMapList((envelope['data'] as Object?));
    final scopeKey = query == null || query.isEmpty
        ? 'default'
        : query.toString();
    final detailIds = <String>[];

    var upsertedCount = 0;

    const chunkSize = 50;
    for (var i = 0; i < rows.length; i += chunkSize) {
      final chunk = rows.skip(i).take(chunkSize);
      await databaseService.transaction((txn) async {
        final tenantId = await ensureTenantId(txn, context);

        for (final row in chunk) {
          final remoteId = V2SyncUtils.asString(row['id']);
          final idPos = V2SyncUtils.asString(row['id_pos']);
          if (remoteId == null && idPos == null) {
            continue;
          }
          if (remoteId != null) {
            detailIds.add(remoteId);
          }
          await _upsertOrderHeader(
            txn,
            tenantId,
            row,
            fallbackRemoteId: remoteId,
          );
          upsertedCount += 1;
        }

        await touchCheckpoint(
          txn,
          tenantId,
          endpointName: 'pos-order',
          scopeKey: scopeKey,
          notes: 'Order headers synced from api/v2/pos-order.',
        );
      });
    }

    var replacedChildCount = 0;
    if (pullDetails) {
      for (final detailId in detailIds.take(detailLimit)) {
        final detailResult = await syncDetail(context, detailId);
        upsertedCount += detailResult.upsertedCount;
        replacedChildCount += detailResult.replacedChildCount;
      }
    }

    return V2SyncResult(
      endpointName: 'pos-order',
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
      replacedChildCount: replacedChildCount,
      meta: <String, Object?>{'scopeKey': scopeKey, 'pullDetails': pullDetails},
    );
  }

  Future<V2SyncResult> syncDetail(V2SyncContext context, String orderId) async {
    final envelope = await buildClient(
      context,
    ).getEnvelope('api/v2/pos-order/$orderId');
    final row =
        V2SyncUtils.asMap(envelope['data']) ?? const <String, dynamic>{};
    if (row.isEmpty) {
      return const V2SyncResult(endpointName: 'pos-order-detail');
    }

    var upsertedCount = 0;
    var replacedChildCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      final customerLocalId = await _upsertNestedCustomer(
        txn,
        tenantId,
        row['client'],
      );
      final orderLocalId = await _upsertOrderHeader(
        txn,
        tenantId,
        row,
        customerLocalId: customerLocalId,
        fallbackRemoteId: orderId,
      );
      upsertedCount += 1;

      final itemRows = <Map<String, Object?>>[];
      final now = V2SyncUtils.nowIso();
      for (final item in V2SyncUtils.asMapList(row['items'])) {
        final productRemoteId = V2SyncUtils.asString(
          item['itemid'] ?? item['item_id'],
        );
        final productLocalId = await findLocalIdByRemoteId(
          txn,
          'product',
          tenantId,
          productRemoteId,
        );
        final qty = V2SyncUtils.asDouble(item['qty'], fallback: 0);
        final priceAmount = V2SyncUtils.moneyToMinor(item['rate']);
        final basePriceAmount = V2SyncUtils.moneyToMinor(
          item['regular_rate'] ?? item['rate'],
        );
        itemRows.add(<String, Object?>{
          'tenant_id': tenantId,
          'order_id': orderLocalId,
          'product_id': productLocalId,
          'remote_id': V2SyncUtils.asString(item['id']),
          'order_remote_id': V2SyncUtils.asString(row['id']) ?? orderId,
          'order_id_pos': V2SyncUtils.asString(row['id_pos']),
          'product_remote_id': productRemoteId,
          'product_name_snapshot': V2SyncUtils.asString(
            item['description'] ?? item['name'],
          ),
          'description': V2SyncUtils.asString(item['description']),
          'long_description': V2SyncUtils.asString(item['long_description']),
          'unit_name': V2SyncUtils.asString(item['unit']),
          'qty': qty,
          'price_amount': priceAmount,
          'base_price_amount': basePriceAmount,
          'line_subtotal_amount': (priceAmount * qty).round(),
          'discount_amount': ((basePriceAmount - priceAmount) * qty).round(),
          'discount_type': V2SyncUtils.asString(item['discount_type']),
          'order_type_code': V2SyncUtils.asString(item['order_type']),
          'note': V2SyncUtils.asString(item['note']),
          'tax_names_json': V2SyncUtils.encodeJson(item['taxes']),
          'kitchen_status': V2SyncUtils.asString(item['kitchen_status']),
          'is_refund': V2SyncUtils.intToBoolFlag(item['is_refund']) ? 1 : 0,
          'sort_order': V2SyncUtils.asInt(item['item_order']),
          'raw_payload_json': V2SyncUtils.encodeJson(item),
          'last_synced_at': now,
          'created_at': now,
          'updated_at': now,
        });
      }
      await databaseService.replaceChildren(
        txn,
        'pos_order_item',
        where: 'tenant_id = ? AND order_id = ?',
        whereArgs: <Object?>[tenantId, orderLocalId],
        rows: itemRows,
      );
      replacedChildCount += itemRows.length;

      for (final payment in V2SyncUtils.asMapList(row['payments'])) {
        await _upsertNestedPayment(txn, tenantId, orderLocalId, row, payment);
        upsertedCount += 1;
      }

      await touchCheckpoint(
        txn,
        tenantId,
        endpointName: 'pos-order-detail',
        scopeKey: orderId,
        notes: 'Detailed order payload stored locally.',
      );
    });

    return V2SyncResult(
      endpointName: 'pos-order-detail',
      fetchedCount: 1,
      upsertedCount: upsertedCount,
      replacedChildCount: replacedChildCount,
      meta: <String, Object?>{'orderId': orderId},
    );
  }

  Future<int> _upsertOrderHeader(
    DatabaseExecutor executor,
    int tenantId,
    Map<String, dynamic> row, {
    int? customerLocalId,
    String? fallbackRemoteId,
  }) async {
    final remoteId = V2SyncUtils.asString(row['id']) ?? fallbackRemoteId;
    final idPos = V2SyncUtils.asString(row['id_pos']);
    final customerRemoteId = V2SyncUtils.asString(row['clientid']);
    final saleStaffRemoteId = V2SyncUtils.asString(row['sale_agent']);
    final existingLocalId = await findOrderLocalId(
      executor,
      tenantId,
      remoteId: remoteId,
      idPos: idPos,
    );
    if (customerLocalId == null && existingLocalId != null) {
      final existingRows = await executor.query(
        'pos_order',
        columns: const <String>['customer_id'],
        where: 'id = ?',
        whereArgs: <Object?>[existingLocalId],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        final existingCustomerId = existingRows.first['customer_id'];
        if (existingCustomerId is int) {
          customerLocalId = existingCustomerId;
        } else if (existingCustomerId != null) {
          customerLocalId = int.tryParse(existingCustomerId.toString());
        }
      }
    }
    if (customerLocalId == null &&
        customerRemoteId != null &&
        customerRemoteId.isNotEmpty) {
      customerLocalId = await findLocalIdByRemoteId(
        executor,
        'customer',
        tenantId,
        customerRemoteId,
      );
    }
    String? preservedCustomFieldsJson;
    String? preservedOrderNote;
    int? preservedManualDiscountValue;
    String? preservedLocationId;
    String? preservedRegisterId;
    int? preservedShiftSessionId;
    int? preservedDeviceSessionId;
    String? preservedShiftSessionRemoteId;
    String? preservedDeviceSessionRemoteId;
    if (existingLocalId != null) {
      final existingRows = await executor.query(
        'pos_order',
        columns: const <String>[
          'custom_fields_json',
          'order_note',
          'manual_discount_value',
          'location_id',
          'register_id',
          'shift_session_id',
          'device_session_id',
          'shift_session_remote_id',
          'device_session_remote_id',
        ],
        where: 'id = ?',
        whereArgs: <Object?>[existingLocalId],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        preservedCustomFieldsJson = existingRows.first['custom_fields_json']
            ?.toString();
        preservedOrderNote = existingRows.first['order_note']?.toString();
        preservedLocationId = existingRows.first['location_id']?.toString();
        preservedRegisterId = existingRows.first['register_id']?.toString();
        preservedShiftSessionId = _asNullableInt(
          existingRows.first['shift_session_id'],
        );
        preservedDeviceSessionId = _asNullableInt(
          existingRows.first['device_session_id'],
        );
        preservedShiftSessionRemoteId = existingRows
            .first['shift_session_remote_id']
            ?.toString();
        preservedDeviceSessionRemoteId = existingRows
            .first['device_session_remote_id']
            ?.toString();
        final manualValue = existingRows.first['manual_discount_value'];
        if (manualValue is int) {
          preservedManualDiscountValue = manualValue;
        } else if (manualValue != null) {
          preservedManualDiscountValue = int.tryParse(manualValue.toString());
        }
      }
    }
    final incomingCustomFieldsJson = V2SyncUtils.encodeJson(
      row['custom_fields'],
    );
    final resolvedCustomFieldsJson =
        (incomingCustomFieldsJson == null || incomingCustomFieldsJson == 'null')
        ? preservedCustomFieldsJson
        : incomingCustomFieldsJson;
    final incomingOrderNote = V2SyncUtils.asString(row['order_note']);
    final resolvedOrderNote =
        incomingOrderNote == null || incomingOrderNote.isEmpty
        ? preservedOrderNote
        : incomingOrderNote;
    final rawManualDiscountValue = row['manual_discount_value'];
    final resolvedManualDiscountValue =
        rawManualDiscountValue == null ||
            rawManualDiscountValue.toString().isEmpty
        ? (preservedManualDiscountValue ?? 0)
        : V2SyncUtils.moneyToMinor(rawManualDiscountValue);
    final saleStaffId = await findLocalIdByRemoteId(
      executor,
      'staff',
      tenantId,
      saleStaffRemoteId,
    );
    final incomingShiftSessionRemoteId = V2SyncUtils.asString(
      row['shift_session_id'],
    );
    final resolvedShiftSessionRemoteId =
        incomingShiftSessionRemoteId ?? preservedShiftSessionRemoteId;
    final shiftSessionLocalId = resolvedShiftSessionRemoteId == null
        ? preservedShiftSessionId
        : await findLocalIdByRemoteId(
                executor,
                'shift_session',
                tenantId,
                resolvedShiftSessionRemoteId,
              ) ??
              preservedShiftSessionId;
    final incomingDeviceSessionRemoteId = V2SyncUtils.asString(
      row['device_session_id'],
    );
    final resolvedDeviceSessionRemoteId =
        incomingDeviceSessionRemoteId ?? preservedDeviceSessionRemoteId;
    final deviceSessionLocalId = await _findDeviceSessionLocalId(
      executor,
      tenantId,
      remoteId: resolvedDeviceSessionRemoteId,
      deviceId: V2SyncUtils.asString(row['device_id']),
      staffRemoteId: saleStaffRemoteId,
      fallbackLocalId: preservedDeviceSessionId,
    );
    final resolvedLocationId =
        V2SyncUtils.asString(row['location_id']) ?? preservedLocationId;
    final resolvedRegisterId =
        V2SyncUtils.asString(row['register_id']) ?? preservedRegisterId;
    final uniqueWhere = existingLocalId != null
        ? 'tenant_id = ? AND id = ?'
        : (idPos != null && idPos.isNotEmpty
              ? 'tenant_id = ? AND id_pos = ?'
              : 'tenant_id = ? AND remote_id = ?');
    final uniqueArgs = existingLocalId != null
        ? <Object?>[tenantId, existingLocalId]
        : (idPos != null && idPos.isNotEmpty
              ? <Object?>[tenantId, idPos]
              : <Object?>[tenantId, remoteId]);
    final now = V2SyncUtils.nowIso();

    return databaseService.upsertByUnique(
      executor,
      'pos_order',
      where: uniqueWhere,
      whereArgs: uniqueArgs,
      insertValues: <String, Object?>{
        'tenant_id': tenantId,
        'customer_id': customerLocalId,
        'sale_staff_id': saleStaffId,
        'shift_session_id': shiftSessionLocalId,
        'device_session_id': deviceSessionLocalId,
        'remote_id': remoteId,
        'id_pos': idPos,
        'location_id': resolvedLocationId,
        'register_id': resolvedRegisterId,
        'customer_remote_id': customerRemoteId,
        'sale_staff_remote_id': saleStaffRemoteId,
        'shift_session_remote_id': resolvedShiftSessionRemoteId,
        'device_session_remote_id': resolvedDeviceSessionRemoteId,
        'invoice_number': V2SyncUtils.asString(row['number']),
        'formatted_number': _formattedNumber(row),
        'prefix': V2SyncUtils.asString(row['prefix']),
        'order_date': V2SyncUtils.asString(row['date']),
        'due_date': V2SyncUtils.asString(row['duedate']),
        'business_date': V2SyncUtils.asString(row['date']),
        'currency_remote_id': V2SyncUtils.asString(
          row['currencyid'] ?? row['currency'],
        ),
        'currency_code': V2SyncUtils.asString(row['currency_name']),
        'billing_street': V2SyncUtils.asString(row['billing_street']),
        'billing_city': V2SyncUtils.asString(row['billing_city']),
        'billing_state': V2SyncUtils.asString(row['billing_state']),
        'billing_postal_code': V2SyncUtils.asString(row['billing_zip']),
        'billing_country': V2SyncUtils.asString(row['billing_country']),
        'shipping_street': V2SyncUtils.asString(row['shipping_street']),
        'shipping_city': V2SyncUtils.asString(row['shipping_city']),
        'shipping_state': V2SyncUtils.asString(row['shipping_state']),
        'shipping_postal_code': V2SyncUtils.asString(row['shipping_zip']),
        'shipping_country': V2SyncUtils.asString(row['shipping_country']),
        'allowed_payment_modes_json': _encodeAllowedPaymentModesJson(
          row['allowed_payment_modes'],
        ),
        'source_channel': V2SyncUtils.asString(row['source_channel']) ?? 'pos',
        'order_type_code': V2SyncUtils.asString(row['order_type']),
        'queue_number': V2SyncUtils.asInt(row['queue_number']),
        'table_code': V2SyncUtils.asString(row['table_code']),
        'status_code': V2SyncUtils.asString(row['status']),
        'status_text': V2SyncUtils.asString(
          row['status_name'] ?? row['status'],
        ),
        'subtotal_amount': V2SyncUtils.moneyToMinor(row['subtotal']),
        'discount_total_amount': _discountTotal(row),
        'discount_percent': V2SyncUtils.asDouble(row['discount_percent']),
        'discount_type': V2SyncUtils.asString(row['discount_type']),
        'manual_discount_value': resolvedManualDiscountValue,
        'adjustment_amount': V2SyncUtils.moneyToMinor(row['adjustment']),
        'total_amount': V2SyncUtils.moneyToMinor(row['total']),
        'amount_received': V2SyncUtils.moneyToMinor(row['amount_received']),
        'change_amount': V2SyncUtils.moneyToMinor(row['change_amount']),
        'total_left_to_pay_amount': V2SyncUtils.moneyToMinor(
          row['total_left_to_pay'],
        ),
        'awarded_points': V2SyncUtils.asInt(row['points']),
        'customer_deposit_amount': V2SyncUtils.moneyToMinor(
          row['deposit_amount'],
        ),
        'weight_estimate': V2SyncUtils.asDouble(row['weight']),
        'label': V2SyncUtils.asString(row['label']),
        'admin_note': V2SyncUtils.asString(row['adminnote']),
        'client_note': V2SyncUtils.asString(row['clientnote']),
        'terms': V2SyncUtils.asString(row['terms']),
        'order_note': resolvedOrderNote,
        'custom_fields_json': resolvedCustomFieldsJson,
        'raw_payload_json': V2SyncUtils.encodeJson(row),
        'last_synced_at': now,
        'created_at': now,
        'updated_at': now,
      },
      updateValues: <String, Object?>{
        'customer_id': customerLocalId,
        'sale_staff_id': saleStaffId,
        'shift_session_id': shiftSessionLocalId,
        'device_session_id': deviceSessionLocalId,
        'remote_id': remoteId,
        'id_pos': idPos,
        'location_id': resolvedLocationId,
        'register_id': resolvedRegisterId,
        'customer_remote_id': customerRemoteId,
        'sale_staff_remote_id': saleStaffRemoteId,
        'shift_session_remote_id': resolvedShiftSessionRemoteId,
        'device_session_remote_id': resolvedDeviceSessionRemoteId,
        'invoice_number': V2SyncUtils.asString(row['number']),
        'formatted_number': _formattedNumber(row),
        'prefix': V2SyncUtils.asString(row['prefix']),
        'order_date': V2SyncUtils.asString(row['date']),
        'due_date': V2SyncUtils.asString(row['duedate']),
        'business_date': V2SyncUtils.asString(row['date']),
        'currency_remote_id': V2SyncUtils.asString(
          row['currencyid'] ?? row['currency'],
        ),
        'currency_code': V2SyncUtils.asString(row['currency_name']),
        'billing_street': V2SyncUtils.asString(row['billing_street']),
        'billing_city': V2SyncUtils.asString(row['billing_city']),
        'billing_state': V2SyncUtils.asString(row['billing_state']),
        'billing_postal_code': V2SyncUtils.asString(row['billing_zip']),
        'billing_country': V2SyncUtils.asString(row['billing_country']),
        'shipping_street': V2SyncUtils.asString(row['shipping_street']),
        'shipping_city': V2SyncUtils.asString(row['shipping_city']),
        'shipping_state': V2SyncUtils.asString(row['shipping_state']),
        'shipping_postal_code': V2SyncUtils.asString(row['shipping_zip']),
        'shipping_country': V2SyncUtils.asString(row['shipping_country']),
        'allowed_payment_modes_json': _encodeAllowedPaymentModesJson(
          row['allowed_payment_modes'],
        ),
        'source_channel': V2SyncUtils.asString(row['source_channel']) ?? 'pos',
        'order_type_code': V2SyncUtils.asString(row['order_type']),
        'queue_number': V2SyncUtils.asInt(row['queue_number']),
        'table_code': V2SyncUtils.asString(row['table_code']),
        'status_code': V2SyncUtils.asString(row['status']),
        'status_text': V2SyncUtils.asString(
          row['status_name'] ?? row['status'],
        ),
        'subtotal_amount': V2SyncUtils.moneyToMinor(row['subtotal']),
        'discount_total_amount': _discountTotal(row),
        'discount_percent': V2SyncUtils.asDouble(row['discount_percent']),
        'discount_type': V2SyncUtils.asString(row['discount_type']),
        'manual_discount_value': resolvedManualDiscountValue,
        'adjustment_amount': V2SyncUtils.moneyToMinor(row['adjustment']),
        'total_amount': V2SyncUtils.moneyToMinor(row['total']),
        'amount_received': V2SyncUtils.moneyToMinor(row['amount_received']),
        'change_amount': V2SyncUtils.moneyToMinor(row['change_amount']),
        'total_left_to_pay_amount': V2SyncUtils.moneyToMinor(
          row['total_left_to_pay'],
        ),
        'awarded_points': V2SyncUtils.asInt(row['points']),
        'customer_deposit_amount': V2SyncUtils.moneyToMinor(
          row['deposit_amount'],
        ),
        'weight_estimate': V2SyncUtils.asDouble(row['weight']),
        'label': V2SyncUtils.asString(row['label']),
        'admin_note': V2SyncUtils.asString(row['adminnote']),
        'client_note': V2SyncUtils.asString(row['clientnote']),
        'terms': V2SyncUtils.asString(row['terms']),
        'order_note': resolvedOrderNote,
        'custom_fields_json': resolvedCustomFieldsJson,
        'raw_payload_json': V2SyncUtils.encodeJson(row),
        'last_synced_at': now,
        'updated_at': now,
        'deleted_at': null,
      },
    );
  }

  Future<int?> _upsertNestedCustomer(
    DatabaseExecutor executor,
    int tenantId,
    dynamic rawClient,
  ) async {
    final clientRows = rawClient is Map<String, dynamic>
        ? <Map<String, dynamic>>[rawClient]
        : V2SyncUtils.asMapList(rawClient);
    if (clientRows.isEmpty) {
      return null;
    }
    final row = clientRows.first;
    final remoteId = V2SyncUtils.asString(row['id']);
    if (remoteId == null) {
      return null;
    }

    final now = V2SyncUtils.nowIso();
    return databaseService.upsertByUnique(
      executor,
      'customer',
      where: 'tenant_id = ? AND remote_id = ?',
      whereArgs: <Object?>[tenantId, remoteId],
      insertValues: <String, Object?>{
        'tenant_id': tenantId,
        'remote_id': remoteId,
        'display_name': V2SyncUtils.asString(row['nama'] ?? row['company']),
        'company_name': V2SyncUtils.asString(row['company'] ?? row['nama']),
        'phone_number': V2SyncUtils.asString(
          row['no_hp'] ?? row['phonenumber'],
        ),
        'address_line1': V2SyncUtils.asString(row['alamat'] ?? row['address']),
        'points_balance': V2SyncUtils.asInt(row['value_pts'] ?? row['points']),
        'raw_payload_json': V2SyncUtils.encodeJson(row),
        'last_synced_at': now,
        'created_at': now,
        'updated_at': now,
      },
      updateValues: <String, Object?>{
        'display_name': V2SyncUtils.asString(row['nama'] ?? row['company']),
        'company_name': V2SyncUtils.asString(row['company'] ?? row['nama']),
        'phone_number': V2SyncUtils.asString(
          row['no_hp'] ?? row['phonenumber'],
        ),
        'address_line1': V2SyncUtils.asString(row['alamat'] ?? row['address']),
        'points_balance': V2SyncUtils.asInt(row['value_pts'] ?? row['points']),
        'raw_payload_json': V2SyncUtils.encodeJson(row),
        'last_synced_at': now,
        'updated_at': now,
        'deleted_at': null,
      },
    );
  }

  Future<void> _upsertNestedPayment(
    DatabaseExecutor executor,
    int tenantId,
    int orderLocalId,
    Map<String, dynamic> orderRow,
    Map<String, dynamic> paymentRow,
  ) async {
    final remoteId = V2SyncUtils.asString(paymentRow['id']);
    final paymentModeRemoteId = V2SyncUtils.asString(paymentRow['paymentmode']);
    final paymentModeLocalId = await findLocalIdByRemoteId(
      executor,
      'payment_mode',
      tenantId,
      paymentModeRemoteId,
    );
    final now = V2SyncUtils.nowIso();

    await databaseService.upsertByUnique(
      executor,
      'pos_order_payment',
      where: remoteId != null
          ? 'tenant_id = ? AND remote_id = ?'
          : 'tenant_id = ? AND order_id = ? AND amount = ? AND payment_date = ?',
      whereArgs: remoteId != null
          ? <Object?>[tenantId, remoteId]
          : <Object?>[
              tenantId,
              orderLocalId,
              V2SyncUtils.moneyToMinor(paymentRow['amount']),
              V2SyncUtils.asString(paymentRow['date']),
            ],
      insertValues: <String, Object?>{
        'tenant_id': tenantId,
        'order_id': orderLocalId,
        'payment_mode_id': paymentModeLocalId,
        'remote_id': remoteId,
        'invoice_remote_id': V2SyncUtils.asString(paymentRow['invoiceid']),
        'id_pos': V2SyncUtils.asString(orderRow['id_pos']),
        'payment_mode_remote_id': paymentModeRemoteId,
        'amount': V2SyncUtils.moneyToMinor(paymentRow['amount']),
        'payment_method': V2SyncUtils.asString(paymentRow['paymentmethod']),
        'payment_date': V2SyncUtils.asString(paymentRow['date']),
        'recorded_at': V2SyncUtils.asString(paymentRow['daterecorded']),
        'note': V2SyncUtils.asString(paymentRow['note']),
        'transaction_reference': V2SyncUtils.asString(
          paymentRow['transactionid'],
        ),
        'raw_payload_json': V2SyncUtils.encodeJson(paymentRow),
        'last_synced_at': now,
        'created_at': now,
        'updated_at': now,
      },
      updateValues: <String, Object?>{
        'order_id': orderLocalId,
        'payment_mode_id': paymentModeLocalId,
        'invoice_remote_id': V2SyncUtils.asString(paymentRow['invoiceid']),
        'id_pos': V2SyncUtils.asString(orderRow['id_pos']),
        'payment_mode_remote_id': paymentModeRemoteId,
        'amount': V2SyncUtils.moneyToMinor(paymentRow['amount']),
        'payment_method': V2SyncUtils.asString(paymentRow['paymentmethod']),
        'payment_date': V2SyncUtils.asString(paymentRow['date']),
        'recorded_at': V2SyncUtils.asString(paymentRow['daterecorded']),
        'note': V2SyncUtils.asString(paymentRow['note']),
        'transaction_reference': V2SyncUtils.asString(
          paymentRow['transactionid'],
        ),
        'raw_payload_json': V2SyncUtils.encodeJson(paymentRow),
        'last_synced_at': now,
        'updated_at': now,
        'deleted_at': null,
      },
    );
  }

  String? _formattedNumber(Map<String, dynamic> row) {
    final explicit = V2SyncUtils.asString(row['formatted_number']);
    if (explicit != null) {
      return explicit;
    }

    final prefix = V2SyncUtils.asString(row['prefix']) ?? '';
    final number = V2SyncUtils.asString(row['number']) ?? '';
    final combined = '$prefix$number'.trim();
    return combined.isEmpty ? null : combined;
  }

  Future<int?> _findDeviceSessionLocalId(
    DatabaseExecutor executor,
    int tenantId, {
    String? remoteId,
    String? deviceId,
    String? staffRemoteId,
    int? fallbackLocalId,
  }) async {
    if (remoteId != null && remoteId.isNotEmpty) {
      return await findLocalIdByRemoteId(
            executor,
            'device_session',
            tenantId,
            remoteId,
          ) ??
          fallbackLocalId;
    }
    if (deviceId == null || deviceId.isEmpty) {
      return fallbackLocalId;
    }

    final where = StringBuffer('tenant_id = ? AND device_id = ?');
    final whereArgs = <Object?>[tenantId, deviceId];
    if (staffRemoteId != null && staffRemoteId.isNotEmpty) {
      where.write(
        ' AND (staff_remote_id = ? OR staff_remote_id IS NULL OR staff_remote_id = \'\')',
      );
      whereArgs.add(staffRemoteId);
    }

    final rows = await executor.query(
      'device_session',
      columns: const <String>['id'],
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy:
          "CASE WHEN status = 'active' THEN 0 ELSE 1 END, updated_at DESC, id DESC",
      limit: 1,
    );
    if (rows.isEmpty) {
      return fallbackLocalId;
    }
    return _asNullableInt(rows.first['id']) ?? fallbackLocalId;
  }

  String? _encodeAllowedPaymentModesJson(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is List || value is Map) {
      return V2SyncUtils.encodeJson(value);
    }

    final text = V2SyncUtils.asString(value);
    if (text == null) {
      return null;
    }

    final decoded = V2SyncUtils.decodeLooseJson(text);
    if (decoded is List || decoded is Map) {
      return V2SyncUtils.encodeJson(decoded);
    }

    final phpSerializedValues = RegExp(r's:\d+:"([^"]*)"')
        .allMatches(text)
        .map((match) => match.group(1))
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (phpSerializedValues.isNotEmpty) {
      return V2SyncUtils.encodeJson(phpSerializedValues);
    }

    final csvValues = text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (csvValues.length > 1) {
      return V2SyncUtils.encodeJson(csvValues);
    }

    return V2SyncUtils.encodeJson(text);
  }

  int? _asNullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
  }

  int _discountTotal(Map<String, dynamic> row) {
    final subtotal = V2SyncUtils.moneyToMinor(row['subtotal']);
    final total = V2SyncUtils.moneyToMinor(row['total']);
    final explicit = V2SyncUtils.moneyToMinor(row['discount_total']);
    if (explicit > 0) {
      return explicit;
    }
    if (subtotal > total) {
      return subtotal - total;
    }
    return 0;
  }
}
