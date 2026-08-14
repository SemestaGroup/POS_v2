import 'dart:convert';

import '../../../../core/network/v2_api_client.dart';
import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../models/marketplace_item.dart';

class MarketplaceService {
  MarketplaceService._();
  static final MarketplaceService instance = MarketplaceService._();

  static const int _pruneDays = 30;

  Future<List<MarketplaceItem>> loadCachedItems() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) return const [];

    try {
      final rows = await DatabaseService.instance.query(
        'marketplace_item',
        where: 'tenant_id = ?',
        whereArgs: <Object?>[session.tenantId],
        orderBy: 'created_at DESC',
      );
      return rows.map(MarketplaceItem.fromDbRow).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<MarketplaceItem>?> fetchRemoteItems() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) return null;

    try {
      final client = V2ApiClient(
        baseUrl: session.baseUrl,
        authToken: session.authToken,
      );
      final data = await client
          .getJson('api/items', query: const {'type': 'can_be_purchased'})
          .timeout(const Duration(seconds: 15));

      if (data is List) {
        final items = data
            .map((e) => MarketplaceItem.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);

        try {
          await DatabaseService.instance.transaction((txn) async {
            for (final itm in items) {
              await DatabaseService.instance.upsertByUnique(
                txn,
                'marketplace_item',
                where: 'tenant_id = ? AND item_remote_id = ?',
                whereArgs: <Object?>[session.tenantId, itm.itemId],
                insertValues: <String, Object?>{
                  'tenant_id': session.tenantId,
                  'item_remote_id': itm.itemId,
                  'description': itm.description,
                  'rate': itm.rate,
                  'commodity_code': itm.commodityCode,
                  'sku_code': itm.skuCode,
                  'group_name': itm.groupName,
                  'image_url': itm.imageUrl,
                  'can_be_inventory': itm.canBeInventory ? '1' : '0',
                  'images_json': jsonEncode(itm.images ?? []),
                  'raw_payload_json': _itmRawJson(itm),
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                },
                updateValues: <String, Object?>{
                  'description': itm.description,
                  'rate': itm.rate,
                  'commodity_code': itm.commodityCode,
                  'sku_code': itm.skuCode,
                  'group_name': itm.groupName,
                  'image_url': itm.imageUrl,
                  'can_be_inventory': itm.canBeInventory ? '1' : '0',
                  'images_json': jsonEncode(itm.images ?? []),
                  'raw_payload_json': _itmRawJson(itm),
                  'updated_at': DateTime.now().toIso8601String(),
                },
              );
            }
            try {
              final cutoff = DateTime.now()
                  .subtract(const Duration(days: _pruneDays))
                  .toIso8601String();
              await txn.delete(
                'marketplace_item',
                where: 'tenant_id = ? AND updated_at < ?',
                whereArgs: <Object?>[session.tenantId, cutoff],
              );
            } catch (_) {}
          });
        } catch (_) {}

        return items;
      }
    } catch (_) {
      // Retain local cache on network error
    }
    return null;
  }

  static String _itmRawJson(MarketplaceItem itm) {
    return '{"itemid":"${itm.itemId}","rate":"${itm.rate}","group_name":"${itm.groupName ?? ''}","description":"${itm.description}","commodity_code":"${itm.commodityCode ?? ''}"}';
  }
}
