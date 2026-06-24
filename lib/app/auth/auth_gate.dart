import 'package:flutter/material.dart';

import '../role_access/role_manager.dart';
import '../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../modules/sales/shared/models/pos_catalog_store.dart';
import '../../modules/auth/views/merchant_login_wrapper.dart';
import '../../modules/auth/views/shift_gate_screen.dart';
import '../../modules/auth/views/sync_bootstrap_screen.dart';
import '../../modules/operations/shift/models/active_shift_store.dart';
import '../shell/views/main_shell_router.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isRestoring = true;
  bool _needsShiftOpen = false;

  @override
  void initState() {
    super.initState();
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(
      _handleSessionChanged,
    );
    ActiveShiftStore.instance.activeShiftNotifier.addListener(
      _handleShiftChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreAndEvaluate();
    });
  }

  @override
  void dispose() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.removeListener(
      _handleSessionChanged,
    );
    ActiveShiftStore.instance.activeShiftNotifier.removeListener(
      _handleShiftChanged,
    );
    super.dispose();
  }

  void _handleSessionChanged() {
    // Set _isRestoring = true SYNCHRONOUSLY so the loading screen shows
    // immediately, preventing the MainShellRouter from flashing.
    if (mounted) {
      setState(() {
        _isRestoring = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _evaluateSession(PosV2RuntimeSessionStore.instance.currentSession);
    });
  }

  void _handleShiftChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _evaluateSession(PosV2RuntimeSessionStore.instance.currentSession);
    });
  }

  Future<void> _restoreAndEvaluate() async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    await _evaluateSession(session);
  }

  Future<void> _evaluateSession(PosV2RuntimeSession? session) async {
    var needsShiftOpen = false;
    if (session != null) {
      final needsBootstrapSync = session.lastBootstrapAt == null;

      if (!needsBootstrapSync) {
        await PosCatalogStore.instance.refresh();
      }

      if (!needsBootstrapSync) {
        await ActiveShiftStore.instance.refresh();
        final role = RoleManager.fromCode(session.staffRoleCode);
        final requiresShift =
            role == AppRole.cashier && (session.staffId?.isNotEmpty ?? false);
        needsShiftOpen =
            requiresShift &&
            ActiveShiftStore.instance.activeShiftNotifier.value == null;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _needsShiftOpen = needsShiftOpen;
      _isRestoring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ValueListenableBuilder<PosV2RuntimeSession?>(
      valueListenable: PosV2RuntimeSessionStore.instance.sessionNotifier,
      builder: (context, session, _) {
        if (session == null) {
          return const MerchantLoginWrapper();
        }
        // Check lastBootstrapAt directly from session — synchronous,
        // no 1-frame gap where MainShellRouter could flash.
        if (session.lastBootstrapAt == null) {
          return const SyncBootstrapScreen();
        }
        if (_needsShiftOpen) {
          return const ShiftGateScreen();
        }
        return const MainShellRouter();
      },
    );
  }
}
