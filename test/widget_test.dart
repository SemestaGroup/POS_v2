import 'package:flinkpos_v2/core/widgets/responsive/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the mobile layout below the shared 600dp breakpoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(390, 844)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ResponsiveLayout(
            mobile: Text('mobile'),
            tablet: Text('tablet'),
          ),
        ),
      ),
    );

    expect(find.text('mobile'), findsOneWidget);
    expect(find.text('tablet'), findsNothing);
  });

  testWidgets('uses the tablet layout at the shared 600dp breakpoint', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(600, 900)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ResponsiveLayout(
            mobile: Text('mobile'),
            tablet: Text('tablet'),
          ),
        ),
      ),
    );

    expect(find.text('mobile'), findsNothing);
    expect(find.text('tablet'), findsOneWidget);
  });
}
