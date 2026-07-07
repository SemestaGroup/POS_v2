import '../../../core/constants/app_constants.dart';
import '../../../core/services/sync/pos_v2_auth_service.dart';

class MerchantLoginController {
  MerchantLoginController({PosV2AuthService? authService})
    : _authService = authService ?? PosV2AuthService();

  final PosV2AuthService _authService;

  Future<void> submit({
    required String email,
    required String password,
    String? deviceId,
    String? registerId,
  }) {
    return _authService.discoverAndLoginOnly(
      centralBaseUrl: AppConstants.centralLoginBaseUrl,
      email: email.trim(),
      password: password,
      deviceId: deviceId?.trim().isEmpty == true ? null : deviceId?.trim(),
      registerId: registerId?.trim().isEmpty == true
          ? null
          : registerId?.trim(),
    );
  }
}
