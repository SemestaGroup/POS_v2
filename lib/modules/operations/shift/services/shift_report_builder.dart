import 'dart:convert';
import 'package:intl/intl.dart';

import '../../../../../../core/printing/models/printer_render_models.dart';
import '../../../../../../core/services/local/database_service.dart';
import 'shift_report_calculations.dart';

class ShiftReportBuilder {
  ShiftReportBuilder._();
  static final instance = ShiftReportBuilder._();

  Future<PrinterDocumentData?> buildReport({
    required int tenantId,
    required int shiftSessionId,
    required bool isEod,
  }) async {
    final db = DatabaseService.instance;
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final dateFmt = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

    // 1. Fetch Shift Info
    final shiftRows = await db.rawQuery(
      'SELECT * FROM shift_session WHERE id = ? AND tenant_id = ? LIMIT 1',
      <Object?>[shiftSessionId, tenantId],
    );
    if (shiftRows.isEmpty) return null;

    final shift = shiftRows.first;
    final shiftName = shift['shift_name']?.toString() ?? '—';
    final staffName = shift['pos_staff_name_snapshot']?.toString() ?? '—';
    final openedAtRaw = shift['opened_at']?.toString();
    final closedAtRaw = shift['closed_at']?.toString();

    DateTime? openedAt = openedAtRaw != null
        ? DateTime.tryParse(openedAtRaw.replaceFirst(' ', 'T'))
        : null;
    DateTime? closedAt = closedAtRaw != null && closedAtRaw.isNotEmpty
        ? DateTime.tryParse(closedAtRaw.replaceFirst(' ', 'T'))
        : null;

    final openingBalance = _asInt(shift['opening_balance']);
    final expectedCash = _asInt(shift['expected_cash']);
    final actualCash = _asInt(shift['actual_cash']);
    final variance = actualCash - expectedCash;

    // 2. Fetch Cash In/Out
    final cashFlowRows = await db.rawQuery(
      'SELECT type, SUM(amount) as total FROM pos_cash_flow WHERE tenant_id = ? AND shift_session_id = ? AND deleted_at IS NULL GROUP BY type',
      <Object?>[tenantId, shiftSessionId],
    );
    int cashIn = 0;
    int cashOut = 0;
    for (final row in cashFlowRows) {
      if (row['type'] == 'cash_in') cashIn = _asInt(row['total']);
      if (row['type'] == 'cash_out') cashOut = _asInt(row['total']);
    }

    // 3. Fetch Sales Metrics
    // Gross sales, Discounts, Voids/Refunds, Net Sales
    final orderRows = await db.rawQuery(
      '''
      SELECT
        SUM(subtotal_amount) as gross_sales,
        SUM(COALESCE(NULLIF(discount_total_amount, 0), manual_discount_value, 0)) as total_discount,
        SUM(total_amount) as net_sales
      FROM pos_order
      WHERE tenant_id = ? AND shift_session_id = ? AND status_code IN ('2', '4') AND deleted_at IS NULL
    ''',
      <Object?>[tenantId, shiftSessionId],
    );

    final orderSummary = orderRows.isNotEmpty ? orderRows.first : {};
    final grossSales = _asInt(orderSummary['gross_sales']);
    final totalDiscount = _asInt(orderSummary['total_discount']);
    final netSales = _asInt(orderSummary['net_sales']);

    // Voids/Refunds
    final refundRows = await db.rawQuery(
      '''
      SELECT SUM(total_amount) as total_void 
      FROM pos_order 
      WHERE tenant_id = ? AND shift_session_id = ? AND deleted_at IS NOT NULL
    ''',
      <Object?>[tenantId, shiftSessionId],
    );
    final totalVoid = refundRows.isNotEmpty
        ? _asInt(refundRows.first['total_void'])
        : 0;

    // Cash Sales
    final cashPaymentRows = await db.rawQuery(
      '''
      SELECT
        COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), 'Tunai/Kas') as name,
        SUM(p.amount) as total
      FROM pos_order_payment p
      JOIN pos_order o ON p.order_id = o.id
      LEFT JOIN payment_mode pm ON pm.remote_id = p.payment_mode_remote_id AND pm.tenant_id = p.tenant_id
      WHERE p.tenant_id = ? AND o.shift_session_id = ? 
        AND o.status_code IN ('2', '4')
        AND p.deleted_at IS NULL
      GROUP BY COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), 'Tunai/Kas')
    ''',
      <Object?>[tenantId, shiftSessionId],
    );
    final cashSales = cashPaymentRows
        .where(
          (row) => ShiftReportCalculations.isCashPaymentName(
            row['name']?.toString(),
          ),
        )
        .fold<int>(0, (sum, row) => sum + _asInt(row['total']));

    // Tax calculation
    final orderTaxRows = await db.rawQuery(
      '''
      SELECT total_amount, subtotal_amount, discount_total_amount, manual_discount_value, custom_fields_json
      FROM pos_order
      WHERE tenant_id = ? AND shift_session_id = ?
        AND status_code IN ('2', '4')
        AND deleted_at IS NULL
    ''',
      <Object?>[tenantId, shiftSessionId],
    );
    final totalTax = ShiftReportCalculations.totalTaxFromOrderRows(
      orderTaxRows,
    );
    final infoRows = <PrinterInfoRow>[
      PrinterInfoRow(label: 'Shift', value: shiftName),
      PrinterInfoRow(label: 'Kasir', value: staffName),
      if (openedAt != null)
        PrinterInfoRow(label: 'Buka', value: dateFmt.format(openedAt)),
      if (closedAt != null)
        PrinterInfoRow(label: 'Tutup', value: dateFmt.format(closedAt)),
    ];

    final summaryRows = <PrinterSummaryRow>[
      PrinterSummaryRow(
        label: 'Saldo Awal',
        value: currencyFmt.format(openingBalance),
      ),
      PrinterSummaryRow(label: 'Kas Masuk', value: currencyFmt.format(cashIn)),
      PrinterSummaryRow(
        label: 'Kas Keluar',
        value: currencyFmt.format(cashOut),
      ),
      PrinterSummaryRow(
        label: 'Penjualan Tunai',
        value: currencyFmt.format(cashSales),
      ),
      PrinterSummaryRow(
        label: 'Sistem (Expected)',
        value: currencyFmt.format(expectedCash),
      ),
      PrinterSummaryRow(
        label: 'Fisik (Actual)',
        value: currencyFmt.format(actualCash),
      ),
      PrinterSummaryRow(
        label: 'Total Pajak',
        value: currencyFmt.format(totalTax),
      ),
      PrinterSummaryRow(
        label: 'Selisih',
        value: currencyFmt.format(variance),
        highlighted: variance != 0,
      ),
    ];

    final items = <PrinterLineItem>[];

    // 4. Fetch Payment Methods Breakdown
    final paymentBreakdown = await db.rawQuery(
      '''
      SELECT
        COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), 'Tunai/Kas') as name,
        SUM(p.amount) as total,
        COUNT(p.id) as qty
      FROM pos_order_payment p
      JOIN pos_order o ON p.order_id = o.id
      LEFT JOIN payment_mode pm ON pm.remote_id = p.payment_mode_remote_id AND pm.tenant_id = p.tenant_id
      WHERE p.tenant_id = ? AND o.shift_session_id = ?
        AND o.status_code IN ('2', '4')
        AND p.deleted_at IS NULL
      GROUP BY COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), 'Tunai/Kas')
    ''',
      <Object?>[tenantId, shiftSessionId],
    );

    if (paymentBreakdown.isNotEmpty) {
      items.add(
        const PrinterLineItem(
          label: 'METODE PEMBAYARAN',
          quantity: 0,
          amount: null,
        ),
      );
      for (final row in paymentBreakdown) {
        final name = (row['name']?.toString() ?? '').trim();
        final displayName = name.isNotEmpty ? name : 'Tunai/Kas';
        final total = _asInt(row['total']);
        final qty = _asDouble(row['qty']).round();
        items.add(
          PrinterLineItem(
            label: displayName,
            quantity: qty,
            amount: total,
            note: ' ',
          ),
        );
      }
    }

    // 5. Fetch Items Breakdown (Products)
    final itemsBreakdown = await db.rawQuery(
      '''
      SELECT i.product_name_snapshot as name, SUM(i.qty) as qty, SUM(i.line_subtotal_amount) as total
      FROM pos_order_item i
      JOIN pos_order o ON i.order_id = o.id
      WHERE i.tenant_id = ? AND o.shift_session_id = ?
        AND o.status_code IN ('2', '4')
        AND i.deleted_at IS NULL
      GROUP BY i.product_name_snapshot
    ''',
      <Object?>[tenantId, shiftSessionId],
    );

    if (itemsBreakdown.isNotEmpty) {
      items.add(
        const PrinterLineItem(label: 'ITEM TERJUAL', quantity: 0, amount: null),
      );
      for (final row in itemsBreakdown) {
        final name = row['name']?.toString() ?? 'Produk';
        final qty = _asDouble(row['qty']).round();
        final total = _asInt(row['total']);
        items.add(
          PrinterLineItem(
            label: name,
            quantity: qty > 0 ? qty : 1,
            amount: total > 0 ? total : null,
            note: ' ',
          ),
        );
      }
    }

    // 6. Fetch Cash Out details
    final cashOutRows = await db.rawQuery(
      '''
      SELECT note, amount 
      FROM pos_cash_flow 
      WHERE tenant_id = ? AND shift_session_id = ? AND type = 'cash_out' AND deleted_at IS NULL
    ''',
      <Object?>[tenantId, shiftSessionId],
    );

    if (cashOutRows.isNotEmpty) {
      items.add(
        const PrinterLineItem(label: 'PENGELUARAN', quantity: 0, amount: null),
      );
      for (final row in cashOutRows) {
        final note = row['note']?.toString() ?? 'Kas Keluar';
        final amount = _asInt(row['amount']);
        items.add(
          PrinterLineItem(label: note, quantity: 0, amount: amount, note: ' '),
        );
      }
    }
    // Insert Sales Summary at the top of summary
    summaryRows.insert(
      0,
      PrinterSummaryRow(
        label: 'Net Sales',
        value: currencyFmt.format(netSales),
        highlighted: true,
      ),
    );
    summaryRows.insert(
      0,
      PrinterSummaryRow(
        label: 'Total Void/Refund',
        value: currencyFmt.format(totalVoid),
      ),
    );
    summaryRows.insert(
      0,
      PrinterSummaryRow(
        label: 'Total Diskon',
        value: currencyFmt.format(totalDiscount),
      ),
    );
    summaryRows.insert(
      0,
      PrinterSummaryRow(
        label: 'Gross Sales',
        value: currencyFmt.format(grossSales),
      ),
    );

    return PrinterDocumentData(
      type: PrinterDocumentType.report,
      title: isEod ? 'End of Day (EOD)' : 'Rekapan Shift',
      subtitle: isEod
          ? 'Laporan lengkap penutupan kasir'
          : 'Ringkasan operasional shift',
      infoRows: infoRows,
      items: items,
      summaryRows: summaryRows,
      footerLines: const ['Dicetak dari FlinkPOS V2'],
    );
  }

