import 'package:flutter/foundation.dart';

import '../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../modules/operations/shift/models/active_shift_store.dart';
import '../../../modules/sales/shared/models/pos_catalog_store.dart';
import '../../../modules/sales/shared/models/sales_order_store.dart';
import '../../role_access/role_manager.dart';
import '../models/auth_gate_state.dart';

class AuthGateController {
  AuthGateController._() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(
      _handleSessionChanged,
    );
    ActiveShiftStore.instance.activeShiftNotifier.addListener(
      _handleShiftChanged,
    );
  }

  static final AuthGateController instance = AuthGateController._();

  final ValueNotifier<AuthGateState> stateNotifier = ValueNotifier<AuthGateState>(
    const AuthGateState(
      isRestoring: true,
      screen: AuthGateScreen.login,
    ),
  );

  Future<void> restoreAndEvaluate() async {
    stateNotifier.value = stateNotifier.value.copyWith(isRestoring: true);
    final session = await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    await _evaluateSession(session);
  }

  void _handleSessionChanged() {
    stateNotifier.value = stateNotifier.value.copyWith(isRestoring: true);
    _evaluateSession(PosV2RuntimeSessionStore.instance.currentSession);
  }

  void _handleShiftChanged() {
    _evaluateSession(
      PosV2RuntimeSessionStore.instance.currentSession,
      isShiftPoll: true,
    );
  }

  Future<void> _evaluateSession(
    PosV2RuntimeSession? session, {
    bool isShiftPoll = false,
  }) async {
    var nextScreen = AuthGateScreen.login;

    if (session != null) {
      final needsBootstrapSync = session.lastBootstrapAt == null;

      if (!needsBootstrapSync && !isShiftPoll) {
        await PosCatalogStore.instance.refresh();
        await SalesOrderStore.instance.refreshFromPersistence();
      }

      if (needsBootstrapSync) {
        nextScreen = AuthGateScreen.bootstrap;
      } else {
        await ActiveShiftStore.instance.refresh();
        final role = RoleManager.fromCode(session.staffRoleCode);
        final requiresShift =
            role == AppRole.cashier && (session.staffId?.isNotEmpty ?? false);
        final needsShiftOpen =
            requiresShift && ActiveShiftStore.instance.activeShiftNotifier.value == null;
        nextScreen = needsShiftOpen ? AuthGateScreen.shift : AuthGateScreen.shell;
      }
    }

    final current = stateNotifier.value;
    if (isShiftPoll && !current.isRestoring && current.screen == nextScreen) {
      return;
    }

    stateNotifier.value = current.copyWith(
      isRestoring: false,
      screen: nextScreen,
    );
  }
}
