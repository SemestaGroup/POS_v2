import 'package:flutter/material.dart';

import '../../modules/auth/views/merchant_login_wrapper.dart';
import '../../modules/auth/views/shift_gate_screen.dart';
import '../../modules/auth/views/sync_bootstrap_screen.dart';
import 'controllers/auth_gate_controller.dart';
import 'models/auth_gate_state.dart';
import '../shell/views/main_shell_router.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthGateController _controller = AuthGateController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.restoreAndEvaluate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthGateState>(
      valueListenable: _controller.stateNotifier,
      builder: (context, gateState, _) {
        if (gateState.isRestoring) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        switch (gateState.screen) {
          case AuthGateScreen.login:
            return const MerchantLoginWrapper();
          case AuthGateScreen.bootstrap:
            return const SyncBootstrapScreen();
          case AuthGateScreen.shift:
            return const ShiftGateScreen();
          case AuthGateScreen.shell:
            return const MainShellRouter();
        }
      },
    );
  }
}
