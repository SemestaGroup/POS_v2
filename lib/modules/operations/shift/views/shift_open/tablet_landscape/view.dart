import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../models/active_shift_store.dart';

class ShiftOpenView extends StatefulWidget {
  const ShiftOpenView({super.key});

  @override
  State<ShiftOpenView> createState() => _ShiftOpenViewState();
}

class _ShiftOpenViewState extends State<ShiftOpenView> {
  final _shiftNameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    ActiveShiftStore.instance.refresh();
  }

  @override
  void dispose() {
    _shiftNameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _openShift() async {
    final l10n = AppLocalizations.of(context)!;
    final shiftName = _shiftNameController.text.trim();
    final balanceText = _openingBalanceController.text.replaceAll('.', '').trim();
    final openingBalance = int.tryParse(balanceText) ?? 0;

    if (shiftName.isEmpty) {
      setState(() => _errorMessage = l10n.shiftGateIncomplete);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ActiveShiftStore.instance.openShift(
        shiftName: shiftName,
        openingBalance: openingBalance,
      );
      if (mounted) {
        _shiftNameController.clear();
        _openingBalanceController.clear();
        setState(() {
          _isLoading = false;
          _errorMessage = null;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<ActiveShiftRecord?>(
      valueListenable: ActiveShiftStore.instance.activeShiftNotifier,
      builder: (context, activeShift, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Bar ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    activeShift != null ? 'Buka Shift Baru' : l10n.shiftGateTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            
            // ── Content ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Active Shift Card ────────────────────────────────────────
                    if (activeShift != null) ...[
                      _buildActiveShiftCard(activeShift, theme, primaryColor, l10n),
                      const SizedBox(height: 24),
                    ],

                    // ── Open Shift Form ─────────────────────────────────────────
                    _buildOpenShiftForm(theme, primaryColor, l10n, activeShift),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveShiftCard(
    ActiveShiftRecord shift,
    ThemeData theme,
    Color primaryColor,
    AppLocalizations l10n,
  ) {
    final now = DateTime.now();
    final duration = now.difference(shift.openedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final formatter = NumberFormat('#,###', 'id_ID');
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'SHIFT AKTIF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            shift.shiftName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            shift.staffName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildShiftInfoChip(
                Icons.schedule_rounded,
                'Dibuka: ${dateFormatter.format(shift.openedAt)}',
              ),
              const SizedBox(width: 10),
              _buildShiftInfoChip(
                Icons.timer_rounded,
                '${hours}j ${minutes}m berjalan',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildShiftInfoChip(
                Icons.account_balance_wallet_rounded,
                'Saldo Awal: Rp ${formatter.format(shift.openingBalance)}',
              ),
              if (shift.registerId != null) ...[
                const SizedBox(width: 10),
                _buildShiftInfoChip(
                  Icons.point_of_sale_rounded,
                  'Register: ${shift.registerId}',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenShiftForm(
    ThemeData theme,
    Color primaryColor,
    AppLocalizations l10n,
    ActiveShiftRecord? activeShift,
  ) {
    final session = PosV2RuntimeSessionStore.instance.currentSession;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Form fields
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location info (read-only)
                if (session != null) ...[
                  _buildInfoRow(
                    icon: Icons.store_rounded,
                    label: l10n.locationLabel,
                    value: session.tenantName ?? '-',
                    color: primaryColor,
                  ),
                  const SizedBox(height: 16),
                ],

                // Shift name
                _buildLabel('Nama Shift', required: true),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _shiftNameController,
                  decoration: _inputDecoration(
                    hint: 'Contoh: Shift Pagi',
                    icon: Icons.badge_outlined,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Opening balance
                _buildLabel(l10n.openingBalanceLabel),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _openingBalanceController,
                  decoration: _inputDecoration(
                    hint: '0',
                    icon: Icons.account_balance_wallet_outlined,
                    prefix: 'Rp',
                  ),
                  style: const TextStyle(fontSize: 13),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 4),
                Text(
                  'Jumlah uang tunai yang ada di laci kasir saat shift dimulai.',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red.shade600,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _openShift,
                    icon: _isLoading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          )
                        : const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: Text(
                      _isLoading ? 'Membuka shift...' : l10n.openShiftAction,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        if (required) ...[
          const SizedBox(width: 2),
          const Text('*', style: TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
      prefixIcon: Icon(icon, size: 16, color: Colors.grey.shade400),
      prefixText: prefix != null ? '$prefix  ' : null,
      prefixStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }
}
