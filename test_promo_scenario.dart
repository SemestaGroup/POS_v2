import 'dart:convert';
import 'lib/modules/sales/shared/models/pos_promotion_service.dart';

void main() {
  final items = [
    PosPromotionMatchItem(
      refId: 'item1',
      productRemoteId: 'PROD1',
      productName: 'Product 1',
      categoryRemoteId: null,
      brandRemoteId: null,
      activeUnitPrice: 10000,
      quantity: 4,
    )
  ];

  final promos = [
    PosPromotionResult(
      remoteId: 'PROMO_A',
      name: 'Promo A',
      promoType: 'discount',
      discountAmount: 1000,
      displayAmount: '1000',
      matchedTotal: 10000,
      summary: '',
      isMultiplied: true,
      rawPayload: {
        'items': {
          'detail': [
            {
              'target_id': 'PROD1',
              'discount_type': 'nominal',
              'discount_value': 1000
            }
          ]
        }
      }
    ),
    PosPromotionResult(
      remoteId: 'PROMO_B',
      name: 'Promo B',
      promoType: 'discount',
      discountAmount: 2000,
      displayAmount: '2000',
      matchedTotal: 10000,
      summary: '',
      isMultiplied: true,
      rawPayload: {
        'items': {
          'detail': [
            {
              'target_id': 'PROD1',
              'discount_type': 'nominal',
              'discount_value': 2000
            }
          ]
        }
      }
    )
  ];

  final alloc = PosPromotionService.instance.allocatePromotions(
    items: items,
    selectedPromotions: promos
  );

  for (final item in alloc.allocatedItems) {
    print('Allocated: ${item.quantity}x ${item.productName} -> ${item.appliedPromoName}');
  }
}
