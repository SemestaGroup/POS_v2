class V2SyncResult {
  const V2SyncResult({
    required this.endpointName,
    this.fetchedCount = 0,
    this.upsertedCount = 0,
    this.replacedChildCount = 0,
    this.meta = const <String, Object?>{},
  });

  final String endpointName;
  final int fetchedCount;
  final int upsertedCount;
  final int replacedChildCount;
  final Map<String, Object?> meta;
}
