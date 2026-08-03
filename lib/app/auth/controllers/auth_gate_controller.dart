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
    ActiveShiftStore.instance.readOnlyModeNotifier.addListener(
      _handleReadOnlyModeChanged,
    );
  }

  static final AuthGateController instance = AuthGateController._();

  final ValueNotifier<AuthGateState> stateNotifier =
      ValueNotifier<AuthGateState>(
        const AuthGateState(isRestoring: true, screen: AuthGateScreen.login),
      );

  Future<void> restoreAndEvaluate() async {
    stateNotifier.value = stateNotifier.value.copyWith(isRestoring: true);
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    await _evaluateSession(session);
  }

  void _handleSessionChanged() {
    // Reset read-only mode on new session (logout/re-login).
    ActiveShiftStore.instance.exitReadOnlyMode();
    stateNotifier.value = stateNotifier.value.copyWith(isRestoring: true);
    _evaluateSession(PosV2RuntimeSessionStore.instance.currentSession);
  }

  void _handleShiftChanged() {
    _evaluateSession(
      PosV2RuntimeSessionStore.instance.currentSession,
      isShiftPoll: true,
    );
  }

  void _handleReadOnlyModeChanged() {
    // When a non-cashier chooses "enter without shift", navigate to shell.
    if (ActiveShiftStore.instance.isReadOnly) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isRestoring: false,
        screen: AuthGateScreen.shell,
      );
    }
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
        final isCashier = role == AppRole.cashier;
        final activeShift =
            ActiveShiftStore.instance.activeShiftNotifier.value != null;

        if (isCashier) {
          // Cashier must always have an active shift before accessing the shell.
          final needsShiftOpen =
              (session.staffId?.isNotEmpty ?? false) && !activeShift;
          nextScreen = needsShiftOpen
              ? AuthGateScreen.shift
              : AuthGateScreen.shell;
        } else {
          // Non-cashier (owner/supervisor/etc.):
          // • If there's already an active shift on this device → go straight to shell.
          // • If no active shift → show ShiftGate where they can open a shift OR enter read-only.
          // • If readOnlyMode was already set → go to shell (handled by _handleReadOnlyModeChanged, but guard here too).
          // Owner and supervisor are operational overrides: an active shift
          // belonging to a cashier must not prevent them from entering POS to
          // investigate or resolve an outlet issue.
          if (activeShift || ActiveShiftStore.instance.isReadOnly) {
            nextScreen = AuthGateScreen.shell;
          } else {
            nextScreen = AuthGateScreen.shift;
          }
        }
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
