import 'package:flutter/material.dart';

import '../general_settings_content.dart';

class GeneralSettingsMobileView extends StatelessWidget {
  const GeneralSettingsMobileView({super.key});

  @override
  Widget build(BuildContext context) =>
      const GeneralSettingsContent(isMobile: true);
}
