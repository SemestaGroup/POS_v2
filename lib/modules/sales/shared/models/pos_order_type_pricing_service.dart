import 'order_type_resolver.dart';
import 'pos_cart_item.dart';

class PosOrderTypePricingService {
  const PosOrderTypePricingService._();

  static String _normalizeOrderTypeCode(String code) {
    return code.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
  }

  static Object? _lookupPriceInMap(Map rawMap, String orderType) {
    if (orderType.trim().isEmpty) {
      return null;
    }
    // 1. Direct match
    if (rawMap.containsKey(orderType)) {
      return rawMap[orderType];
    }
    final lower = orderType.trim().toLowerCase();
    for (final entry in rawMap.entries) {
      if (entry.key.toString().trim().toLowerCase() == lower) {
        return entry.value;
      }
    }
    // 2. Normalized alphanumeric match (e.g. dine_in vs dinein vs "Dine In")
    final normSearch = _normalizeOrderTypeCode(orderType);
    for (final entry in rawMap.entries) {
      final keyStr = entry.key.toString();
      if (_normalizeOrderTypeCode(keyStr) == normSearch) {
        return entry.value;
      }
    }
    // 3. Known aliases from OrderTypeResolver
    final mappedSearchAlias =
        OrderTypeResolver.legacyCodeMap[lower] ??
        OrderTypeResolver.legacyCodeMap[normSearch];
    if (mappedSearchAlias != null) {
      for (final entry in rawMap.entries) {
        final keyStr = entry.key.toString().trim().toLowerCase();
        final entryNorm = _normalizeOrderTypeCode(keyStr);
        final mappedEntryAlias =
            OrderTypeResolver.legacyCodeMap[keyStr] ??
            OrderTypeResolver.legacyCodeMap[entryNorm];
        if (keyStr == mappedSearchAlias ||
            entryNorm == mappedSearchAlias ||
            mappedEntryAlias == mappedSearchAlias) {
          return entry.value;
        }
      }
    }
    // 4. Wildcards
    for (final entry in rawMap.entries) {
      final keyStr = entry.key.toString().trim().toLowerCase();
      if (keyStr == '*' || keyStr == 'all' || keyStr == 'default') {
        return entry.value;
      }
    }
    return null;
  }

  /// Checks if a product is allowed for the specified [orderType].
  /// If [orderType] is empty or product has no specific order type restrictions defined in `orderTypePrices`,
  /// it is available for all order types.
  static bool isProductAvailableForOrderType(
    Map<String, dynamic> product,
    String orderType,
  ) {
    if (orderType.trim().isEmpty) {
      return true;
    }
    final rawOrderTypePrices = product['orderTypePrices'];
    if (rawOrderTypePrices is! Map || rawOrderTypePrices.isEmpty) {
      return true;
    }
    return _lookupPriceInMap(rawOrderTypePrices, orderType) != null;
  }

  /// Filters a list of products to only include products available for [orderType].
  static List<Map<String, dynamic>> filterProductsForOrderType(
    List<Map<String, dynamic>> products,
    String orderType,
  ) {
    return products
        .where((p) => isProductAvailableForOrderType(p, orderType))
        .toList();
  }

  /// Applies pricing override for a specific order type if specified in product map.
  static Map<String, dynamic> applyOrderTypePricing(
    Map<String, dynamic> product,
    String orderType,
  ) {
    final mapped = Map<String, dynamic>.from(product);
    final rawOrderTypePrices = mapped['orderTypePrices'];
    if (rawOrderTypePrices is! Map || rawOrderTypePrices.isEmpty) {
      return mapped;
    }
    final rawValue = _lookupPriceInMap(rawOrderTypePrices, orderType);
    if (rawValue == null) {
      return mapped;
    }
    final selectedPrice = parsePriceValue(rawValue);
    if (selectedPrice < 0) {
      return mapped;
    }

    final originalRegularPrice = parsePriceValue(
      mapped['regularPrice'] ?? mapped['price'],
    );
    final currentDiscountedPrice = parsePriceValue(mapped['discountedPrice']);
    final hasCatalogDiscount =
        currentDiscountedPrice > 0 &&
        originalRegularPrice > currentDiscountedPrice;
    final adjustedDiscountedPrice = hasCatalogDiscount
        ? (selectedPrice - (originalRegularPrice - currentDiscountedPrice))
              .clamp(0, selectedPrice)
        : null;

    mapped['regularPrice'] = selectedPrice;
    mapped['discountedPrice'] = adjustedDiscountedPrice;
    mapped['price'] = adjustedDiscountedPrice ?? selectedPrice;
    return mapped;
  }

  /// Creates a standard [PosCartItem] from a catalog [product] and [orderType].
  static PosCartItem createCartItem({
    required String id,
    required Map<String, dynamic> product,
    required String orderType,
    int quantity = 1,
    String? note,
  }) {
    final pricedProduct = applyOrderTypePricing(product, orderType);
    final name = pricedProduct['name']?.toString() ?? '';
    final regularUnitPrice = parsePriceValue(
      pricedProduct['regularPrice'] ?? pricedProduct['price'],
    );
    final discountedPrice = parsePriceValue(pricedProduct['discountedPrice']);
    final discountedUnitPrice = discountedPrice > 0 ? discountedPrice : null;
    final description = pricedProduct['description']?.toString().trim();
    final displayName = (description != null && description.isNotEmpty)
        ? description
        : name;
    final imageUrl =
        pricedProduct['image']?.toString() ??
        pricedProduct['imageUrl']?.toString() ??
        '';

    return PosCartItem(
      id: id,
      name: name,
      displayName: displayName,
      imageUrl: imageUrl,
      regularUnitPrice: regularUnitPrice,
      quantity: quantity,
      productRemoteId: pricedProduct['remoteId']?.toString(),
      discountedUnitPrice: discountedUnitPrice,
      promoLabel: pricedProduct['promo']?.toString(),
      isDiscountEnabled: true,
      orderType: orderType,
      note: note,
    );
  }

  /// Reprices existing cart items to the new order type and filters out items
  /// that are not available in the target order type.
  static List<PosCartItem> repricePosCartItems({
    required List<PosCartItem> items,
    required String orderType,
    required List<Map<String, dynamic>> catalogProducts,
  }) {
    final catalogMap = <String, Map<String, dynamic>>{};
    for (final prod in catalogProducts) {
      final remoteId = prod['remoteId']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        catalogMap[remoteId] = prod;
      }
    }

    return items
        .where((item) {
          final product = catalogMap[item.productRemoteId];
          if (product == null) return true;
          return isProductAvailableForOrderType(product, orderType);
        })
        .map((item) {
          final product = catalogMap[item.productRemoteId];
          if (product == null) {
            return item.copyWith(orderType: orderType);
          }
          final pricedProduct = applyOrderTypePricing(product, orderType);
          final regularPrice = parsePriceValue(
            pricedProduct['regularPrice'] ?? pricedProduct['price'],
          );
          final discountedPrice =
              parsePriceValue(pricedProduct['discountedPrice']);
          return item.copyWith(
            regularUnitPrice: regularPrice,
            discountedUnitPrice: discountedPrice > 0 ? discountedPrice : null,
            orderType: orderType,
          );
        })
        .toList();
  }

  /// Parses price values safely from various types (int, double, String).
  static int parsePriceValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
    }
    return 0;
  }
}
