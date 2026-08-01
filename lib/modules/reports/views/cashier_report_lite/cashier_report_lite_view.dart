import 'package:flutter/material.dart';

import '../../../../core/widgets/responsive/responsive_context.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

class CashierReportLiteView extends StatelessWidget {
  const CashierReportLiteView({super.key});

  @override
  Widget build(BuildContext context) => context.isMobile
      ? const CashierReportLiteMobileView()
      : const CashierReportLiteTabletLandscapeView();
}
