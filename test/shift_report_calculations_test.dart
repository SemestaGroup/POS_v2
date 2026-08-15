import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flinkpos_v2/modules/operations/shift/services/shift_report_builder.dart';
import 'package:flinkpos_v2/modules/operations/shift/services/shift_report_calculations.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_tax_selection_resolver.dart';

class _ArchiveFixture {
  const _ArchiveFixture({
    required this.eodCode,
    required this.createdAt,
    required this.totalTransactions,
    required this.totalRevenue,
    required this.summaryJson,
  });

  final String eodCode;
  final DateTime createdAt;
  final int totalTransactions;
  final int totalRevenue;
  final String summaryJson;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  test('uses a legacy manual discount when total discount is zero', () {
    final totals = ShiftReportCalculations.totalsFromOrderRows(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'subtotal_amount': 100000,
          'discount_total_amount': 0,
          'manual_discount_value': 10000,
          'total_amount': 99000,
          'custom_fields_json': '{"tax_amount":"9000"}',
        },
      ],
    );

    expect(totals.grossSales, 100000);
    expect(totals.totalDiscount, 10000);
    expect(totals.netSales, 99000);
    expect(totals.totalTax, 9000);
  });

  test('infers tax from net total when no custom tax snapshot exists', () {
    final totals = ShiftReportCalculations.totalsFromOrderRows(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'subtotal_amount': 180000,
          'discount_total_amount': 19000,
          'manual_discount_value': 0,
          'total_amount': 177100,
          'custom_fields_json': null,
        },
      ],
    );

    expect(totals.totalTax, 16100);
  });

  test('recognizes cash labels consistently', () {
    expect(ShiftReportCalculations.isCashPaymentName('Cash'), isTrue);
    expect(ShiftReportCalculations.isCashPaymentName('Tunai'), isTrue);
    expect(ShiftReportCalculations.isCashPaymentName('QRIS'), isFalse);
  });

  test('requires all persisted numeric fields for immutable EOD totals', () {
    expect(
      EodReportTotals.fromJson(<String, dynamic>{
        'gross_sales': 100000,
        'total_discount': 10000,
        'net_sales': 99000,
        'total_tax': 9000,
      }),
      isNotNull,
    );
    expect(
      EodReportTotals.fromJson(<String, dynamic>{'gross_sales': 100000}),
      isNull,
    );
  });

  test('disables auto-tax instead of selecting another tax row', () {
    final selection = PosTaxSelectionResolver.fromRows(
      autoTax: true,
      selectedTaxId: 'configured-tax',
      rows: const <Map<String, dynamic>>[],
    );

    expect(selection.isEnabled, isFalse);
    expect(selection.issue, contains('configured-tax'));
  });

  test('renders an EOD archive only from its persisted summary', () async {
    final document = await ShiftReportBuilder.instance.buildFromEodArchive(
      archive: _ArchiveFixture(
        eodCode: 'EOD-001',
        createdAt: DateTime(2026, 8, 13, 10),
        totalTransactions: 1,
        totalRevenue: 99000,
        summaryJson:
            '{"shifts":[],"payments":[],"items":[],"gross_sales":100000,"total_discount":10000,"net_sales":99000,"total_tax":9000}',
      ),
      tenantId: 1,
    );

    expect(
      document.summaryRows.map((row) => row.label),
      containsAll(<String>[
        'Gross Sales',
        'Total Diskon',
        'Net Sales',
        'Total Pajak',
      ]),
    );
  });
}
