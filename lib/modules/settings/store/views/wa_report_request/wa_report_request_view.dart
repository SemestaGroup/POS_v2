import 'package:flutter/material.dart';

import '../../../../../../core/widgets/responsive/responsive_context.dart';
import 'mobile_portrait/view.dart';
import 'tablet_landscape/view.dart';
import 'web_landscape/view.dart';
import 'wa_report_request_content.dart';

class WaReportRequestView extends StatelessWidget {
  const WaReportRequestView({super.key});

  @override
  Widget build(BuildContext context) {
    return WaReportRequestContent(
      builder: (context, data) {
        if (context.isMobile) {
          return WaReportRequestMobileView(data: data);
        } else if (context.isTablet) {
          return WaReportRequestTabletLandscapeView(data: data);
        } else {
          return WaReportRequestWebLandscapeView(data: data);
        }
      },
    );
  }
}
