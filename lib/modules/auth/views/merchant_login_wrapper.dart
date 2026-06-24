import 'package:flutter/material.dart';

import 'merchant_login/tablet_landscape/view.dart';
import 'merchant_login/mobile_portrait/view.dart';

/// Wrapper widget that allows switching between tablet and smartphone
/// login layouts. By default it detects the layout from the screen size,
/// but the user can manually toggle via a button.
class MerchantLoginWrapper extends StatefulWidget {
  const MerchantLoginWrapper({super.key});

  @override
  State<MerchantLoginWrapper> createState() => _MerchantLoginWrapperState();
}

class _MerchantLoginWrapperState extends State<MerchantLoginWrapper> {
  /// null means "auto-detect based on screen width"
  bool? _forceTabletLayout;

  void _toggleLayout() {
    final isCurrentlyTablet = _forceTabletLayout ??
        MediaQuery.of(context).size.width >= 600;
    setState(() {
      _forceTabletLayout = !isCurrentlyTablet;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useTabletLayout = _forceTabletLayout ?? (screenWidth >= 600);

    if (useTabletLayout) {
      return MerchantLoginTabletView(onToggleLayout: _toggleLayout);
    } else {
      return MerchantLoginMobileView(onToggleLayout: _toggleLayout);
    }
  }
}
