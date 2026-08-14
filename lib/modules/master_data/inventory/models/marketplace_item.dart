import 'dart:convert';

import '../stores/inventory_read_stores.dart';

enum StockFilter { all, needsAttention, outOfStock }

class CartEntry {
  CartEntry({
    required this.key,
    required this.name,
    required this.sku,
    this.productId,
    this.remoteId,
    required this.unitCost,
    this.imageUrl,
    this.group,
  });

  final String key;
  final String name;
  final String sku;
  final int? productId;
  final String? remoteId;
  final int unitCost;
  final String? imageUrl;
  final String? group;

  PurchaseOrderInputLine toInputLine(int qty) => PurchaseOrderInputLine(
        productId: productId,
        productRemoteId: remoteId,
        productName: name,
        productSku: sku,
        quantity: qty.toDouble(),
        unitCostAmount: unitCost,
      );
}

class MarketplaceItem {
  MarketplaceItem({
    required this.itemId,
    required this.rate,
    this.groupName,
    required this.description,
    this.commodityCode,
    this.skuCode,
    this.imageUrl,
    this.images,
    this.canBeInventory = false,
  });

  final String itemId;
  final String rate;
  final String? groupName;
  final String description;
  final String? commodityCode;
  final String? skuCode;
  final String? imageUrl;
  final List<dynamic>? images;
  final bool canBeInventory;

  String get displayName => description;

  int get rateCents {
    final parsed = double.tryParse(rate) ?? 0;
    return parsed.round();
  }

  factory MarketplaceItem.fromJson(Map<String, dynamic> json) {
    List<dynamic>? imgs;
    if (json['images'] is List) {
      imgs = json['images'] as List<dynamic>;
    }
    String? firstImg = json['image_url']?.toString();
    if ((firstImg == null || firstImg.isEmpty) &&
        imgs != null &&
        imgs.isNotEmpty) {
      final first = imgs.first;
      if (first is Map && first['url'] != null) {
        firstImg = first['url'].toString();
      }
    }
    return MarketplaceItem(
      itemId: json['itemid']?.toString() ?? '',
      rate: json['rate']?.toString() ?? '0',
      groupName: json['group_name']?.toString(),
      description: json['description']?.toString() ?? '',
      commodityCode: json['commodity_code']?.toString(),
      skuCode: json['sku_code']?.toString(),
      imageUrl: firstImg,
      images: imgs,
      canBeInventory:
          json['can_be_inventory'] == true || json['can_be_inventory'] == '1',
    );
  }

  factory MarketplaceItem.fromDbRow(Map<String, Object?> row) {
    List<dynamic>? imgs;
    if (row['images_json'] != null) {
      try {
        imgs = jsonDecode(row['images_json'].toString()) as List<dynamic>;
      } catch (_) {}
    }
    return MarketplaceItem(
      itemId: row['item_remote_id']?.toString() ?? '',
      rate: row['rate']?.toString() ?? '0',
      groupName: row['group_name']?.toString(),
      description: row['description']?.toString() ?? '',
      commodityCode: row['commodity_code']?.toString(),
      skuCode: row['sku_code']?.toString(),
      imageUrl: row['image_url']?.toString(),
      images: imgs,
      canBeInventory:
          row['can_be_inventory'] == '1' || row['can_be_inventory'] == true,
    );
  }
}
