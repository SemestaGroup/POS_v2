import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../shared/models/sales_order_store.dart';
import '../../../../../../core/theme/app_colors.dart';

class PaymentReviewItemData {
  const PaymentReviewItemData({
    required this.name,
    required this.imageUrl,
    required this.quantity,
    required this.formattedLineTotal,
    required this.detailLine,
    required this.orderTypeLabel,
    this.discountLabel,
  });

  final String name;
  final String imageUrl;
  final int quantity;
  final String formattedLineTotal;
  final String detailLine;
  final String orderTypeLabel;
  final String? discountLabel;
}

class PosPaymentFlowPage extends StatefulWidget {
  const PosPaymentFlowPage({
    super.key,
    required this.snapshot,
    required this.orderTypeLabel,
    required this.customerName,
    required this.totalPayAmount,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.totalQuantity,
    required this.reviewItems,
    required this.onConfirm,
  });

  final SalesPaymentModeSnapshot snapshot;
  final String orderTypeLabel;
  final String customerName;
  final int totalPayAmount;
  final int subtotalAmount;
  final int discountAmount;
  final int totalQuantity;
  final List<PaymentReviewItemData> reviewItems;
  final Future<String?> Function(
    SalesPaymentModeOption option,
    int tenderAmount,
  )
  onConfirm;

  @override
  State<PosPaymentFlowPage> createState() => _PosPaymentFlowPageState();
}

