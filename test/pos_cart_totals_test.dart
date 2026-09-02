import 'package:flinkpos_v2/modules/sales/shared/models/pos_cart_item.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_cart_totals.dart';
import 'package:flutter_test/flutter_test.dart';

PosCartItem _item({
  required int regularUnitPrice,
  required int quantity,
  int? discountedUnitPrice,
  bool isDiscountEnabled = false,
}) {
  return PosCartItem(
    id: 'item-$regularUnitPrice-$quantity',
    name: 'Item',
    displayName: 'Item',
    imageUrl: '',
    regularUnitPrice: regularUnitPrice,
    quantity: quantity,
    discountedUnitPrice: discountedUnitPrice,
    isDiscountEnabled: isDiscountEnabled,
  );
}

void main() {
  group('PosCartTotals', () {
    test('computes subtotal, tax, and total with no discount', () {
      final totals = PosCartTotals.fromCart(
        items: [_item(regularUnitPrice: 35000, quantity: 2)],
        orderLevelDiscountAmount: 0,
        autoTaxEnabled: true,
        taxPercentage: 11,
      );

      expect(totals.subtotalAmount, 70000);
      expect(totals.itemDiscountAmount, 0);
      expect(totals.totalDiscountAmount, 0);
      expect(totals.netAmount, 70000);
      expect(totals.taxAmount, 7700);
      expect(totals.totalPay, 77700);
    });

    test('sums per-item discount from discountedUnitPrice', () {
      final totals = PosCartTotals.fromCart(
        items: [
          _item(
            regularUnitPrice: 20000,
            quantity: 3,
            discountedUnitPrice: 15000,
            isDiscountEnabled: true,
          ),
        ],
        orderLevelDiscountAmount: 0,
        autoTaxEnabled: false,
        taxPercentage: 0,
      );

      expect(totals.subtotalAmount, 60000);
      expect(totals.itemDiscountAmount, 15000);
      expect(totals.netAmount, 45000);
      expect(totals.taxAmount, 0);
      expect(totals.totalPay, 45000);
    });

    test('combines item discount and order-level manual discount', () {
      final totals = PosCartTotals.fromCart(
        items: [
          _item(
            regularUnitPrice: 20000,
            quantity: 1,
            discountedUnitPrice: 18000,
            isDiscountEnabled: true,
          ),
        ],
        orderLevelDiscountAmount: 5000,
        autoTaxEnabled: false,
        taxPercentage: 0,
      );

      expect(totals.itemDiscountAmount, 2000);
      expect(totals.totalDiscountAmount, 7000);
      expect(totals.netAmount, 13000);
    });

    test('never lets net amount go negative when discounts exceed subtotal', () {
      final totals = PosCartTotals.fromCart(
        items: [_item(regularUnitPrice: 20000, quantity: 1)],
        orderLevelDiscountAmount: 999999,
        autoTaxEnabled: true,
        taxPercentage: 11,
      );

      expect(totals.netAmount, 0);
      expect(totals.taxAmount, 0);
      expect(totals.totalPay, 0);
    });

    test('tax is skipped when auto-tax is disabled even with a positive rate', () {
      final totals = PosCartTotals.fromCart(
        items: [_item(regularUnitPrice: 10000, quantity: 1)],
        orderLevelDiscountAmount: 0,
        autoTaxEnabled: false,
        taxPercentage: 11,
      );

      expect(totals.taxAmount, 0);
      expect(totals.totalPay, 10000);
    });

    group('clampManualDiscount', () {
      test('caps a nominal discount at the subtotal', () {
        final totals = PosCartTotals.fromCart(
          items: [_item(regularUnitPrice: 35000, quantity: 1)],
          orderLevelDiscountAmount: 0,
          autoTaxEnabled: false,
          taxPercentage: 0,
        );

        // Regression check for the real bug: typing a nominal discount
        // larger than the subtotal used to be stored as-is on the tablet
        // POS workspace instead of being capped like the mobile one.
        expect(totals.clampManualDiscount(58888), 35000);
      });

      test('leaves a discount within the subtotal untouched', () {
        final totals = PosCartTotals.fromCart(
          items: [_item(regularUnitPrice: 35000, quantity: 1)],
          orderLevelDiscountAmount: 0,
          autoTaxEnabled: false,
          taxPercentage: 0,
        );

        expect(totals.clampManualDiscount(10000), 10000);
      });

      test('floors a negative input at zero', () {
        final totals = PosCartTotals.fromCart(
          items: [_item(regularUnitPrice: 35000, quantity: 1)],
          orderLevelDiscountAmount: 0,
          autoTaxEnabled: false,
          taxPercentage: 0,
        );

        expect(totals.clampManualDiscount(-500), 0);
      });
    });
  });
}
