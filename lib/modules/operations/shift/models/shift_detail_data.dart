class ShiftDetailPaymentMode {
  final String name;
  final int qty;
  final int amount;

  const ShiftDetailPaymentMode({
    required this.name,
    required this.qty,
    required this.amount,
  });
}

class ShiftDetailItemSold {
  final String name;
  final double qty;

  const ShiftDetailItemSold({
    required this.name,
    required this.qty,
  });
}

class ShiftDetailData {
  final int totalRevenue;
  final int totalTransactions;
  final int grossSales;
  final int totalDiscount;
  final int totalTax;
  final int totalServiceCharge;
  final int totalCashIn;
  final int totalCashOut;
  final List<ShiftDetailPaymentMode> payments;
  final List<ShiftDetailItemSold> topItems;

  const ShiftDetailData({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.grossSales,
    required this.totalDiscount,
    required this.totalTax,
    required this.totalServiceCharge,
    required this.totalCashIn,
    required this.totalCashOut,
    required this.payments,
    required this.topItems,
  });
}