class _PosPaymentFlowPageState extends State<PosPaymentFlowPage> {
  late SalesPaymentModeOption _selectedOption;
  int _tenderAmount = 0;
  String? _errorMessage;
  final TextEditingController _manualTenderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedOption = widget.snapshot.options.firstWhere(
      (opt) => opt.remoteId == widget.snapshot.preselectedRemoteId,
      orElse: () => widget.snapshot.options.first,
    );
    _tenderAmount = widget.totalPayAmount;
    _manualTenderController.text = _formatMoney(_tenderAmount);
  }

  @override
  void dispose() {
    _manualTenderController.dispose();
    super.dispose();
  }

  String _formatMoney(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  void _onMethodSelected(SalesPaymentModeOption option) {
    setState(() {
      _selectedOption = option;
      _errorMessage = null;
      // Reset tender amount to exact when switching methods
      _tenderAmount = widget.totalPayAmount;
      _manualTenderController.text = _formatMoney(
        _tenderAmount,
      ).replaceAll('Rp ', '').replaceAll('.', '');
    });
  }

  void _onTenderAmountSelected(int amount) {
    setState(() {
      final isCash = _selectedOption.name.toLowerCase().contains('cash') ||
                     _selectedOption.name.toLowerCase().contains('tunai');
      if (!isCash) {
        final cashOption = widget.snapshot.options.firstWhere(
          (opt) => opt.name.toLowerCase().contains('cash') || opt.name.toLowerCase().contains('tunai'),
          orElse: () => widget.snapshot.options.first,
        );
        _selectedOption = cashOption;
        _errorMessage = null;
      }
      _tenderAmount = amount;
      _manualTenderController.text = amount.toString();
    });
  }

  Future<void> _handleContinue() async {
    if (_tenderAmount < widget.totalPayAmount) {
      setState(() {
        _errorMessage = 'Tender amount cannot be less than total pay';
      });
      return;
    }
    setState(() => _errorMessage = null);
    await _showOrderConfirmationDialog();
  }

  Future<void> _showOrderConfirmationDialog() async {
    final changeAmount = (_tenderAmount - widget.totalPayAmount).clamp(
      0,
      1 << 31,
    );
    final reference = _buildOrderReference();

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        bool isProcessing = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF0FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Color(0xFF6366F1),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Konfirmasi Pesanan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1D2E),
                            ),
                          ),
                        ),
                        if (!isProcessing)
                          IconButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFFC4C7D0),
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nomor Pesanan\n$reference',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatMoney(widget.totalPayAmount),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1D2E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 90,
                          color: const Color(0xFFE5E7EB),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildConfirmationMetric(
                                icon: Icons.account_balance_wallet_outlined,
                                label: 'Metode Pembayaran',
                                value: _selectedOption.name,
                              ),
                              const SizedBox(height: 12),
                              _buildConfirmationMetric(
                                icon: Icons.payments_outlined,
                                label: 'Diterima',
                                value: _formatMoney(_tenderAmount),
                              ),
                              const SizedBox(height: 12),
                              _buildConfirmationMetric(
                                icon: Icons.keyboard_return_rounded,
                                label: 'Kembalian',
                                value: _formatMoney(changeAmount),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dialogError!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isProcessing
                                ? null
                                : () => Navigator.of(dialogCtx).pop(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: const Text(
                              'Batalkan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () async {
                                    setDialogState(() {
                                      isProcessing = true;
                                      dialogError = null;
                                    });
                                    final error = await widget.onConfirm(
                                      _selectedOption,
                                      _tenderAmount,
                                    );
                                    if (!ctx.mounted) return;
                                    if (error != null) {
                                      setDialogState(() {
                                        isProcessing = false;
                                        dialogError = error;
                                      });
                                    } else {
                                      Navigator.of(dialogCtx).pop();
                                      if (mounted) {
                                        await _showPaymentSuccessDialog(
                                          changeAmount: changeAmount,
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: isProcessing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined, size: 16),
                            label: Text(
                              isProcessing ? 'Memproses...' : 'Kirim',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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
      },
    );
  }

  Future<void> _showPaymentSuccessDialog({required int changeAmount}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 520,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop(true);
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFC4C7D0),
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(height: 4),
                // Success icon
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF0FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFF6366F1),
                        size: 38,
                      ),
                    ),
                    Positioned(
                      bottom: -6,
                      right: -6,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pembayaran Berhasil!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Jangan lupa ucapkan terima kasih kepada pelanggan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 24),
                // Info row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSuccessInfo(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Pembayaran',
                        value: _selectedOption.name,
                      ),
                      _buildSuccessInfo(
                        icon: Icons.receipt_outlined,
                        label: 'Total',
                        value: _formatMoney(widget.totalPayAmount),
                      ),
                      _buildSuccessInfo(
                        icon: Icons.payments_outlined,
                        label: 'Diterima',
                        value: _formatMoney(_tenderAmount),
                      ),
                      _buildSuccessInfo(
                        icon: Icons.keyboard_return_rounded,
                        label: 'Kembalian',
                        value: _formatMoney(changeAmount),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        icon: const Icon(
                          Icons.print_outlined,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        label: const Text(
                          'Cetak Label',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        icon: const Icon(
                          Icons.receipt_outlined,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        label: const Text(
                          'Cetak Struk',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'Selesai',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
  }

  Widget _buildSuccessInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1D2E),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF6366F1), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1D2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _buildOrderReference() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$day/$month/$year - $hour.$minute';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(theme, l10n),
              const SizedBox(height: 12),
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
                    children: [
                      _buildTopSummary(theme, l10n),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _buildLeftColumn(theme, l10n),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: _buildRightColumn(theme, l10n),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1D2E)),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF0FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Color(0xFF4C58CA),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Payment',
          style: TextStyle(
            color: Color(0xFF1A1D2E),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildTopSummary(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4FD),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFF6366F1),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatMoney(widget.totalPayAmount),
                      style: const TextStyle(
                        color: Color(0xFF5B61EA),
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: const Color(0xFFF3F4F6)),
          const SizedBox(width: 24),
          // Items
          Expanded(
            child: _buildSummaryMetric(
              icon: Icons.shopping_bag_outlined,
              iconColor: const Color(0xFF8B5CF6),
              iconBg: const Color(0xFFF3E8FF),
              label: 'Items',
              value: '${widget.totalQuantity} Items',
              valueColor: const Color(0xFF8B5CF6),
            ),
          ),
          // Discount
          Expanded(
            child: _buildSummaryMetric(
              icon: Icons.discount_outlined,
              iconColor: const Color(0xFFEF4444),
              iconBg: const Color(0xFFFEE2E2),
              label: 'Discount',
              value: '-${_formatMoney(widget.discountAmount)}',
              valueColor: const Color(0xFFEF4444),
            ),
          ),
          // Subtotal
          Expanded(
            child: _buildSummaryMetric(
              icon: Icons.receipt_outlined,
              iconColor: const Color(0xFF10B981),
              iconBg: const Color(0xFFD1FAE5),
              label: 'Subtotal',
              value: _formatMoney(widget.subtotalAmount),
              valueColor: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeftColumn(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Payment Methods Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: widget.snapshot.options
                .where(
                  (opt) =>
                      !(opt.name.toLowerCase().contains('cash') ||
                          opt.name.toLowerCase().contains('tunai')),
                )
                .map((opt) {
                  final isSelected = _selectedOption.remoteId == opt.remoteId;

                  // Determine colors based on name heuristics or just default
                  Color activeColor = const Color(0xFF3B82F6);
                  IconData methodIcon = Icons.payment_rounded;
                  if (opt.name.toLowerCase().contains('qris')) {
                    activeColor = const Color(0xFF8B5CF6);
                    methodIcon = Icons.qr_code_scanner_rounded;
                  } else if (opt.name.toLowerCase().contains('edc')) {
                    activeColor = const Color(0xFFF59E0B);
                    methodIcon = Icons.credit_card_rounded;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () => _onMethodSelected(opt),
                      borderRadius: BorderRadius.circular(30),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isSelected
                                ? activeColor
                                : const Color(0xFFE5E7EB),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: activeColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                methodIcon,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              opt.name,
                              style: TextStyle(
                                color: const Color(0xFF4B5563),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: activeColor,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: Colors.grey.shade300,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Selected Method Content
        Expanded(
          child: Builder(
            builder: (context) {
              final isCash = _selectedOption.name.toLowerCase().contains('cash') || 
                             _selectedOption.name.toLowerCase().contains('tunai');
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCash ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                    width: isCash ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                  onTap: () {
                    final cashOption = widget.snapshot.options.firstWhere(
                      (opt) => opt.name.toLowerCase().contains('cash') || opt.name.toLowerCase().contains('tunai'),
                      orElse: () => widget.snapshot.options.first,
                    );
                    _onMethodSelected(cashOption);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Cash',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1D2E),
                          ),
                        ),
                        const Spacer(),
                        if (_selectedOption.name.toLowerCase().contains('cash') || _selectedOption.name.toLowerCase().contains('tunai'))
                          const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF10B981))
                        else
                          Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey.shade300),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tender Amount Inputs (always visible as requested)
                _buildTenderGrid(),

                const Spacer(),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Continue Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF67B595),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue Transaction',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
         },
        ),
      ),
    ],
    );
  }

  Widget _buildTenderGrid() {
    final nominals = {
      widget.totalPayAmount,
      _nextThousands(widget.totalPayAmount, 50000),
      _nextThousands(widget.totalPayAmount, 100000),
    }.toList();

    if (nominals.length < 3) {
      nominals.add((nominals.last + 50000) ~/ 50000 * 50000);
    }

    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 4.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ...nominals.take(3).map((amount) => _buildNominalCard(amount)),
        _buildManualNominalCard(),
      ],
    );
  }

  int _nextThousands(int current, int multiple) {
    if (current == 0) return multiple;
    final remainder = current % multiple;
    if (remainder == 0) return current;
    return current + (multiple - remainder);
  }

  Widget _buildNominalCard(int amount) {
    final isCash =
        _selectedOption.name.toLowerCase().contains('cash') ||
        _selectedOption.name.toLowerCase().contains('tunai');
    final isSelected = isCash && _tenderAmount == amount;

    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        _onTenderAmountSelected(amount);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF0FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatMoney(amount),
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF4B5563),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualNominalCard() {
    final isCash =
        _selectedOption.name.toLowerCase().contains('cash') ||
        _selectedOption.name.toLowerCase().contains('tunai');
    final nominals = {
      widget.totalPayAmount,
      _nextThousands(widget.totalPayAmount, 50000),
      _nextThousands(widget.totalPayAmount, 100000),
    }.toList();
    if (nominals.length < 3) {
      nominals.add((nominals.last + 50000) ~/ 50000 * 50000);
    }
    final isCustomAmount =
        isCash &&
        _tenderAmount > 0 &&
        !nominals.take(3).contains(_tenderAmount);

    return InkWell(
      onTap: () async {
        FocusScope.of(context).unfocus();
        final result = await showDialog<int>(
          context: context,
          builder: (context) =>
              _NumpadDialog(initialAmount: isCustomAmount ? _tenderAmount : 0),
        );
        if (result != null) {
          _onTenderAmountSelected(result);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isCustomAmount ? const Color(0xFFEEF0FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCustomAmount
                ? const Color(0xFF6366F1)
                : const Color(0xFFE5E7EB),
            width: isCustomAmount ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isCustomAmount ? _formatMoney(_tenderAmount) : 'Custom Amount',
              style: TextStyle(
                color: isCustomAmount
                    ? const Color(0xFF6366F1)
                    : Colors.grey.shade400,
                fontWeight: isCustomAmount ? FontWeight.w700 : FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Icon(
              Icons.keyboard_alt_outlined,
              color: isCustomAmount
                  ? const Color(0xFF6366F1)
                  : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightColumn(ThemeData theme, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Review Order',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.reviewItems.length,
              separatorBuilder: (context, index) =>
                  Divider(color: Colors.grey.shade100, height: 32),
              itemBuilder: (context, index) {
                final item = widget.reviewItems[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: item.imageUrl.isEmpty
                          ? const Icon(
                              Icons.fastfood_rounded,
                              color: Colors.grey,
                            )
                          : CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const Icon(
                                Icons.image_not_supported_rounded,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF1A1D2E),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.detailLine,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Type : ${item.orderTypeLabel}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                          if (item.discountLabel != null)
                            Text(
                              item.discountLabel!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.formattedLineTotal,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF5B61EA),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _formatMoney(widget.totalPayAmount),
                      style: const TextStyle(
                        color: Color(0xFF5B61EA),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumpadDialog extends StatefulWidget {
  final int initialAmount;
  const _NumpadDialog({this.initialAmount = 0});

  @override
  State<_NumpadDialog> createState() => _NumpadDialogState();
}

class _NumpadDialogState extends State<_NumpadDialog> {
  String _value = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount > 0) {
      _value = widget.initialAmount.toString();
    }
  }

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'C') {
        _value = '';
      } else if (key == '<') {
        if (_value.isNotEmpty) {
          _value = _value.substring(0, _value.length - 1);
        }
      } else if (key == '000') {
        if (_value.isNotEmpty && _value.length < 10) {
          _value += '000';
        }
      } else {
        if (_value.length < 12) {
          _value += key;
        }
      }
    });
  }

  String _formatMoney(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentAmount = int.tryParse(_value) ?? 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Manual Input',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Center(
                child: Text(
                  _value.isEmpty ? 'Rp 0' : _formatMoney(currentAmount),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5B61EA),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildKeypadRow(['1', '2', '3']),
            const SizedBox(height: 8),
            _buildKeypadRow(['4', '5', '6']),
            const SizedBox(height: 8),
            _buildKeypadRow(['7', '8', '9']),
            const SizedBox(height: 8),
            _buildKeypadRow(['C', '0', '<']),
            const SizedBox(height: 8),
            _buildKeypadRow(['000']),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(currentAmount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: key != keys.last ? 12.0 : 0.0),
            child: InkWell(
              onTap: () => _onKeyPress(key),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: key == 'C'
                      ? const Color(0xFFFEE2E2)
                      : (key == '<' ? const Color(0xFFF3F4F6) : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Center(
                  child: key == '<'
                      ? const Icon(
                          Icons.backspace_rounded,
                          color: Color(0xFF4B5563),
                        )
                      : Text(
                          key,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: key == 'C'
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF1A1D2E),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
