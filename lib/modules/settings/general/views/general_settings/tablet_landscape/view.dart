import 'package:flutter/material.dart';

import '../general_settings_content.dart';

export '../general_settings_content.dart' show GeneralSettingsSaveAction;

class GeneralSettingsTabletLandscapeView extends StatelessWidget {
  const GeneralSettingsTabletLandscapeView({super.key});

  @override
  Widget build(BuildContext context) =>
      const GeneralSettingsContent(isMobile: false);
}
