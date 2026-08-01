import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../stores/operations_read_stores.dart';

class CashFlowTabletLandscapeView extends StatefulWidget {
  const CashFlowTabletLandscapeView({super.key});

  @override
  State<CashFlowTabletLandscapeView> createState() =>
      _CashFlowTabletLandscapeViewState();
}

class _CashFlowTabletLandscapeViewState
    extends State<CashFlowTabletLandscapeView> {
  final CashFlowStore _store = CashFlowStore.instance;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh(startDate: _startDate, endDate: _endDate);
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _store.refresh(startDate: _startDate, endDate: _endDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final currencyFmt = NumberFormat('#,###', 'id_ID');

    return ValueListenableBuilder<CashFlowSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.entries.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.entries.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        final netBalance = snapshot.totalIn - snapshot.totalOut;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.swap_vert_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Arus Kas',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (_startDate != null && _endDate != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text(
                          '${DateFormat('dd MMM yyyy', 'id_ID').format(_startDate!)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(_endDate!)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onDeleted: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _store.refresh(startDate: null, endDate: null);
                        },
                        deleteIcon: const Icon(Icons.close, size: 14),
                        backgroundColor: Colors.grey.shade100,
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'today') {
                        final now = DateTime.now();
                        setState(() {
                          _startDate = DateTime(now.year, now.month, now.day);
                          _endDate = DateTime(now.year, now.month, now.day);
                        });
                        _store.refresh(
                          startDate: _startDate,
                          endDate: _endDate,
                        );
                      } else if (value == 'last7days') {
                        final now = DateTime.now();
                        setState(() {
                          _startDate = DateTime(
                            now.year,
                            now.month,
                            now.day,
                          ).subtract(const Duration(days: 6));
                          _endDate = DateTime(now.year, now.month, now.day);
                        });
                        _store.refresh(
                          startDate: _startDate,
                          endDate: _endDate,
                        );
                      } else if (value == 'thisMonth') {
                        final now = DateTime.now();
                        setState(() {
                          _startDate = DateTime(now.year, now.month, 1);
                          // last day of current month
                          _endDate = DateTime(now.year, now.month + 1, 0);
                        });
                        _store.refresh(
                          startDate: _startDate,
                          endDate: _endDate,
                        );
                      } else if (value == 'custom') {
                        await _selectDateRange();
                      }
                    },
                    color: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    offset: const Offset(0, 40),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'today',
                        child: Text('Hari Ini', style: TextStyle(fontSize: 13)),
                      ),
                      const PopupMenuItem(
                        value: 'last7days',
                        child: Text(
                          '7 Hari Terakhir',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'thisMonth',
                        child: Text(
                          'Bulan Ini',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'custom',
                        child: Text(
                          'Kustom Tanggal...',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 14,
                            color: Colors.black87,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Filter Tanggal',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _store.refresh(
                      startDate: _startDate,
                      endDate: _endDate,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(fontSize: 11),
                    ),
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
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _card(
                            'Total Masuk',
                            snapshot.totalIn,
                            Icons.arrow_downward_rounded,
                            const Color(0xFF10B981),
                            currencyFmt,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _card(
                            'Total Keluar',
                            snapshot.totalOut,
                            Icons.arrow_upward_rounded,
                            const Color(0xFFEF4444),
                            currencyFmt,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _card(
                            'Saldo Bersih',
                            netBalance,
                            Icons.account_balance_rounded,
                            primaryColor,
                            currencyFmt,
                          ),
                        ),
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
                      child: snapshot.entries.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  'Belum ada transaksi kas.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: snapshot.entries.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: Colors.grey.shade100,
                              ),
                              itemBuilder: (context, index) {
                                final entry = snapshot.entries[index];
                                final isIn = entry.type == 'in';
                                final color = isIn
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444);
                                final dateFmt = DateFormat(
                                  'dd MMM yyyy HH:mm',
                                  'id_ID',
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isIn
                                              ? Icons.arrow_downward_rounded
                                              : Icons.arrow_upward_rounded,
                                          color: color,
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.description,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF111827),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              dateFmt.format(entry.createdAt),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${isIn ? '+' : '-'} Rp ${currencyFmt.format(entry.amount)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(
    String label,
    int amount,
    IconData icon,
    Color color,
    NumberFormat fmt,
  ) {
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
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 3),
                Text(
                  'Rp ${fmt.format(amount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
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
