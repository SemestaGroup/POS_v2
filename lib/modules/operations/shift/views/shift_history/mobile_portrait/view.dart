import 'package:flutter/material.dart';

import '../shift_history_content.dart';

class ShiftHistoryMobilePortraitView extends StatelessWidget {
  const ShiftHistoryMobilePortraitView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: ShiftHistoryContent(isTablet: false),
      ),
    );
  }
}
