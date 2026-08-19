import 'package:flutter/material.dart';

import '../../../../../../core/widgets/responsive/responsive_context.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

class ShiftHistoryView extends StatelessWidget {
  const ShiftHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return context.isMobile
        ? const ShiftHistoryMobilePortraitView()
        : const ShiftHistoryTabletLandscapeView();
  }
}
