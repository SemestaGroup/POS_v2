import 'package:flutter/material.dart';

import '../../../../../../../core/widgets/responsive/responsive_context.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

class GeneralSettingsView extends StatelessWidget {
  const GeneralSettingsView({super.key});

  @override
  Widget build(BuildContext context) => context.isMobile
      ? const GeneralSettingsMobileView()
      : const GeneralSettingsTabletLandscapeView();
}
