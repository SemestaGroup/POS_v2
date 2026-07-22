import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/services/local/database_service.dart';
import '../../../../../core/services/sync/pos_v2_auth_service.dart';
import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../../../../../core/services/sync/pos_v2_sync_queue_processor.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../app/auth/auth_gate.dart';
import '../../../../../app/role_access/role_manager.dart';
import 'add_staff_dialog.dart';

class SwitchStaffScreen extends StatefulWidget {
  const SwitchStaffScreen({super.key, this.lockedMode = false});

  final bool lockedMode;

  @override
  State<SwitchStaffScreen> createState() => _SwitchStaffScreenState();
}

class _SwitchStaffScreenState extends State<SwitchStaffScreen> {
  final PosV2AuthService _authService = PosV2AuthService();

  PosV2RuntimeSession? _session;
  List<Map<String, Object?>> _allStaffRows = [];
  bool _isLoading = true;
  bool _isLoggingOutLocation = false;
  int _pendingSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();

    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.loginRequiredMessage ??
                  'Login required',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    final staffRows = await DatabaseService.instance.query(
      'staff',
      where: 'tenant_id = ? AND deleted_at IS NULL AND is_active = 1',
      whereArgs: <Object?>[session.tenantId],
      orderBy: 'full_name ASC, email ASC',
    );
    
    final pendingCount = await PosV2SyncQueueProcessor.instance.getPendingSyncCount();