  int _asInt(Object? value) {
    return ShiftReportCalculations.asInt(value);
  }

  double _asDouble(Object? value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Future<PrinterDocumentData> buildFromEodArchive({
    required dynamic archive,
    required int tenantId,
  }) async {
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final dateFmt = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
    Map<String, dynamic>? summary;
    final rawSummary = archive.summaryJson?.toString();
    if (rawSummary != null && rawSummary.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSummary);
        if (decoded is Map<String, dynamic>) {
          summary = decoded;
        }
      } on FormatException {
        // Old archives with invalid JSON retain their saved top-level totals.
      }
    }
    final archivedTotals = summary == null
        ? null
        : EodReportTotals.fromJson(summary);

    final infoRows = <PrinterInfoRow>[
      PrinterInfoRow(label: 'EOD Code', value: archive.eodCode.toString()),
      PrinterInfoRow(
        label: 'Waktu',
        value: dateFmt.format(archive.createdAt as DateTime),
      ),
    ];

    final archivedShifts = summary?['shifts'];
    if (archivedShifts is List) {
      for (final rawShift in archivedShifts) {
        if (rawShift is Map) {
          _addEodShiftInfo(
            infoRows,
            Map<String, dynamic>.from(rawShift),
            dateFmt,
          );
        }
      }
    } else {
      // Compatibility for reports created before shift details were archived.
      final shiftRows = await DatabaseService.instance.rawQuery(
        'SELECT shift_name, pos_staff_name_snapshot, opened_at, closed_at FROM shift_session WHERE eod_group_id = ? AND tenant_id = ? ORDER BY id ASC',
        <Object?>[archive.eodCode, tenantId],
      );
      for (final shift in shiftRows) {
        _addEodShiftInfo(infoRows, shift, dateFmt);
      }
    }

