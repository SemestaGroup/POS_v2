import 'package:flinkpos_v2/modules/reports/stores/report_read_stores.dart';
import 'package:flinkpos_v2/modules/reports/views/promo_sales_report/promo_sales_report_view.dart';
import 'package:flinkpos_v2/modules/reports/views/top_customers_report/top_customers_report_view.dart';
import 'package:flinkpos_v2/modules/settings/device/views/backup_restore/backup_restore_view.dart';
import 'package:flinkpos_v2/modules/settings/help/views/documentation/documentation_view.dart';
import 'package:flinkpos_v2/modules/settings/store/views/service_tables/service_tables_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _tablet = Size(1280, 800);
const _phone = Size(375, 812);

Future<void> _pump(WidgetTester tester, Size size, Widget view) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  for (final size in [_tablet, _phone]) {
    group('at ${size.width.toInt()}px', () {
      testWidgets('documentation page renders without overflow', (
        tester,
      ) async {
        await _pump(tester, size, const DocumentationView());

        expect(find.text('Tutorial & Dokumentasi'), findsOneWidget);
        expect(find.text('docs.flinkaja.com'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('backup and restore page renders without overflow', (
        tester,
      ) async {
        await _pump(tester, size, const BackupRestoreView());

        expect(find.text('Backup & Restore Data'), findsOneWidget);
        expect(find.text('Bagikan Backup'), findsOneWidget);
        expect(find.text('Pilih File Backup'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('top customers ranks members and leaves walk-in unranked', (
        tester,
      ) async {
        TopCustomersReportStore.instance.snapshotNotifier.value =
            TopCustomersSnapshot(
              isLoading: false,
              period: 'month',
              customers: [
                TopCustomerRecord(
                  key: '55',
                  name: 'Budi',
                  isWalkIn: false,
                  phone: '0811',
                  visitCount: 4,
                  totalSpent: 200000,
                  lastOrderAt: DateTime(2026, 9, 20),
                ),
                TopCustomerRecord(
                  key: '56',
                  name: 'Sari',
                  isWalkIn: false,
                  visitCount: 9,
                  totalSpent: 150000,
                ),
                const TopCustomerRecord(
                  key: TopCustomersReportStore.walkInKey,
                  name: TopCustomersReportStore.walkInName,
                  isWalkIn: true,
                  visitCount: 30,
                  totalSpent: 900000,
                ),
              ],
            );
        await _pump(tester, size, const TopCustomersReportView());

        expect(find.text('Budi'), findsOneWidget);
        expect(find.text('Sari'), findsOneWidget);
        expect(find.text(TopCustomersReportStore.walkInName), findsOneWidget);
        // Walk-in is the biggest spender but must not take rank 1.
        expect(find.text('1'), findsOneWidget);
        // Two matches: the rank badge and the member count in the summary strip.
        expect(find.text('2'), findsNWidgets(2));
        expect(find.text('3'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('promo sales lists promos and opens the drill-down', (
        tester,
      ) async {
        PromoSalesReportStore.instance.snapshotNotifier.value =
            PromoSalesSnapshot(
              isLoading: false,
              period: 'month',
              promoOrderCount: 2,
              totalDiscount: 7000,
              promoNetSales: 50000,
              promos: [
                PromoSalesRecord(
                  key: 'id:7',
                  name: 'Diskon Kemerdekaan',
                  type: 'discount',
                  orders: [
                    PromoSalesOrderRecord(
                      orderId: 1,
                      label: 'INV-000123',
                      orderedAt: DateTime(2026, 9, 20, 10),
                      subtotalAmount: 42000,
                      totalAmount: 40000,
                      discountAmount: 2000,
                    ),
                  ],
                ),
              ],
            );
        await _pump(tester, size, const PromoSalesReportView());

        expect(find.text('Diskon Kemerdekaan'), findsOneWidget);
        expect(find.text('Transaksi Promo'), findsOneWidget);

        await tester.tap(find.text('Diskon Kemerdekaan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('INV-000123'), findsOneWidget);
        expect(find.text('Total Potongan'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('add-table dialog stays usable with the keyboard open', (
    tester,
  ) async {
    // Landscape tablet with roughly half the height taken by the keyboard.
    tester.view.physicalSize = _tablet;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 430);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ServiceTablesView())),
    );
    await tester.pump();

    await tester.tap(find.text('Tambah Meja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Kode meja *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
