class V2SyncContext {
  const V2SyncContext({
    required this.baseUrl,
    required this.authToken,
    required this.locationId,
    this.tenantCode,
    this.tenantName,
    this.deviceId,
    this.staffId,
    this.staffEmail,
    this.staffFullName,
  });

  final String baseUrl;
  final String authToken;
  final String locationId;
  final String? tenantCode;
  final String? tenantName;
  final String? deviceId;
  final String? staffId;
  final String? staffEmail;
  final String? staffFullName;

  String get normalizedBaseUrl => baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';

  String get tenantKey => '$normalizedBaseUrl::$locationId';
}
