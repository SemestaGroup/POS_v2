import 'pos_cart_item.dart';

/// Single source of truth for subtotal/discount/tax/total math shared by the
/// tablet and mobile POS workspace screens.
///
/// Before this existed, both screens carried their own copy-pasted set of
/// getters for these exact figures. That drift is how a real bug shipped:
/// the tablet screen was missing a subtotal clamp on manual discounts that
/// the mobile screen already had. Route both screens through this class so a
/// fix in one place can no longer silently miss the other.
class PosCartTotals {
  const PosCartTotals({
    required this.subtotalAmount,
    required this.itemDiscountAmount,
    required this.orderLevelDiscountAmount,
    required this.autoTaxEnabled,
    required this.taxPercentage,
  });

  factory PosCartTotals.fromCart({
    required List<PosCartItem> items,
    required int orderLevelDiscountAmount,
    required bool autoTaxEnabled,
    required double taxPercentage,
  }) {
    return PosCartTotals(
      subtotalAmount: subtotalOf(items),
      itemDiscountAmount: itemDiscountOf(items),
      orderLevelDiscountAmount: orderLevelDiscountAmount,
      autoTaxEnabled: autoTaxEnabled,
      taxPercentage: taxPercentage,
    );
  }

  final int subtotalAmount;
  final int itemDiscountAmount;
  final int orderLevelDiscountAmount;
  final bool autoTaxEnabled;
  final double taxPercentage;

  int get totalDiscountAmount => itemDiscountAmount + orderLevelDiscountAmount;

  int get netAmount =>
      (subtotalAmount - totalDiscountAmount).clamp(0, 1 << 31);

  int get taxAmount {
    if (!autoTaxEnabled || taxPercentage <= 0) return 0;
    return (netAmount * (taxPercentage / 100)).round();
  }

  int get totalPay => netAmount + taxAmount;

  /// Caps a manual nominal discount so it can never exceed [subtotalAmount]
  /// — without this, a mistyped amount can persist a discount larger than
  /// the order itself even though the displayed total floors at zero.
  int clampManualDiscount(int rawAmount) =>
      rawAmount.clamp(0, subtotalAmount);

  static int subtotalOf(List<PosCartItem> items) => items.fold<int>(
    0,
    (sum, item) => sum + (item.regularUnitPrice * item.quantity),
  );

  static int itemDiscountOf(List<PosCartItem> items) => items.fold<int>(
    0,
    (sum, item) =>
        sum +
        ((item.regularUnitPrice - item.activeUnitPrice).clamp(0, 1 << 31) *
            item.quantity),
  );
}
