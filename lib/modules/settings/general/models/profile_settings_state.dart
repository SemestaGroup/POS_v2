import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';

class ProfileSettingsState {
  const ProfileSettingsState({
    required this.isLoading,
    required this.isLoggingOut,
    this.session,
    this.roleLabel,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isLoggingOut;
  final PosV2RuntimeSession? session;
  final String? roleLabel;
  final String? errorMessage;

  ProfileSettingsState copyWith({
    bool? isLoading,
    bool? isLoggingOut,
    PosV2RuntimeSession? session,
    bool keepSession = true,
    String? roleLabel,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isLoggingOut: isLoggingOut ?? this.isLoggingOut,
      session: keepSession ? (session ?? this.session) : session,
      roleLabel: roleLabel ?? this.roleLabel,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
