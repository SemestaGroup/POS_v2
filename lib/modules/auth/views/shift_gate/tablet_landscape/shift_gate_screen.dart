import 'package:flutter/material.dart';

import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../operations/shift/models/active_shift_store.dart';
import '../../../../../app/role_access/role_manager.dart';

class ShiftGateScreen extends StatefulWidget {
  const ShiftGateScreen({super.key});

  @override
  State<ShiftGateScreen> createState() => _ShiftGateScreenState();
}

class _ShiftGateScreenState extends State<ShiftGateScreen> {
  final _shiftNameController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _showShiftForm = false;

  @override
  void initState() {
    super.initState();
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    _shiftNameController.text = _defaultShiftName(session);
  }

  @override
  void dispose() {
    _shiftNameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _openShift() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSubmitting) return;
    final shiftName = _shiftNameController.text.trim();
    final openingBalance = int.tryParse(
      _openingBalanceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (shiftName.isEmpty || openingBalance == null) {
      setState(() => _errorMessage = l10n.shiftGateIncomplete);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ActiveShiftStore.instance.openShift(
        shiftName: shiftName,
        openingBalance: openingBalance,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _enterWithoutShift() {
    ActiveShiftStore.instance.enterReadOnlyMode();
  }

  String _defaultShiftName(PosV2RuntimeSession? session) {
    final rawName = session?.staffFullName?.trim().isNotEmpty == true
        ? session!.staffFullName!.trim()
        : session?.staffEmail?.split('@').first.trim();
    final firstName = (rawName ?? 'Staff').split(RegExp(r'\s+')).first.trim();
    final normalized = firstName.isEmpty ? 'Staff' : firstName;
    return 'Shift $normalized';
  }

  @override
  Widget build(BuildContext context) {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    final role = RoleManager.fromCode(session?.staffRoleCode);
    final isNonCashier = role != AppRole.cashier;
    if (isNonCashier) return _buildNonCashierIntentScreen(context, session);
    return _buildCashierShiftGate(context, session);
  }

  Widget _buildNonCashierIntentScreen(
    BuildContext context,
    PosV2RuntimeSession? session,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final name = session?.staffFullName ?? session?.staffEmail ?? '-';
    final roleLabel = RoleManager.roleToString(
      RoleManager.fromCode(session?.staffRoleCode),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, primary.withValues(alpha: 0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Halo, $name',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih tujuan masuk ke aplikasi',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _IntentOptionCard(
                      icon: Icons.visibility_outlined,
                      iconColor: Colors.indigo.shade400,
                      iconBg: Colors.indigo.shade50,
                      title: l10n.enterWithoutShift,
                      subtitle: l10n.enterWithoutShiftHint,
                      onTap: _enterWithoutShift,
                    ),
                    const SizedBox(height: 14),
                    _IntentOptionCard(
                      icon: Icons.point_of_sale_rounded,
                      iconColor: Colors.green.shade700,
                      iconBg: Colors.green.shade50,
                      title: l10n.openShiftAction,
                      subtitle:
                          'Buka shift baru dan mulai transaksi penjualan.',
                      onTap: () =>
                          setState(() => _showShiftForm = !_showShiftForm),
                      showChevron: true,
                    ),
                    if (_showShiftForm) ...[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _buildShiftForm(
                            context,
                            theme,
                            l10n,
                            showCancel: true,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (session != null)
                      Text(
                        '${l10n.deviceIdLabel}: ${session.deviceId ?? '-'}  •  ${l10n.locationLabel}: ${session.locationId}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCashierShiftGate(
    BuildContext context,
    PosV2RuntimeSession? session,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.point_of_sale_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.shiftGateTitle,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.shiftGateSubtitle,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.grey.shade700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (session != null) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.staffFullName ??
                                        session.staffEmail ??
                                        '-',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${l10n.deviceIdLabel}: ${session.deviceId ?? '-'}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${l10n.locationLabel}: ${session.locationId}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          _buildShiftForm(context, theme, l10n),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShiftForm(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n, {
    bool showCancel = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _shiftNameController,
          decoration: InputDecoration(labelText: l10n.shiftNameLabel),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _openingBalanceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.openingBalanceLabel),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _isSubmitting ? null : _openShift,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.openShiftAction),
        ),
        if (showCancel) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() {
              _showShiftForm = false;
              _errorMessage = null;
            }),
            child: const Text('Batal'),
          ),
        ],
      ],
    );
  }
}

class _IntentOptionCard extends StatelessWidget {
  const _IntentOptionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
