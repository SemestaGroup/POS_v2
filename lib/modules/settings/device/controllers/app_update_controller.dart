import 'package:flutter/foundation.dart';

import '../../../../../core/services/sync/pos_v2_options_service.dart';
import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../models/app_update_state.dart';

class AppUpdateController {
  AppUpdateController._();

  static final AppUpdateController instance = AppUpdateController._();

  final ValueNotifier<AppUpdateState> stateNotifier =
      ValueNotifier<AppUpdateState>(
    const AppUpdateState(isLoading: false, isRefreshing: false),
  );

  Future<void> refresh() async {
    stateNotifier.value = stateNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );
    try {
      await PosV2OptionsService.instance.fetchAndSaveOptions();
      final options = await PosV2OptionsService.instance.getLocalOptions();
      final session = PosV2RuntimeSessionStore.instance.currentSession ??
          await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        backendVersion: options['version']?.toString(),
        baseUrl: session?.baseUrl,
        locationId: session?.locationId,
        registerId: session?.registerId,
        lastBootstrapAt: session?.lastBootstrapAt,
      );
    } catch (error) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> refreshBootstrap() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found.');
    }
    stateNotifier.value = stateNotifier.value.copyWith(
      isRefreshing: true,
      clearError: true,
    );
    try {
      await PosV2SyncOrchestrator().syncBootstrap(session.toSyncContext());
      await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
      await refresh();
      stateNotifier.value = stateNotifier.value.copyWith(isRefreshing: false);
    } catch (error) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isRefreshing: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}