    if (mounted) {
      setState(() {
        _session = session;
        _allStaffRows = staffRows;
        _pendingSyncCount = pendingCount;
        _isLoading = false;
      });
    }
  }

  String _roleLabel(AppLocalizations l10n, AppRole role) {
    switch (role) {
      case AppRole.owner:
        return l10n.ownerRoleLabel;
      case AppRole.supervisor:
        return l10n.supervisorRoleLabel;
      case AppRole.cashier:
        return l10n.cashierRoleLabel;
      case AppRole.kitchen:
        return l10n.kitchenRoleLabel;
      case AppRole.programmer:
        return l10n.programmerRoleLabel;
    }
  }

  Future<void> _showPinDialog(Map<String, Object?> staffInfo) async {
    final email = staffInfo['email']?.toString();
    if (email == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PinKeypadDialog(
        staffInfo: staffInfo,
        session: _session!,
        authService: _authService,
        onSuccess: () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<void> _lockApp() async {
    if (!mounted || widget.lockedMode) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const SwitchStaffScreen(lockedMode: true),
      ),
    );
  }

  Future<void> _logoutLocation() async {
    if (_isLoggingOutLocation) {
      return;
    }

    final pendingCount = await PosV2SyncQueueProcessor.instance.getPendingSyncCount();

    if (!mounted) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade600,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Konfirmasi Keluar Lokasi',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 16),
                if (pendingCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sync_problem_rounded, color: Colors.orange.shade700, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Masih ada $pendingCount data yang belum tersinkronisasi. Pastikan sinkronisasi selesai sebelum keluar, atau data tersebut akan HILANG.',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'Semua data operasional lokal akan dihapus dari perangkat ini. Apakah Anda yakin ingin melanjutkan?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Ya, Keluar Lokasi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isLoggingOutLocation = true;
    });

    try {
      await _authService.logoutLocationAndClearLocalData(
        reason: 'Logout Location from switch staff screen',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
      setState(() {
        _isLoggingOutLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: !widget.lockedMode,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme, l10n),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCurrentSessionBanner(theme, l10n),
                        const SizedBox(height: 24),
                        Expanded(child: _buildStaffGrid(theme, l10n)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: [
        if (!widget.lockedMode) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.switchStaffTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.switchStaffSubtitle,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        const Spacer(),
        if (!widget.lockedMode) ...[
          OutlinedButton.icon(
            onPressed: _lockApp,
            icon: const Icon(Icons.lock_outline, color: Colors.orange),
            label: Text(
              l10n.switchStaffLockAppAction,
              style: const TextStyle(color: Colors.orange),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        if (_pendingSyncCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_problem_rounded, color: Colors.orange.shade700, size: 16),
                const SizedBox(width: 8),
                Text(
                  '$_pendingSyncCount belum sinkron',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() {
                    _isLoading = true;
                  });
                  try {
                    if (_session != null) {
                      await PosV2SyncOrchestrator().syncStaff(
                        _session!.toSyncContext(),
                      );
                    }
                    await _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.switchStaffSyncedMessage)),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                },
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.sync),
          label: Text(l10n.switchStaffSyncAction),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 42),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _isLoggingOutLocation ? null : _logoutLocation,
          icon: _isLoggingOutLocation
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.power_settings_new),
          label: Text(l10n.switchStaffLogoutLocationAction),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 42),
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSessionBanner(ThemeData theme, AppLocalizations l10n) {
    final currentStaffName =
        _session?.staffFullName ?? l10n.switchStaffNoCurrentSession;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                l10n.switchStaffCurrentSessionTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.person,
                      size: 32,
                      color: AppColors.primary,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentStaffName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      l10n.switchStaffSelectAccountPrompt,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              _buildFeatureInfo(
                l10n,
                icon: Icons.shield_outlined,
                title: l10n.switchStaffSecureTitle,
                subtitle: l10n.switchStaffSecureSubtitle,
              ),
              _buildFeatureInfo(
                l10n,
                icon: Icons.people_outline,
                title: l10n.switchStaffRoleAccessTitle,
                subtitle: l10n.switchStaffRoleAccessSubtitle,
              ),
              _buildFeatureInfo(
                l10n,
                icon: Icons.history_outlined,
                title: l10n.switchStaffAuditTitle,
                subtitle: l10n.switchStaffAuditSubtitle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureInfo(
    AppLocalizations l10n, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      flex: 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffGrid(ThemeData theme, AppLocalizations l10n) {
    final bool isOwner =
        RoleManager.fromCode(_session?.staffRoleCode) == AppRole.owner;

    int itemCount = _allStaffRows.length;
    if (isOwner) itemCount += 1;

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, // Fit more cards in a row to reduce huge sizes
              childAspectRatio: 0.95, // Make them a bit squarer
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (isOwner && index == _allStaffRows.length) {
                return _buildAddStaffCard(theme, l10n);
              }
              return _buildStaffCard(theme, l10n, _allStaffRows[index]);
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 24.0, bottom: 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.switchStaffPoweredBy,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffCard(
    ThemeData theme,
    AppLocalizations l10n,
    Map<String, Object?> staffInfo,
  ) {
    final name = staffInfo['full_name']?.toString() ?? '-';
    final roleCode = staffInfo['role_code']?.toString();
    final role = RoleManager.fromCode(roleCode);
    final roleName = _roleLabel(l10n, role).toUpperCase();
    final isCurrentStaff =
        !widget.lockedMode &&
        (_session?.staffId == staffInfo['remote_id']?.toString());

    // Use different gradients based on role
    final gradientColors = role == AppRole.owner
        ? [Colors.orange.shade300, Colors.orange.shade600]
        : [Colors.red.shade300, Colors.red.shade600];

    return InkWell(
      onTap: isCurrentStaff ? null : () => _showPinDialog(staffInfo),
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isCurrentStaff ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: isCurrentStaff ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isCurrentStaff
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
            border: Border.all(
              color: isCurrentStaff
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.grey.shade100,
              width: isCurrentStaff ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isCurrentStaff
                        ? [Colors.grey.shade400, Colors.grey.shade600]
                        : gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: isCurrentStaff
                      ? null
                      : [
                          BoxShadow(
                            color: gradientColors.last.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: const Icon(Icons.person, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (isCurrentStaff)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SEDANG AKTIF',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    roleName,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddStaffCard(ThemeData theme, AppLocalizations l10n) {
    return InkWell(
      onTap: () {
        if (_session == null) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AddStaffDialog(
            session: _session!,
            authService: _authService,
            onSuccess: () async {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Staf berhasil ditambahkan! Mengsinkronkan data...',
                  ),
                ),
              );
              setState(() {
                _isLoading = true;
              });
              try {
                await PosV2SyncOrchestrator().syncStaff(
                  _session!.toSyncContext(),
                );
                await _loadData();
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade50,
              ),
              child: const Icon(
                Icons.person_add_alt_1,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.switchStaffAddStaffAction,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.switchStaffOwnerOnly,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinKeypadDialog extends StatefulWidget {
  final Map<String, Object?> staffInfo;
  final PosV2RuntimeSession session;
  final PosV2AuthService authService;
  final VoidCallback onSuccess;

  const _PinKeypadDialog({
    required this.staffInfo,
    required this.session,
    required this.authService,
    required this.onSuccess,
  });

  @override
  State<_PinKeypadDialog> createState() => _PinKeypadDialogState();
}

class _PinKeypadDialogState extends State<_PinKeypadDialog> {
  static const int _maxPinLength = 12;

  String _pin = '';
  bool _isSubmitting = false;
  String? _errorMessage;

  void _onKeyTap(String key) {
    if (_isSubmitting) return;
    setState(() {
      _errorMessage = null;
      if (key == 'delete') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (key == 'clear') {
        _pin = '';
      } else {
        if (_pin.length < _maxPinLength) _pin += key;
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_pin.isEmpty) {
      setState(() => _errorMessage = l10n.switchStaffPinRequired);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final email = widget.staffInfo['email']?.toString() ?? '';
      await widget.authService.pinLoginAndSyncBootstrap(
        tenantBaseUrl: widget.session.baseUrl,
        email: email,
        pin: _pin,
        deviceId: widget.session.deviceId ?? 'FLINKPOS-V2-DEVICE',
        registerId: widget.session.registerId,
      );
      if (mounted) {
        Navigator.of(context).pop(); // close dialog
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _pin = ''; // clear pin on error
        });
      }
    }
  }

  Widget _buildKey(String text, {VoidCallback? onTap, IconData? icon}) {
    return InkWell(
      onTap: onTap ?? () => _onKeyTap(text),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: icon != null
            ? Icon(icon, size: 24, color: Colors.black87)
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name =
        widget.staffInfo['full_name']?.toString() ?? l10n.cashierRoleLabel;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(
                    width: 48,
                  ), // space to balance the close button
                  Expanded(
                    child: Text(
                      l10n.switchStaffEnterPinFor(name),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_pin.isEmpty)
                Text(
                  l10n.switchAccountPinLabel,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: List<Widget>.generate(_pin.length, (index) {
                    return Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    );
                  }),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const SizedBox(height: 16 + 18),
              ],
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: [
                  _buildKey('1'),
                  _buildKey('2'),
                  _buildKey('3'),
                  _buildKey('4'),
                  _buildKey('5'),
                  _buildKey('6'),
                  _buildKey('7'),
                  _buildKey('8'),
                  _buildKey('9'),
                  _buildKey('clear', icon: Icons.refresh),
                  _buildKey('0'),
                  _buildKey('delete', icon: Icons.backspace_outlined),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (_isSubmitting || _pin.isEmpty) ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          l10n.switchAccountAction,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
