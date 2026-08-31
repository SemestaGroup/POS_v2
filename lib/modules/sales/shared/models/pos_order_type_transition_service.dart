import 'order_type_resolver.dart';
import 'pos_order_type.dart';
import 'pos_order_type_pricing_service.dart';
import 'pos_promotion_service.dart';

export 'pos_cart_item.dart';

class PosOrderTypeTransitionResult {
  const PosOrderTypeTransitionResult({
    required this.orderType,
    required this.items,
    required this.validPromotions,
    this.totalDiscountAmount = 0,
    this.appliedOrderPromoLabel,
    required this.isChanged,
  });

  final String orderType;
  final List<PosCartItem> items;
  final List<PosPromotionResult> validPromotions;
  final int totalDiscountAmount;
  final String? appliedOrderPromoLabel;
  final bool isChanged;
}

class PosOrderTypeTransitionService {
  const PosOrderTypeTransitionService._();

  /// Orchestrates order type reconciliation or change for standard [PosCartItem] list.
  /// 1. Reconciles [targetOrderType] against active master [activeOrderTypes].
  /// 2. If order type changed from [currentOrderType]:
  ///    - Reprices cart items according to catalog for the resolved order type (and drops forbidden items).
  ///    - Validates [currentPromotions] against new order type and repriced items.
  ///    - Recalculates promotions on the repriced cart.
  /// 3. Returns a [PosOrderTypeTransitionResult].
  static Future<PosOrderTypeTransitionResult> transitionPosCartOrderType({
    required String currentOrderType,
    String? targetOrderType,
    required List<PosCartItem> currentItems,
    required List<PosPromotionResult> currentPromotions,
    required List<Map<String, dynamic>> catalogProducts,
    required List<PosOrderType> activeOrderTypes,
    PosPromotionService? promotionService,
  }) async {
    final promoService = promotionService ?? PosPromotionService.instance;
    final resolvedType = OrderTypeResolver.reconcileSelected(
      currentSelected: targetOrderType ?? currentOrderType,
      activeTypes: activeOrderTypes,
    );

    if (resolvedType == currentOrderType) {
      return PosOrderTypeTransitionResult(
        orderType: currentOrderType,
        items: currentItems,
        validPromotions: currentPromotions,
        isChanged: false,
      );
    }

    final repricedItems = PosOrderTypePricingService.repricePosCartItems(
      items: currentItems,
      orderType: resolvedType,
      catalogProducts: catalogProducts,
    );

    var validPromos = currentPromotions;
    if (currentPromotions.isNotEmpty) {
      final matchItems = PosPromotionService.buildPosCartMatchItems(
        items: repricedItems,
        catalogProducts: catalogProducts,
      );
      validPromos = await promoService.validateSelectedPromotions(
        currentSelection: currentPromotions,
        items: matchItems,
        orderTypeCode: resolvedType,
      );
    }

    final promoResult = promoService.recalculatePosCartPromotions(
      cartItems: repricedItems,
      selectedPromotions: validPromos,
      catalogProducts: catalogProducts,
      selectedOrderType: resolvedType,
    );

    return PosOrderTypeTransitionResult(
      orderType: resolvedType,
      items: promoResult.items,
      validPromotions: validPromos,
      totalDiscountAmount: promoResult.totalDiscountAmount,
      appliedOrderPromoLabel: promoResult.appliedOrderPromoLabel,
      isChanged: true,
    );
  }
}
