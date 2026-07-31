import 'package:flutter/material.dart';

import '../../../../../core/widgets/responsive/responsive_context.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';

/// Thin Router untuk PosWorkspace yang memilih antarmuka
/// murni Mobile atau murni Tablet berdasarkan context.isMobile
class PosWorkspaceView extends StatelessWidget {
  const PosWorkspaceView({
    super.key,
    this.embedded = false,
    this.onSectionSelected,
    this.isReadOnly = false,
  });

  final bool embedded;
  final ValueChanged<int>? onSectionSelected;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    return context.isMobile
        ? PosWorkspaceMobileView(isReadOnly: isReadOnly)
        : PosWorkspaceTabletLandscapeView(
            embedded: embedded,
            onSectionSelected: onSectionSelected,
            isReadOnly: isReadOnly,
          );
  }
}
