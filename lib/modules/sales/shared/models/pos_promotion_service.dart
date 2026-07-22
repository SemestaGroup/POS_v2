import 'dart:convert';

import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';

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

class PosPromotionService {
  PosPromotionService._();

  static final PosPromotionService instance = PosPromotionService._();

  Future<List<PosPromotionResult>> getApplicablePromotions({
    required List<PosPromotionMatchItem> items,
    required String orderTypeCode,
  }) async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      return const <PosPromotionResult>[];
    }

    final rows = await DatabaseService.instance.query(
      'promotion',
      where: 'tenant_id = ? AND deleted_at IS NULL AND status IN (?, ?)',
      whereArgs: <Object?>[session.tenantId, '1', 'active'],
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

      final orderTypes = _asStringList(decoded['order_types']);
      if (orderTypes.isNotEmpty && !orderTypes.contains(orderTypeCode)) {
        continue;
      }

      final locationIds = _asStringList(decoded['locations']);
      if (locationIds.isNotEmpty && !locationIds.contains(session.locationId)) {
        continue;
      }

      final promoType = decoded['promo_type']?.toString() ?? '';
      final promoName = decoded['name']?.toString() ?? '';
      final remoteId = decoded['id']?.toString() ?? '';
      final isMultiplied = (decoded['is_multiply']?.toString() ?? decoded['is_multiplied']?.toString() ?? '0') == '1';
      final isStackable = (decoded['is_stackable']?.toString() ?? '0') == '1';

      final eligibleProductIds = <String>{};
      final eligibleCategoryIds = <String>{};
      final originalPriceOverrides = <String, int>{};

      final itemsRule = decoded['items'];
      if (itemsRule is Map) {
        final detailRules =
            (itemsRule['detail'] as List?)?.whereType<Map>() ?? [];
        if (promoType == 'bundling') {
          for (final rule in detailRules) {
            final targetIds = _asStringList(rule['target_id'] ?? rule['item_id']);
            eligibleProductIds.addAll(targetIds);
          }
        } else if (promoType == 'discount') {
          for (final rule in detailRules) {
            final targetIds = _asStringList(rule['target_id'] ?? rule['item_id']);
            for (final targetId in targetIds) {
              eligibleProductIds.add(targetId);
              final rawOriginalPrice = rule['original_price']?.toString();
              if (rawOriginalPrice != null && rawOriginalPrice.isNotEmpty) {
                final overridePrice = int.tryParse(rawOriginalPrice);
                if (overridePrice != null && overridePrice > 0) {
                  originalPriceOverrides[targetId] = overridePrice;
                }
              }
            }
          }
        }
      }

      var result = switch (promoType) {
        'bundling' => _evaluateBundling(decoded, items, isMultiplied, isStackable),
        'discount' => _evaluateDiscount(decoded, items, isMultiplied, isStackable),
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
            fallbackTotalBundlePrice = int.tryParse(
                  (itemsRule['total_price'] ?? '0').toString().replaceAll(',', ''),
                ) ??
                0;
          } else if (promoType == 'discount') {
            final details = itemsRule['detail'] as List?;
            if (details != null) {
              for (final d in details) {
                if (d is Map) {
                  final dtype = d['discount_type']?.toString() ?? '';
                  if (dtype.toLowerCase().replaceAll(' ', '_') != 'final_price') {
                    fallbackDiscountValue += int.tryParse(
                          (d['discount_value'] ?? d['discount'] ?? '0').toString(),
                        ) ?? 0;
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
            discountAmount: promoType == 'bundling' ? fallbackTotalBundlePrice : fallbackDiscountValue,
            displayAmount: promoType == 'bundling' ? fallbackTotalBundlePrice.toString() : fallbackDiscountValue.toString(),
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

  PosPromotionAllocationResult allocatePromotions({
    required List<PosPromotionMatchItem> items,
    required List<PosPromotionResult> selectedPromotions,
  }) {
    final allocatedItems = <PosPromotionAllocatedItem>[];
    var totalDiscountAmount = 0;
    
    final pool = items.map((e) => _AllocationPoolItem.fromMatchItem(e)).toList();

    for (final promo in selectedPromotions) {
      if (promo.promoType == 'discount') {
        final rules = promo.rawPayload['items']?['detail'] as List?;
        if (rules == null) continue;

        for (final rule in rules) {
          final targetIds = _asStringList(rule['target_id'] ?? rule['item_id']);
          if (targetIds.isEmpty) continue;

          final discountType = rule['discount_type']?.toString() ?? '';
          final discountValue = int.tryParse((rule['discount_value'] ?? rule['discount'] ?? '0').toString()) ?? 0;

          final currentPool = List<_AllocationPoolItem>.from(pool);
          var appliedCount = 0;

          for (final poolItem in currentPool) {
            if (appliedCount >= 1 && !promo.isMultiplied) break;
            if (poolItem.qty <= 0) continue;
            if (poolItem.isLocked) continue;
            if (!targetIds.contains(poolItem.productRemoteId)) continue;
            // Prevent the same promo from applying multiple rules to the same item
            if (poolItem.appliedPromoIds.contains(promo.remoteId)) continue;
            
            final overridePrice = promo.originalPriceOverrides[poolItem.productRemoteId];

            final consumeQty = promo.isMultiplied ? poolItem.qty : 1;
            if (consumeQty > poolItem.qty) continue;

            final basePrice = overridePrice ?? poolItem.activeUnitPrice;
            final currentPrice = basePrice - poolItem.accumulatedDiscount;
            
            final normType = discountType.toLowerCase().replaceAll(' ', '_');
            final discountPerUnit = switch (normType) {
              'final_price' || 'finalprice' => (currentPrice - discountValue).clamp(0, currentPrice),
              'percent' || 'percentage' => ((currentPrice * discountValue) / 100).round(),
              'nominal' || 'fixed_amount' || 'fixedamount' => discountValue.clamp(0, currentPrice),
              _ => 0,
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
        final totalBundlePrice = int.tryParse(
          (promo.rawPayload['items']?['total_price'] ?? '0')
              .toString()
              .replaceAll(',', ''),
        ) ?? 0;
        final detailRules = (promo.rawPayload['items']?['detail'] as List?)
            ?.whereType<Map>() ?? const [];

        // Map refId -> planned qty to consume (cumulative for this promo)
        final cumulativePlanned = <String, int>{};
        
        int appliedCount = 0;
        final maxApply = promo.isMultiplied ? 9999 : 1;

        while (appliedCount < maxApply) {
          final currentPassPlanned = <String, int>{};
          var allSlotsFilled = detailRules.isNotEmpty;

          for (final rule in detailRules) {
            final slotQty = int.tryParse((rule['qty'] ?? '0').toString()) ?? 0;
            if (slotQty <= 0) { allSlotsFilled = false; break; }
            final targetIds = _asStringList(rule['target_id'] ?? rule['item_id']);
            if (targetIds.isEmpty) { allSlotsFilled = false; break; }

            var needed = slotQty;
            for (final poolItem in pool) {
              if (needed <= 0) break;
              
              final alreadyPlanned = (cumulativePlanned[poolItem.refId] ?? 0) + (currentPassPlanned[poolItem.refId] ?? 0);
              final available = poolItem.qty - alreadyPlanned;
              if (available <= 0) continue;
              if (!targetIds.contains(poolItem.productRemoteId)) continue;

              final take = needed.clamp(0, available);
              currentPassPlanned[poolItem.refId] = (currentPassPlanned[poolItem.refId] ?? 0) + take;
              needed -= take;
            }
            if (needed > 0) { allSlotsFilled = false; break; }
          }

          // Commit current pass
          var passAllocatedTotal = 0;
          final takenItems = <_AllocationPoolItem, int>{};
          for (final entry in currentPassPlanned.entries) {
            var needed = entry.value;
            // Iterate over a copy because we might split items
            final currentPool = List<_AllocationPoolItem>.from(pool);
            for (final poolItem in currentPool) {
              if (needed <= 0) break;
              if (poolItem.refId != entry.key || poolItem.isLocked) continue;
              
              final take = needed.clamp(0, poolItem.qty);
              if (take <= 0) continue;

              passAllocatedTotal += poolItem.activeUnitPrice * take;
              needed -= take;

              if (take < poolItem.qty) {
                final splitItem = poolItem.clone(poolItem.qty - take);
                poolItem.qty = take;
                pool.add(splitItem);
              }
              
              takenItems[poolItem] = take;
              poolItem.appliedPromoIds.add(promo.remoteId);
              poolItem.appliedPromoNames.add(promo.name);
              if (!promo.isStackable) {
                poolItem.isLocked = true;
              }
            }
          }

          if (allSlotsFilled && totalBundlePrice > 0 && passAllocatedTotal > 0) {
            final discount = (passAllocatedTotal - totalBundlePrice).clamp(0, passAllocatedTotal);
            var remainingDiscount = discount;
            for (final entry in takenItems.entries) {
               final poolItem = entry.key;
               final take = entry.value;
               if (remainingDiscount <= 0) break;

               final maxDiscountForThisItem = (poolItem.activeUnitPrice * take);
               final applyDiscount = remainingDiscount.clamp(0, maxDiscountForThisItem);
               
               final perUnitDiscount = (applyDiscount / take).floor();
               poolItem.accumulatedDiscount += perUnitDiscount;
               
               if (!poolItem.appliedPromoIds.contains(promo.remoteId)) {
                 poolItem.appliedPromoIds.add(promo.remoteId);
                 poolItem.appliedPromoNames.add(promo.name);
               }
               
               remainingDiscount -= (perUnitDiscount * take);
            }
            appliedCount++;
          } else {
            // Partial or empty. We break out since we can't form another full bundle.
            break;
          }
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
            appliedPromoId: poolItem.appliedPromoIds.isEmpty ? null : poolItem.appliedPromoIds.join('\n'),
            appliedPromoName: poolItem.appliedPromoNames.isEmpty ? null : poolItem.appliedPromoNames.join('\n'),
            overriddenUnitPrice: poolItem.accumulatedDiscount > 0 ? (poolItem.activeUnitPrice - poolItem.accumulatedDiscount).clamp(0, poolItem.activeUnitPrice) : null,
          ),
        );
      }
    }

    // Aggregate identical rows
    final aggregatedItems = <PosPromotionAllocatedItem>[];
    for (final item in allocatedItems) {
      final existingIndex = aggregatedItems.indexWhere(
        (a) => a.refId == item.refId && 
               a.appliedPromoId == item.appliedPromoId &&
               a.overriddenUnitPrice == item.overriddenUnitPrice &&
               a.appliedPromoName == item.appliedPromoName
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
      final targetIds = _asStringList(rule['target_id']);
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
        final isMatch = targetIds.contains(candidate.productRemoteId);
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
      final targetIds = _asStringList(rule['target_id'] ?? rule['item_id']);
      if (targetIds.isEmpty) continue;
      final discountType = rule['discount_type']?.toString() ?? '';
      final discountValue =
          int.tryParse(
            (rule['discount_value'] ?? rule['discount'] ?? '0').toString(),
          ) ??
          0;
      final rawOriginalPrice = rule['original_price']?.toString();
      final overridePrice = rawOriginalPrice != null && rawOriginalPrice.isNotEmpty
          ? int.tryParse(rawOriginalPrice)
          : null;

      final matchedItems = items
          .where((item) => targetIds.contains(item.productRemoteId))
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
          'final_price' || 'finalprice' => (effectiveUnitPrice - discountValue).clamp(0, effectiveUnitPrice),
          'percent' || 'percentage' => ((effectiveUnitPrice * discountValue) / 100).round(),
          'nominal' || 'fixed_amount' || 'fixedamount' => discountValue.clamp(0, effectiveUnitPrice),
          _ => 0,
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
  })  : appliedPromoIds = appliedPromoIds ?? [],
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

