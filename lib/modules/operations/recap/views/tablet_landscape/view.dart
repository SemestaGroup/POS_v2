import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../stores/operations_read_stores.dart';

class RecapView extends StatefulWidget {
  const RecapView({super.key});

  @override
  State<RecapView> createState() => _RecapViewState();
}

class _RecapViewState extends State<RecapView> {
  final RecapStore _store = RecapStore.instance;

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

    return ValueListenableBuilder<RecapSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.shifts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.shifts.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Rekap Shift',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _store.refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(foregroundColor: primaryColor),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _card('Total Transaksi', '${snapshot.totalTransactions}', Icons.receipt_long_rounded, primaryColor)),
                        const SizedBox(width: 10),
                        Expanded(child: _card('Total Pendapatan', 'Rp ${currencyFmt.format(snapshot.totalRevenue)}', Icons.payments_rounded, const Color(0xFF10B981))),
                        const SizedBox(width: 10),
                        Expanded(child: _card('Total Shift', '${snapshot.shifts.length}', Icons.access_time_rounded, const Color(0xFFF59E0B))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _shiftTable(snapshot, currencyFmt),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
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
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
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

  Widget _shiftTable(RecapSnapshot snapshot, NumberFormat currencyFmt) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    if (snapshot.shifts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'Belum ada riwayat shift.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFF9FAFB),
          child: const Row(
            children: [
              _ShiftHeader('Nama Shift', 3),
              _ShiftHeader('Staf', 2),
              _ShiftHeader('Dibuka', 3),
              _ShiftHeader('Ditutup', 3),
              _ShiftHeader('Saldo Awal', 2),
              _ShiftHeader('Status', 2),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade100),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.shifts.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade100),
          itemBuilder: (context, index) {
            final shift = snapshot.shifts[index];
            final isOpen = shift.status == 'open';
            return Container(
              color: index.isOdd ? Colors.transparent : const Color(0xFFFAFAFB),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  _ShiftCell(shift.shiftName, 3, bold: true),
                  _ShiftCell(shift.staffName, 2),
                  _ShiftCell(dateFmt.format(shift.openedAt), 3),
                  _ShiftCell(shift.closedAt != null ? dateFmt.format(shift.closedAt!) : '—', 3),
                  _ShiftCell('Rp ${currencyFmt.format(shift.openingBalance)}', 2),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOpen ? const Color(0xFFDBEAFE) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isOpen ? 'Open' : 'Closed',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isOpen ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ShiftHeader extends StatelessWidget {
  const _ShiftHeader(this.label, this.flex);

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
      ),
    );
  }
}

class _ShiftCell extends StatelessWidget {
  const _ShiftCell(this.value, this.flex, {this.bold = false});

  final String value;
  final int flex;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: const Color(0xFF374151),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
