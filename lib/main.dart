import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/flinkpos_v2_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runFlinkPosV2();
}
