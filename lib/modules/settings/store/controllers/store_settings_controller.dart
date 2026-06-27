import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../../core/services/sync/pos_v2_options_service.dart';
import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../models/store_settings_state.dart';

class StoreProfileController {
  StoreProfileController._();

  static final StoreProfileController instance = StoreProfileController._();

  final ValueNotifier<StoreProfileState> stateNotifier =
      ValueNotifier<StoreProfileState>(
    const StoreProfileState(isLoading: false),
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
        tenantName: session?.tenantName,
        tenantCode: session?.tenantCode,
        baseUrl: session?.baseUrl,
        locationId: session?.locationId,
        deviceId: session?.deviceId,
        registerId: session?.registerId,
        feedbackUrl: options['pos_feedback_url']?.toString(),
        onlineStoreBaseUrl: options['pos_online_store_base_url']?.toString(),
        version: options['version']?.toString(),
        lastBootstrapAt: session?.lastBootstrapAt,
      );
    } catch (error) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class ShiftConfigController {
  ShiftConfigController._();

  static final ShiftConfigController instance = ShiftConfigController._();

  final ValueNotifier<ShiftConfigState> stateNotifier =
      ValueNotifier<ShiftConfigState>(
    const ShiftConfigState(
      isLoading: false,
      requireOpeningBalance: true,
      autoPrintShiftRecap: false,
      allowEditActualCash: true,
      enforceSingleDevicePerStaff: true,
      requireDeviceId: true,
      selfOrderEnabled: false,
      operatingMode: 'classic_pos',
      shiftScheduleEnabled: false,
      shiftScheduleJson: null,
    ),
  );

  Future<void> refresh() async {
    stateNotifier.value = stateNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );
    try {
      await PosV2OptionsService.instance.fetchAndSaveOptions();
      final options = await PosV2OptionsService.instance.getLocalOptions();
      final appSettings = _asMap(options['pos_app_settings']);
      final devicePolicy = _asMap(options['pos_device_session_policy']);
      final selfOrder = _asMap(options['pos_self_order_settings']);
      final operatingMode = _asMap(options['pos_operating_mode']);

      final shiftConfig = options['pos_shift_config'];
      String? shiftConfigJson;
      bool shiftScheduleEnabled = false;
      if (shiftConfig is Map) {
        shiftScheduleEnabled =
            _asBool(shiftConfig['schedule_enabled'], fallback: false);
        shiftConfigJson = _asMap(shiftConfig).isNotEmpty
            ? jsonEncode(shiftConfig)
            : null;
      } else if (shiftConfig is String && shiftConfig.isNotEmpty) {
        shiftConfigJson = shiftConfig;
        try {
          final parsed = Map<String, dynamic>.from(
              (shiftConfig.startsWith('{') ? {} : {}));
          shiftScheduleEnabled =
              _asBool(parsed['schedule_enabled'], fallback: false);
        } catch (_) {}
      }

      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        requireOpeningBalance:
            _asBool(appSettings['require_opening_balance'], fallback: true),
        autoPrintShiftRecap:
            _asBool(appSettings['auto_print_shift_recap'], fallback: false),
        allowEditActualCash:
            _asBool(appSettings['allow_edit_actual_cash'], fallback: true),
        enforceSingleDevicePerStaff: _asBool(
          devicePolicy['enforce_single_device_per_staff'],
          fallback: true,
        ),
        requireDeviceId:
            _asBool(devicePolicy['require_device_id'], fallback: true),
        selfOrderEnabled: _asBool(selfOrder['enabled'], fallback: false),
        operatingMode: operatingMode['mode']?.toString() ?? 'classic_pos',
        shiftScheduleEnabled: shiftScheduleEnabled,
        shiftScheduleJson: shiftConfigJson,
      );
    } catch (error) {
      stateNotifier.value = stateNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> updateQuickRules({
    bool? requireOpeningBalance,
    bool? autoPrintShiftRecap,
    bool? allowEditActualCash,
  }) async {
    final options = await PosV2OptionsService.instance.getLocalOptions();
    final appSettings = _asMap(options['pos_app_settings']);
    if (requireOpeningBalance != null) {
      appSettings['require_opening_balance'] = requireOpeningBalance;
    }
    if (autoPrintShiftRecap != null) {
      appSettings['auto_print_shift_recap'] = autoPrintShiftRecap;
    }
    if (allowEditActualCash != null) {
      appSettings['allow_edit_actual_cash'] = allowEditActualCash;
    }
    await PosV2OptionsService.instance.updateOption('pos_app_settings', appSettings);
    await refresh();
  }

  Future<void> updateShiftSchedule({
    required bool enabled,
    List<Map<String, dynamic>> schedules = const [],
  }) async {
    final payload = <String, dynamic>{
      'schedule_enabled': enabled,
      'schedules': schedules,
    };
    await PosV2OptionsService.instance.updateOption('pos_shift_config', payload);
    await refresh();
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

bool _asBool(Object? value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return fallback;
  return normalized == '1' || normalized == 'true' || normalized == 'yes' || normalized == 'on';
}
