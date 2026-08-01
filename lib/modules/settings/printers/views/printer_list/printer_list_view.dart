import 'package:flutter/material.dart';

import '../../../../../core/widgets/responsive/responsive_context.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

/// Stateful Coordinator for PrinterListView
class PrinterListView extends StatelessWidget {
  const PrinterListView({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) {
      return const PrinterListMobileView();
    }
    return const PrinterListTabletLandscapeView();
  }
}
