import 'package:flutter/material.dart';
import '../tablet_landscape/view.dart';
import '../wa_report_request_content.dart';

class WaReportRequestWebLandscapeView extends StatelessWidget {
  const WaReportRequestWebLandscapeView({super.key, required this.data});

  final WaReportRequestData data;

  @override
  Widget build(BuildContext context) {
    return WaReportRequestTabletLandscapeView(data: data);
  }
}
