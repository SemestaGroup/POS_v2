import 'package:flutter/material.dart';

import 'responsive_context.dart';

/// Thin Layout Switcher yang memisahkan tampilan Mobile dan Tablet
/// berdasarkan context.isMobile
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
  });

  final Widget mobile;
  final Widget tablet;

  @override
  Widget build(BuildContext context) {
    return context.isMobile ? mobile : tablet;
  }
}
