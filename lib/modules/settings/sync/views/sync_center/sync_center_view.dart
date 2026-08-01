import 'package:flutter/material.dart';
import '../../../../../../core/widgets/responsive/responsive_context.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

class SyncCenterView extends StatelessWidget {
  const SyncCenterView({super.key});
  @override
  Widget build(BuildContext context) => context.isMobile
      ? const SyncCenterMobileView()
      : const SyncCenterTabletLandscapeView();
}
