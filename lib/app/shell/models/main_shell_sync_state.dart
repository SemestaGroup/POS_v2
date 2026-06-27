class MainShellSyncState {
  const MainShellSyncState({
    required this.started,
    required this.didStartForCurrentSession,
    this.lastSessionKey,
  });

  final bool started;
  final bool didStartForCurrentSession;
  final String? lastSessionKey;

  MainShellSyncState copyWith({
    bool? started,
    bool? didStartForCurrentSession,
    String? lastSessionKey,
    bool clearSessionKey = false,
  }) {
    return MainShellSyncState(
      started: started ?? this.started,
      didStartForCurrentSession:
          didStartForCurrentSession ?? this.didStartForCurrentSession,
      lastSessionKey:
          clearSessionKey ? null : (lastSessionKey ?? this.lastSessionKey),
    );
  }
}
