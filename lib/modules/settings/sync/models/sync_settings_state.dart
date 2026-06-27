import '../../../../../core/services/sync/pos_v2_sync_status_store.dart';

class SyncCenterState {
  const SyncCenterState({
    required this.isLoading,
    required this.pendingCount,
    required this.failedCount,
    required this.processedCount,
    required this.errorCount,
    required this.status,
    this.errorMessage,
  });

  final bool isLoading;
  final int pendingCount;
  final int failedCount;
  final int processedCount;
  final int errorCount;
  final PosV2SyncStatus status;
  final String? errorMessage;

  SyncCenterState copyWith({
    bool? isLoading,
    int? pendingCount,
    int? failedCount,
    int? processedCount,
    int? errorCount,
    PosV2SyncStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SyncCenterState(
      isLoading: isLoading ?? this.isLoading,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      processedCount: processedCount ?? this.processedCount,
      errorCount: errorCount ?? this.errorCount,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SyncHistoryEntry {
  const SyncHistoryEntry({
    required this.id,
    required this.entityType,
    required this.operation,
    required this.endpoint,
    required this.status,
    required this.retryCount,
    this.lastError,
    this.createdAt,
    this.processedAt,
  });

  final int id;
  final String entityType;
  final String operation;
  final String endpoint;
  final String status;
  final int retryCount;
  final String? lastError;
  final String? createdAt;
  final String? processedAt;
}

class SyncErrorEntry {
  const SyncErrorEntry({
    required this.id,
    required this.category,
    required this.message,
    required this.status,
    this.errorCode,
    this.createdAt,
  });

  final int id;
  final String category;
  final String message;
  final String status;
  final String? errorCode;
  final String? createdAt;
}

class SyncHistoryState {
  const SyncHistoryState({
    required this.isLoading,
    required this.queueEntries,
    required this.errorEntries,
    this.errorMessage,
  });

  final bool isLoading;
  final List<SyncHistoryEntry> queueEntries;
  final List<SyncErrorEntry> errorEntries;
  final String? errorMessage;

  SyncHistoryState copyWith({
    bool? isLoading,
    List<SyncHistoryEntry>? queueEntries,
    List<SyncErrorEntry>? errorEntries,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SyncHistoryState(
      isLoading: isLoading ?? this.isLoading,
      queueEntries: queueEntries ?? this.queueEntries,
      errorEntries: errorEntries ?? this.errorEntries,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
