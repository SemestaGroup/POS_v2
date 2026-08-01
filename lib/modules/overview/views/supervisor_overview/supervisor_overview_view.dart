import 'package:flutter/material.dart';

import '../../../../core/widgets/responsive/responsive_context.dart';
import '../owner_overview/mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

class SupervisorOverviewView extends StatelessWidget {
  const SupervisorOverviewView({super.key});

  @override
  Widget build(BuildContext context) => context.isMobile
      ? const OwnerOverviewMobileView()
      : const SupervisorOverviewTabletLandscapeView();
}
