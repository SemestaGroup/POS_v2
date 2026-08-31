import 'dart:convert';

import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import 'order_type_resolver.dart';
import 'pos_cart_item.dart';
import 'pos_order_type_pricing_service.dart';
import 'pos_order_type_store.dart';

export 'pos_cart_item.dart';

class PosPromotionMatchItem {
  const PosPromotionMatchItem({
    required this.refId,
    required this.productRemoteId,
    required this.productName,
    required this.categoryRemoteId,
    required this.brandRemoteId,
    required this.activeUnitPrice,
    required this.quantity,
  });

  final String refId;
  final String productRemoteId;
  final String productName;
  final String? categoryRemoteId;
  final String? brandRemoteId;
  final int activeUnitPrice;
  final int quantity;
}

class PosPromotionAllocatedItem {
  PosPromotionAllocatedItem({
    required this.refId,
    required this.productRemoteId,
    required this.productName,
    required this.quantity,
    required this.activeUnitPrice,
    this.appliedPromoId,
    this.appliedPromoName,
    this.overriddenUnitPrice,
  });

  final String refId;
  final String productRemoteId;
  final String productName;
  final int quantity;
  final int activeUnitPrice;
  final String? appliedPromoId;
  final String? appliedPromoName;
  final int? overriddenUnitPrice;
}

class PosPromotionAllocationResult {
  PosPromotionAllocationResult({
    required this.allocatedItems,
    required this.totalDiscountAmount,
  });

  final List<PosPromotionAllocatedItem> allocatedItems;
  final int totalDiscountAmount;
}

class PosPromotionResult {
  const PosPromotionResult({
    required this.remoteId,
    required this.name,
    required this.promoType,
    required this.discountAmount,
    required this.displayAmount,
    required this.matchedTotal,
    required this.summary,
    this.totalBundlePrice,
    this.isApplicable = true,
    this.isMultiplied = false,
    this.isStackable = false,
    this.eligibleProductIds = const <String>{},
    this.eligibleCategoryIds = const <String>{},
    this.originalPriceOverrides = const <String, int>{},
    this.rawPayload = const <String, dynamic>{},
  });

  final String remoteId;
  final String name;
  final String promoType;
  final int discountAmount;
  final String displayAmount;
  final int matchedTotal;
  final String summary;
  final int? totalBundlePrice;
  final bool isApplicable;
  final bool isMultiplied;
  final bool isStackable;
  final Set<String> eligibleProductIds;
  final Set<String> eligibleCategoryIds;
  final Map<String, int> originalPriceOverrides;
  final Map<String, dynamic> rawPayload;
}

class PosPromotionCalculationResult {
  const PosPromotionCalculationResult({
    required this.items,
    required this.totalDiscountAmount,
    this.appliedOrderPromoLabel,
  });

  final List<PosCartItem> items;
  final int totalDiscountAmount;
  final String? appliedOrderPromoLabel;
}

class PosPromotionService {
  PosPromotionService._();

  static final PosPromotionService instance = PosPromotionService._();

  /// Builds promotion match items specifically for a list of [PosCartItem].
  static List<PosPromotionMatchItem> buildPosCartMatchItems({
    required List<PosCartItem> items,
    required List<Map<String, dynamic>> catalogProducts,
  }) => buildMatchItems(items: items, catalogProducts: catalogProducts);

  /// Builds promotion match items from a list of cart items and catalog product data.
  static List<PosPromotionMatchItem> buildMatchItems({
    required List<PosCartItem> items,
    required List<Map<String, dynamic>> catalogProducts,
  }) {
    final productIndex = <String, Map<String, dynamic>>{};
    for (final product in catalogProducts) {
      final remoteId = product['remoteId']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        productIndex[remoteId] = product;
      }
    }

