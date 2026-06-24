import 'package:sqflite/sqflite.dart';

import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class ItemsSyncAdapter extends BaseV2SyncAdapter {
  ItemsSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(
    V2SyncContext context, {
    Map<String, dynamic>? query,
  }) async {
    final envelope = await buildClient(
      context,
    ).getEnvelope('api/v2/pos-items', query: query);
    final rows = V2SyncUtils.asMapList((envelope['data'] as Object?));
    final scopeKey = query == null || query.isEmpty
        ? 'default'
        : query.toString();

    var upsertedCount = 0;
    var replacedChildCount = 0;

    const chunkSize = 50;
    for (var i = 0; i < rows.length; i += chunkSize) {
      final chunk = rows.skip(i).take(chunkSize);
      await databaseService.transaction((txn) async {
        final now = V2SyncUtils.nowIso();
        final tenantId = await ensureTenantId(txn, context);

        for (final row in chunk) {
          final itemId = V2SyncUtils.asString(row['id']);
          if (itemId == null) {
            continue;
          }

          final groupNames = V2SyncUtils.asMapList(row['group_names']);
          final brandIds = _extractBrandIds(row, groupNames);
          final categoryRemoteId = V2SyncUtils.asString(row['category_id']);
          final categoryLocalId = await findLocalIdByRemoteId(
            txn,
            'category',
            tenantId,
            categoryRemoteId,
          );

          int? primaryBrandId;
          String? primaryBrandRemoteId;
          for (final (index, brandRow) in groupNames.indexed) {
            final brandRemoteId = V2SyncUtils.asString(brandRow['id']);
            if (brandRemoteId == null) {
              continue;
            }
            final brandLocalId = await databaseService.upsertByUnique(
              txn,
              'brand',
              where: 'tenant_id = ? AND remote_id = ?',
              whereArgs: <Object?>[tenantId, brandRemoteId],
              insertValues: <String, Object?>{
                'tenant_id': tenantId,
                'remote_id': brandRemoteId,
                'code': V2SyncUtils.asString(brandRow['commodity_group_code']),
                'name': V2SyncUtils.asString(brandRow['name']),
                'display_flag': 1,
                'sort_order': index,
                'note': V2SyncUtils.asString(brandRow['note']),
                'raw_payload_json': V2SyncUtils.encodeJson(brandRow),
                'last_synced_at': now,
                'created_at': now,
                'updated_at': now,
              },
              updateValues: <String, Object?>{
                'code': V2SyncUtils.asString(brandRow['commodity_group_code']),
                'name': V2SyncUtils.asString(brandRow['name']),
                'display_flag': 1,
                'sort_order': index,
                'note': V2SyncUtils.asString(brandRow['note']),
                'raw_payload_json': V2SyncUtils.encodeJson(brandRow),
                'last_synced_at': now,
                'updated_at': now,
                'deleted_at': null,
              },
            );
            upsertedCount += 1;
            if (index == 0) {
              primaryBrandId = brandLocalId;
              primaryBrandRemoteId = brandRemoteId;
            }
          }

          if (primaryBrandRemoteId == null && brandIds.isNotEmpty) {
            primaryBrandRemoteId = brandIds.first;
            primaryBrandId = await findLocalIdByRemoteId(
              txn,
              'brand',
              tenantId,
              primaryBrandRemoteId,
            );
          }

          final parentRemoteId = V2SyncUtils.asString(row['parent']);
          final parentProductId = await findLocalIdByRemoteId(
            txn,
            'product',
            tenantId,
            parentRemoteId,
          );

          final productLocalId = await databaseService.upsertByUnique(
            txn,
            'product',
            where: 'tenant_id = ? AND remote_id = ?',
            whereArgs: <Object?>[tenantId, itemId],
            insertValues: <String, Object?>{
              'tenant_id': tenantId,
              'remote_id': itemId,
              'category_id': categoryLocalId,
              'category_remote_id': categoryRemoteId,
              'primary_brand_id': primaryBrandId,
              'primary_brand_remote_id': primaryBrandRemoteId,
              'parent_product_id': parentProductId,
              'parent_remote_id': parentRemoteId,
              'name': V2SyncUtils.asString(row['name']) ?? itemId,
              'sku': V2SyncUtils.asString(row['sku']),
              'barcode': V2SyncUtils.asString(row['barcode']),
              'description': V2SyncUtils.asString(row['description']),
              'image_url': V2SyncUtils.asString(row['image_url']),
              'cost_amount': V2SyncUtils.moneyToMinor(row['cost']),
              'price_amount': V2SyncUtils.moneyToMinor(row['price']),
              'stock_quantity': V2SyncUtils.asDouble(row['stock_quantity']),
              'min_stock_level': V2SyncUtils.asDouble(row['min_stock_level']),
              'discount_total_amount': V2SyncUtils.moneyToMinor(
                row['discount_total'],
              ),
              'discount_type': V2SyncUtils.asString(row['discount_type']),
              'tax_rate': V2SyncUtils.asDouble(row['tax_rate']),
              'is_available':
                  V2SyncUtils.intToBoolFlag(
                    row['is_available'],
                    defaultValue: true,
                  )
                  ? 1
                  : 0,
              'sort_order': V2SyncUtils.asInt(row['sort_order']),
              'status': V2SyncUtils.asString(row['status']) ?? 'active',
              'children_json': V2SyncUtils.encodeJson(row['children']),
              'units_json': V2SyncUtils.encodeJson(row['units']),
              'legacy_locations_raw': V2SyncUtils.encodeJson(row['locations']),
              'legacy_brand_ids_raw': V2SyncUtils.asString(row['brand_id']),
              'source_created_at': V2SyncUtils.asString(row['created_at']),
              'source_updated_at': V2SyncUtils.asString(row['updated_at']),
              'raw_payload_json': V2SyncUtils.encodeJson(row),
              'last_synced_at': now,
              'created_at': now,
              'updated_at': now,
            },
            updateValues: <String, Object?>{
              'category_id': categoryLocalId,
              'category_remote_id': categoryRemoteId,
              'primary_brand_id': primaryBrandId,
              'primary_brand_remote_id': primaryBrandRemoteId,
              'parent_product_id': parentProductId,
              'parent_remote_id': parentRemoteId,
              'name': V2SyncUtils.asString(row['name']) ?? itemId,
              'sku': V2SyncUtils.asString(row['sku']),
              'barcode': V2SyncUtils.asString(row['barcode']),
              'description': V2SyncUtils.asString(row['description']),
              'image_url': V2SyncUtils.asString(row['image_url']),
              'cost_amount': V2SyncUtils.moneyToMinor(row['cost']),
              'price_amount': V2SyncUtils.moneyToMinor(row['price']),
              'stock_quantity': V2SyncUtils.asDouble(row['stock_quantity']),
              'min_stock_level': V2SyncUtils.asDouble(row['min_stock_level']),
              'discount_total_amount': V2SyncUtils.moneyToMinor(
                row['discount_total'],
              ),
              'discount_type': V2SyncUtils.asString(row['discount_type']),
              'tax_rate': V2SyncUtils.asDouble(row['tax_rate']),
              'is_available':
                  V2SyncUtils.intToBoolFlag(
                    row['is_available'],
                    defaultValue: true,
                  )
                  ? 1
                  : 0,
              'sort_order': V2SyncUtils.asInt(row['sort_order']),
              'status': V2SyncUtils.asString(row['status']) ?? 'active',
              'children_json': V2SyncUtils.encodeJson(row['children']),
              'units_json': V2SyncUtils.encodeJson(row['units']),
              'legacy_locations_raw': V2SyncUtils.encodeJson(row['locations']),
              'legacy_brand_ids_raw': V2SyncUtils.asString(row['brand_id']),
              'source_created_at': V2SyncUtils.asString(row['created_at']),
              'source_updated_at': V2SyncUtils.asString(row['updated_at']),
              'raw_payload_json': V2SyncUtils.encodeJson(row),
              'last_synced_at': now,
              'updated_at': now,
              'deleted_at': null,
            },
          );
          upsertedCount += 1;

          final productBrandRows = <Map<String, Object?>>[];
          for (final (index, brandRemoteId) in brandIds.indexed) {
            final brandLocalId = await findLocalIdByRemoteId(
              txn,
              'brand',
              tenantId,
              brandRemoteId,
            );
            productBrandRows.add(<String, Object?>{
              'tenant_id': tenantId,
              'product_id': productLocalId,
              'brand_id': brandLocalId,
              'product_remote_id': itemId,
              'brand_remote_id': brandRemoteId,
              'sort_order': index,
            });
          }
          await databaseService.replaceChildren(
            txn,
            'product_brand',
            where: 'tenant_id = ? AND product_remote_id = ?',
            whereArgs: <Object?>[tenantId, itemId],
            rows: productBrandRows,
          );
          replacedChildCount += productBrandRows.length;

          final productLocationRows = <Map<String, Object?>>[];
          for (final location in _extractLocations(row['locations'])) {
            productLocationRows.add(<String, Object?>{
              'tenant_id': tenantId,
              'product_id': productLocalId,
              'product_remote_id': itemId,
              'location_id': location.$1,
              'location_name': location.$2,
            });
          }
          await databaseService.replaceChildren(
            txn,
            'product_location',
            where: 'tenant_id = ? AND product_remote_id = ?',
            whereArgs: <Object?>[tenantId, itemId],
            rows: productLocationRows,
          );
          replacedChildCount += productLocationRows.length;

          final productOrderTypeRows = <Map<String, Object?>>[];
          for (final orderType in _extractOrderTypes(row['order_types'])) {
            final orderTypeLocalId = await _resolveOrderTypeLocalId(
              txn,
              tenantId,
              orderType.code,
              orderType.remoteId,
            );
            productOrderTypeRows.add(<String, Object?>{
              'tenant_id': tenantId,
              'product_id': productLocalId,
              'order_type_id': orderTypeLocalId,
              'product_remote_id': itemId,
              'order_type_remote_id': orderType.remoteId,
              'order_type_code': orderType.code,
              'price_amount': orderType.priceAmount,
              'raw_json': orderType.rawJson,
            });
          }
          await databaseService.replaceChildren(
            txn,
            'product_order_type',
            where: 'tenant_id = ? AND product_remote_id = ?',
            whereArgs: <Object?>[tenantId, itemId],
            rows: productOrderTypeRows,
          );
          replacedChildCount += productOrderTypeRows.length;
        }

        await touchCheckpoint(
          txn,
          tenantId,
          endpointName: 'pos-items',
          scopeKey: scopeKey,
          notes: 'Catalog items synced from api/v2/pos-items.',
        );
      });
    }

    return V2SyncResult(
      endpointName: 'pos-items',
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
      replacedChildCount: replacedChildCount,
      meta: <String, Object?>{'scopeKey': scopeKey},
    );
  }

  List<String> _extractBrandIds(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> groupNames,
  ) {
    final brandIds = <String>{};
    brandIds.addAll(V2SyncUtils.asStringList(row['brand_id']));
    for (final brandRow in groupNames) {
      final remoteId = V2SyncUtils.asString(brandRow['id']);
      if (remoteId != null) {
        brandIds.add(remoteId);
      }
    }
    return brandIds.toList(growable: false);
  }

  List<(String, String?)> _extractLocations(dynamic rawLocations) {
    final locations = <(String, String?)>[];
    for (final row in V2SyncUtils.asMapList(rawLocations)) {
      final locationId = V2SyncUtils.asString(
        row['id'] ?? row['location_id'] ?? row['value'],
      );
      if (locationId == null) {
        continue;
      }
      locations.add((locationId, V2SyncUtils.asString(row['name'])));
    }

    if (locations.isNotEmpty) {
      return locations;
    }

    return V2SyncUtils.asStringList(
      rawLocations,
    ).map<(String, String?)>((value) => (value, null)).toList(growable: false);
  }

  List<_OrderTypeRef> _extractOrderTypes(dynamic rawOrderTypes) {
    final orderTypes = <_OrderTypeRef>[];
    for (final row in V2SyncUtils.asMapList(rawOrderTypes)) {
      final code =
          V2SyncUtils.asString(row['code']) ??
          V2SyncUtils.asString(row['name']) ??
          V2SyncUtils.asString(row['id']);
      if (code == null) {
        if (row.length == 1) {
          final entry = row.entries.first;
          orderTypes.add(
            _OrderTypeRef(
              code: entry.key,
              priceAmount: V2SyncUtils.moneyToMinor(entry.value),
              rawJson: V2SyncUtils.encodeJson(row),
            ),
          );
        }
        continue;
      }
      orderTypes.add(
        _OrderTypeRef(
          code: code,
          remoteId: V2SyncUtils.asString(row['id']),
          priceAmount: V2SyncUtils.moneyToMinor(
            row['price'] ?? row['amount'] ?? row[code],
          ),
          rawJson: V2SyncUtils.encodeJson(row),
        ),
      );
    }

    if (orderTypes.isNotEmpty) {
      return orderTypes;
    }

    return V2SyncUtils.asStringList(rawOrderTypes)
        .map<_OrderTypeRef>(
          (value) => _OrderTypeRef(code: value, remoteId: value),
        )
        .toList(growable: false);
  }

  Future<int?> _resolveOrderTypeLocalId(
    DatabaseExecutor executor,
    int tenantId,
    String code,
    String? remoteId,
  ) async {
    if (remoteId != null && remoteId.isNotEmpty) {
      final byRemote = await findLocalIdByRemoteId(
        executor,
        'order_type',
        tenantId,
        remoteId,
      );
      if (byRemote != null) {
        return byRemote;
      }
    }

    return databaseService.findLocalId(
      executor,
      'order_type',
      where: 'tenant_id = ? AND code = ?',
      whereArgs: <Object?>[tenantId, code],
    );
  }
}

class _OrderTypeRef {
  const _OrderTypeRef({
    required this.code,
    this.remoteId,
    this.priceAmount = 0,
    this.rawJson,
  });

  final String code;
  final String? remoteId;
  final int priceAmount;
  final String? rawJson;
}
