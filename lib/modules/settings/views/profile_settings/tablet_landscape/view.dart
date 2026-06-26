import 'package:flutter/material.dart';

import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../app/auth/auth_gate.dart';

class ProfileSettingsView extends StatefulWidget {
  const ProfileSettingsView({super.key});

  @override
  State<ProfileSettingsView> createState() => _ProfileSettingsViewState();
}

class _ProfileSettingsViewState extends State<ProfileSettingsView> {
  bool _isLoading = true;
  String? _errorMessage;

  String _staffName = '-';
  String _staffEmail = '-';
  String _staffRole = '-';
  String _deviceName = '-';
  String _deviceId = '-';
  String _registerId = '-';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final session = PosV2RuntimeSessionStore.instance.currentSession ??
          await PosV2RuntimeSessionStore.instance.restoreFromDatabase();

      if (session == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Tidak ada sesi aktif.';
        });
        return;
      }

      _staffName = session.staffFullName ?? 'Staf FlinkPOS';
      _staffEmail = session.staffEmail ?? '-';
      _staffRole = session.staffRoleCode ?? 'Staf';
      _deviceName = session.deviceName ?? 'Perangkat Tidak Diketahui';
      _deviceId = session.deviceId ?? '-';
      _registerId = session.registerId ?? '-';

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Keluar',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi ini? Anda harus login kembali menggunakan PIN atau password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _performLogout();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _performLogout() async {
    // Navigate back to auth gate which will handle the logout flow
    // By setting the session to null, AuthGate will route to Login
    PosV2RuntimeSessionStore.instance.setSession(null);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade600)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _staffName.isNotEmpty
                              ? _staffName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _staffName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1D2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _staffRole,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: const Text('Keluar Sesi'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Informasi Profil',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Email Terdaftar', _staffEmail),
                _buildInfoRow('Perangkat Aktif', _deviceName),
                _buildInfoRow('Device ID', _deviceId),
                _buildInfoRow('Register ID', _registerId, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1D2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
