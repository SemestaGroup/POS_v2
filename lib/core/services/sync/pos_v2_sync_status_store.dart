import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PosV2SyncStatus {
  const PosV2SyncStatus({
    required this.isSyncing,
    required this.isBlocking,
    required this.stage,
    this.progress,
    this.lastSuccessAt,
    this.errorMessage,
  });

  const PosV2SyncStatus.idle()
    : isSyncing = false,
      isBlocking = false,
      stage = 'idle',
      progress = null,
      lastSuccessAt = null,
      errorMessage = null;

  final bool isSyncing;
  final bool isBlocking;
  final String stage;
  final double? progress;
  final DateTime? lastSuccessAt;
  final String? errorMessage;

  PosV2SyncStatus copyWith({
    bool? isSyncing,
    bool? isBlocking,
    String? stage,
    double? progress,
    DateTime? lastSuccessAt,
    String? errorMessage,
  }) {
    return PosV2SyncStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      isBlocking: isBlocking ?? this.isBlocking,
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      errorMessage: errorMessage,
    );
  }
}

class PosV2SyncStatusStore {
  PosV2SyncStatusStore._();

  static final PosV2SyncStatusStore instance = PosV2SyncStatusStore._();

  final ValueNotifier<PosV2SyncStatus> statusNotifier =
      ValueNotifier<PosV2SyncStatus>(const PosV2SyncStatus.idle());

  PosV2SyncStatus? _pendingStatus;
  bool _isFlushScheduled = false;

  void start({
    required bool blocking,
    required String stage,
    double? progress,
  }) {
    _setStatus(
      statusNotifier.value.copyWith(
        isSyncing: true,
        isBlocking: blocking,
        stage: stage,
        progress: progress,
        errorMessage: null,
      ),
    );
  }

  void update({required String stage, double? progress}) {
    _setStatus(
      statusNotifier.value.copyWith(
        isSyncing: true,
        stage: stage,
        progress: progress,
        errorMessage: null,
      ),
    );
  }

  void succeed({String stage = 'success'}) {
    _setStatus(
      statusNotifier.value.copyWith(
        isSyncing: false,
        isBlocking: false,
        stage: stage,
        progress: 1,
        lastSuccessAt: DateTime.now(),
        errorMessage: null,
      ),
    );
  }

  void fail(String message) {
    _setStatus(
      statusNotifier.value.copyWith(
        isSyncing: false,
        isBlocking: false,
        stage: 'error',
        errorMessage: message,
      ),
    );
  }

  void _setStatus(PosV2SyncStatus next) {
    if (_isSameStatus(statusNotifier.value, next)) {
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    final shouldDefer =
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.persistentCallbacks;

    if (!shouldDefer) {
      statusNotifier.value = next;
      return;
    }

    _pendingStatus = next;
    if (_isFlushScheduled) {
      return;
    }

    _isFlushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isFlushScheduled = false;
      final pending = _pendingStatus;
      _pendingStatus = null;
      if (pending == null || _isSameStatus(statusNotifier.value, pending)) {
        return;
      }
      statusNotifier.value = pending;
    });
  }

  bool _isSameStatus(PosV2SyncStatus left, PosV2SyncStatus right) {
    return left.isSyncing == right.isSyncing &&
        left.isBlocking == right.isBlocking &&
        left.stage == right.stage &&
        left.progress == right.progress &&
        left.lastSuccessAt == right.lastSuccessAt &&
        left.errorMessage == right.errorMessage;
  }
}
