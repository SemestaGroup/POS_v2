import 'dart:convert';

import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';

class PosPromotionMatchItem {
  const PosPromotionMatchItem({
    required this.productRemoteId,
    required this.productName,
    required this.categoryRemoteId,
    required this.brandRemoteId,
    required this.activeUnitPrice,
    required this.quantity,
  });

  final String productRemoteId;
  final String productName;
  final String? categoryRemoteId;
  final String? brandRemoteId;
  final int activeUnitPrice;
  final int quantity;
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
  });

  final String remoteId;
  final String name;
  final String promoType;
  final int discountAmount;
  final String displayAmount;
  final int matchedTotal;
  final String summary;
  final int? totalBundlePrice;
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
      where: 'tenant_id = ? AND deleted_at IS NULL AND status = ?',
      whereArgs: <Object?>[session.tenantId, '1'],
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

      final result = switch (promoType) {
        'bundling' => _evaluateBundling(decoded, items),
        'discount' => _evaluateDiscount(decoded, items),
        _ => null,
      };

      if (result != null) {
        results.add(result);
      } else {
        results.add(
          PosPromotionResult(
            remoteId: remoteId,
            name: promoName,
            promoType: promoType,
            discountAmount: 0,
            displayAmount: '0',
            matchedTotal: 0,
            summary: 'PROMO_NOT_APPLICABLE',
          ),
        );
      }
    }

    return results;
  }

  PosPromotionResult? _evaluateBundling(
    Map<String, dynamic> promotion,
    List<PosPromotionMatchItem> items,
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
    );
  }

  PosPromotionResult? _evaluateDiscount(
    Map<String, dynamic> promotion,
    List<PosPromotionMatchItem> items,
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
      final targetItemId = rule['item_id']?.toString();
      if (targetItemId == null || targetItemId.isEmpty) {
        continue;
      }
      final discountType = rule['discount_type']?.toString() ?? '';
      final discountValue =
          int.tryParse(
            (rule['discount_value'] ?? rule['discount'] ?? '0').toString(),
          ) ??
          0;
      final matchedItems = items
          .where((item) => item.productRemoteId == targetItemId)
          .toList(growable: false);
      if (matchedItems.isEmpty) {
        continue;
      }

      for (final item in matchedItems) {
        final currentLineTotal = item.activeUnitPrice * item.quantity;
        final discountPerUnit = switch (discountType) {
          'final_price' => (item.activeUnitPrice - discountValue).clamp(
            0,
            item.activeUnitPrice,
          ),
          'percent' => ((item.activeUnitPrice * discountValue) / 100).round(),
          'nominal' ||
          'fixed_amount' => discountValue.clamp(0, item.activeUnitPrice),
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
    );
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
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
