import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_gate.dart';
import '../l10n/app_localizations.dart';

import '../core/theme/flinkpos_theme.dart';
import '../core/localization/locale_manager.dart';

void runFlinkPosV2() {
  runApp(const FlinkPosV2App());
}

class FlinkPosV2App extends StatelessWidget {
  const FlinkPosV2App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleManager.localeNotifier,
      builder: (context, locale, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FlinkPOS V2',
          theme: FlinkPosTheme.light(),
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('id')],
          home: const AuthGate(),
        );
      },
    );
  }
}
