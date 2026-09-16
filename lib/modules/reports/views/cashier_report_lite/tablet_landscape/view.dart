import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../operations/shift/controllers/shift_history_controller.dart';
import '../../../../operations/shift/models/shift_history_item.dart';
import '../../../../operations/shift/widgets/shift_history_detail_modal.dart';
import '../../../../sales/orders/shared/orders_history_sync_service.dart';
import '../../../stores/report_read_stores.dart';

class CashierReportLiteTabletLandscapeView extends StatefulWidget {
  const CashierReportLiteTabletLandscapeView({super.key});

  @override
  State<CashierReportLiteTabletLandscapeView> createState() =>
      _CashierReportLiteTabletLandscapeViewState();
}

class _CashierReportLiteTabletLandscapeViewState
    extends State<CashierReportLiteTabletLandscapeView> {
  final CashierReportLiteStore _store = CashierReportLiteStore.instance;
  final ShiftHistoryController _shiftController =
      ShiftHistoryController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
    });
  }

  Future<void> _syncHistoryAndRefresh({
    String? period,
    DateTimeRange? customRange,
  }) async {
    unawaited(OrdersHistorySyncService.instance.ensureSynced());
    await _store.refresh(period: period, customDateRange: customRange);
  }

  Future<void> _pickCustomDateRange(CashierReportLiteSnapshot snapshot) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: snapshot.customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null && mounted) {
      await _syncHistoryAndRefresh(period: 'custom', customRange: picked);
    }
  }

  void _openDetailModal(ShiftHistoryItem shift) {
    ShiftHistoryDetailModal.show(
      context,
      shift: shift,
      isPrinting: _shiftController.printingShiftId == shift.id,
      onPrint: () => _shiftController.printThermalReport(context, shift),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final shortDateFmt = DateFormat('dd/MM/yyyy', 'id_ID');
    final timeFmt = DateFormat('HH:mm', 'id_ID');

    return ValueListenableBuilder<CashierReportLiteSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.rows.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.rows.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  snapshot.errorMessage!,
                  style: TextStyle(color: Colors.red.shade600, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _syncHistoryAndRefresh(
                    period: snapshot.period,
                    customRange: snapshot.customDateRange,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          );
        }

        final totalRevenue = snapshot.totalCash + snapshot.totalNonCash;

        return Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Period Filter Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    _buildPeriodChip('Hari Ini', 'today', primaryColor, snapshot),
                    const SizedBox(width: 8),
                    _buildPeriodChip('7 Hari', 'week', primaryColor, snapshot),
                    const SizedBox(width: 8),
                    _buildPeriodChip('Bulan Ini', 'month', primaryColor, snapshot),
                    const SizedBox(width: 10),
                    _buildCustomDateChip(primaryColor, snapshot, shortDateFmt),
                    const Spacer(),
                    InkWell(
                      onTap: () => _syncHistoryAndRefresh(
                        period: snapshot.period,
                        customRange: snapshot.customDateRange,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: 16, color: primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'Sinkron Data',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Summary Metric Card
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    children: [
                      _buildStrip(
                        'Total Penjualan',
                        'Rp ${currencyFmt.format(totalRevenue)}',
                        primaryColor,
                      ),
                      _buildStripDivider(),
                      _buildStrip(
                        'Total Transaksi',
                        '${snapshot.totalTransactions} tx',
                        const Color(0xFF1E293B),
                      ),
                      _buildStripDivider(),
                      _buildStrip(
                        'Penjualan Tunai',
                        'Rp ${currencyFmt.format(snapshot.totalCash)}',
                        const Color(0xFF047857),
                      ),
                      _buildStripDivider(),
                      _buildStrip(
                        'Penjualan Non-Tunai',
                        'Rp ${currencyFmt.format(snapshot.totalNonCash)}',
                        const Color(0xFF1D4ED8),
                      ),
                      _buildStripDivider(),
                      _buildStrip(
                        'Net Selisih Kas',
                        _formatNetVariance(snapshot.totalVariance, currencyFmt),
                        _varianceColor(snapshot.totalVariance),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Table Container (Header + List inside unified card)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(11),
                            ),
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: const Row(
                            children: [
                              _HeaderCell('Waktu Shift', 12),
                              _HeaderCell('Kasir & Shift', 16),
                              _HeaderCell('Kas Awal', 10, alignEnd: true),
                              _HeaderCell('Tunai', 10, alignEnd: true),
                              _HeaderCell('Non-Tunai', 10, alignEnd: true),
                              _HeaderCell('Total Omzet', 11, alignEnd: true),
                              _HeaderCell('Status / Selisih', 14, center: true),
                              _HeaderCell('', 3, alignEnd: true),
                            ],
                          ),
                        ),

                        // Table Body
                        Expanded(
                          child: snapshot.rows.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 40,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Belum ada data shift kasir pada periode ini.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: snapshot.rows.length,
                                  separatorBuilder: (_, _) => Divider(
                                    height: 1,
                                    color: Colors.grey.shade100,
                                  ),
                                  itemBuilder: (context, index) {
                                    final row = snapshot.rows[index];
                                    final shift = row.shiftItem;
                                    final isClosed = shift.isClosed;
                                    final openedTime =
                                        timeFmt.format(shift.openedAt);
                                    final closedTime = shift.closedAt != null
                                        ? timeFmt.format(shift.closedAt!)
                                        : 'Sekarang';
                                    final cleanStaffName = shift.staffName
                                        .replaceAll(RegExp(r'\s*-\s*$'), '')
                                        .trim();

                                    return Material(
                                      color: index.isOdd
                                          ? const Color(0xFFFBFBFD)
                                          : Colors.white,
                                      child: InkWell(
                                        onTap: () {
                                          _openDetailModal(shift);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              // Waktu Shift
                                            Expanded(
                                              flex: 12,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    shortDateFmt
                                                        .format(shift.openedAt),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '$openedTime - $closedTime',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Kasir & Shift
                                            Expanded(
                                              flex: 16,
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 15,
                                                    backgroundColor: primaryColor
                                                        .withValues(alpha: 0.10),
                                                    child: Text(
                                                      cleanStaffName.isNotEmpty
                                                          ? cleanStaffName[0]
                                                              .toUpperCase()
                                                          : 'K',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          cleanStaffName.isNotEmpty
                                                              ? cleanStaffName
                                                              : 'Kasir',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: Color(
                                                                0xFF0F172A),
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(height: 1),
                                                        Text(
                                                          shift.shiftName
                                                                  .isNotEmpty
                                                              ? shift.shiftName
                                                              : 'Shift',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey.shade600,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Kas Awal (Right-aligned)
                                            Expanded(
                                              flex: 10,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  'Rp ${currencyFmt.format(shift.openingBalance)}',
                                                  textAlign: TextAlign.end,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Tunai (Right-aligned)
                                            Expanded(
                                              flex: 10,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  'Rp ${currencyFmt.format(shift.cashSales)}',
                                                  textAlign: TextAlign.end,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Non-Tunai (Right-aligned)
                                            Expanded(
                                              flex: 10,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Text(
                                                  'Rp ${currencyFmt.format(shift.totalNonCash)}',
                                                  textAlign: TextAlign.end,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Total Omzet (Right-aligned)
                                            Expanded(
                                              flex: 11,
                                              child: Align(
                                                alignment: Alignment.centerRight,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      'Rp ${currencyFmt.format(row.totalSales)}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      '${row.totalOrders} tx',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors.grey.shade500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Status / Rekonsiliasi
                                            Expanded(
                                              flex: 14,
                                              child: Center(
                                                child: _buildVarianceBadge(
                                                  shift: shift,
                                                  isClosed: isClosed,
                                                  currencyFmt: currencyFmt,
                                                ),
                                              ),
                                            ),
                                            // Action Chevron
                                            Expanded(
                                              flex: 3,
                                              child: Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.grey.shade100,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.chevron_right_rounded,
                                                    size: 16,
                                                    color:
                                                        Colors.grey.shade600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodChip(
    String label,
    String value,
    Color primaryColor,
    CashierReportLiteSnapshot snapshot,
  ) {
    final isActive = snapshot.period == value;
    return InkWell(
      onTap: () => _syncHistoryAndRefresh(period: value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primaryColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? primaryColor : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateChip(
    Color primaryColor,
    CashierReportLiteSnapshot snapshot,
    DateFormat shortDateFmt,
  ) {
    final isCustom = snapshot.period == 'custom';
    final label = isCustom && snapshot.customDateRange != null
        ? '${shortDateFmt.format(snapshot.customDateRange!.start)} - ${shortDateFmt.format(snapshot.customDateRange!.end)}'
        : 'Pilih Rentang';

    return InkWell(
      onTap: () => _pickCustomDateRange(snapshot),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isCustom ? primaryColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isCustom ? primaryColor : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: isCustom ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isCustom ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrip(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStripDivider() {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: const Color(0xFFE2E8F0),
    );
  }
  Widget _buildVarianceBadge({
    required ShiftHistoryItem shift,
    required bool isClosed,
    required NumberFormat currencyFmt,
  }) {
    if (!isClosed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 6, color: Color(0xFF059669)),
            SizedBox(width: 5),
            Text(
              'Berjalan',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      );
    }

    final variance = shift.variance;
    final Color bg;
    final Color border;
    final Color text;
    final String label;

    if (variance == 0) {
      bg = const Color(0xFFF8FAFC);
      border = const Color(0xFFE2E8F0);
      text = const Color(0xFF64748B);
      label = 'Pas';
    } else if (variance < 0) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      text = const Color(0xFFDC2626);
      label = '-Rp ${currencyFmt.format(variance.abs())}';
    } else {
      bg = const Color(0xFFEFF6FF);
      border = const Color(0xFFBFDBFE);
      text = const Color(0xFF2563EB);
      label = '+Rp ${currencyFmt.format(variance)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: -0.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
  String _formatNetVariance(int variance, NumberFormat currencyFmt) {
    if (variance == 0) return 'Pas';
    if (variance < 0) {
      return '-Rp ${currencyFmt.format(variance.abs())}';
    }
    return '+Rp ${currencyFmt.format(variance)}';
  }

  Color _varianceColor(int variance) {
    if (variance == 0) return const Color(0xFF64748B);
    if (variance < 0) return const Color(0xFFDC2626);
    return const Color(0xFF2563EB);
  }

}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.label,
    this.flex, {
    this.alignEnd = false,
    this.center = false,
  });

  final String label;
  final int flex;
  final bool alignEnd;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final alignment = center
        ? Alignment.center
        : alignEnd
            ? Alignment.centerRight
            : Alignment.centerLeft;

    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF334155),
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
