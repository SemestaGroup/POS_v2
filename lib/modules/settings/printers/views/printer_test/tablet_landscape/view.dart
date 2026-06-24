import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';

class PrinterTestView extends StatelessWidget {
  const PrinterTestView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(
          context,
        )!.placeholderPage(AppLocalizations.of(context)!.printerTestMenu),
      ),
    );
  }
}
