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
      for (final row in rows) {
        final didUpsert = await _upsertPaymentRow(txn, tenantId, row);
        if (didUpsert) {
          upsertedCount += 1;
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

  Future<bool> _upsertPaymentRow(
    DatabaseExecutor executor,
    int tenantId,
    Map<String, dynamic> row,
  ) async {
    final remoteId = V2SyncUtils.asString(row['id']);
    final idPos = V2SyncUtils.asString(row['id_pos']);
    final invoiceRemoteId = V2SyncUtils.asString(row['invoiceid']);
    final paymentModeRemoteId = V2SyncUtils.asString(row['paymentmode']);

    if (remoteId == null && idPos == null && invoiceRemoteId == null) {
      return false;
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

    return true;
  }
}
