import 'package:flutter/material.dart';
import 'dart:math';

import '../../../../../core/services/local/database_service.dart';
import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../core/services/sync/pos_v2_staff_service.dart';
import '../../../stores/master_data_read_stores.dart';

/// Add/edit dialog for a staff account, used by the Data Master "Daftar
/// Staf" screen. Pass [existing] to edit that staff member; omit it to
/// create a new one.
class StaffFormDialog extends StatefulWidget {
  const StaffFormDialog({super.key, this.existing});

  final StaffListRecord? existing;

  static Future<bool?> show(BuildContext context, {StaffListRecord? existing}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StaffFormDialog(existing: existing),
    );
  }

  @override
  State<StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends State<StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();

  List<Map<String, Object?>> _roles = [];
  String? _selectedRoleId;
  String? _selectedRoleName;

  bool _isSubmitting = false;
  bool _isDeactivating = false;
  bool _obscurePassword = true;
  bool _obscurePin = true;
  String? _errorMessage;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _firstNameController = TextEditingController(
      text: existing?.firstName ?? _splitName(existing?.fullName).$1,
    );
    _lastNameController = TextEditingController(
      text: existing?.lastName ?? _splitName(existing?.fullName).$2,
    );
    _emailController = TextEditingController(text: existing?.email ?? '');
    _phoneController = TextEditingController(text: existing?.phoneNumber ?? '');
    _selectedRoleId = existing?.roleRemoteId;
    _loadRoles();
  }

  (String, String) _splitName(String? fullName) {
    final trimmed = fullName?.trim() ?? '';
    if (trimmed.isEmpty) return ('', '');
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts.first, '');
    return (parts.first, parts.sublist(1).join(' '));
  }

  Future<void> _loadRoles() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return;
    try {
      final rows = await DatabaseService.instance.query(
        'pos_role',
        where: 'tenant_id = ?',
        whereArgs: [session.tenantId],
        orderBy: 'name ASC',
      );
      if (!mounted) return;
      setState(() {
        _roles = rows;
        if (_selectedRoleId != null) {
          final match = _roles.firstWhere(
            (r) => r['role_id']?.toString() == _selectedRoleId,
            orElse: () => const {},
          );
          _selectedRoleName = match['name']?.toString();
        }
      });
    } catch (_) {
      // Role picker just stays empty; the form still reports "pilih peran".
    }
  }

  void _generatePassword() {
    final suffix = Random().nextInt(900000) + 100000;
    _passwordController.text = 'Flink$suffix';
    setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoleId == null || _selectedRoleName == null) {
      setState(() => _errorMessage = 'Pilih peran (role) terlebih dahulu.');
      return;
    }
    if (!_isEdit && _pinController.text.trim().length < 4) {
      setState(() => _errorMessage = 'PIN minimal 4 digit.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();
      final pin = _pinController.text.trim();

      if (_isEdit) {
        await PosV2StaffService.instance.updateStaff(
          localId: widget.existing!.id,
          firstName: firstName,
          lastName: lastName,
          email: email.isNotEmpty ? email : null,
          phone: phone.isNotEmpty ? phone : null,
          roleId: _selectedRoleId,
          roleName: _selectedRoleName,
          password: password.isNotEmpty ? password : null,
          pin: pin.isNotEmpty ? pin : null,
        );
      } else {
        await PosV2StaffService.instance.createStaff(
          firstName: firstName,
          lastName: lastName,
          email: email,
          password: password,
          roleId: _selectedRoleId!,
          roleName: _selectedRoleName!,
          pin: pin,
        );
      }

      StaffListStore.instance.refresh();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nonaktifkan Staf?'),
        content: Text(
          '${widget.existing!.fullName} tidak akan bisa login lagi. Tindakan ini bisa diaktifkan kembali lewat backoffice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeactivating = true);
    try {
      await PosV2StaffService.instance.deactivateStaff(
        localId: widget.existing!.id,
      );
      StaffListStore.instance.refresh();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isDeactivating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final busy = _isSubmitting || _isDeactivating;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEdit ? 'Edit Staf' : 'Tambah Staf',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isEdit
                                  ? 'Perbarui data dan peran staf ini'
                                  : 'Buat akun staf baru untuk perangkat kasir',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: busy ? null : () => Navigator.of(context).pop(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          enabled: !busy,
                          decoration: _fieldDecoration('Nama Depan *', Icons.person_outline_rounded),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          enabled: !busy,
                          decoration: _fieldDecoration('Nama Belakang', Icons.person_outline_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    enabled: !busy && !_isEdit,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _fieldDecoration(
                      'Email *',
                      Icons.email_outlined,
                    ).copyWith(
                      helperText: _isEdit ? 'Email tidak bisa diubah di sini' : null,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                      if (!v.contains('@')) return 'Email tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    enabled: !busy,
                    keyboardType: TextInputType.phone,
                    decoration: _fieldDecoration('Nomor Telepon', Icons.phone_outlined),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRoleId,
                    decoration: _fieldDecoration('Peran (Role) *', Icons.badge_outlined),
                    items: _roles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r['role_id']?.toString(),
                            child: Text(r['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (value) {
                            final match = _roles.firstWhere(
                              (r) => r['role_id']?.toString() == value,
                              orElse: () => const {},
                            );
                            setState(() {
                              _selectedRoleId = value;
                              _selectedRoleName = match['name']?.toString();
                            });
                          },
                    validator: (v) => v == null ? 'Wajib dipilih' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !busy,
                    obscureText: _obscurePassword,
                    decoration: _fieldDecoration(
                      _isEdit ? 'Password Baru (opsional)' : 'Password *',
                      Icons.lock_outline_rounded,
                    ).copyWith(
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.casino_outlined, size: 18),
                            tooltip: 'Buat password acak',
                            onPressed: busy ? null : _generatePassword,
                          ),
                          IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ],
                      ),
                    ),
                    validator: (v) {
                      if (_isEdit) return null;
                      if (v == null || v.trim().length < 6) return 'Minimal 6 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pinController,
                    enabled: !busy,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: _fieldDecoration(
                      _isEdit ? 'PIN Baru (opsional)' : 'PIN (Wajib untuk Switch Staf) *',
                      Icons.pin_outlined,
                    ).copyWith(
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscurePin = !_obscurePin),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (_isEdit)
                        TextButton.icon(
                          onPressed: busy ? null : _handleDeactivate,
                          icon: _isDeactivating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.person_off_outlined, size: 16),
                          label: const Text('Nonaktifkan'),
                          style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: busy ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Batal',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: busy ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _isEdit ? 'Simpan Perubahan' : 'Tambah Staf',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
