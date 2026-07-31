import 'package:flutter/material.dart';
import '../../../../../core/widgets/responsive/responsive_context.dart';
import '../../../../../core/network/v2_api_client.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/services/sync/pos_v2_auth_service.dart';
import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../core/services/local/database_service.dart';

class AddStaffDialog extends StatefulWidget {
  const AddStaffDialog({
    super.key,
    required this.session,
    required this.authService,
    required this.onSuccess,
  });

  final PosV2RuntimeSession session;
  final PosV2AuthService authService;
  final VoidCallback onSuccess;

  @override
  State<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePin = true;

  List<Map<String, Object?>> _roles = [];
  String? _selectedRoleId;
  String? _selectedRoleName;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      final rows = await DatabaseService.instance.query(
        'pos_role',
        where: 'tenant_id = ?',
        whereArgs: [widget.session.tenantId],
        orderBy: 'name ASC',
      );
      if (mounted) {
        setState(() {
          _roles = rows;
        });
      }
    } catch (e) {
      debugPrint('Failed to load pos_roles: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRoleId == null || _selectedRoleName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih Role terlebih dahulu')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final pin = _pinController.text;

      final payload = {
        'firstname': firstName,
        'lastname': lastName,
        'email': email,
        'password': password,
        'role_id': int.parse(_selectedRoleId!),
        'role': _selectedRoleName,
        'pin': pin,
        'active': 1,
        'admin': 0,
      };

      final client = V2ApiClient(
        baseUrl: widget.session.baseUrl,
        authToken: widget.session.authToken,
      );

      final envelope = await client.postEnvelope(
        'api/v2/pos-staff',
        body: payload,
      );

      if (envelope['status'] == true) {
        widget.onSuccess();
      } else {
        final msg = envelope['message'] ?? 'Gagal menambahkan staf';
        throw Exception(msg);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    int? maxLength,
    Widget? extraAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${isRequired ? ' *' : ''}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: isPassword && obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            counterText: '',
            prefixIcon: Icon(icon, size: 18, color: Colors.black45),
            suffixIcon: isPassword
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      extraAction ?? const SizedBox.shrink(),
                      IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_off : Icons.visibility,
                          size: 18,
                          color: Colors.black45,
                        ),
                        onPressed: onToggleObscure,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                  )
                : extraAction,
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
          validator: isRequired
              ? (val) => val == null || val.isEmpty ? 'Wajib diisi' : null
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    Widget bodyContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrasi Staf',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tambahkan staf baru ke dalam sistem',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                splashRadius: 20,
              ),
            ],
          ),
        ),

        // Body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMobile) ...[
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'Nama Depan',
                      icon: Icons.badge_outlined,
                      isRequired: true,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Nama Belakang',
                      icon: Icons.person_outline,
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _firstNameController,
                            label: 'Nama Depan',
                            icon: Icons.badge_outlined,
                            isRequired: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _lastNameController,
                            label: 'Nama Belakang',
                            icon: Icons.person_outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (isMobile) ...[
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      isRequired: true,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Peran (Role) *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRoleId,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.black45,
                            size: 18,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: const Icon(
                              Icons.work_outline,
                              size: 18,
                              color: Colors.black45,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                          items: _roles.map((r) {
                            return DropdownMenuItem<String>(
                              value: r['role_id']?.toString(),
                              child: Text(
                                r['name']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedRoleId = val;
                              final roleMap = _roles.firstWhere(
                                (r) => r['role_id']?.toString() == val,
                              );
                              _selectedRoleName =
                                  roleMap['name']?.toString();
                            });
                          },
                          validator: (val) => val == null
                              ? 'Wajib pilih peran'
                              : null,
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            isRequired: true,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Peran (Role) *',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedRoleId,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.black45,
                                  size: 18,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  prefixIcon: const Icon(
                                    Icons.work_outline,
                                    size: 18,
                                    color: Colors.black45,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: _roles.map((r) {
                                  return DropdownMenuItem<String>(
                                    value: r['role_id']?.toString(),
                                    child: Text(
                                      r['name']?.toString() ?? '-',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedRoleId = val;
                                    final roleMap = _roles.firstWhere(
                                      (r) => r['role_id']?.toString() == val,
                                    );
                                    _selectedRoleName =
                                        roleMap['name']?.toString();
                                  });
                                },
                                validator: (val) => val == null
                                    ? 'Wajib pilih peran'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (isMobile) ...[
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Kata Sandi',
                      icon: Icons.lock_outline,
                      isRequired: true,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onToggleObscure: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      extraAction: ExcludeSemantics(
                        child: Tooltip(
                          message: 'Generate',
                          child: IconButton(
                            icon: const Icon(
                              Icons.auto_awesome,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              final random = (100000 +
                                      (DateTime.now().millisecondsSinceEpoch %
                                          899999))
                                  .toString();
                              _passwordController.text = 'Flink$random';
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _pinController,
                      label: 'PIN (Wajib untuk Switch)',
                      icon: Icons.dialpad_rounded,
                      isRequired: true,
                      isPassword: true,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onToggleObscure: () =>
                          setState(() => _obscurePin = !_obscurePin),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _passwordController,
                            label: 'Kata Sandi',
                            icon: Icons.lock_outline,
                            isRequired: true,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            extraAction: ExcludeSemantics(
                              child: Tooltip(
                                message: 'Generate',
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.auto_awesome,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    final random = (100000 +
                                            (DateTime.now().millisecondsSinceEpoch %
                                                899999))
                                        .toString();
                                    _passwordController.text = 'Flink$random';
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _pinController,
                            label: 'PIN (Wajib untuk Switch)',
                            icon: Icons.dialpad_rounded,
                            isRequired: true,
                            isPassword: true,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            onToggleObscure: () =>
                                setState(() => _obscurePin = !_obscurePin),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Simpan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Center(
        child: Container(
          width: isMobile ? MediaQuery.of(context).size.width * 0.92 : 520,
          margin: EdgeInsets.symmetric(vertical: isMobile ? 24 : 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: bodyContent,
        ),
      ),
    );
  }
}
