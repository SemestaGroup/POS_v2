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

class _ShiftCloseViewState extends State<ShiftCloseView>
    with AutomaticKeepAliveClientMixin {
  final _actualCashController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingEstimate = true;
  String? _errorMessage;
  int _estimatedCash = 0;
  int _cashIn = 0;
  int _cashOut = 0;
  int _cashSales = 0;
  List<ShiftPaymentMethodRecapRecord> _paymentMethodRecaps =
      const <ShiftPaymentMethodRecapRecord>[];
  List<ShiftPaymentMethodRecapRecord> _dbRecaps =
      const <ShiftPaymentMethodRecapRecord>[];
  List<ShiftPaymentMethodRecapRecord> _availableModes = const <ShiftPaymentMethodRecapRecord>[];

  @override
  bool get wantKeepAlive => true;

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
    final store = ActiveShiftStore.instance;
    final estimate = await store.getEstimatedCashFromSqlite();
    final cashIn = await store.getShiftCashInTotal();
    final cashOut = await store.getShiftCashOutTotal();
    final cashSales = await store.getShiftCashSalesTotal();
    final recapRows = await store.getNonCashRecapFromSqlite();
    final available = await store.getAvailableNonCashPaymentModes();

    if (mounted) {
      setState(() {
        _estimatedCash = estimate;
        _cashIn = cashIn;
        _cashOut = cashOut;
        _cashSales = cashSales;
        _dbRecaps = recapRows;
        _availableModes = available;
        _paymentMethodRecaps =
            const <
              ShiftPaymentMethodRecapRecord
            >[]; // User requested empty by default
        _isLoadingEstimate = false;
      });
    }
  }

  int get _actualCash {
    final text = _actualCashController.text.replaceAll('.', '').trim();
    return int.tryParse(text) ?? 0;
  }

  int get _variance => _actualCash - _estimatedCash;

  int get _totalNonCash =>
      _paymentMethodRecaps.fold<int>(0, (sum, row) => sum + row.actualAmount);

  bool get _hasUnaddedTransactions {
    final addedIds = _paymentMethodRecaps.map((e) => e.remoteId).toSet();
    final availableIds = _availableModes.map((e) => e.remoteId).toSet();
    return _dbRecaps.any(
      (r) =>
          r.estimatedAmount > 0 &&
          r.remoteId.isNotEmpty &&
          availableIds.contains(r.remoteId) &&
          !addedIds.contains(r.remoteId),
    );
  }

  Future<void> _addPaymentMethodRecap() async {
    final l10n = AppLocalizations.of(context)!;
    final formatter = NumberFormat('#,###', 'id_ID');
    final availableModes = await ActiveShiftStore.instance
        .getAvailableNonCashPaymentModes();
    final nonCashRecaps = await ActiveShiftStore.instance
        .getNonCashRecapFromSqlite();

    final existingIds = _paymentMethodRecaps
        .map((row) => row.remoteId)
        .where((value) => value.isNotEmpty)
        .toSet();

    final choices = availableModes
        .where((mode) => !existingIds.contains(mode.remoteId))
        .map((mode) {
          final recap = nonCashRecaps
              .where((r) => r.remoteId == mode.remoteId)
              .firstOrNull;
          return ShiftPaymentMethodRecapRecord(
            remoteId: mode.remoteId,
            name: mode.name,
            estimatedAmount: recap?.estimatedAmount ?? 0,
            actualAmount: recap?.actualAmount ?? 0,
          );
        })
        .toList(growable: false);

    if (!mounted) {
      return;
    }
    if (choices.isEmpty) {
      setState(() {
        _errorMessage = l10n.shiftCloseNoAdditionalPaymentModes;
      });
      return;
    }

    final selected = await showDialog<ShiftPaymentMethodRecapRecord>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.add_card_rounded,
              color: Color(0xFF374151),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.shiftCloseAddPaymentMethodTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded, size: 20),
              color: Colors.grey.shade500,
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: choices.length,
            itemBuilder: (context, index) {
              final choice = choices[index];
              final primary = Theme.of(context).colorScheme.primary;
              final hasTransaction = choice.estimatedAmount > 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: hasTransaction
                      ? Colors.white
                      : const Color(0xFFF9FAFB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: hasTransaction
                          ? primary.withValues(alpha: 0.3)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(ctx).pop(choice),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: hasTransaction
                                  ? primary.withValues(alpha: 0.1)
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.credit_card_outlined,
                              size: 18,
                              color: hasTransaction
                                  ? primary
                                  : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  choice.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: hasTransaction
                                        ? const Color(0xFF111827)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasTransaction
                                      ? 'Estimasi: Rp ${formatter.format(choice.estimatedAmount)}'
                                      : 'Belum ada transaksi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: hasTransaction
                                        ? primary
                                        : Colors.grey.shade500,
                                    fontWeight: hasTransaction
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _paymentMethodRecaps = <ShiftPaymentMethodRecapRecord>[
        ..._paymentMethodRecaps,
        selected,
      ];
      _errorMessage = null;
    });
  }

  void _updatePaymentMethodAmount(int index, String rawValue) {
    final amount =
        int.tryParse(rawValue.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    setState(() {
      final rows = List<ShiftPaymentMethodRecapRecord>.from(
        _paymentMethodRecaps,
      );
      rows[index] = ShiftPaymentMethodRecapRecord(
        remoteId: rows[index].remoteId,
        name: rows[index].name,
        estimatedAmount: rows[index].estimatedAmount,
        actualAmount: amount,
      );
      _paymentMethodRecaps = rows;
    });
  }

  void _removePaymentMethodRecap(int index) {
    setState(() {
      final rows = List<ShiftPaymentMethodRecapRecord>.from(
        _paymentMethodRecaps,
      );
      rows.removeAt(index);
      _paymentMethodRecaps = rows;
    });
  }

  Future<void> _confirmAndClose(AppLocalizations l10n) async {
    if (_actualCashController.text.trim().isEmpty) {
      setState(
        () => _errorMessage =
            'Masukkan jumlah uang tunai aktual terlebih dahulu.',
      );
      return;
    }

    final formatter = NumberFormat('#,###', 'id_ID');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        actionsPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 12),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.exit_to_app_rounded, color: Colors.red.shade600, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Tutup Shift',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pastikan semua transaksi telah selesai dan uang kas telah dihitung dengan benar.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _confirmRow('Estimasi Kas', _estimatedCash, formatter),
                    _confirmRow('Kas Aktual', _actualCash, formatter),
                    if (_paymentMethodRecaps.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                      ),
                      _confirmRow(
                        l10n.shiftCloseNonCashSummaryLabel,
                        _totalNonCash,
                        formatter,
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                    ),
                    _confirmRow('Selisih', _variance, formatter, colored: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Batal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Konfirmasi',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
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
        totalNonCash: _totalNonCash,
        reconciliationJson: <String, dynamic>{
          'payment_modes': _paymentMethodRecaps
              .map(
                (row) => <String, dynamic>{
                  'payment_mode_remote_id': row.remoteId,
                  'payment_mode_name': row.name,
                  'estimated_amount': row.estimatedAmount,
                  'amount': row.actualAmount,
                },
              )
              .toList(growable: false),
        },
      );
      if (mounted) {
        _actualCashController.clear();
        setState(() {
          _isLoading = false;
          _estimatedCash = 0;
          _paymentMethodRecaps = const <ShiftPaymentMethodRecapRecord>[];
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
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
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
    super.build(context);

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
                  Icon(
                    Icons.lock_clock_outlined,
                    color: Colors.red.shade600,
                    size: 18,
                  ),
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
                    label: const Text(
                      'Refresh',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(foregroundColor: primary),
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
                    : _buildCloseForm(activeShift, primary, l10n, formatter),
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
            Icon(
              Icons.do_not_disturb_alt_rounded,
              size: 44,
              color: Colors.grey.shade300,
            ),
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
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                shift.shiftName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                shift.staffName,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  ExcludeSemantics(
                    child: Tooltip(
                      message:
                          'Dihitung dari transaksi cash di shift ini.\nNilai final ditentukan oleh server.',
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoadingEstimate)
                const SizedBox(
                  height: 28,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                Text(
                  'Rp ${formatter.format(_estimatedCash)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Modal Awal (Petty Cash)', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                          Text('Rp ${formatter.format(shift.openingBalance)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (_cashIn > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Kas Masuk', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                            Text('+Rp ${formatter.format(_cashIn)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                          ],
                        ),
                      ],
                      if (_cashOut > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Kas Keluar (Pengeluaran)', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                            Text('-Rp ${formatter.format(_cashOut)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFE11D48))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Penjualan Tunai (Cash Sales)', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                          Text('Rp ${formatter.format(_cashSales)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Kas tunai yang harus ada di laci (Modal Awal + Kas Masuk + Penjualan Tunai - Kas Keluar).',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Non-Cash Payment Recap ────────────────────────────────────
        Row(
          children: [
            const Icon(
              Icons.payments_outlined,
              size: 18,
              color: Color(0xFF374151),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.shiftCloseAddPaymentMethodTitle,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: _addPaymentMethodRecap,
              icon: const Icon(Icons.add_rounded, size: 14),
              label: Text(
                l10n.shiftCloseAddPaymentMethodAction,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_hasUnaddedTransactions)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Terdapat metode pembayaran non-tunai yang belum Anda periksa aktualnya. Silakan tambahkan.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF92400E),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_paymentMethodRecaps.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.grey.shade200,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 28,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.shiftCloseNoPaymentMethodRecap,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else ...[
          ...List<Widget>.generate(_paymentMethodRecaps.length, (index) {
            final row = _paymentMethodRecaps[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.credit_card_outlined,
                      size: 18,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Estimasi POS: Rp ${formatter.format(row.estimatedAmount)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      initialValue: row.actualAmount > 0
                          ? row.actualAmount.toString()
                          : '',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) =>
                          _updatePaymentMethodAmount(index, value),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Nominal Aktual',
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                        hintText: row.estimatedAmount > 0
                            ? row.estimatedAmount.toString()
                            : '0',
                        prefixText: 'Rp  ',
                        prefixStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                          borderSide: BorderSide(color: primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removePaymentMethodRecap(index),
                    icon: Icon(
                      Icons.remove_circle_outline_rounded,
                      color: Colors.red.shade400,
                      size: 20,
                    ),
                    tooltip: 'Hapus Metode',
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${l10n.shiftCloseNonCashSummaryLabel}: Rp ${formatter.format(_totalNonCash)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Uang Tunai Aktual *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            Row(
              children: [
                InkWell(
                  onTap: () {
                    _actualCashController.text = _estimatedCash.toString();
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_copy_rounded, size: 11, color: primary),
                        const SizedBox(width: 4),
                        Text(
                          'Isi Total Laci (Rp ${formatter.format(_estimatedCash)})',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _actualCashController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(
              Icons.account_balance_wallet_outlined,
              size: 16,
              color: Colors.grey.shade400,
            ),
            prefixText: 'Rp  ',
            prefixStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
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
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hitung seluruh uang tunai fisik di laci kasir (Sisa Petty Cash + Penjualan Tunai) lalu masukkan jumlahnya.',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),

        // ── Variance Display ──────────────────────────────────────────
        if (_actualCashController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _variance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                  ),
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
            onPressed: _isLoading ? null : () => _confirmAndClose(l10n),
            icon: _isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  )
                : const Icon(Icons.lock_rounded, size: 16),
            label: Text(
              _isLoading ? 'Menutup shift...' : 'Tutup Shift',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 10, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}
