import 'dart:convert';
import 'package:intl/intl.dart';

import '../../../../../../core/printing/models/printer_render_models.dart';
import '../../../../../../core/services/local/database_service.dart';
import 'shift_history_service.dart';
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
    final actualCash = _asInt(shift['actual_cash']);
    // A synced history may retain only the remote shift ID (or neither local
    // relation), while its orders are still correctly dated.  Reuse the exact
    // resolver used by the history card and its detail modal so a reprint does
    // not silently become an empty report on those devices.
    final detail = await ShiftHistoryService.instance.fetchShiftDetailData(
      shiftId: shiftSessionId,
      openedAt: openedAt ?? DateTime.now(),
      closedAt: closedAt,
      tenantId: tenantId,
    );
    final cashIn = detail.totalCashIn;
    final cashOut = detail.totalCashOut;
    final cashSales = detail.cashSales;
    final expectedCash = ShiftReportCalculations.expectedCash(
      openingBalance: openingBalance,
      cashIn: cashIn,
      cashOut: cashOut,
      cashSales: cashSales,
    );
    final variance = ShiftReportCalculations.cashVariance(
      actualCash: actualCash,
      expectedCash: expectedCash,
    );
    final grossSales = detail.grossSales;
    final totalDiscount = detail.totalDiscount;
    final netSales = detail.totalRevenue;
    final totalTax = detail.totalTax;

    final startStr = _formatSqlDate(openedAt ?? DateTime.now());
    final endStr = _formatSqlDate(closedAt);
    final remoteShiftId = shift['remote_id']?.toString().trim();

    // Voids/Refunds
    final refundRows = await db.rawQuery(
      '''
      SELECT SUM(total_amount) as total_void 
      FROM pos_order 
      WHERE (tenant_id = ? OR tenant_id IS NULL OR tenant_id = 0)
        AND deleted_at IS NOT NULL AND deleted_at != '' AND deleted_at != '0'
        AND (
          shift_session_id = ?
          OR CAST(shift_session_id AS TEXT) = ?
          OR (? IS NOT NULL AND shift_session_remote_id = ?)
          OR (
            (CASE WHEN length(trim(substr(replace(COALESCE(NULLIF(order_date, ''), NULLIF(created_at, ''), ''), 'T', ' '), 1, 19))) <= 10
                  THEN trim(substr(replace(COALESCE(NULLIF(order_date, ''), NULLIF(created_at, ''), ''), 'T', ' '), 1, 10)) || ' 00:00:00'
                  ELSE substr(replace(COALESCE(NULLIF(order_date, ''), NULLIF(created_at, ''), ''), 'T', ' '), 1, 19) END) >= ?
            AND
            (CASE WHEN length(trim(substr(replace(COALESCE(NULLIF(order_date, ''), NULLIF(created_at, ''), ''), 'T', ' '), 1, 19))) <= 10
                  THEN trim(substr(replace(COALESCE(NULLIF(order_date, ''), NULLIF(created_at, ''), ''), 'T', ' '), 1, 10)) || ' 23:59:59'
                  ELSE substr(replace(COALESCE(NULLIF(order_date, ''), NULLIF(created_at, ''), ''), 'T', ' '), 1, 19) END) <= ?
          )
        )
    ''',
      <Object?>[
        tenantId,
        shiftSessionId,
        shiftSessionId.toString(),
        remoteShiftId,
        remoteShiftId,
        startStr,
        endStr,
      ],
    );
    final totalVoid = refundRows.isNotEmpty
        ? _asInt(refundRows.first['total_void'])
        : 0;

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

    final storedExpectedCash = _asInt(shift['expected_cash']);
    if (storedExpectedCash > 0 && storedExpectedCash != expectedCash) {
      summaryRows.add(
        PrinterSummaryRow(
          label: 'Expected tersimpan',
          value: currencyFmt.format(storedExpectedCash),
        ),
      );
    }

    final items = <PrinterLineItem>[];

    if (detail.payments.isNotEmpty) {
      items.add(
        const PrinterLineItem(
          label: 'METODE PEMBAYARAN',
          quantity: 0,
          amount: null,
        ),
      );
      for (final payment in detail.payments) {
        final name = payment.name.trim();
        final displayName = name.isNotEmpty ? name : 'Tunai/Kas';
        items.add(
          PrinterLineItem(
            label: displayName,
            quantity: payment.qty,
            amount: payment.amount,
            note: ' ',
          ),
        );
      }
    }

    if (detail.topItems.isNotEmpty) {
      items.add(
        const PrinterLineItem(label: 'ITEM TERJUAL', quantity: 0, amount: null),
      );
      for (final item in detail.topItems) {
        final qty = item.qty.round();
        items.add(
          PrinterLineItem(
            label: item.name,
            quantity: qty > 0 ? qty : 1,
            amount: null,
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
      WHERE (tenant_id = ? OR tenant_id IS NULL)
        AND type IN ('out', 'cash_out')
        AND deleted_at IS NULL
        AND (
          shift_session_id = ?
          OR (
            shift_session_id IS NULL
            AND substr(replace(created_at, 'T', ' '), 1, 19) >= ?
            AND substr(replace(created_at, 'T', ' '), 1, 19) <= ?
          )
        )
    ''',
      <Object?>[tenantId, shiftSessionId, startStr, endStr],
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

  String _formatSqlDate(DateTime? value) {
    if (value == null) return '9999-12-31 23:59:59';
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
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
