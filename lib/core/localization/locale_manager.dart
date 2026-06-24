import 'package:flutter/material.dart';

class LocaleManager {
  // Default to Indonesian as requested
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(
    const Locale('id'),
  );

  static void changeLocale(Locale locale) {
    localeNotifier.value = locale;
  }
}
