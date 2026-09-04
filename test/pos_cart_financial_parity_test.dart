import 'package:flutter_test/flutter_test.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_promotion_service.dart';

void main() {
  group('POS Cart Financial Calculation Parity Tests', () {
    test('Catalog discount only: calculates gross subtotal, item discount, net, and total correctly', () {
      const cartItems = [
        PosCartItem(
          id: '1',
          name: 'Item Diskon Katalog',
          displayName: 'Item Diskon Katalog',
          imageUrl: '',
          productRemoteId: 'p1',
          regularUnitPrice: 50000,
          discountedUnitPrice: 40000,
          isDiscountEnabled: true,
          quantity: 2,
        ),
      ];

      final subtotal = cartItems.fold<int>(0, (sum, i) => sum + (i.regularUnitPrice * i.quantity));
      final itemDiscount = cartItems.fold<int>(0, (sum, i) => sum + ((i.regularUnitPrice - i.activeUnitPrice) * i.quantity));
      const orderDiscount = 0;
      final totalDiscount = itemDiscount + orderDiscount;
      final net = subtotal - totalDiscount;
      final tax = (net * 0.11).round();
      final total = net + tax;

      expect(subtotal, 100000);
      expect(itemDiscount, 20000);
      expect(totalDiscount, 20000);
      expect(net, 80000);
      expect(tax, 8800);
      expect(total, 88800);
    });

    test('Promo bundling only: does NOT double discount in cart math', () {
      final cartItems = [
        const PosCartItem(
          id: '1',
          name: 'Kopi',
          displayName: 'Kopi',
          imageUrl: '',
          productRemoteId: 'p-kopi',
          regularUnitPrice: 20000,
          quantity: 2,
        ),
      ];

      final bundlePromo = PosPromotionResult(
        remoteId: 'promo-bundle',
        name: 'Beli 2 Kopi 30rb',
        promoType: 'bundling',
        discountAmount: 10000,
        displayAmount: 'Rp 30.000',
        matchedTotal: 1,
        summary: 'Bundle 2 for 30000',
        rawPayload: {
          'items': {
            'total_price': '30000',
            'detail': [
              {'qty': '2', 'target_id': 'p-kopi'},
            ],
          },
        },
      );

      final result = PosPromotionService.instance.recalculatePosCartPromotions(
        cartItems: cartItems,
        selectedPromotions: [bundlePromo],
        catalogProducts: [
          {'remoteId': 'p-kopi', 'name': 'Kopi', 'regularPrice': 20000},
        ],
        selectedOrderType: 'dinein',
      );

      final items = result.items;
      final subtotal = items.fold<int>(0, (sum, i) => sum + (i.regularUnitPrice * i.quantity));
      final itemDiscount = items.fold<int>(0, (sum, i) => sum + ((i.regularUnitPrice - i.activeUnitPrice) * i.quantity));
      const orderDiscount = 0; // Promo is handled in items
      final totalDiscount = itemDiscount + orderDiscount;
      final net = subtotal - totalDiscount;

      expect(subtotal, 40000);
      expect(itemDiscount, 10000);
      expect(totalDiscount, 10000);
      expect(net, 30000);
    });

    test('Manual order discount + Promo bundling: stacks cleanly without double deduction', () {
      final cartItems = [
        const PosCartItem(
          id: '1',
          name: 'Kopi',
          displayName: 'Kopi',
          imageUrl: '',
          productRemoteId: 'p-kopi',
          regularUnitPrice: 20000,
          quantity: 2,
        ),
      ];

      final bundlePromo = PosPromotionResult(
        remoteId: 'promo-bundle',
        name: 'Beli 2 Kopi 30rb',
        promoType: 'bundling',
        discountAmount: 10000,
        displayAmount: 'Rp 30.000',
        matchedTotal: 1,
        summary: 'Bundle 2 for 30000',
        rawPayload: {
          'items': {
            'total_price': '30000',
            'detail': [
              {'qty': '2', 'target_id': 'p-kopi'},
            ],
          },
        },
      );

      final result = PosPromotionService.instance.recalculatePosCartPromotions(
        cartItems: cartItems,
        selectedPromotions: [bundlePromo],
        catalogProducts: [
          {'remoteId': 'p-kopi', 'name': 'Kopi', 'regularPrice': 20000},
        ],
        selectedOrderType: 'dinein',
      );

      final items = result.items;
      final subtotal = items.fold<int>(0, (sum, i) => sum + (i.regularUnitPrice * i.quantity));
      final itemDiscount = items.fold<int>(0, (sum, i) => sum + ((i.regularUnitPrice - i.activeUnitPrice) * i.quantity));
      const manualDiscount = 5000; // Manual Rp 5.000
      final totalDiscount = itemDiscount + manualDiscount;
      final net = subtotal - totalDiscount;

      expect(subtotal, 40000);
      expect(itemDiscount, 10000);
      expect(totalDiscount, 15000);
      expect(net, 25000);
    });
  });
}
