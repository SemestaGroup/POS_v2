import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../stores/report_read_stores.dart';

class CashierReportLiteView extends StatefulWidget {
  const CashierReportLiteView({super.key});

  @override
  State<CashierReportLiteView> createState() => _CashierReportLiteViewState();
}

class _CashierReportLiteViewState extends State<CashierReportLiteView> {
  final CashierReportLiteStore _store = CashierReportLiteStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return ValueListenableBuilder<CashierReportLiteSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.paymentBreakdown.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.paymentBreakdown.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        final totalRevenue = snapshot.totalCash + snapshot.totalNonCash;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: snapshot.hasActiveShift
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_pin_rounded,
                        color: snapshot.hasActiveShift
                            ? const Color(0xFF10B981)
                            : Colors.grey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshot.hasActiveShift
                                ? snapshot.shiftName
                                : 'Tidak Ada Shift Aktif',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: snapshot.hasActiveShift
                                  ? const Color(0xFF111827)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (snapshot.hasActiveShift && snapshot.shiftOpenedAt != null)
                            Text(
                              'Dibuka: ${dateFmt.format(snapshot.shiftOpenedAt!)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ),
                    if (snapshot.hasActiveShift)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Saldo Awal',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                          ),
                          Text(
                            'Rp ${currencyFmt.format(snapshot.openingBalance)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _store.refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(foregroundColor: primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _card('Total Penjualan', 'Rp ${currencyFmt.format(totalRevenue)}', Icons.payments_rounded, primaryColor)),
                  const SizedBox(width: 10),
                  Expanded(child: _card('Transaksi', '${snapshot.totalTransactions}', Icons.receipt_long_rounded, const Color(0xFF8B5CF6))),
                  const SizedBox(width: 10),
                  Expanded(child: _card('Tunai', 'Rp ${currencyFmt.format(snapshot.totalCash)}', Icons.money_rounded, const Color(0xFF10B981))),
                  const SizedBox(width: 10),
                  Expanded(child: _card('Non-Tunai', 'Rp ${currencyFmt.format(snapshot.totalNonCash)}', Icons.credit_card_rounded, const Color(0xFF3B82F6))),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Breakdown Metode Pembayaran',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 14),
                    if (snapshot.paymentBreakdown.isEmpty)
                      Text(
                        'Belum ada breakdown pembayaran hari ini.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      )
                    else
                      ...snapshot.paymentBreakdown.map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                                ),
                              ),
                              Text(
                                '${row.count} tx',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Rp ${currencyFmt.format(row.amount)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: row.isCash ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
