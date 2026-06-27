class StoreProfileState {
  const StoreProfileState({
    required this.isLoading,
    this.tenantName,
    this.tenantCode,
    this.baseUrl,
    this.locationId,
    this.deviceId,
    this.registerId,
    this.feedbackUrl,
    this.onlineStoreBaseUrl,
    this.version,
    this.lastBootstrapAt,
    this.errorMessage,
  });

  final bool isLoading;
  final String? tenantName;
  final String? tenantCode;
  final String? baseUrl;
  final String? locationId;
  final String? deviceId;
  final String? registerId;
  final String? feedbackUrl;
  final String? onlineStoreBaseUrl;
  final String? version;
  final String? lastBootstrapAt;
  final String? errorMessage;

  StoreProfileState copyWith({
    bool? isLoading,
    String? tenantName,
    String? tenantCode,
    String? baseUrl,
    String? locationId,
    String? deviceId,
    String? registerId,
    String? feedbackUrl,
    String? onlineStoreBaseUrl,
    String? version,
    String? lastBootstrapAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StoreProfileState(
      isLoading: isLoading ?? this.isLoading,
      tenantName: tenantName ?? this.tenantName,
      tenantCode: tenantCode ?? this.tenantCode,
      baseUrl: baseUrl ?? this.baseUrl,
      locationId: locationId ?? this.locationId,
      deviceId: deviceId ?? this.deviceId,
      registerId: registerId ?? this.registerId,
      feedbackUrl: feedbackUrl ?? this.feedbackUrl,
      onlineStoreBaseUrl: onlineStoreBaseUrl ?? this.onlineStoreBaseUrl,
      version: version ?? this.version,
      lastBootstrapAt: lastBootstrapAt ?? this.lastBootstrapAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ShiftConfigState {
  const ShiftConfigState({
    required this.isLoading,
    required this.requireOpeningBalance,
    required this.autoPrintShiftRecap,
    required this.allowEditActualCash,
    required this.enforceSingleDevicePerStaff,
    required this.requireDeviceId,
    required this.selfOrderEnabled,
    required this.operatingMode,
    required this.shiftScheduleEnabled,
    this.shiftScheduleJson,
    this.errorMessage,
  });

  final bool isLoading;
  final bool requireOpeningBalance;
  final bool autoPrintShiftRecap;
  final bool allowEditActualCash;
  final bool enforceSingleDevicePerStaff;
  final bool requireDeviceId;
  final bool selfOrderEnabled;
  final String operatingMode;
  /// If true, only staff registered in shiftScheduleJson can open shifts
  final bool shiftScheduleEnabled;
  /// Raw JSON string from pos_shift_config option
  final String? shiftScheduleJson;
  final String? errorMessage;

  ShiftConfigState copyWith({
    bool? isLoading,
    bool? requireOpeningBalance,
    bool? autoPrintShiftRecap,
    bool? allowEditActualCash,
    bool? enforceSingleDevicePerStaff,
    bool? requireDeviceId,
    bool? selfOrderEnabled,
    String? operatingMode,
    bool? shiftScheduleEnabled,
    String? shiftScheduleJson,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ShiftConfigState(
      isLoading: isLoading ?? this.isLoading,
      requireOpeningBalance:
          requireOpeningBalance ?? this.requireOpeningBalance,
      autoPrintShiftRecap:
          autoPrintShiftRecap ?? this.autoPrintShiftRecap,
      allowEditActualCash:
          allowEditActualCash ?? this.allowEditActualCash,
      enforceSingleDevicePerStaff:
          enforceSingleDevicePerStaff ?? this.enforceSingleDevicePerStaff,
      requireDeviceId: requireDeviceId ?? this.requireDeviceId,
      selfOrderEnabled: selfOrderEnabled ?? this.selfOrderEnabled,
      operatingMode: operatingMode ?? this.operatingMode,
      shiftScheduleEnabled: shiftScheduleEnabled ?? this.shiftScheduleEnabled,
      shiftScheduleJson: shiftScheduleJson ?? this.shiftScheduleJson,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
