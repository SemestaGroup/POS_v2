import 'package:flutter/material.dart';

import '../../../../../core/localization/locale_manager.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../controllers/merchant_login_controller.dart';

class MerchantLoginTabletView extends StatefulWidget {
  const MerchantLoginTabletView({super.key, this.onToggleLayout});

  final VoidCallback? onToggleLayout;

  @override
  State<MerchantLoginTabletView> createState() =>
      _MerchantLoginTabletViewState();
}

class _MerchantLoginTabletViewState extends State<MerchantLoginTabletView>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceIdController =
      TextEditingController(text: 'FLINKPOS-V2-DEVICE');
  final _registerIdController = TextEditingController();
  final MerchantLoginController _loginAction = MerchantLoginController();

  bool _isLoading = false;
  bool _isObscured = true;
  String? _errorMessage;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimLeft;
  late final Animation<Offset> _slideAnimLeft;
  late final Animation<double> _fadeAnimRight;
  late final Animation<Offset> _slideAnimRight;

  // Primary & gradient colors from V1
  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _gradientStart = Color(0xFF482CD9);
  static const Color _gradientMid = Color(0xFF6A4FE8);
  static const Color _gradientEnd = Color(0xFF9B7FFF);
  static const Color _scaffoldBg = Color(0xFFF8FAFB);

  // Font families from V1
  static const String _fontBold = 'popsem';
  static const String _fontMedium = 'popmed';
  static const String _fontRegular = 'popreg';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimLeft = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _slideAnimLeft =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimRight = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _slideAnimRight =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
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
      setState(() {
        _errorMessage = l10n.loginFormIncomplete;
      });
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _scaffoldBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Row(
          children: [
            // ─── LEFT PANEL: Illustration ───────────────────────
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_gradientStart, _gradientMid, _gradientEnd],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -60,
                      left: -60,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      right: -80,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 100,
                      left: -40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    // Content
                    Center(
                      child: SingleChildScrollView(
                        child: FadeTransition(
                          opacity: _fadeAnimLeft,
                          child: SlideTransition(
                            position: _slideAnimLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Logo
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.asset(
                                    'assets/img/main_logo.jpeg',
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.store_rounded,
                                      size: 120,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                const Text(
                                  'Flink POS',
                                  style: TextStyle(
                                    fontFamily: _fontBold,
                                    fontSize: 28,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.loginHeroTagline,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: _fontRegular,
                                    fontSize: 14,
                                     color: Colors.white.withValues(alpha: 0.80),
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            ),

            // ─── RIGHT PANEL: Login Form ────────────────────────
            Expanded(
              flex: 4,
              child: Container(
                color: Colors.white,
                child: Stack(
                  children: [

                    // Form content
                    Positioned.fill(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 24,
                          ),
                          child: FadeTransition(
                          opacity: _fadeAnimRight,
                          child: SlideTransition(
                            position: _slideAnimRight,
                            child: _buildLoginForm(l10n),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Top-right corner: language switch + layout toggle
                  Positioned(
                    top: 16,
                    right: 16,
                    child: FadeTransition(
                      opacity: _fadeAnimRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLanguageSwitch(),
                          const SizedBox(width: 8),
                          _buildLayoutToggle(),
                        ],
                      ),
                    ),
                  ),
                  ],
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
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header icon
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.point_of_sale_rounded,
            color: _primaryColor,
            size: 32,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.loginTitle,
          style: const TextStyle(
            fontFamily: _fontBold,
            fontSize: 26,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.loginSubtitle,
          style: TextStyle(
            fontFamily: _fontRegular,
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 36),

        // Email field
        _buildFieldLabel(l10n.emailLabel),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _emailController,
          hint: 'name@email.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),

        // Password field
        _buildFieldLabel(l10n.passwordLabel),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _passwordController,
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: true,
        ),
        const SizedBox(height: 20),


        // Error message
        if (_errorMessage != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontFamily: _fontRegular,
                      color: Color(0xFFB91C1C),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),

        // Login button
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _primaryColor,
                      ),
                    )
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
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Footer
        Center(
          child: Text(
            '© 2025 Flink POS · All rights reserved',
            style: TextStyle(
              fontFamily: _fontRegular,
              fontSize: 11,
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
        fontSize: 13,
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
        fontSize: 14,
        color: Color(0xFF1A1A2E),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: _fontRegular,
          fontSize: 13,
          color: Colors.grey[400],
        ),
        prefixIcon: Icon(icon, color: _primaryColor, size: 20),
        suffixIcon: obscureText
            ? IconButton(
                icon: Icon(
                  _isObscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color:
                      _isObscured ? Colors.grey[400] : _primaryColor,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _isObscured = !_isObscured),
              )
            : null,
        filled: true,
        fillColor: _scaffoldBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: locale.languageCode,
              isDense: true,
              icon: Icon(Icons.expand_more,
                  size: 18, color: Colors.grey.shade600),
              style: TextStyle(
                fontFamily: _fontMedium,
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'id',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇮🇩', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6),
                      Text('ID'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🇬🇧', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6),
                      Text('EN'),
                    ],
                  ),
                ),
              ],
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
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onToggleLayout,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Icon(
            Icons.smartphone,
            size: 18,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
