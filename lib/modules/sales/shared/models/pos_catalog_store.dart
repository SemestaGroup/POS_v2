import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/local/product_image_cache_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';

class PosCatalogSnapshot {
  const PosCatalogSnapshot({
    this.products = const <Map<String, dynamic>>[],
    this.categories = const <String>[],
    this.brands = const <String>[],
    this.activeBrandName,
    this.tenantId,
    this.isLoading = false,
    this.isLoaded = false,
    this.errorMessage,
  });

  final List<Map<String, dynamic>> products;
  final List<String> categories;
  final List<String> brands;
  final String? activeBrandName;
  final int? tenantId;
  final bool isLoading;
  final bool isLoaded;
  final String? errorMessage;

  bool get hasData =>
      products.isNotEmpty || categories.isNotEmpty || brands.isNotEmpty;

  PosCatalogSnapshot copyWith({
    List<Map<String, dynamic>>? products,
    List<String>? categories,
    List<String>? brands,
    String? activeBrandName,
    int? tenantId,
    bool? isLoading,
    bool? isLoaded,
    String? errorMessage,
  }) {
    return PosCatalogSnapshot(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      brands: brands ?? this.brands,
      activeBrandName: activeBrandName ?? this.activeBrandName,
      tenantId: tenantId ?? this.tenantId,
      isLoading: isLoading ?? this.isLoading,
      isLoaded: isLoaded ?? this.isLoaded,
      errorMessage: errorMessage,
    );
  }
}

