import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class PromotionsSyncAdapter extends BaseV2SyncAdapter {
  PromotionsSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(
    V2SyncContext context, {
    Map<String, dynamic>? query,
    bool allowNotFoundEmpty = false,
  }) async {
    List<Map<String, dynamic>> rows;
    try {
      final envelope = await buildClient(
        context,
      ).getEnvelope('api/v2/pos-promotions', query: query);
      rows = V2SyncUtils.asMapList(envelope['data']);
    } catch (error) {
      if (allowNotFoundEmpty &&
          error.toString().contains('Promotion not found')) {
        rows = const <Map<String, dynamic>>[];
      } else {
        rethrow;
      }
    }
    final scopeKey = query == null || query.isEmpty
        ? 'default'
        : query.toString();

    var upsertedCount = 0;
    var replacedChildCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);
      final now = V2SyncUtils.nowIso();
      final locationId = V2SyncUtils.asString(query?['id_location']);
      final remoteIds = rows
          .map((row) => V2SyncUtils.asString(row['id']))
          .whereType<String>()
          .toList(growable: false);

      await _markMissingPromotionsDeleted(
        txn,
        tenantId,
        now: now,
        keepRemoteIds: remoteIds,
        locationId: locationId,
      );

      for (final row in rows) {
        final remoteId = V2SyncUtils.asString(row['id']);
        if (remoteId == null) {
          continue;
        }

        final promotionLocalId = await databaseService.upsertByUnique(
          txn,
          'promotion',
          where: 'tenant_id = ? AND remote_id = ?',
          whereArgs: <Object?>[tenantId, remoteId],
          insertValues: <String, Object?>{
            'tenant_id': tenantId,
            'remote_id': remoteId,
            'name': V2SyncUtils.asString(row['name']),
            'promo_type': V2SyncUtils.asString(row['promo_type']),
            'description': V2SyncUtils.asString(row['description']),
            'terms_conditions': V2SyncUtils.asString(row['terms_conditions']),
            'start_at': V2SyncUtils.asString(row['start_date']),
            'end_at': V2SyncUtils.asString(row['end_date']),
            'is_multiplied': V2SyncUtils.intToBoolFlag(row['is_multiplied'])
                ? 1
                : 0,
            'is_stackable': V2SyncUtils.intToBoolFlag(row['is_stackable'])
                ? 1
                : 0,
            'status': V2SyncUtils.asString(row['status']),
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'name': V2SyncUtils.asString(row['name']),
            'promo_type': V2SyncUtils.asString(row['promo_type']),
            'description': V2SyncUtils.asString(row['description']),
            'terms_conditions': V2SyncUtils.asString(row['terms_conditions']),
            'start_at': V2SyncUtils.asString(row['start_date']),
            'end_at': V2SyncUtils.asString(row['end_date']),
            'is_multiplied': V2SyncUtils.intToBoolFlag(row['is_multiplied'])
                ? 1
                : 0,
            'is_stackable': V2SyncUtils.intToBoolFlag(row['is_stackable'])
                ? 1
                : 0,
            'status': V2SyncUtils.asString(row['status']),
            'raw_payload_json': V2SyncUtils.encodeJson(row),
            'last_synced_at': now,
            'updated_at': now,
            'deleted_at': null,
          },
        );
        upsertedCount += 1;

        final brandRows = V2SyncUtils.asStringList(row['brands'])
            .map(
              (brandRemoteId) => <String, Object?>{
                'tenant_id': tenantId,
                'promotion_id': promotionLocalId,
                'brand_id': null,
                'promotion_remote_id': remoteId,
                'brand_remote_id': brandRemoteId,
              },
            )
            .toList(growable: false);
        await databaseService.replaceChildren(
          txn,
          'promotion_brand',
          where: 'tenant_id = ? AND promotion_remote_id = ?',
          whereArgs: <Object?>[tenantId, remoteId],
          rows: brandRows,
        );
        replacedChildCount += brandRows.length;

        final itemRows = _extractPromotionItemRows(
          tenantId: tenantId,
          promotionLocalId: promotionLocalId,
          promotionRemoteId: remoteId,
          itemsValue: row['items'],
        );
        await databaseService.replaceChildren(
          txn,
          'promotion_item',
          where: 'tenant_id = ? AND promotion_remote_id = ?',
          whereArgs: <Object?>[tenantId, remoteId],
          rows: itemRows,
        );
        replacedChildCount += itemRows.length;

        final locationRows = V2SyncUtils.asStringList(row['locations'])
            .map(
              (locationId) => <String, Object?>{
                'tenant_id': tenantId,
                'promotion_id': promotionLocalId,
                'promotion_remote_id': remoteId,
                'location_id': locationId,
              },
            )
            .toList(growable: false);
        await databaseService.replaceChildren(
          txn,
          'promotion_location',
          where: 'tenant_id = ? AND promotion_remote_id = ?',
          whereArgs: <Object?>[tenantId, remoteId],
          rows: locationRows,
        );
        replacedChildCount += locationRows.length;

        final orderTypeRows = V2SyncUtils.asStringList(row['order_types'])
            .map(
              (orderTypeCode) => <String, Object?>{
                'tenant_id': tenantId,
                'promotion_id': promotionLocalId,
                'order_type_id': null,
                'promotion_remote_id': remoteId,
                'order_type_code': orderTypeCode,
                'order_type_remote_id': null,
              },
            )
            .toList(growable: false);
        await databaseService.replaceChildren(
          txn,
          'promotion_order_type',
          where: 'tenant_id = ? AND promotion_remote_id = ?',
          whereArgs: <Object?>[tenantId, remoteId],
          rows: orderTypeRows,
        );
        replacedChildCount += orderTypeRows.length;
      }

      await touchCheckpoint(
        txn,
        tenantId,
        endpointName: 'pos-promotions',
        scopeKey: scopeKey,
        notes: 'Promotion data synced from api/v2/pos-promotions.',
      );
    });

    return V2SyncResult(
      endpointName: 'pos-promotions',
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
      replacedChildCount: replacedChildCount,
      meta: <String, Object?>{'scopeKey': scopeKey},
    );
  }

  Future<void> _markMissingPromotionsDeleted(
    dynamic txn,
    int tenantId, {
    required String now,
    required List<String> keepRemoteIds,
    String? locationId,
  }) async {
    final where = StringBuffer('tenant_id = ? AND deleted_at IS NULL');
    final whereArgs = <Object?>[tenantId];

    if (locationId != null && locationId.isNotEmpty) {
      where.write(
        ' AND id IN ('
        'SELECT promotion_id FROM promotion_location '
        'WHERE tenant_id = ? AND location_id = ?'
        ')',
      );
      whereArgs.addAll(<Object?>[tenantId, locationId]);
    }

    if (keepRemoteIds.isNotEmpty) {
      final placeholders = List.filled(keepRemoteIds.length, '?').join(',');
      where.write(' AND remote_id NOT IN ($placeholders)');
      whereArgs.addAll(keepRemoteIds);
    }

    await txn.update(
      'promotion',
      <String, Object?>{'deleted_at': now, 'updated_at': now},
      where: where.toString(),
      whereArgs: whereArgs,
    );
  }

  List<Map<String, Object?>> _extractPromotionItemRows({
    required int tenantId,
    required int promotionLocalId,
    required String promotionRemoteId,
    required dynamic itemsValue,
  }) {
    final rows = <Map<String, Object?>>[];

    if (itemsValue is List) {
      for (final productRemoteId in V2SyncUtils.asStringList(itemsValue)) {
        rows.add(<String, Object?>{
          'tenant_id': tenantId,
          'promotion_id': promotionLocalId,
          'product_id': null,
          'promotion_remote_id': promotionRemoteId,
          'product_remote_id': productRemoteId,
        });
      }
      return rows;
    }

    final itemsMap = V2SyncUtils.asMap(itemsValue);
    final detailRows = V2SyncUtils.asMapList(itemsMap?['detail']);
    for (final detail in detailRows) {
      final discountItemId = V2SyncUtils.asString(detail['item_id']);
      if (discountItemId != null && discountItemId.isNotEmpty) {
        rows.add(<String, Object?>{
          'tenant_id': tenantId,
          'promotion_id': promotionLocalId,
          'product_id': null,
          'promotion_remote_id': promotionRemoteId,
          'product_remote_id': discountItemId,
        });
        continue;
      }

      if (detail['type']?.toString() != 'product') {
        continue;
      }
      final targetIds = detail['target_id'] is List
          ? (detail['target_id'] as List)
                .map((value) => value?.toString())
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const <String>[];
      for (final productRemoteId in targetIds) {
        rows.add(<String, Object?>{
          'tenant_id': tenantId,
          'promotion_id': promotionLocalId,
          'product_id': null,
          'promotion_remote_id': promotionRemoteId,
          'product_remote_id': productRemoteId,
        });
      }
    }

    return rows;
  }
}
