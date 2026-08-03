import 'package:flutter/material.dart';

import '../../../app/auth/auth_gate.dart';
import '../../../core/services/local/database_service.dart';
import '../../../core/services/sync/pos_v2_auth_service.dart';
import '../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../l10n/app_localizations.dart';

Future<void> showPinAccountSwitchDialog(BuildContext context) async {
  final session =
      PosV2RuntimeSessionStore.instance.currentSession ??
      await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
  if (session == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.loginRequiredMessage),
        ),
      );
    }
    return;
  }

  final staffRows = await DatabaseService.instance.query(
    'staff',
    where: 'tenant_id = ? AND deleted_at IS NULL AND is_active = 1',
    whereArgs: <Object?>[session.tenantId],
    orderBy: 'full_name ASC, email ASC',
  );

  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (_) =>
        _PinAccountSwitchDialog(session: session, staffRows: staffRows),
  );
}

class _PinAccountSwitchDialog extends StatefulWidget {
  const _PinAccountSwitchDialog({
    required this.session,
    required this.staffRows,
  });

  final PosV2RuntimeSession session;
  final List<Map<String, Object?>> staffRows;

  @override
  State<_PinAccountSwitchDialog> createState() =>
      _PinAccountSwitchDialogState();
}

class _PinAccountSwitchDialogState extends State<_PinAccountSwitchDialog> {
  final _pinController = TextEditingController();
  final PosV2AuthService _authService = PosV2AuthService();
  String? _selectedEmail;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedEmail = widget.staffRows.isNotEmpty
        ? widget.staffRows.first['email']?.toString()
        : null;
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit({bool forceLogoutOtherSession = false}) async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSubmitting) {
      return;
    }

    if ((_selectedEmail ?? '').isEmpty || _pinController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = l10n.switchAccountIncomplete;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final selectedStaff = widget.staffRows.firstWhere(
        (row) => row['email']?.toString() == _selectedEmail,
        orElse: () => <String, Object?>{},
      );
      final staffRemoteId =
          selectedStaff['remote_id']?.toString() ??
          selectedStaff['id']?.toString();
      final staffRoleCode =
          selectedStaff['role_code']?.toString() ??
          selectedStaff['role_name']?.toString();

      await _authService.pinLoginAndSyncBootstrap(
        tenantBaseUrl: widget.session.baseUrl,
        email: _selectedEmail!,
        pin: _pinController.text.trim(),
        deviceId: widget.session.deviceId ?? 'FLINKPOS-V2-DEVICE',
        registerId: widget.session.registerId,
        staffId: staffRemoteId,
        staffRoleCode: staffRoleCode,
        actingStaffId: widget.session.staffId,
        forceLogoutOtherSession: forceLogoutOtherSession,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final errorMsg = error.toString().replaceFirst('Exception: ', '');
      if (!forceLogoutOtherSession &&
          errorMsg.toLowerCase().contains(
            'already has an active session on another device',
          )) {
        setState(() {
          _isSubmitting = false;
        });
        _showForceLogoutDialog();
      } else {
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showForceLogoutDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          loc.activeSessionTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.activeSessionMessage,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(loc.cancel),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _submit(forceLogoutOtherSession: true);
                        },
                        child: Text(loc.activeSessionForceLogout),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.switchAccountTitle),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.staffRows.isEmpty)
              Text(l10n.switchAccountNoCachedStaff)
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedEmail,
                items: widget.staffRows
                    .map((row) {
                      final email = row['email']?.toString() ?? '';
                      final fullName = row['full_name']?.toString();
                      final role =
                          row['role_name']?.toString() ??
                          row['role_code']?.toString() ??
                          '';
                      final label = [fullName, email]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' - ');
                      return DropdownMenuItem<String>(
                        value: email,
                        child: Text(label.isEmpty ? email : '$label ($role)'),
                      );
                    })
                    .toList(growable: false),
                decoration: InputDecoration(
                  labelText: l10n.switchAccountUserLabel,
                ),
                onChanged: (value) => setState(() => _selectedEmail = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.switchAccountPinLabel,
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: widget.staffRows.isEmpty || _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.switchAccountAction),
        ),
      ],
    );
  }
}
