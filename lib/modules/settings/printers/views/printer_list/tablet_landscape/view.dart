import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';

class PrinterListView extends StatelessWidget {
  const PrinterListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(
          context,
        )!.placeholderPage(AppLocalizations.of(context)!.printerListMenu),
      ),
    );
  }
}