class PosCatalogStore {
  PosCatalogStore._() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(refresh);
    unawaited(refresh());
  }

  static final PosCatalogStore instance = PosCatalogStore._();

  final ValueNotifier<PosCatalogSnapshot> snapshotNotifier =
      ValueNotifier<PosCatalogSnapshot>(const PosCatalogSnapshot());
  int _refreshGeneration = 0;

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      if (generation != _refreshGeneration) {
        return;
      }
      snapshotNotifier.value = const PosCatalogSnapshot(isLoaded: true);
      return;
    }

    final currentSnapshot = snapshotNotifier.value;
    snapshotNotifier.value = currentSnapshot.copyWith(
      tenantId: session.tenantId,
      isLoading: true,
      errorMessage: null,
    );

    final db = DatabaseService.instance;
    try {
      final categoriesRows = await db.query(
        'category',
        where: 'tenant_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[session.tenantId],
        orderBy: 'name ASC',
      );
      final brandRows = await db.query(
        'brand',
        where: 'tenant_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[session.tenantId],
        orderBy: 'sort_order ASC, name ASC',
      );
      final productRows = await db.rawQuery(
        '''
        SELECT
          product.remote_id,
          product.category_remote_id,
          product.primary_brand_remote_id,
          product.name,
          product.image_url,
          product.description,
          product.price_amount,
          product.discount_total_amount,
          product.discount_type,
          product.stock_quantity,
          product.sort_order,
          category.name AS category_name,
          brand.name AS brand_name
        FROM product
        LEFT JOIN category ON category.id = product.category_id
        LEFT JOIN brand ON brand.id = product.primary_brand_id
        WHERE product.tenant_id = ?
          AND product.deleted_at IS NULL
          AND product.status IN ('1', 'active')
        ORDER BY product.sort_order ASC, product.name ASC
        ''',
        <Object?>[session.tenantId],
      );
      final orderTypeRows = await db.rawQuery(
        '''
        SELECT product_remote_id, order_type_code, price_amount
        FROM product_order_type
        WHERE tenant_id = ?
        ''',
        <Object?>[session.tenantId],
      );

      final priceMap = <String, Map<String, int>>{};
      for (final row in orderTypeRows) {
        final productRemoteId = row['product_remote_id']?.toString();
        final orderTypeCode = row['order_type_code']?.toString();
        final priceAmount = row['price_amount'] is int
            ? row['price_amount'] as int
            : int.tryParse(row['price_amount'].toString()) ?? 0;
        if (productRemoteId == null || orderTypeCode == null) {
          continue;
        }
        priceMap.putIfAbsent(
          productRemoteId,
          () => <String, int>{},
        )[orderTypeCode] = priceAmount;
      }

      final activeBrandSet = <String>{};
      final activeCategorySet = <String>{};
      for (final row in productRows) {
        final brandName = row['brand_name']?.toString();
        final categoryName = row['category_name']?.toString();
        if (brandName != null && brandName.isNotEmpty) {
          activeBrandSet.add(brandName);
        }
        if (categoryName != null && categoryName.isNotEmpty) {
          activeCategorySet.add(categoryName);
        }
      }

      final categories = categoriesRows
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .where(
            (value) => value.isNotEmpty && activeCategorySet.contains(value),
          )
          .toList(growable: false);
      final brands = brandRows
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .where((value) => value.isNotEmpty && activeBrandSet.contains(value))
          .toList(growable: false);
      final activeBrandName = brands.isEmpty ? null : brands.first;

      final products = productRows
          .map((row) {
            final remoteId = row['remote_id']?.toString() ?? '';
            final basePrice = row['price_amount'] is int
                ? row['price_amount'] as int
                : int.tryParse(row['price_amount'].toString()) ?? 0;
            final discountTotal = row['discount_total_amount'] is int
                ? row['discount_total_amount'] as int
                : int.tryParse(row['discount_total_amount'].toString()) ?? 0;
            final discountType = row['discount_type']?.toString();
            final discountedPrice = _computeDiscountedPrice(
              basePrice: basePrice,
              discountTotal: discountTotal,
              discountType: discountType,
            );
            final orderTypePrices = priceMap[remoteId] ?? const <String, int>{};
            return <String, dynamic>{
              'remoteId': remoteId,
              'categoryRemoteId': row['category_remote_id']?.toString(),
              'brandRemoteId': row['primary_brand_remote_id']?.toString(),
              'name': row['name']?.toString() ?? '',
              'price': _formatCurrency(discountedPrice ?? basePrice),
              'regularPrice': basePrice,
              'discountedPrice': discountedPrice,
              'stock': _formatStock(row['stock_quantity']),
              'image': _resolveProductImageUrl(row['image_url']?.toString()),
              'promo': discountTotal > 0 ? 'Promo' : null,
              'categoryName': row['category_name']?.toString(),
              'brandName': row['brand_name']?.toString(),
              'orderTypePrices': orderTypePrices,
            };
          })
          .toList(growable: false);

      if (generation != _refreshGeneration) {
        return;
      }

      snapshotNotifier.value = PosCatalogSnapshot(
        products: products,
        categories: categories,
        brands: brands,
        activeBrandName: activeBrandName,
        tenantId: session.tenantId,
        isLoading: false,
        isLoaded: true,
        errorMessage: null,
      );

      ProductImageCacheService.instance.prefetchInBackground(
        products
            .map((product) => product['image']?.toString() ?? '')
            .where((url) => url.isNotEmpty),
      );
    } catch (error) {
      if (generation != _refreshGeneration) {
        return;
      }
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        tenantId: session.tenantId,
        isLoading: false,
        isLoaded: true,
        errorMessage: error.toString(),
      );
    }
  }

  static int? _computeDiscountedPrice({
    required int basePrice,
    required int discountTotal,
    required String? discountType,
  }) {
    if (discountTotal <= 0 || basePrice <= 0) {
      return null;
    }
    if (discountType == 'percent') {
      final discounted = basePrice - ((basePrice * discountTotal) ~/ 100);
      return discounted.clamp(0, basePrice);
    }
    final discounted = basePrice - discountTotal;
    return discounted.clamp(0, basePrice);
  }

  static String _formatCurrency(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      final position = digits.length - index;
      buffer.write(digits[index]);
      if (position > 1 && position % 3 == 1) {
        buffer.write('.');
      }
    }
    return 'Rp. $buffer';
  }

  static String _resolveProductImageUrl(String? rawImageUrl) {
    final value = rawImageUrl?.trim() ?? '';
    if (value.isEmpty) {
      return ''; // No image available — UI will show fallback icon
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return 'https://flinkaja.com/uploads/products/$value';
  }

  static String _formatStock(Object? value) {
    final text = value?.toString() ?? '0';
    final parsed = double.tryParse(text);
    if (parsed == null) {
      return text;
    }
    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString().padLeft(2, '0');
    }
    return parsed.toString();
  }
}
