import 'package:flutter/material.dart';

import '../../../../../core/localization/locale_manager.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../services/merchant_login_service.dart';

class MerchantLoginMobileView extends StatefulWidget {
  const MerchantLoginMobileView({super.key, this.onToggleLayout});

  final VoidCallback? onToggleLayout;

  @override
  State<MerchantLoginMobileView> createState() =>
      _MerchantLoginMobileViewState();
}

class _MerchantLoginMobileViewState extends State<MerchantLoginMobileView>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceIdController =
      TextEditingController(text: 'FLINKPOS-V2-DEVICE');
  final _registerIdController = TextEditingController();
  final MerchantLoginService _loginAction = MerchantLoginService();

  bool _isLoading = false;
  bool _isObscured = true;
  String? _errorMessage;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Colors & fonts from V1
  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _gradientStart = Color(0xFF482CD9);
  static const Color _gradientMid = Color(0xFF6A4FE8);
  static const Color _gradientEnd = Color(0xFF9B7FFF);
  static const Color _scaffoldBg = Color(0xFFF8FAFB);
  static const String _fontBold = 'popsem';
  static const String _fontMedium = 'popmed';
  static const String _fontRegular = 'popreg';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _deviceIdController.dispose();
    _registerIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) return;

    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _deviceIdController.text.trim().isEmpty) {
      setState(() => _errorMessage = l10n.loginFormIncomplete);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _loginAction.submit(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        deviceId: _deviceIdController.text.trim(),
        registerId: _registerIdController.text.trim(),
      );
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ─── TOP: Purple gradient hero ──────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gradientStart, _gradientMid, _gradientEnd],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    top: -30,
                    left: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    right: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  // Top-right buttons
                  Positioned(
                    top: 0,
                    right: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLanguageSwitch(),
                        const SizedBox(width: 6),
                        _buildLayoutToggle(),
                      ],
                    ),
                  ),
                  // Logo + Title
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/img/main_logo.jpeg',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.store_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Flink POS',
                          style: TextStyle(
                            fontFamily: _fontBold,
                            fontSize: 22,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kelola bisnis Anda lebih efisien',
                          style: TextStyle(
                            fontFamily: _fontRegular,
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── BOTTOM: Login Form ──────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildLoginForm(l10n),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.point_of_sale_rounded,
            color: _primaryColor,
            size: 26,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.loginTitle,
          style: const TextStyle(
            fontFamily: _fontBold,
            fontSize: 22,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.loginSubtitle,
          style: TextStyle(
            fontFamily: _fontRegular,
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 28),

        _buildFieldLabel(l10n.emailLabel),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _emailController,
          hint: 'name@email.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        _buildFieldLabel(l10n.passwordLabel),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _passwordController,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
        ),
        const SizedBox(height: 16),

        _buildFieldLabel(l10n.deviceIdLabel),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _deviceIdController,
          hint: 'FLINKPOS-V2-DEVICE',
          icon: Icons.devices_rounded,
        ),
        const SizedBox(height: 16),

        _buildFieldLabel('Register ID'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _registerIdController,
          hint: 'Optional during transition',
          icon: Icons.point_of_sale_rounded,
        ),
        const SizedBox(height: 6),
        Text(
          Localizations.localeOf(context).languageCode == 'id'
              ? 'Kosongkan jika register masih mengikuti Device ID.'
              : 'Leave blank if the register should still follow the Device ID.',
          style: TextStyle(
            fontFamily: _fontRegular,
            fontSize: 10,
            color: Colors.grey.shade500,
            height: 1.35,
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFEF4444), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontFamily: _fontRegular,
                      color: Color(0xFFB91C1C),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _primaryColor))
              : ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _submit();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.loginButton,
                    style: const TextStyle(
                      fontFamily: _fontBold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '© 2025 Flink POS · All rights reserved',
            style: TextStyle(
              fontFamily: _fontRegular,
              fontSize: 10,
              color: Colors.grey[400],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: _fontBold,
        fontSize: 12,
        color: Color(0xFF1A1A2E),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText ? _isObscured : false,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: _fontMedium,
        fontSize: 13,
        color: Color(0xFF1A1A2E),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: _fontRegular,
          fontSize: 12,
          color: Colors.grey[400],
        ),
        prefixIcon: Icon(icon, color: _primaryColor, size: 18),
        suffixIcon: obscureText
            ? IconButton(
                icon: Icon(
                  _isObscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _isObscured ? Colors.grey[400] : _primaryColor,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _isObscured = !_isObscured),
              )
            : null,
        filled: true,
        fillColor: _scaffoldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildLanguageSwitch() {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleManager.localeNotifier,
      builder: (context, locale, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: locale.languageCode,
              isDense: true,
              icon: const Icon(Icons.expand_more,
                  size: 16, color: Colors.white),
              dropdownColor: Colors.white,
              style: TextStyle(
                fontFamily: _fontMedium,
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'id',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇮🇩', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 4),
                      Text('ID'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇬🇧', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 4),
                      Text('EN'),
                    ],
                  ),
                ),
              ],
              selectedItemBuilder: (context) {
                return [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇮🇩',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('ID',
                          style: TextStyle(
                            fontFamily: _fontMedium,
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.95),
                          )),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇬🇧',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('EN',
                          style: TextStyle(
                            fontFamily: _fontMedium,
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.95),
                          )),
                    ],
                  ),
                ];
              },
              onChanged: (code) {
                if (code != null) {
                  LocaleManager.changeLocale(Locale(code));
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayoutToggle() {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onToggleLayout,
        child: Container(
          padding: const EdgeInsets.all(6),
          child: const Icon(
            Icons.tablet_mac,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
