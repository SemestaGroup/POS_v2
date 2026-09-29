import 'package:flinkpos_v2/core/services/sync/pos_v2_service_table_service.dart';
import 'package:flinkpos_v2/modules/settings/store/views/service_tables/service_tables_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('QR dialog renders the code and address', (tester) async {
    tester.view.physicalSize = const Size(1340, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const table = ServiceTableRecord(
      localId: 1,
      remoteId: '1',
      tableCode: 'TUJI1',
      tableName: 'Meja Uji 1',
      capacity: 0,
      selfOrderEnabled: true,
      isActive: true,
      qrToken: 'TBL-8A439E35B326',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => const ServiceTableQrDialog(
                  table: table,
                  url: 'https://a.example.com/order?table=TUJI1&token=TBL-X',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('QR Meja Uji 1'), findsOneWidget);
    expect(find.textContaining('order?table=TUJI1'), findsOneWidget);
  });

  test('the print sheet is a valid PDF holding every table', () async {
    const tables = [
      ServiceTableRecord(
        localId: 1,
        remoteId: '1',
        tableCode: 'A1',
        tableName: 'Meja 1',
        capacity: 4,
        selfOrderEnabled: true,
        isActive: true,
        qrToken: 'TBL-1',
      ),
      ServiceTableRecord(
        localId: 2,
        remoteId: '2',
        tableCode: 'A2',
        tableName: 'Meja 2',
        areaName: 'Teras',
        capacity: 2,
        selfOrderEnabled: true,
        isActive: true,
        qrToken: 'TBL-2',
      ),
    ];
    final requested = <String>[];

    final bytes = await buildServiceTablesPdf(tables, (table) {
      requested.add(table.tableCode);
      return 'https://a.example.com/order?table=${table.tableCode}';
    });

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(requested, ['A1', 'A2']);
  });
}
