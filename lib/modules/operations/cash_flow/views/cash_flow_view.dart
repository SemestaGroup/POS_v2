import 'package:flutter/material.dart';

import '../../../../core/widgets/responsive/responsive_context.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

/// Chooses the presentation only. Data loading remains owned by each layout,
/// so phone-specific UI changes cannot affect the tablet workflow.
class CashFlowView extends StatelessWidget {
  const CashFlowView({super.key});

  @override
  Widget build(BuildContext context) => context.isMobile
      ? const CashFlowMobileView()
      : const CashFlowTabletLandscapeView();
}
