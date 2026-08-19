import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/shift_history_item.dart';

class ShiftHistoryCard extends StatelessWidget {
  final ShiftHistoryItem shift;
  final VoidCallback onTap;
  final VoidCallback onPrint;
  final bool isPrinting;

  const ShiftHistoryCard({
    super.key,
    required this.shift,
    required this.onTap,
    required this.onPrint,
    this.isPrinting = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final compactDateFmt = DateFormat('dd MMM yy · HH:mm', 'id_ID');

    final isOpen = !shift.isClosed;

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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0.5,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isOpen
                  ? primaryColor.withValues(alpha: 0.4)
                  : const Color(0xFFE2E8F0),
              width: isOpen ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Cashier Avatar & Status Pill
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: isOpen
                          ? primaryColor.withValues(alpha: 0.12)
                          : const Color(0xFFF1F5F9),
                      child: Text(
                        staffInitials,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isOpen
                              ? primaryColor
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shift.staffName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shiftSubtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF64748B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOpen ? 'AKTIF' : 'SELESAI',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isOpen
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF475569),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // KPI Metric Tiles Grid (4 Tiles: 2x2 Grid)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            'Saldo Awal',
                            'Rp ${currencyFmt.format(shift.openingBalance)}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'Penjualan Tercatat',
                            'Rp ${currencyFmt.format(shift.totalShiftSales)}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            isOpen ? 'Kas Sistem' : 'Kas Aktual',
                            'Rp ${currencyFmt.format(isOpen ? shift.expectedCash : shift.actualCash)}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'Selisih Kas',
                            shift.formatVariance(currencyFmt),
                            valueColor: shift.varianceColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Footer Bar: Opened Time & Actions
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      compactDateFmt.format(shift.openedAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: isPrinting ? null : onPrint,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            if (isPrinting)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                ),
                              )
                            else
                              Icon(
                                Icons.print_outlined,
                                size: 13,
                                color: primaryColor,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              'Cetak',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          'Detail',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
