import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../stores/operations_read_stores.dart';

/// Phone-first cash-flow presentation. It intentionally consumes the existing
/// [CashFlowStore] only; no cash-flow calculation or persistence lives here.
class CashFlowMobileView extends StatefulWidget {
  const CashFlowMobileView({super.key});

  @override
  State<CashFlowMobileView> createState() => _CashFlowMobileViewState();
}

class _CashFlowMobileViewState extends State<CashFlowMobileView> {
  final CashFlowStore _store = CashFlowStore.instance;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() =>
      _store.refresh(startDate: _startDate, endDate: _endDate);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday =>
      _startDate != null &&
      _endDate != null &&
      DateUtils.isSameDay(_startDate, _today) &&
      DateUtils.isSameDay(_endDate, _today);

  bool get _isLastSevenDays =>
      _startDate != null &&
      _endDate != null &&
      DateUtils.isSameDay(
        _startDate,
        _today.subtract(const Duration(days: 6)),
      ) &&
      DateUtils.isSameDay(_endDate, _today);

  bool get _isThisMonth =>
      _startDate != null &&
      _endDate != null &&
      DateUtils.isSameDay(_startDate, DateTime(_today.year, _today.month, 1)) &&
      DateUtils.isSameDay(_endDate, DateTime(_today.year, _today.month + 1, 0));

