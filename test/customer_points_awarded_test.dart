import 'package:flutter_test/flutter_test.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/sales_order_store.dart';

void main() {
  group('SalesOrderStore.calculateAwardedPoints', () {
    test('returns 0 for walk-in customer with remoteId 1', () {
      final points = SalesOrderStore.calculateAwardedPoints(
        customerRemoteId: '1',
        customerName: 'General Customer',
        subtotalAmount: 50000,
        totalDiscountAmount: 0,
      );
      expect(points, 0);
    });

    test('returns 0 for customer name containing walk-in or pelanggan umum', () {
      final pointsWalkIn = SalesOrderStore.calculateAwardedPoints(
        customerRemoteId: '99',
        customerName: 'Walk-In Guest',
        subtotalAmount: 100000,
        totalDiscountAmount: 0,
      );
      expect(pointsWalkIn, 0);

      final pointsUmum = SalesOrderStore.calculateAwardedPoints(
        customerRemoteId: '100',
        customerName: 'Pelanggan Umum Meja 3',
        subtotalAmount: 100000,
        totalDiscountAmount: 0,
      );
      expect(pointsUmum, 0);
    });

    test('calculates 1 point per Rp 10.000 net sales (subtotal - discount)', () {
      // 50.000 net sales => 5 points
      final points50k = SalesOrderStore.calculateAwardedPoints(
        customerRemoteId: '42',
        customerName: 'Budi Santoso',
        subtotalAmount: 50000,
        totalDiscountAmount: 0,
      );
      expect(points50k, 5);

      // 75.000 subtotal - 10.000 discount = 65.000 net => 6 points
      final pointsDiscounted = SalesOrderStore.calculateAwardedPoints(
        customerRemoteId: '42',
        customerName: 'Budi Santoso',
        subtotalAmount: 75000,
        totalDiscountAmount: 10000,
      );
      expect(pointsDiscounted, 6);

      // 9.999 net sales => 0 points
      final pointsUnder10k = SalesOrderStore.calculateAwardedPoints(
        customerRemoteId: '42',
        customerName: 'Budi Santoso',
        subtotalAmount: 9999,
        totalDiscountAmount: 0,
      );
      expect(pointsUnder10k, 0);
    });

    test('clamps negative net sales to 0', () {
      final pointsNegative = SalesOrderStore.calculateAwardedPoints(
        customerRemoteId: '42',
        customerName: 'Budi Santoso',
        subtotalAmount: 10000,
        totalDiscountAmount: 20000,
      );
      expect(pointsNegative, 0);
    });
  });
}
