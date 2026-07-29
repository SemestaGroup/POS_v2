import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_gate.dart';
import '../l10n/app_localizations.dart';

import '../core/theme/flinkpos_theme.dart';
import '../core/localization/locale_manager.dart';

void runFlinkPosV2() {
  runApp(const FlinkPosV2App());
}

class FlinkPosV2App extends StatefulWidget {
  const FlinkPosV2App({super.key});

  @override
  State<FlinkPosV2App> createState() => _FlinkPosV2AppState();
}

class _FlinkPosV2AppState extends State<FlinkPosV2App>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableFullscreen();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enableFullscreen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enableFullscreen();
    }
  }

  void _enableFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

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