    return items
        .where(
          (item) =>
              item.productRemoteId != null && item.productRemoteId!.isNotEmpty,
        )
        .map((item) {
          final remoteId = item.productRemoteId!;
          final product = productIndex[remoteId] ?? const <String, dynamic>{};
          return PosPromotionMatchItem(
            refId: item.id,
            productRemoteId: remoteId,
            productName: item.name,
            categoryRemoteId: product['categoryRemoteId']?.toString(),
            brandRemoteId: product['brandRemoteId']?.toString(),
            activeUnitPrice: item.activeUnitPrice,
            quantity: item.quantity,
          );
        })
        .toList(growable: false);
  }

  /// Recalculates promotions across a list of [PosCartItem].
  PosPromotionCalculationResult recalculatePosCartPromotions({
    required List<PosCartItem> cartItems,
    required List<PosPromotionResult> selectedPromotions,
    required List<Map<String, dynamic>> catalogProducts,
    required String? selectedOrderType,
  }) => recalculateCartPromotions(
    cartItems: cartItems,
    selectedPromotions: selectedPromotions,
    catalogProducts: catalogProducts,
    selectedOrderType: selectedOrderType,
  );

  /// Recalculates promotions across a cart of items, updating discounts, promo assignments, and totals.
  PosPromotionCalculationResult recalculateCartPromotions({
    required List<PosCartItem> cartItems,
    required List<PosPromotionResult> selectedPromotions,
    required List<Map<String, dynamic>> catalogProducts,
    required String? selectedOrderType,
  }) {
    final productIndex = <String, Map<String, dynamic>>{};
    for (final product in catalogProducts) {
      final remoteId = product['remoteId']?.toString();
      if (remoteId != null && remoteId.isNotEmpty) {
        productIndex[remoteId] = product;
      }
    }

    final rawItems = <PosCartItem>[];
    for (final item in cartItems) {
      final remoteId = item.productRemoteId;
      final catalogProduct = remoteId != null ? productIndex[remoteId] : null;

      int? catalogRegularPrice;
      int? originalDiscountedPrice;
      String? originalPromoLabel;

      if (catalogProduct != null) {
        final orderType = item.orderType ?? selectedOrderType ?? 'dinein';
        final pricedProduct = PosOrderTypePricingService.applyOrderTypePricing(
          catalogProduct,
          orderType,
        );
        catalogRegularPrice = PosOrderTypePricingService.parsePriceValue(
          pricedProduct['regularPrice'] ?? pricedProduct['price'],
        );
        final catalogDiscountedPrice =
            PosOrderTypePricingService.parsePriceValue(
              pricedProduct['discountedPrice'],
            );
        originalDiscountedPrice = catalogDiscountedPrice > 0
            ? catalogDiscountedPrice
            : null;
        originalPromoLabel = pricedProduct['promo']?.toString();
      }

      final cleanItem = item.copyWith(
        regularUnitPrice:
            (catalogRegularPrice != null && catalogRegularPrice > 0)
            ? catalogRegularPrice
            : null,
        discountedUnitPrice: originalDiscountedPrice,
        promoLabel: originalPromoLabel,
        isDiscountEnabled: originalDiscountedPrice != null,
        appliedPromoId: null,
        appliedPromoName: null,
        overriddenUnitPrice: null,
        clearAppliedPromoId: true,
        clearAppliedPromoName: true,
        clearDiscountedUnitPrice: originalDiscountedPrice == null,
        clearPromoLabel: originalPromoLabel == null,
        clearOverriddenUnitPrice: true,
      );

      rawItems.add(cleanItem);
    }

    final matchItems = <PosPromotionMatchItem>[];
    for (final item in rawItems) {
      final remoteId = item.productRemoteId;
      if (remoteId == null || remoteId.isEmpty) {
        continue;
      }
      final metadata = productIndex[remoteId] ?? const <String, dynamic>{};
      matchItems.add(
        PosPromotionMatchItem(
          refId: item.id,
          productRemoteId: remoteId,
          productName: item.name,
          categoryRemoteId: metadata['categoryRemoteId']?.toString(),
          brandRemoteId: metadata['brandRemoteId']?.toString(),
          activeUnitPrice: item.activeUnitPrice,
          quantity: item.quantity,
        ),
      );
    }

    final allocation = allocatePromotions(
      items: matchItems,
      selectedPromotions: selectedPromotions,
    );

    final nextCartItems = <PosCartItem>[];
    for (final rawItem in rawItems) {
      final itemId = rawItem.id;
      final matchingAllocations = allocation.allocatedItems
          .where((a) => a.refId == itemId)
          .toList(growable: false);

      if (matchingAllocations.isEmpty) {
        nextCartItems.add(rawItem);
        continue;
      }

      for (var i = 0; i < matchingAllocations.length; i++) {
        final allocated = matchingAllocations[i];
        final hasPromo =
            allocated.appliedPromoId != null &&
            allocated.appliedPromoId!.isNotEmpty;
        final isSplit = i > 0;

        nextCartItems.add(
          rawItem.copyWith(
            id: isSplit ? '${itemId}_split_$i' : null,
            quantity: allocated.quantity,
            appliedPromoId: allocated.appliedPromoId,
            appliedPromoName: allocated.appliedPromoName,
            overriddenUnitPrice: allocated.overriddenUnitPrice,
            clearAppliedPromoId: !hasPromo,
            clearAppliedPromoName: !hasPromo,
            clearOverriddenUnitPrice: !hasPromo,
            clearDiscountedUnitPrice: false,
            clearPromoLabel: false,
          ),
        );
      }
    }

    String? appliedOrderPromoLabel;
    if (selectedPromotions.isNotEmpty) {
      final names = selectedPromotions.map((p) => p.name).join('|');
      appliedOrderPromoLabel = names.isNotEmpty ? names : null;
    }

    return PosPromotionCalculationResult(
      items: nextCartItems,
      totalDiscountAmount: allocation.totalDiscountAmount,
      appliedOrderPromoLabel: appliedOrderPromoLabel,
    );
  }

  Future<List<PosPromotionResult>> getApplicablePromotions({
    required List<PosPromotionMatchItem> items,
    required String orderTypeCode,
  }) async {
    final session = PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      return const <PosPromotionResult>[];
    }

    final activeTypes = PosOrderTypeStore.instance.snapshot.orderTypes;
    final resolvedOrderTypeCode =
        OrderTypeResolver.resolveCode(orderTypeCode, activeTypes) ??
        orderTypeCode;

    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'promotion',
      where: 'tenant_id = ? AND deleted_at IS NULL AND (status IN (?, ?, ?, ?) OR status IS NULL)',
      whereArgs: <Object?>[session.tenantId, '1', 'active', 'Active', 'ACTIVE'],
      orderBy: 'created_at DESC',
    );

    final results = <PosPromotionResult>[];
    for (final row in rows) {
      final raw = row['raw_payload_json']?.toString();
      if (raw == null || raw.isEmpty) {
        continue;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }

      final remoteId =
          decoded['id']?.toString() ?? row['remote_id']?.toString() ?? '';
      final promoName =
          decoded['name']?.toString() ?? row['name']?.toString() ?? '';
      final promoType = (decoded['promo_type'] ??
              decoded['type'] ??
              row['promo_type'] ??
              row['type'] ??
              '')
          .toString()
          .toLowerCase()
          .replaceAll(' ', '_');

      final orderTypes = _asStringList(
        decoded['order_types'] ?? decoded['order_type'],
      );
      if (orderTypes.isNotEmpty) {
        final normalizedCurrent = (OrderTypeResolver.resolveCode(
                  resolvedOrderTypeCode,
                  activeTypes,
                ) ??
                resolvedOrderTypeCode)
            .toLowerCase();
        final matchesOrderType = orderTypes.any((rawType) {
          final rawStr = rawType.toString().trim();
          final rawLower = rawStr.toLowerCase();
          if (rawLower == 'all' || rawLower == '*' || rawLower == 'semua') {
            return true;
          }
          if (rawLower == normalizedCurrent) return true;
          final mappedLegacy = OrderTypeResolver.legacyCodeMap[rawLower];
          if (mappedLegacy != null &&
              (mappedLegacy == normalizedCurrent ||
                  mappedLegacy == resolvedOrderTypeCode.toLowerCase())) {
            return true;
          }
          final resolved = OrderTypeResolver.resolveCode(rawStr, activeTypes);
          if (resolved != null && resolved.toLowerCase() == normalizedCurrent) {
            return true;
          }
          return false;
        });
        if (!matchesOrderType) {
          continue;
        }
      }

      final isMultiplied = (decoded['is_multiplied']?.toString() ??
              row['is_multiplied']?.toString() ??
              '0') ==
          '1';
      final isStackable = (decoded['is_stackable']?.toString() ??
              row['is_stackable']?.toString() ??
              '0') ==
          '1';

      final eligibleProductIds = <String>{};
      final eligibleCategoryIds = <String>{};
      final originalPriceOverrides = <String, int>{};

      final itemsRule = decoded['items'];
      if (itemsRule is Map) {
        final detail = itemsRule['detail'] as List?;
        if (detail != null) {
          for (final d in detail) {
            if (d is Map) {
              final targetIds = _asStringList(d['target_id'] ?? d['item_id']);
              eligibleProductIds.addAll(targetIds);

              final rawOriginalPrice = d['original_price']?.toString();
              final overridePrice =
                  rawOriginalPrice != null && rawOriginalPrice.isNotEmpty
                  ? int.tryParse(rawOriginalPrice)
                  : null;
              if (overridePrice != null && overridePrice > 0) {
                for (final tid in targetIds) {
                  originalPriceOverrides[tid] = overridePrice;
                }
              }
            }
          }
        }
      }

      final result = switch (promoType) {
        'bundling' => _evaluateBundling(
          decoded,
          items,
          isMultiplied,
          isStackable,
        ),
        'discount' => _evaluateDiscount(
          decoded,
          items,
          isMultiplied,
          isStackable,
        ),
        _ => null,
      };

      if (result != null) {
        final withMeta = PosPromotionResult(
          remoteId: result.remoteId,
          name: result.name,
          promoType: result.promoType,
          discountAmount: result.discountAmount,
          displayAmount: result.displayAmount,
          matchedTotal: result.matchedTotal,
          summary: result.summary,
          totalBundlePrice: result.totalBundlePrice,
          isApplicable: result.isApplicable,
          isMultiplied: result.isMultiplied,
          isStackable: result.isStackable,
          eligibleProductIds: eligibleProductIds,
          eligibleCategoryIds: eligibleCategoryIds,
          originalPriceOverrides: originalPriceOverrides,
          rawPayload: decoded,
        );
        results.add(withMeta);
      } else {
        int fallbackTotalBundlePrice = 0;
        int fallbackDiscountValue = 0;
        final itemsRule = decoded['items'];
        if (itemsRule is Map) {
          if (promoType == 'bundling') {
            fallbackTotalBundlePrice =
                int.tryParse(
                  (itemsRule['total_price'] ?? '0').toString().replaceAll(
                    ',',
                    '',
                  ),
                ) ??
                0;
          } else if (promoType == 'discount') {
            final details = itemsRule['detail'] as List?;
            if (details != null) {
              for (final d in details) {
                if (d is Map) {
                  final dtype = d['discount_type']?.toString() ?? '';
                  if (dtype.toLowerCase().replaceAll(' ', '_') !=
                      'final_price') {
                    fallbackDiscountValue +=
                        int.tryParse(
                          (d['discount_value'] ?? d['discount'] ?? '0')
                              .toString(),
                        ) ??
                        0;
                  }
                }
              }
            }
          }
        }

        results.add(
          PosPromotionResult(
            remoteId: remoteId,
            name: promoName,
            promoType: promoType,
            discountAmount: promoType == 'bundling'
                ? fallbackTotalBundlePrice
                : fallbackDiscountValue,
            displayAmount: promoType == 'bundling'
                ? fallbackTotalBundlePrice.toString()
                : fallbackDiscountValue.toString(),
            matchedTotal: 0,
            summary: '',
            isApplicable: false,
            isMultiplied: isMultiplied,
            isStackable: isStackable,
            totalBundlePrice: fallbackTotalBundlePrice,
            eligibleProductIds: eligibleProductIds,
            eligibleCategoryIds: eligibleCategoryIds,
            originalPriceOverrides: originalPriceOverrides,
            rawPayload: decoded,
          ),
        );
      }
    }

    return results;
  }

  /// Filters [currentSelection] to only include promotions that are valid and applicable
  /// for the specified [orderTypeCode] and cart [items].
  Future<List<PosPromotionResult>> validateSelectedPromotions({
    required List<PosPromotionResult> currentSelection,
    required List<PosPromotionMatchItem> items,
    required String orderTypeCode,
  }) async {
    if (currentSelection.isEmpty) {
      return const <PosPromotionResult>[];
    }
    final applicablePromos = await getApplicablePromotions(
      items: items,
      orderTypeCode: orderTypeCode,
    );
    final applicableRemoteIds = applicablePromos
        .where((p) => p.isApplicable)
        .map((p) => p.remoteId)
        .toSet();
    return currentSelection
        .where((p) => applicableRemoteIds.contains(p.remoteId))
        .toList(growable: false);
  }

  PosPromotionAllocationResult allocatePromotions({
    required List<PosPromotionMatchItem> items,
    required List<PosPromotionResult> selectedPromotions,
  }) {
    final allocatedItems = <PosPromotionAllocatedItem>[];

    final pool = items
        .map((e) => _AllocationPoolItem.fromMatchItem(e))
        .toList();

    for (final promo in selectedPromotions) {
      if (promo.promoType == 'discount') {
        final rules = promo.rawPayload['items']?['detail'] as List?;
        if (rules == null) continue;

        for (final rule in rules) {
          final targetIds = _asStringList(
            rule['target_id'] ?? rule['item_id'] ?? rule['product_id'],
          );
          if (targetIds.isEmpty) continue;

          final discountType = rule['discount_type']?.toString() ?? '';
          final discountValue =
              int.tryParse(
                (rule['discount_value'] ?? rule['discount'] ?? '0').toString(),
              ) ??
              0;

          final currentPool = List<_AllocationPoolItem>.from(pool);
          var appliedCount = 0;

          for (final poolItem in currentPool) {
            if (appliedCount >= 1 && !promo.isMultiplied) break;
            if (poolItem.qty <= 0) continue;
            if (poolItem.isLocked) continue;
            final isMatch = targetIds.contains(poolItem.productRemoteId) ||
                (poolItem.categoryRemoteId != null &&
                    targetIds.contains(poolItem.categoryRemoteId));
            if (!isMatch) continue;
            // Prevent the same promo from applying multiple rules to the same item
            if (poolItem.appliedPromoIds.contains(promo.remoteId)) continue;

            final overridePrice =
                promo.originalPriceOverrides[poolItem.productRemoteId];

            final consumeQty = promo.isMultiplied ? poolItem.qty : 1;
            if (consumeQty > poolItem.qty) continue;

            final basePrice = overridePrice ?? poolItem.activeUnitPrice;
            final currentPrice = basePrice - poolItem.accumulatedDiscount;

            final normType = discountType.toLowerCase().replaceAll(' ', '_');
            final discountPerUnit = switch (normType) {
              'final_price' || 'finalprice' || 'price' || 'harga_coret' || 'harga_spesial' =>
                (currentPrice - discountValue).clamp(0, currentPrice),
              'percent' || 'percentage' || '%' || 'persen' || 'diskon_persen' =>
                ((currentPrice * discountValue) / 100).round().clamp(0, currentPrice),
              'nominal' || 'fixed_amount' || 'fixedamount' || 'fixed' || 'amount' || 'rupiah' || 'rp' || 'diskon_nominal' =>
                discountValue.clamp(0, currentPrice),
              _ => discountValue > 0 && discountValue <= 100 && normType.contains('percent')
                  ? ((currentPrice * discountValue) / 100).round().clamp(0, currentPrice)
                  : discountValue.clamp(0, currentPrice),
            };

            if (consumeQty < poolItem.qty) {
              final splitItem = poolItem.clone(poolItem.qty - consumeQty);
              poolItem.qty = consumeQty;
              pool.add(splitItem);
            }

            poolItem.appliedPromoIds.add(promo.remoteId);
            poolItem.appliedPromoNames.add(promo.name);
            poolItem.accumulatedDiscount += discountPerUnit;
            if (!promo.isStackable) {
              poolItem.isLocked = true;
            }
            appliedCount++;
          }
        }
      } else if (promo.promoType == 'bundling') {
        final totalBundlePrice =
            int.tryParse(
              (promo.rawPayload['items']?['total_price'] ?? '0')
                  .toString()
                  .replaceAll(',', ''),
            ) ??
            0;
        final detailRules =
            (promo.rawPayload['items']?['detail'] as List?)?.whereType<Map>() ??
            const [];

        int appliedCount = 0;
        final maxApply = promo.isMultiplied ? 9999 : 1;

        while (appliedCount < maxApply) {
          final unitsToTake = <_AllocationPoolItem, int>{};
          var allSlotsFilled = detailRules.isNotEmpty;

          for (final rule in detailRules) {
            final slotQty = int.tryParse((rule['qty'] ?? '0').toString()) ?? 0;
            if (slotQty <= 0) {
              allSlotsFilled = false;
              break;
            }
            final targetIds = _asStringList(
              rule['target_id'] ?? rule['item_id'] ?? rule['product_id'],
            );
            final mustBeDifferent =
                (rule['must_be_different']?.toString() ?? '0') == '1';
            if (targetIds.isEmpty) {
              allSlotsFilled = false;
              break;
            }

            var needed = slotQty;
            final matchedProductIdsInRule = <String>{};
            for (final poolItem in pool) {
              if (needed <= 0) break;
              if (poolItem.qty <= 0) continue;
              if (poolItem.isLocked) continue;
              if (poolItem.appliedPromoIds.contains(promo.remoteId)) continue;
              final isMatch = targetIds.contains(poolItem.productRemoteId) ||
                  (poolItem.categoryRemoteId != null &&
                      targetIds.contains(poolItem.categoryRemoteId));
              if (!isMatch) continue;
              if (mustBeDifferent &&
                  matchedProductIdsInRule.contains(poolItem.productRemoteId)) {
                continue;
              }

              final alreadyTaken = unitsToTake[poolItem] ?? 0;
              final available = poolItem.qty - alreadyTaken;
              if (available <= 0) continue;

              final take = mustBeDifferent ? 1 : needed.clamp(0, available);
              unitsToTake[poolItem] = alreadyTaken + take;
              if (mustBeDifferent) {
                matchedProductIdsInRule.add(poolItem.productRemoteId);
              }
              needed -= take;
            }
            if (needed > 0) {
              allSlotsFilled = false;
              break;
            }
          }

          if (!allSlotsFilled) {
            // Cannot form a complete bundle in this pass. Stop cleanly without mutating any pool items.
            break;
          }

          // All slots for this bundle are satisfied! Now commit and split pool items.
          var passAllocatedTotal = 0;
          final passTakenItems = <_AllocationPoolItem>[];

          for (final entry in unitsToTake.entries) {
            final poolItem = entry.key;
            final take = entry.value;
            if (take <= 0) continue;

            if (take < poolItem.qty) {
              final remainder = poolItem.clone(poolItem.qty - take);
              poolItem.qty = take;
              pool.add(remainder);
            }

            passTakenItems.add(poolItem);
            passAllocatedTotal += poolItem.activeUnitPrice * poolItem.qty;
          }

          final discount =
              (totalBundlePrice > 0 && passAllocatedTotal > totalBundlePrice)
              ? (passAllocatedTotal - totalBundlePrice)
              : 0;

          var remainingDiscount = discount;
          for (var i = 0; i < passTakenItems.length; i++) {
            final poolItem = passTakenItems[i];
            poolItem.appliedPromoIds.add(promo.remoteId);
            poolItem.appliedPromoNames.add(promo.name);
            if (!promo.isStackable) {
              poolItem.isLocked = true;
            }

            if (remainingDiscount > 0) {
              final isLastItem = i == passTakenItems.length - 1;
              final maxItemDiscount = poolItem.activeUnitPrice * poolItem.qty;
              final proportionalDiscount = isLastItem
                  ? remainingDiscount
                  : ((discount * (poolItem.activeUnitPrice * poolItem.qty)) ~/
                        passAllocatedTotal);

              final applyDiscount = proportionalDiscount
                  .clamp(0, remainingDiscount)
                  .clamp(0, maxItemDiscount);

              final baseDiscount = applyDiscount ~/ poolItem.qty;
              final remainder = applyDiscount % poolItem.qty;

              if (remainder > 0) {
                final splitQty = poolItem.qty - remainder;
                final splitItem = poolItem.clone(splitQty);
                splitItem.accumulatedDiscount += baseDiscount;
                pool.add(splitItem);

                poolItem.qty = remainder;
                poolItem.accumulatedDiscount += (baseDiscount + 1);
              } else {
                poolItem.accumulatedDiscount += baseDiscount;
              }

              remainingDiscount -= applyDiscount;
            }
          }

          appliedCount++;
        }
      }
    }

    for (final poolItem in pool) {
      if (poolItem.qty > 0) {
        allocatedItems.add(
          PosPromotionAllocatedItem(
            refId: poolItem.refId,
            productRemoteId: poolItem.productRemoteId,
            productName: poolItem.productName,
            quantity: poolItem.qty,
            activeUnitPrice: poolItem.activeUnitPrice,
            appliedPromoId: poolItem.appliedPromoIds.isEmpty
                ? null
                : poolItem.appliedPromoIds.join('\n'),
            appliedPromoName: poolItem.appliedPromoNames.isEmpty
                ? null
                : poolItem.appliedPromoNames.join('\n'),
            overriddenUnitPrice: poolItem.accumulatedDiscount > 0
                ? (poolItem.activeUnitPrice - poolItem.accumulatedDiscount)
                      .clamp(0, poolItem.activeUnitPrice)
                : null,
          ),
        );
      }
    }

    // Aggregate identical rows
    final aggregatedItems = <PosPromotionAllocatedItem>[];
    for (final item in allocatedItems) {
      final existingIndex = aggregatedItems.indexWhere(
        (a) =>
            a.refId == item.refId &&
            a.appliedPromoId == item.appliedPromoId &&
            a.overriddenUnitPrice == item.overriddenUnitPrice &&
            a.appliedPromoName == item.appliedPromoName,
      );
      if (existingIndex >= 0) {
        final existing = aggregatedItems[existingIndex];
        aggregatedItems[existingIndex] = PosPromotionAllocatedItem(
          refId: existing.refId,
          productRemoteId: existing.productRemoteId,
          productName: existing.productName,
          quantity: existing.quantity + item.quantity,
          activeUnitPrice: existing.activeUnitPrice,
          appliedPromoId: existing.appliedPromoId,
          appliedPromoName: existing.appliedPromoName,
          overriddenUnitPrice: existing.overriddenUnitPrice,
        );
      } else {
        aggregatedItems.add(item);
      }
    }

    final totalDiscountAmount = pool.fold<int>(
      0,
      (sum, item) => sum + (item.accumulatedDiscount * item.qty),
    );

    return PosPromotionAllocationResult(
      allocatedItems: aggregatedItems,
      totalDiscountAmount: totalDiscountAmount,
    );
  }

  PosPromotionResult? _evaluateBundling(
    Map<String, dynamic> promotion,
    List<PosPromotionMatchItem> items,
    bool isMultiplied,
    bool isStackable,
  ) {
    final promoName = promotion['name']?.toString() ?? '';
    final remoteId = promotion['id']?.toString() ?? '';
    final itemsRule = promotion['items'];
    if (itemsRule is! Map<String, dynamic>) {
      return null;
    }

    final detailRules =
        (itemsRule['detail'] as List?)
            ?.whereType<Map>()
            .map(
              (item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)),
            )
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    if (detailRules.isEmpty) {
      return null;
    }

    final pool = <_PromotionPoolUnit>[];
    for (final item in items) {
      for (var i = 0; i < item.quantity; i++) {
        pool.add(
          _PromotionPoolUnit(
            productRemoteId: item.productRemoteId,
            productName: item.productName,
            categoryRemoteId: item.categoryRemoteId,
            brandRemoteId: item.brandRemoteId,
            activeUnitPrice: item.activeUnitPrice,
          ),
        );
      }
    }

    final selectedUnits = <_PromotionPoolUnit>[];
    final consumedIndexes = <int>{};

    for (final rule in detailRules) {
      final qty = int.tryParse((rule['qty'] ?? '0').toString()) ?? 0;
      final targetIds = _asStringList(
        rule['target_id'] ?? rule['item_id'] ?? rule['product_id'],
      );
      final mustBeDifferent =
          (rule['must_be_different']?.toString() ?? '0') == '1';
      if (qty <= 0 || targetIds.isEmpty) {
        return null;
      }

      final matchedIndexes = <int>[];
      final matchedProductIds = <String>{};
      for (var index = 0; index < pool.length; index++) {
        if (consumedIndexes.contains(index)) {
          continue;
        }
        final candidate = pool[index];
        final isMatch = targetIds.contains(candidate.productRemoteId) ||
            (candidate.categoryRemoteId != null &&
                targetIds.contains(candidate.categoryRemoteId));
        if (!isMatch) {
          continue;
        }
        if (mustBeDifferent &&
            matchedProductIds.contains(candidate.productRemoteId)) {
          continue;
        }

        matchedIndexes.add(index);
        matchedProductIds.add(candidate.productRemoteId);
        if (matchedIndexes.length == qty) {
          break;
        }
      }

      if (matchedIndexes.length < qty) {
        return null;
      }
      for (final index in matchedIndexes) {
        consumedIndexes.add(index);
        selectedUnits.add(pool[index]);
      }
    }

    final matchedTotal = selectedUnits.fold<int>(
      0,
      (sum, item) => sum + item.activeUnitPrice,
    );
    final totalBundlePrice =
        int.tryParse(
          (itemsRule['total_price'] ?? '0').toString().replaceAll(',', ''),
        ) ??
        0;
    final discountAmount = matchedTotal - totalBundlePrice;
    if (discountAmount <= 0) {
      return null;
    }

    return PosPromotionResult(
      remoteId: remoteId,
      name: promoName,
      promoType: 'bundling',
      discountAmount: discountAmount,
      displayAmount: totalBundlePrice.toString(),
      matchedTotal: matchedTotal,
      summary:
          'Bundle ${selectedUnits.length} item -> total ${totalBundlePrice.toString()}',
      totalBundlePrice: totalBundlePrice,
      isApplicable: true,
      isMultiplied: isMultiplied,
      isStackable: isStackable,
    );
  }

  PosPromotionResult? _evaluateDiscount(
    Map<String, dynamic> promotion,
    List<PosPromotionMatchItem> items,
    bool isMultiplied,
    bool isStackable,
  ) {
    final promoName = promotion['name']?.toString() ?? '';
    final remoteId = promotion['id']?.toString() ?? '';
    final itemsRule = promotion['items'];
    if (itemsRule is! Map<String, dynamic>) {
      return null;
    }

    final detailRules =
        (itemsRule['detail'] as List?)
            ?.whereType<Map>()
            .map(
              (item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)),
            )
            .toList(growable: false) ??
        const <Map<String, dynamic>>[];
    if (detailRules.isEmpty) {
      return null;
    }

    var discountAmount = 0;
    var matchedTotal = 0;
    final matchedLabels = <String>[];

    for (final rule in detailRules) {
      final targetIds = _asStringList(
        rule['target_id'] ?? rule['item_id'] ?? rule['product_id'],
      );
      if (targetIds.isEmpty) continue;
      final discountType = rule['discount_type']?.toString() ?? '';
      final discountValue =
          int.tryParse(
            (rule['discount_value'] ?? rule['discount'] ?? '0').toString(),
          ) ??
          0;
      final rawOriginalPrice = rule['original_price']?.toString();
      final overridePrice =
          rawOriginalPrice != null && rawOriginalPrice.isNotEmpty
          ? int.tryParse(rawOriginalPrice)
          : null;

      final matchedItems = items
          .where((item) {
            return targetIds.contains(item.productRemoteId) ||
                (item.categoryRemoteId != null &&
                    targetIds.contains(item.categoryRemoteId));
          })
          .toList(growable: false);
      if (matchedItems.isEmpty) {
        continue;
      }

      for (final item in matchedItems) {
        final effectiveUnitPrice = (overridePrice != null && overridePrice > 0)
            ? overridePrice
            : item.activeUnitPrice;

        final currentLineTotal = effectiveUnitPrice * item.quantity;
        final normType = discountType.toLowerCase().replaceAll(' ', '_');
        final discountPerUnit = switch (normType) {
          'final_price' || 'finalprice' || 'price' || 'harga_coret' || 'harga_spesial' =>
            (effectiveUnitPrice - discountValue).clamp(0, effectiveUnitPrice),
          'percent' || 'percentage' || '%' || 'persen' || 'diskon_persen' =>
            ((effectiveUnitPrice * discountValue) / 100).round().clamp(0, effectiveUnitPrice),
          'nominal' || 'fixed_amount' || 'fixedamount' || 'fixed' || 'amount' || 'rupiah' || 'rp' || 'diskon_nominal' =>
            discountValue.clamp(0, effectiveUnitPrice),
          _ => discountValue > 0 && discountValue <= 100 && normType.contains('percent')
              ? ((effectiveUnitPrice * discountValue) / 100).round().clamp(0, effectiveUnitPrice)
              : discountValue.clamp(0, effectiveUnitPrice),
        };
        final lineDiscount = discountPerUnit * item.quantity;
        if (lineDiscount <= 0) {
          continue;
        }
        matchedTotal += currentLineTotal;
        discountAmount += lineDiscount;
        matchedLabels.add(item.productName);
      }
    }

    if (discountAmount <= 0) {
      return null;
    }

    final summaryItems = matchedLabels.toSet().join(', ');
    return PosPromotionResult(
      remoteId: remoteId,
      name: promoName,
      promoType: 'discount',
      discountAmount: discountAmount,
      displayAmount: discountAmount.toString(),
      matchedTotal: matchedTotal,
      summary: summaryItems.isEmpty
          ? 'Discount applied to matching items'
          : 'Discount applied to $summaryItems',
      isApplicable: true,
      isMultiplied: isMultiplied,
      isStackable: isStackable,
    );
  }

  List<String> _asStringList(dynamic value) {
    if (value == null) return const <String>[];

    var actualValue = value;
    if (actualValue is String) {
      final trimmed = actualValue.trim();
      if (trimmed.startsWith('[')) {
        try {
          actualValue = jsonDecode(trimmed);
        } catch (_) {}
      } else if (trimmed.isNotEmpty) {
        return [trimmed];
      }
    } else if (actualValue is int || actualValue is double) {
      return [actualValue.toString()];
    }

    if (actualValue is List) {
      return actualValue
          .map((item) => item?.toString())
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}

class _PromotionPoolUnit {
  const _PromotionPoolUnit({
    required this.productRemoteId,
    required this.productName,
    required this.categoryRemoteId,
    required this.brandRemoteId,
    required this.activeUnitPrice,
  });

  final String productRemoteId;
  final String productName;
  final String? categoryRemoteId;
  final String? brandRemoteId;
  final int activeUnitPrice;
}

class _AllocationPoolItem {
  _AllocationPoolItem({
    required this.refId,
    required this.productRemoteId,
    required this.productName,
    required this.categoryRemoteId,
    required this.activeUnitPrice,
    required this.qty,
    List<String>? appliedPromoIds,
    List<String>? appliedPromoNames,
    this.accumulatedDiscount = 0,
    this.isLocked = false,
  }) : appliedPromoIds = appliedPromoIds ?? [],
       appliedPromoNames = appliedPromoNames ?? [];

  final String refId;
  final String productRemoteId;
  final String productName;
  final String? categoryRemoteId;
  final int activeUnitPrice;
  int qty;
  List<String> appliedPromoIds;
  List<String> appliedPromoNames;
  int accumulatedDiscount;
  bool isLocked;

  factory _AllocationPoolItem.fromMatchItem(PosPromotionMatchItem item) {
    return _AllocationPoolItem(
      refId: item.refId,
      productRemoteId: item.productRemoteId,
      productName: item.productName,
      categoryRemoteId: item.categoryRemoteId,
      activeUnitPrice: item.activeUnitPrice,
      qty: item.quantity,
    );
  }

  _AllocationPoolItem clone(int newQty) {
    return _AllocationPoolItem(
      refId: refId,
      productRemoteId: productRemoteId,
      productName: productName,
      categoryRemoteId: categoryRemoteId,
      activeUnitPrice: activeUnitPrice,
      qty: newQty,
      appliedPromoIds: List.from(appliedPromoIds),
      appliedPromoNames: List.from(appliedPromoNames),
      accumulatedDiscount: accumulatedDiscount,
      isLocked: isLocked,
    );
  }
}
