import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';

class CategoriesView extends StatelessWidget {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(
          context,
        )!.placeholderPage(AppLocalizations.of(context)!.categoriesMenu),
      ),
    );
  }
}
