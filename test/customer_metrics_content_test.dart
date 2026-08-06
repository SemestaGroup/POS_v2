import 'package:flinkpos_v2/l10n/app_localizations.dart';
import 'package:flinkpos_v2/modules/overview/stores/overview_store.dart';
import 'package:flinkpos_v2/modules/overview/views/owner_overview/customer_metrics_content.dart';
import 'package:flinkpos_v2/modules/overview/views/owner_overview/tablet_landscape/customer_metrics_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({required bool compact}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomerMetricsContent(
          compact: compact,
          includeWalkIns: false,
          onIncludeWalkInsChanged: (_) {},
          snapshot: const OverviewSnapshot(
            isLoading: false,
            totalCustomers: 28,
            activeCustomers: 9,
            newCustomers: 3,
            returningCustomers: 4,
            totalCustomersIncludingWalkIns: 29,
            activeCustomersIncludingWalkIns: 10,
            newCustomersIncludingWalkIns: 4,
            returningCustomersIncludingWalkIns: 5,
            topCustomers: [
              TopCustomerRecord(
                name: 'Rani',
                transactionCount: 6,
                totalSales: 270000,
              ),
            ],
            topCustomersIncludingWalkIns: [
              TopCustomerRecord(
                name: 'Walk-In Customer',
                transactionCount: 12,
                totalSales: 480000,
                isWalkIn: true,
              ),
              TopCustomerRecord(
                name: 'Rani',
                transactionCount: 6,
                totalSales: 270000,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('lays out the tablet customer summary in a scroll view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomerMetricsView(
            includeWalkIns: false,
            onIncludeWalkInsChanged: (_) {},
            snapshot: const OverviewSnapshot(
              isLoading: false,
              totalCustomers: 28,
              activeCustomers: 9,
              newCustomers: 3,
              returningCustomers: 4,
              totalCustomersIncludingWalkIns: 29,
              activeCustomersIncludingWalkIns: 10,
              newCustomersIncludingWalkIns: 4,
              returningCustomersIncludingWalkIns: 5,
              topCustomers: [
                TopCustomerRecord(
                  name: 'Rani',
                  transactionCount: 6,
                  totalSales: 270000,
                ),
              ],
              topCustomersIncludingWalkIns: [
                TopCustomerRecord(
                  name: 'Walk-In Customer',
                  transactionCount: 12,
                  totalSales: 480000,
                  isWalkIn: true,
                ),
                TopCustomerRecord(
                  name: 'Rani',
                  transactionCount: 6,
                  totalSales: 270000,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Total Customers'), findsOneWidget);
    expect(find.text('Rani'), findsOneWidget);
  });

  testWidgets('lays out the compact customer summary', (tester) async {
    await tester.pumpWidget(buildSubject(compact: true));

    expect(tester.takeException(), isNull);
    expect(find.text('Active Customers'), findsOneWidget);
    expect(find.text('Rani'), findsOneWidget);
  });

  testWidgets('the global walk-in switch updates the whole overview', (
    tester,
  ) async {
    bool includeWalkIns = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: CustomerMetricsContent(
              compact: true,
              includeWalkIns: includeWalkIns,
              onIncludeWalkInsChanged: (value) {
                setState(() => includeWalkIns = value);
              },
              snapshot: const OverviewSnapshot(
                isLoading: false,
                totalCustomers: 28,
                activeCustomers: 9,
                newCustomers: 3,
                returningCustomers: 4,
                totalCustomersIncludingWalkIns: 29,
                activeCustomersIncludingWalkIns: 10,
                newCustomersIncludingWalkIns: 4,
                returningCustomersIncludingWalkIns: 5,
                topCustomers: [
                  TopCustomerRecord(
                    name: 'Rani',
                    transactionCount: 6,
                    totalSales: 270000,
                  ),
                ],
                topCustomersIncludingWalkIns: [
                  TopCustomerRecord(
                    name: 'Walk-In Customer',
                    transactionCount: 12,
                    totalSales: 480000,
                    isWalkIn: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Walk-in'), findsNothing);
    final includeWalkInSwitch = find.byType(Switch);
    await tester.ensureVisible(includeWalkInSwitch);
    await tester.tap(includeWalkInSwitch);
    await tester.pump();

    expect(find.text('Walk-in'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });
}
