enum AuthGateScreen { login, bootstrap, shift, shell }

class AuthGateState {
  const AuthGateState({
    required this.isRestoring,
    required this.screen,
  });

  final bool isRestoring;
  final AuthGateScreen screen;

  AuthGateState copyWith({
    bool? isRestoring,
    AuthGateScreen? screen,
  }) {
    return AuthGateState(
      isRestoring: isRestoring ?? this.isRestoring,
      screen: screen ?? this.screen,
    );
  }
}
