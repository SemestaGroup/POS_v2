class AppUpdateState {
  const AppUpdateState({
    required this.isLoading,
    required this.isRefreshing,
    this.backendVersion,
    this.baseUrl,
    this.locationId,
    this.registerId,
    this.lastBootstrapAt,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isRefreshing;
  final String? backendVersion;
  final String? baseUrl;
  final String? locationId;
  final String? registerId;
  final String? lastBootstrapAt;
  final String? errorMessage;

  AppUpdateState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? backendVersion,
    String? baseUrl,
    String? locationId,
    String? registerId,
    String? lastBootstrapAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppUpdateState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      backendVersion: backendVersion ?? this.backendVersion,
      baseUrl: baseUrl ?? this.baseUrl,
      locationId: locationId ?? this.locationId,
      registerId: registerId ?? this.registerId,
      lastBootstrapAt: lastBootstrapAt ?? this.lastBootstrapAt,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
