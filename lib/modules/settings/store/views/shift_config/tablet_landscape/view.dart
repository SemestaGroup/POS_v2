import 'package:flutter/material.dart';

import '../shift_config_content.dart';

class ShiftConfigTabletLandscapeView extends StatelessWidget {
  const ShiftConfigTabletLandscapeView({super.key});

  @override
  Widget build(BuildContext context) =>
      const ShiftConfigContent(isMobile: false);
}