  Future<void> _applyRange(DateTime? startDate, DateTime? endDate) async {
    setState(() {
      _startDate = startDate;
      _endDate = endDate;
    });
    await _refresh();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: _today,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            surface: Colors.white,
            onSurface: const Color(0xFF172033),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      await _applyRange(picked.start, picked.end);
    }
  }

  Future<void> _handleQuickFilter(_CashFlowPeriod period) async {
    switch (period) {
      case _CashFlowPeriod.all:
        await _applyRange(null, null);
      case _CashFlowPeriod.today:
        await _applyRange(_today, _today);
      case _CashFlowPeriod.lastSevenDays:
        await _applyRange(_today.subtract(const Duration(days: 6)), _today);
      case _CashFlowPeriod.thisMonth:
        await _applyRange(
          DateTime(_today.year, _today.month, 1),
          DateTime(_today.year, _today.month + 1, 0),
        );
    }
  }

  bool _selected(_CashFlowPeriod period) {
    switch (period) {
      case _CashFlowPeriod.all:
        return _startDate == null && _endDate == null;
      case _CashFlowPeriod.today:
        return _isToday;
      case _CashFlowPeriod.lastSevenDays:
        return _isLastSevenDays;
      case _CashFlowPeriod.thisMonth:
        return _isThisMonth;
    }
  }

  String get _dateRangeLabel {
    if (_startDate == null || _endDate == null) return 'Semua periode';
    final format = DateFormat('d MMM yyyy', 'id_ID');
    if (DateUtils.isSameDay(_startDate, _endDate)) {
      return format.format(_startDate!);
    }
    return '${format.format(_startDate!)} – ${format.format(_endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currencyFmt = NumberFormat('#,###', 'id_ID');

    return ValueListenableBuilder<CashFlowSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.entries.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.entries.isEmpty) {
          return _CashFlowLoadError(
            message: snapshot.errorMessage!,
            onRetry: _refresh,
          );
        }

        return RefreshIndicator(
          color: primaryColor,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _buildIntro(primaryColor),
              const SizedBox(height: 16),
              _buildPeriodControls(primaryColor),
              const SizedBox(height: 16),
              _buildNetCard(snapshot, primaryColor, currencyFmt),
              const SizedBox(height: 12),
              _buildDirectionTotals(snapshot, currencyFmt),
              const SizedBox(height: 22),
              _buildTransactionHeader(snapshot.entries.length),
              const SizedBox(height: 10),
              if (snapshot.errorMessage != null) ...[
                _CashFlowInlineError(message: snapshot.errorMessage!),
                const SizedBox(height: 10),
              ],
              if (snapshot.isLoading)
                const LinearProgressIndicator(minHeight: 2),
              if (snapshot.isLoading) const SizedBox(height: 10),
              if (snapshot.entries.isEmpty)
                const _CashFlowEmptyState()
              else
                _buildEntries(snapshot.entries, currencyFmt),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntro(Color primaryColor) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: primaryColor,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ringkasan arus kas',
                style: TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Tarik ke bawah untuk memperbarui data.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: _refresh,
          icon: Icon(Icons.refresh_rounded, color: primaryColor),
        ),
      ],
    );
  }

  Widget _buildPeriodControls(Color primaryColor) {
    const periods = <(_CashFlowPeriod, String)>[
      (_CashFlowPeriod.all, 'Semua'),
      (_CashFlowPeriod.today, 'Hari ini'),
      (_CashFlowPeriod.lastSevenDays, '7 hari'),
      (_CashFlowPeriod.thisMonth, 'Bulan ini'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: periods.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final period = periods[index].$1;
              final selected = _selected(period);
              return ChoiceChip(
                label: Text(periods[index].$2),
                selected: selected,
                onSelected: (_) => _handleQuickFilter(period),
                selectedColor: primaryColor.withValues(alpha: 0.12),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? primaryColor : const Color(0xFF64748B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected
                      ? primaryColor.withValues(alpha: 0.28)
                      : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _selectDateRange,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            alignment: Alignment.centerLeft,
            foregroundColor: const Color(0xFF334155),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Expanded(
            child: Text(
              _dateRangeLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetCard(
    CashFlowSnapshot snapshot,
    Color primaryColor,
    NumberFormat currencyFmt,
  ) {
    final netMovement = snapshot.totalIn - snapshot.totalOut;
    final isPositive = netMovement >= 0;
    final tone = isPositive ? const Color(0xFF0F9D77) : const Color(0xFFE25D5D);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.80)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pergerakan kas bersih',
                  style: TextStyle(
                    color: Color(0xFFE9EEFF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${netMovement < 0 ? '-' : ''}Rp ${currencyFmt.format(netMovement.abs())}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isPositive
                      ? 'Pemasukan lebih besar dari pengeluaran'
                      : 'Pengeluaran lebih besar dari pemasukan',
                  style: TextStyle(
                    color: tone == const Color(0xFF0F9D77)
                        ? const Color(0xFFDDFBF1)
                        : const Color(0xFFFFE3E3),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionTotals(
    CashFlowSnapshot snapshot,
    NumberFormat currencyFmt,
  ) {
    return Row(
      children: [
        Expanded(
          child: _CashFlowDirectionCard(
            label: 'Kas masuk',
            amount: snapshot.totalIn,
            color: const Color(0xFF0F9D77),
            background: const Color(0xFFECFDF5),
            icon: Icons.south_west_rounded,
            currencyFmt: currencyFmt,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CashFlowDirectionCard(
            label: 'Kas keluar',
            amount: snapshot.totalOut,
            color: const Color(0xFFE25D5D),
            background: const Color(0xFFFFF1F1),
            icon: Icons.north_east_rounded,
            currencyFmt: currencyFmt,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionHeader(int count) => Row(
    children: [
      const Expanded(
        child: Text(
          'Aktivitas kas',
          style: TextStyle(
            color: Color(0xFF172033),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Text(
        '$count transaksi',
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _buildEntries(
    List<CashFlowEntryRecord> entries,
    NumberFormat currencyFmt,
  ) {
    final widgets = <Widget>[];
    DateTime? previousDate;
    for (final entry in entries) {
      if (previousDate == null ||
          !DateUtils.isSameDay(previousDate, entry.createdAt)) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 14));
        widgets.add(_CashFlowDateLabel(date: entry.createdAt));
        widgets.add(const SizedBox(height: 7));
        previousDate = entry.createdAt;
      }
      widgets.add(_CashFlowEntryCard(entry: entry, currencyFmt: currencyFmt));
      widgets.add(const SizedBox(height: 8));
    }
    if (widgets.isNotEmpty) widgets.removeLast();
    return Column(children: widgets);
  }
}

enum _CashFlowPeriod { all, today, lastSevenDays, thisMonth }

class _CashFlowDirectionCard extends StatelessWidget {
  const _CashFlowDirectionCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.background,
    required this.icon,
    required this.currencyFmt,
  });

  final String label;
  final int amount;
  final Color color;
  final Color background;
  final IconData icon;
  final NumberFormat currencyFmt;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE8EDF5)),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 29,
          height: 29,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Rp ${currencyFmt.format(amount)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CashFlowEntryCard extends StatelessWidget {
  const _CashFlowEntryCard({required this.entry, required this.currencyFmt});

  final CashFlowEntryRecord entry;
  final NumberFormat currencyFmt;

  @override
  Widget build(BuildContext context) {
    final isIn = entry.type == 'in';
    final color = isIn ? const Color(0xFF0F9D77) : const Color(0xFFE25D5D);
    final background = isIn ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F1);
    final time = DateFormat('HH:mm', 'id_ID').format(entry.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8EDF5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: color,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$time · ${isIn ? 'Kas masuk' : 'Kas keluar'}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${isIn ? '+' : '-'}Rp ${currencyFmt.format(entry.amount)}',
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowDateLabel extends StatelessWidget {
  const _CashFlowDateLabel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final label = DateUtils.isSameDay(date, today)
        ? 'Hari ini'
        : DateUtils.isSameDay(date, today.subtract(const Duration(days: 1)))
        ? 'Kemarin'
        : DateFormat('EEEE, d MMMM', 'id_ID').format(date);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CashFlowEmptyState extends StatelessWidget {
  const _CashFlowEmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8EDF5)),
    ),
    child: const Column(
      children: [
        Icon(Icons.receipt_long_outlined, color: Color(0xFF94A3B8), size: 34),
        SizedBox(height: 10),
        Text(
          'Belum ada aktivitas kas',
          style: TextStyle(
            color: Color(0xFF334155),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Coba pilih periode lain atau tarik layar untuk memuat ulang.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _CashFlowLoadError extends StatelessWidget {
  const _CashFlowLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: Color(0xFF94A3B8),
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text(
            'Arus kas belum dapat dimuat',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );
}

class _CashFlowInlineError extends StatelessWidget {
  const _CashFlowInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFFED7AA)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: Color(0xFFC2410C),
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF9A3412), fontSize: 11.5),
          ),
        ),
      ],
    ),
  );
}
