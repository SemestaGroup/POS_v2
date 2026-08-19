import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../controllers/shift_history_controller.dart';
import '../../../models/shift_history_item.dart';
import '../../../widgets/shift_history_detail_modal.dart';
import '../../../widgets/shift_history_filter_bar.dart';

class ShiftHistoryTabletLandscapeView extends StatefulWidget {
  const ShiftHistoryTabletLandscapeView({super.key});

  @override
  State<ShiftHistoryTabletLandscapeView> createState() =>
      _ShiftHistoryTabletLandscapeViewState();
}

class _ShiftHistoryTabletLandscapeViewState
    extends State<ShiftHistoryTabletLandscapeView> {
  final ShiftHistoryController _controller = ShiftHistoryController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.load();
    });
  }

  void _openDetailModal(ShiftHistoryItem shift) {
    ShiftHistoryDetailModal.show(
      context,
      shift: shift,
      isPrinting: _controller.printingShiftId == shift.id,
      onPrint: () => _controller.printThermalReport(context, shift),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final currencyFmt = NumberFormat('#,###', 'id_ID');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final allRows = _controller.allRows;
            final filteredRows = _controller.filteredRows;

            final openCount = allRows.where((r) => !r.isClosed).length;
            final closedCount = allRows.where((r) => r.isClosed).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar Header for Tablet
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.history_toggle_off_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Riwayat Shift Kasir',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Histori sesi kasir & rekonsiliasi kas',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: _controller.load,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Refresh',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter Bar Segment
                Container(
                  height: 52,
                  color: Colors.white,
                  child: ShiftHistoryFilterBar(
                    selectedFilter: _controller.selectedFilter,
                    onFilterSelected: _controller.setFilter,
                    totalCount: allRows.length,
                    openCount: openCount,
                    closedCount: closedCount,
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Content Area in Expanded
                Expanded(
                  child: _controller.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : _controller.errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 48,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _controller.errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _controller.load,
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Coba Lagi'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : filteredRows.isEmpty
                              ? RefreshIndicator(
                                  onRefresh: _controller.load,
                                  child: ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.5,
                                        child: const Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.history_toggle_off_rounded,
                                                size: 56,
                                                color: Color(0xFF94A3B8),
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                'Belum ada riwayat shift',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Data riwayat shift akan muncul di sini.',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _controller.load,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(20),
                                    itemCount: filteredRows.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final shift = filteredRows[index];
                                      return _buildTabletCard(
                                        context: context,
                                        shift: shift,
                                        primaryColor: primaryColor,
                                        currencyFmt: currencyFmt,
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabletCard({
    required BuildContext context,
    required ShiftHistoryItem shift,
    required Color primaryColor,
    required NumberFormat currencyFmt,
  }) {
    final isOpen = !shift.isClosed;
    final statusColor =
        isOpen ? const Color(0xFF15803D) : const Color(0xFF475569);
    final statusBg =
        isOpen ? const Color(0xFFECFDF3) : const Color(0xFFF1F5F9);
    final compactDateFmt = DateFormat('dd MMM yy · HH:mm', 'id_ID');

    final staffInitials = shift.staffName.trim().isNotEmpty
        ? shift.staffName
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'KS';

    final shiftSubtitle = shift.shiftName +
        (shift.registerId != null && shift.registerId!.isNotEmpty
            ? ' · Reg #${shift.registerId}'
            : '');

    final isPrinting = _controller.printingShiftId == shift.id;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: () => _openDetailModal(shift),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isOpen
                  ? primaryColor.withValues(alpha: 0.35)
                  : const Color(0xFFE2E8F0),
              width: isOpen ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Staff info, Register ID, Status Pill
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: primaryColor.withValues(alpha: 0.10),
                    child: Text(
                      staffInitials,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.staffName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shiftSubtitle,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOpen ? 'AKTIF' : 'SELESAI',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFF0F3F7)),
              ),

              // Metrics Grid: 2 rows of 2 columns
              Row(
                children: [
                  Expanded(
                    child: _shiftCardMetric(
                      'Dibuka',
                      compactDateFmt.format(shift.openedAt),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _shiftCardMetric(
                      'Ditutup',
                      shift.closedAt == null
                          ? 'Masih berjalan'
                          : compactDateFmt.format(shift.closedAt!),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _shiftCardMetric(
                      'Saldo Awal',
                      'Rp ${currencyFmt.format(shift.openingBalance)}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _shiftCardMetric(
                      'Penjualan Tercatat',
                      'Rp ${currencyFmt.format(shift.totalShiftSales)}',
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _shiftCardMetric(
                      isOpen ? 'Kas Sistem' : 'Kas Aktual',
                      'Rp ${currencyFmt.format(isOpen ? shift.expectedCash : shift.actualCash)}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _shiftCardMetric(
                      'Selisih Kas',
                      shift.formatVariance(currencyFmt),
                      valueColor: shift.varianceColor,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Footer Bar: Detail Action & Print Button
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Lihat Ringkasan Shift',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: isPrinting
                        ? null
                        : () => _controller.printThermalReport(context, shift),
                    icon: isPrinting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined, size: 15),
                    label: Text(
                      isPrinting ? 'Mencetak...' : 'Cetak Struk',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shiftCardMetric(
    String label,
    String value, {
    Color? valueColor,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
