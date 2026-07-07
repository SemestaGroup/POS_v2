class AppConstants {
  /// The single source of truth for the application version.
  static const String appVersion = "2.0.0";

  /// Base URL of the central server
  static const String centralBaseUrl = 'https://flinkaja.com';
  
  /// Central Login Base URL
  static const String centralLoginBaseUrl = '$centralBaseUrl/';
  
  /// Helper to get full product image URL
  static String getProductImageUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '$centralBaseUrl/uploads/products/$value';
  }
}
