import 'package:sqflite/sqflite.dart';

import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class PaymentsSyncAdapter extends BaseV2SyncAdapter {
  PaymentsSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(
    V2SyncContext context, {
    Map<String, dynamic>? query,
  }) async {
    final envelope = await buildClient(
      context,
    ).getEnvelope('api/v2/pos-transaction', query: query);
    final rows = V2SyncUtils.asMapList((envelope['data'] as Object?));
    final scopeKey = query == null || query.isEmpty
        ? 'default'
        : query.toString();

    var upsertedCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      final affectedOrderIds = <int>{};
      for (final row in rows) {
        final orderLocalId = await _upsertPaymentRow(txn, tenantId, row);
        if (orderLocalId != null) {
          upsertedCount += 1;
          affectedOrderIds.add(orderLocalId);
        }
      }

      for (final orderLocalId in affectedOrderIds) {
        await _refreshOrderPaymentSummary(txn, tenantId, orderLocalId);
      }

      if (affectedOrderIds.isEmpty) {
        for (final row in rows) {
          final orderLocalId = await findOrderLocalId(
            txn,
            tenantId,
            remoteId: V2SyncUtils.asString(row['invoiceid']),
            idPos: V2SyncUtils.asString(row['id_pos']),
          );
          if (orderLocalId != null && affectedOrderIds.add(orderLocalId)) {
            await _refreshOrderPaymentSummary(txn, tenantId, orderLocalId);
          }
        }
      }

      await touchCheckpoint(
        txn,
        tenantId,
        endpointName: 'pos-transaction',
        scopeKey: scopeKey,
        notes: 'Payment rows synced from api/v2/pos-transaction.',
      );
    });

    return V2SyncResult(
      endpointName: 'pos-transaction',
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
      meta: <String, Object?>{'scopeKey': scopeKey},
    );
  }

  Future<int?> _upsertPaymentRow(
    DatabaseExecutor executor,
    int tenantId,
    Map<String, dynamic> row,
  ) async {
    final remoteId = V2SyncUtils.asString(row['id']);
    final idPos = V2SyncUtils.asString(row['id_pos']);
    final invoiceRemoteId = V2SyncUtils.asString(row['invoiceid']);
    final paymentModeRemoteId = V2SyncUtils.asString(row['paymentmode']);

    if (remoteId == null && idPos == null && invoiceRemoteId == null) {
      return null;
    }

    final orderLocalId = await findOrderLocalId(
      executor,
      tenantId,
      remoteId: invoiceRemoteId,
      idPos: idPos,
    );
    final paymentModeLocalId = await findLocalIdByRemoteId(
      executor,
      'payment_mode',
      tenantId,
      paymentModeRemoteId,
    );

    final now = V2SyncUtils.nowIso();
    final where = remoteId != null
        ? 'tenant_id = ? AND remote_id = ?'
        : 'tenant_id = ? AND id_pos = ? AND amount = ? AND payment_date = ?';
    final whereArgs = remoteId != null
        ? <Object?>[tenantId, remoteId]
        : <Object?>[
            tenantId,
            idPos,
            V2SyncUtils.moneyToMinor(row['amount']),
            V2SyncUtils.asString(row['date']),
          ];

    await databaseService.upsertByUnique(
      executor,
      'pos_order_payment',
      where: where,
      whereArgs: whereArgs,
      insertValues: <String, Object?>{
        'tenant_id': tenantId,
        'order_id': orderLocalId,
        'payment_mode_id': paymentModeLocalId,
        'remote_id': remoteId,
        'invoice_remote_id': invoiceRemoteId,
        'id_pos': idPos,
        'payment_mode_remote_id': paymentModeRemoteId,
        'payment_mode_name_snapshot': V2SyncUtils.asString(row['name']),
        'amount': V2SyncUtils.moneyToMinor(row['amount']),
        'payment_method': V2SyncUtils.asString(row['paymentmethod']),
        'payment_date': V2SyncUtils.asString(row['date']),
        'recorded_at': V2SyncUtils.asString(row['daterecorded']),
        'note': V2SyncUtils.asString(row['note']),
        'transaction_reference': V2SyncUtils.asString(
          row['transactionid'] ?? row['transaction_id'],
        ),
        'raw_payload_json': V2SyncUtils.encodeJson(row),
        'last_synced_at': now,
        'created_at': now,
        'updated_at': now,
      },
      updateValues: <String, Object?>{
        'order_id': orderLocalId,
        'payment_mode_id': paymentModeLocalId,
        'invoice_remote_id': invoiceRemoteId,
        'id_pos': idPos,
        'payment_mode_remote_id': paymentModeRemoteId,
        'payment_mode_name_snapshot': V2SyncUtils.asString(row['name']),
        'amount': V2SyncUtils.moneyToMinor(row['amount']),
        'payment_method': V2SyncUtils.asString(row['paymentmethod']),
        'payment_date': V2SyncUtils.asString(row['date']),
        'recorded_at': V2SyncUtils.asString(row['daterecorded']),
        'note': V2SyncUtils.asString(row['note']),
        'transaction_reference': V2SyncUtils.asString(
          row['transactionid'] ?? row['transaction_id'],
        ),
        'raw_payload_json': V2SyncUtils.encodeJson(row),
        'last_synced_at': now,
        'updated_at': now,
        'deleted_at': null,
      },
    );

    return orderLocalId;
  }

  Future<void> _refreshOrderPaymentSummary(
    DatabaseExecutor executor,
    int tenantId,
    int orderLocalId,
  ) async {
    final aggregateRows = await executor.query(
      'pos_order_payment',
      columns: const <String>['SUM(amount) AS total_paid'],
      where: 'tenant_id = ? AND order_id = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[tenantId, orderLocalId],
      limit: 1,
    );
    final orderRows = await executor.query(
      'pos_order',
      columns: const <String>['total_amount'],
      where: 'tenant_id = ? AND id = ?',
      whereArgs: <Object?>[tenantId, orderLocalId],
      limit: 1,
    );
    if (orderRows.isEmpty) {
      return;
    }

    final paidAmount = V2SyncUtils.asInt(aggregateRows.first['total_paid']);
    final totalAmount = V2SyncUtils.asInt(orderRows.first['total_amount']);
    final totalLeftToPay = totalAmount > paidAmount
        ? totalAmount - paidAmount
        : 0;
    final changeAmount = paidAmount > totalAmount
        ? paidAmount - totalAmount
        : 0;
    final now = V2SyncUtils.nowIso();

    await executor.update(
      'pos_order',
      <String, Object?>{
        'amount_received': paidAmount,
        'change_amount': changeAmount,
        'total_left_to_pay_amount': totalLeftToPay,
        'updated_at': now,
      },
      where: 'tenant_id = ? AND id = ?',
      whereArgs: <Object?>[tenantId, orderLocalId],
    );
  }
}
