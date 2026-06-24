import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';

class StaffRolesView extends StatelessWidget {
  const StaffRolesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(
          context,
        )!.placeholderPage(AppLocalizations.of(context)!.staffRolesMenu),
      ),
    );
  }
}
