import 'package:flutter/material.dart';

import '../shift_config_content.dart';

class ShiftConfigMobileView extends StatelessWidget {
  const ShiftConfigMobileView({super.key});

  @override
  Widget build(BuildContext context) =>
      const ShiftConfigContent(isMobile: true);
}
