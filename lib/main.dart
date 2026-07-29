import 'package:flutter/material.dart';

import 'app/flinkpos_v2_app.dart';
import 'core/services/sync/pos_v2_session_monitor_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PosV2SessionMonitorService.instance.init();
  runFlinkPosV2();
}
