import '../../../core/services/sync/pos_v2_auth_service.dart';

class MerchantLoginController {
  MerchantLoginController({PosV2AuthService? authService})
      : _authService = authService ?? PosV2AuthService();

  final PosV2AuthService _authService;

  static const String centralLoginBaseUrl = 'https://flinkaja.com/';

  Future<void> submit({
    required String email,
    required String password,
    required String deviceId,
    String? registerId,
  }) {
    return _authService.loginOnly(
      loginBaseUrl: centralLoginBaseUrl,
      email: email.trim(),
      password: password,
      deviceId: deviceId.trim(),
      registerId: registerId?.trim().isEmpty == true ? null : registerId?.trim(),
    );
  }
}
