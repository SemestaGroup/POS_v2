import 'dart:convert';

class EodReportTotals {
  const EodReportTotals({
    required this.grossSales,
    required this.totalDiscount,
    required this.netSales,
    required this.totalTax,
  });

  final int grossSales;
  final int totalDiscount;
  final int netSales;
  final int totalTax;

  Map<String, int> toJson() => <String, int>{
    'gross_sales': grossSales,
    'total_discount': totalDiscount,
    'net_sales': netSales,
    'total_tax': totalTax,
  };

  static EodReportTotals? fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('gross_sales') ||
        !json.containsKey('total_discount') ||
        !json.containsKey('net_sales') ||
        !json.containsKey('total_tax')) {
      return null;
    }
    return EodReportTotals(
      grossSales: ShiftReportCalculations.asInt(json['gross_sales']),
      totalDiscount: ShiftReportCalculations.asInt(json['total_discount']),
      netSales: ShiftReportCalculations.asInt(json['net_sales']),
      totalTax: ShiftReportCalculations.asInt(json['total_tax']),
    );
  }
}

abstract final class ShiftReportCalculations {
  static int expectedCash({
    required int openingBalance,
    required int cashIn,
    required int cashOut,
    required int cashSales,
  }) => openingBalance + cashIn - cashOut + cashSales;

  static int cashVariance({
    required int actualCash,
    required int expectedCash,
  }) => actualCash - expectedCash;

  static int asInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString().split('.').first) ?? 0;
  }

  static int effectiveDiscount(Map<String, dynamic> order) {
    final totalDiscount = asInt(order['discount_total_amount']);
    return totalDiscount > 0
        ? totalDiscount
        : asInt(order['manual_discount_value']);
  }

  static int totalTaxFromOrderRows(List<Map<String, dynamic>> orderRows) {
    var totalTax = 0;
    for (final row in orderRows) {
      var rowTax = 0;
      final customFields = row['custom_fields_json']?.toString();
      if (customFields != null && customFields.isNotEmpty) {
        try {
          final decoded = jsonDecode(customFields);
          if (decoded is Map<String, dynamic>) {
            rowTax = asInt(decoded['tax_amount']);
          }
        } on FormatException {
          // Legacy or malformed custom fields have no authoritative tax.
        }
      }
      if (rowTax == 0) {
        final netBeforeTax =
            (asInt(row['subtotal_amount']) - effectiveDiscount(row)).clamp(
              0,
              1 << 31,
            );
        final inferredTax = asInt(row['total_amount']) - netBeforeTax;
        if (inferredTax > 0) {
          rowTax = inferredTax;
        }
      }
      totalTax += rowTax;
    }
    return totalTax;
  }

  static EodReportTotals totalsFromOrderRows(
    List<Map<String, dynamic>> orderRows,
  ) {
    return EodReportTotals(
      grossSales: orderRows.fold<int>(
        0,
        (sum, row) => sum + asInt(row['subtotal_amount']),
      ),
      totalDiscount: orderRows.fold<int>(
        0,
        (sum, row) => sum + effectiveDiscount(row),
      ),
      netSales: orderRows.fold<int>(
        0,
        (sum, row) => sum + asInt(row['total_amount']),
      ),
      totalTax: totalTaxFromOrderRows(orderRows),
    );
  }

  static bool isCashPaymentName(String? paymentName) {
    final normalized = paymentName?.trim().toLowerCase() ?? '';
    return normalized.contains('cash') || normalized.contains('tunai');
  }
}
