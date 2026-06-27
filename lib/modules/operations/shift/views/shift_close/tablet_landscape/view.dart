import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../models/active_shift_store.dart';

class ShiftCloseView extends StatefulWidget {
  const ShiftCloseView({super.key});

  @override
  State<ShiftCloseView> createState() => _ShiftCloseViewState();
}

class _ShiftCloseViewState extends State<ShiftCloseView> {
  final _actualCashController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingEstimate = true;
  String? _errorMessage;
  int _estimatedCash = 0;

  @override
  void initState() {
    super.initState();
    _loadEstimatedCash();
  }

  @override
  void dispose() {
    _actualCashController.dispose();
    super.dispose();
  }

  Future<void> _loadEstimatedCash() async {
    setState(() => _isLoadingEstimate = true);
    final estimate =
        await ActiveShiftStore.instance.getEstimatedCashFromSqlite();
    if (mounted) {
      setState(() {
        _estimatedCash = estimate;
        _isLoadingEstimate = false;
      });
    }
  }

  int get _actualCash {
    final text = _actualCashController.text.replaceAll('.', '').trim();
    return int.tryParse(text) ?? 0;
  }

  int get _variance => _actualCash - _estimatedCash;

  Future<void> _confirmAndClose(AppLocalizations l10n) async {
    if (_actualCashController.text.trim().isEmpty) {
      setState(() =>
          _errorMessage =
              'Masukkan jumlah uang tunai aktual terlebih dahulu.');
      return;
    }

    final formatter = NumberFormat('#,###', 'id_ID');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Konfirmasi Tutup Shift',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pastikan semua transaksi sudah selesai sebelum menutup shift.',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.5),
            ),
            const SizedBox(height: 12),
            _confirmRow('Estimasi Kas', _estimatedCash, formatter),
            _confirmRow('Kas Aktual', _actualCash, formatter),
            _confirmRow('Selisih', _variance, formatter, colored: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(fontSize: 12)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tutup Shift',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ActiveShiftStore.instance.closeShift(
        actualCash: _actualCash,
        expectedCash: _estimatedCash,
      );
      if (mounted) {
        _actualCashController.clear();
        setState(() {
          _isLoading = false;
          _estimatedCash = 0;
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

  Widget _confirmRow(
    String label,
    int amount,
    NumberFormat formatter, {
    bool colored = false,
  }) {
    Color? color;
    if (colored) {
      color = _variance >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280))),
          Text(
            'Rp ${formatter.format(amount)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color ?? const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;
    final formatter = NumberFormat('#,###', 'id_ID');

    return ValueListenableBuilder<ActiveShiftRecord?>(
      valueListenable: ActiveShiftStore.instance.activeShiftNotifier,
      builder: (context, activeShift, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.lock_clock_outlined,
                      color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Tutup Shift',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _loadEstimatedCash,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Refresh',
                        style: TextStyle(fontSize: 11)),
                    style:
                        TextButton.styleFrom(foregroundColor: primary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),

            // ── Content ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: activeShift == null
                    ? _buildNoShift()
                    : _buildCloseForm(
                        activeShift, primary, l10n, formatter),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoShift() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.do_not_disturb_alt_rounded,
                size: 44, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Tidak ada shift aktif saat ini.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              'Buka shift terlebih dahulu dari menu Shift.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseForm(
    ActiveShiftRecord shift,
    Color primary,
    AppLocalizations l10n,
    NumberFormat formatter,
  ) {
    final now = DateTime.now();
    final duration = now.difference(shift.openedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Shift Card ────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SHIFT AKTIF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${hours}j ${minutes}m berjalan',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                shift.shiftName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                shift.staffName,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(
                    Icons.account_balance_wallet_outlined,
                    'Saldo Awal: Rp ${formatter.format(shift.openingBalance)}',
                  ),
                  if (shift.registerId != null)
                    _chip(
                      Icons.point_of_sale_rounded,
                      'Register: ${shift.registerId}',
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Cash Summary ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Estimasi Kas Tunai',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message:
                        'Dihitung dari transaksi cash di shift ini.\nNilai final ditentukan oleh server.',
                    child: Icon(Icons.info_outline_rounded,
                        size: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoadingEstimate)
                const SizedBox(
                  height: 28,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                Text(
                  'Rp ${formatter.format(_estimatedCash)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Jumlah kas tunai yang seharusnya ada di laci berdasarkan transaksi tercatat.',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    height: 1.4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Actual Cash Input ─────────────────────────────────────────
        const Text(
          'Uang Tunai Aktual *',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _actualCashController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(
                color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(
                Icons.account_balance_wallet_outlined,
                size: 16,
                color: Colors.grey.shade400),
            prefixText: 'Rp  ',
            prefixStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hitung uang tunai fisik di laci kasir lalu masukkan jumlahnya.',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),

        // ── Variance Display ──────────────────────────────────────────
        if (_actualCashController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _variance >= 0
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _variance >= 0
                    ? Colors.green.shade200
                    : Colors.red.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _variance >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: _variance >= 0
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _variance == 0
                            ? 'Kas sesuai — tidak ada selisih'
                            : _variance > 0
                                ? 'Kas lebih Rp ${formatter.format(_variance.abs())}'
                                : 'Kas kurang Rp ${formatter.format(_variance.abs())}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _variance >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      if (_variance != 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          _variance > 0
                              ? 'Kas fisik lebih besar dari estimasi transaksi.'
                              : 'Kas fisik lebih kecil dari estimasi transaksi. Periksa kembali.',
                          style: TextStyle(
                            fontSize: 10,
                            color: _variance >= 0
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Error Message ─────────────────────────────────────────────
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: Colors.red.shade600, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMessage!,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ── Submit Button ─────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _isLoading ? null : () => _confirmAndClose(l10n),
            icon: _isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          Colors.white.withValues(alpha: 0.8),
                    ),
                  )
                : const Icon(Icons.lock_rounded, size: 16),
            label: Text(
              _isLoading ? 'Menutup shift...' : 'Tutup Shift',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF374151))),
        ],
      ),
    );
  }
}