    final summaryRows = <PrinterSummaryRow>[
      if (archivedTotals != null) ...[
        PrinterSummaryRow(
          label: 'Gross Sales',
          value: currencyFmt.format(archivedTotals.grossSales),
        ),
        PrinterSummaryRow(
          label: 'Total Diskon',
          value: currencyFmt.format(archivedTotals.totalDiscount),
        ),
        PrinterSummaryRow(
          label: 'Net Sales',
          value: currencyFmt.format(archivedTotals.netSales),
        ),
      ],
      PrinterSummaryRow(
        label: 'Total Transaksi',
        value: archive.totalTransactions.toString(),
      ),
      PrinterSummaryRow(
        label: 'Total Revenue',
        value: currencyFmt.format(archive.totalRevenue),
        highlighted: true,
      ),
      if (archivedTotals != null)
        PrinterSummaryRow(
          label: 'Total Pajak',
          value: currencyFmt.format(archivedTotals.totalTax),
        ),
    ];
    final items = <PrinterLineItem>[];

    if (summary != null) {
      _addEodPaymentItems(items, summary['payments']);
      _addEodProductItems(items, summary['items']);
    }

    return PrinterDocumentData(
      type: PrinterDocumentType.report,
      title: 'End of Day (EOD) - Rekap',
      subtitle: 'Arsip Laporan EOD',
      infoRows: infoRows,
      items: items,
      summaryRows: summaryRows,
      footerLines: const ['Dicetak dari FlinkPOS V2'],
    );
  }

  void _addEodShiftInfo(
    List<PrinterInfoRow> infoRows,
    Map<String, dynamic> shift,
    DateFormat dateFmt,
  ) {
    final openedAtRaw = shift['opened_at']?.toString();
    final closedAtRaw = shift['closed_at']?.toString();
    final openedAt = openedAtRaw == null
        ? null
        : DateTime.tryParse(openedAtRaw.replaceFirst(' ', 'T'));
    final closedAt = closedAtRaw == null || closedAtRaw.isEmpty
        ? null
        : DateTime.tryParse(closedAtRaw.replaceFirst(' ', 'T'));
    infoRows.add(const PrinterInfoRow(label: '---', value: ''));
    infoRows.add(
      PrinterInfoRow(
        label: 'Shift',
        value: shift['shift_name']?.toString() ?? '—',
      ),
    );
    infoRows.add(
      PrinterInfoRow(
        label: 'Kasir',
        value: shift['pos_staff_name_snapshot']?.toString() ?? '—',
      ),
    );
    if (openedAt != null) {
      infoRows.add(
        PrinterInfoRow(label: 'Buka', value: dateFmt.format(openedAt)),
      );
    }
    if (closedAt != null) {
      infoRows.add(
        PrinterInfoRow(label: 'Tutup', value: dateFmt.format(closedAt)),
      );
    }
  }

  void _addEodPaymentItems(List<PrinterLineItem> items, Object? rawPayments) {
    if (rawPayments is! List || rawPayments.isEmpty) return;
    items.add(
      const PrinterLineItem(
        label: 'METODE PEMBAYARAN',
        quantity: 0,
        amount: null,
      ),
    );
    for (final rawPayment in rawPayments) {
      if (rawPayment is! Map) continue;
      final payment = Map<String, dynamic>.from(rawPayment);
      items.add(
        PrinterLineItem(
          label:
              '${_asDouble(payment['qty']).round()}x ${payment['name']?.toString() ?? 'Lainnya'}',
          quantity: 0,
          amount: _asInt(payment['amount']),
          note: ' ',
        ),
      );
    }
  }

  void _addEodProductItems(List<PrinterLineItem> items, Object? rawProducts) {
    if (rawProducts is! List || rawProducts.isEmpty) return;
    items.add(
      const PrinterLineItem(label: 'ITEM TERJUAL', quantity: 0, amount: null),
    );
    for (final rawProduct in rawProducts) {
      if (rawProduct is! Map) continue;
      final product = Map<String, dynamic>.from(rawProduct);
      items.add(
        PrinterLineItem(
          label:
              '${_asDouble(product['qty']).round()}x ${product['name']?.toString() ?? 'Produk'}',
          quantity: 0,
          amount: null,
          note: ' ',
        ),
      );
    }
  }
}
