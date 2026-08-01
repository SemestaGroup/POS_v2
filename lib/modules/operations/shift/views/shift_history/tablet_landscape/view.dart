import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/services/local/database_service.dart';
import '../../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../../core/printing/services/printer_rendering_service.dart';
import '../../../../../../core/printing/services/printer_transport_service.dart';
import '../../../../../settings/printers/controllers/printer_settings_controller.dart';
import '../../../services/shift_report_builder.dart';

class _ShiftRow {
  final int id;
  final String shiftName;
  final String staffName;
  final String? registerId;
  final String status;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int openingBalance;
  final int expectedCash;
  final int actualCash;

  int get variance => actualCash - expectedCash;

  const _ShiftRow({
    required this.id,
    required this.shiftName,
    required this.staffName,
    this.registerId,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.openingBalance,
    required this.expectedCash,
    required this.actualCash,
  });
}

class ShiftHistoryView extends StatefulWidget {
  const ShiftHistoryView({super.key});

  @override
  State<ShiftHistoryView> createState() => _ShiftHistoryViewState();
}

class _ShiftHistoryViewState extends State<ShiftHistoryView> {
  List<_ShiftRow> _rows = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final session =
          PosV2RuntimeSessionStore.instance.currentSession ??
          await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
      if (session == null) {
        setState(() {
          _isLoading = false;
          _rows = [];
        });
        return;
      }

      final tenantRows = await DatabaseService.instance.rawQuery(
        'SELECT id FROM app_tenant WHERE tenant_key = ? LIMIT 1',
        <Object?>[session.tenantKey],
      );
      if (tenantRows.isEmpty) {
        setState(() {
          _isLoading = false;
          _rows = [];
        });
        return;
      }
      final tenantId = tenantRows.first['id'];

      final raw = await DatabaseService.instance.rawQuery(
        '''
        SELECT id, shift_name, pos_staff_name_snapshot, register_id,
               status, opened_at, closed_at,
               opening_balance, expected_cash, actual_cash
        FROM shift_session
        WHERE tenant_id = ? AND deleted_at IS NULL
        ORDER BY opened_at DESC
        LIMIT 50
        ''',
        <Object?>[tenantId],
      );

      int asInt(Object? v) {
        if (v == null) return 0;
        if (v is int) return v;
        if (v is double) return v.round();
        return int.tryParse(v.toString().split('.').first) ?? 0;
      }

      DateTime parseDate(Object? v) {
        final s = v?.toString() ?? '';
        return DateTime.tryParse(s.replaceFirst(' ', 'T')) ?? DateTime.now();
      }

      final rows = raw.map((r) {
        final closedStr = r['closed_at']?.toString();
        return _ShiftRow(
          id: asInt(r['id']),
          shiftName: r['shift_name']?.toString() ?? '—',
          staffName: r['pos_staff_name_snapshot']?.toString() ?? '—',
          registerId: r['register_id']?.toString(),
          status: r['status']?.toString() ?? 'open',
          openedAt: parseDate(r['opened_at']),
          closedAt: (closedStr != null && closedStr.isNotEmpty)
              ? DateTime.tryParse(closedStr.replaceFirst(' ', 'T'))
              : null,
          openingBalance: asInt(r['opening_balance']),
          expectedCash: asInt(r['expected_cash']),
          actualCash: asInt(r['actual_cash']),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Colors.white,
          child: Row(
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                color: primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Riwayat Shift',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? _buildError()
              : _rows.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _rows.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) => _buildCard(
                    _rows[index],
                    primaryColor,
                    currencyFmt,
                    dateFmt,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'Error',
            style: TextStyle(fontSize: 12, color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _load,
            child: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            'Belum ada riwayat shift.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    ),
  );

  Widget _buildCard(
    _ShiftRow shift,
    Color primaryColor,
    NumberFormat currencyFmt,
    DateFormat dateFmt,
  ) {
    final isOpen = shift.status == 'open';
    final statusColor = isOpen
        ? const Color(0xFF15803D)
        : const Color(0xFF475569);
    final statusBg = isOpen ? const Color(0xFFECFDF3) : const Color(0xFFF1F5F9);
    final variance = shift.variance;
    final varianceColor = variance < 0
        ? const Color(0xFFB91C1C)
        : (variance > 0 ? const Color(0xFFB45309) : const Color(0xFF15803D));
    final compactDateFmt = DateFormat('dd MMM yy · HH:mm', 'id_ID');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showShiftDetail(shift, context, currencyFmt, dateFmt),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5EAF2)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: primaryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shift.staffName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          shift.shiftName +
                              (shift.registerId != null
                                  ? ' · ${shift.registerId}'
                                  : ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      isOpen ? 'AKTIF' : 'SELESAI',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 8.5,
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
              Row(
                children: [
                  Expanded(
                    child: _shiftCardMetric(
                      'Dibuka',
                      compactDateFmt.format(shift.openedAt),
                    ),
                  ),
                  const SizedBox(width: 14),
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
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _shiftCardMetric(
                      'Saldo awal',
                      'Rp ${currencyFmt.format(shift.openingBalance)}',
                    ),
                  ),
                  if (!isOpen) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      child: _shiftCardMetric(
                        'Kas aktual',
                        'Rp ${currencyFmt.format(shift.actualCash)}',
                        alignEnd: true,
                      ),
                    ),
                  ],
                ],
              ),
              if (!isOpen) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: variance == 0
                        ? const Color(0xFFF0FDF4)
                        : variance > 0
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Selisih kas',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          variance == 0
                              ? 'Rp 0 · Pas'
                              : '${variance > 0 ? '+' : '-'}Rp ${currencyFmt.format(variance.abs())}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: varianceColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: Color(0xFF64748B),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Lihat rekap shift',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: primaryColor,
                    size: 19,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shiftCardMetric(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showShiftDetail(
    _ShiftRow shift,
    BuildContext context,
    NumberFormat currencyFmt,
    DateFormat dateFmt,
  ) async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // Normalize datetime: strip T, Z, microseconds for reliable SQLite string comparison.
    // SQLite stores dates without timezone so we compare in local-date-only form.
    String fmtSql(DateTime? dt) {
      if (dt == null) return '9999-12-31 23:59:59';
      // toLocal() converts from UTC if needed, then format as simple string
      final local = dt.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    }

    // Fetch shift's remote_id so we can also match via shift_session_remote_id on orders
    final shiftRemoteRows = await DatabaseService.instance.rawQuery(
      'SELECT remote_id FROM shift_session WHERE id = ? LIMIT 1',
      <Object?>[shift.id],
    );
    final shiftRemoteId = shiftRemoteRows.isNotEmpty
        ? shiftRemoteRows.first['remote_id']?.toString()
        : null;

    final startStr = fmtSql(shift.openedAt);
    final endStr = fmtSql(shift.closedAt);

    // Match orders by: local FK shift_session_id, OR remote_id match, OR time range
    // Time range uses substr(19) to strip timezone 'Z' and microseconds
    String orderWhere(String tableAlias) =>
        '''
      ${tableAlias}tenant_id = ?
        AND ${tableAlias}deleted_at IS NULL
        AND (
          ${tableAlias}shift_session_id = ?
          OR (? IS NOT NULL AND ${tableAlias}shift_session_remote_id = ?)
          OR (
            ${tableAlias}shift_session_id IS NULL
            AND substr(replace(${tableAlias}created_at, 'T', ' '), 1, 19) >= ?
            AND substr(replace(${tableAlias}created_at, 'T', ' '), 1, 19) <= ?
          )
        )
    ''';

    List<Object?> orderArgs(int tenantId) => [
      tenantId,
      shift.id,
      shiftRemoteId,
      shiftRemoteId,
      startStr,
      endStr,
    ];

    final paymentRows = await DatabaseService.instance.rawQuery('''
      SELECT COALESCE(NULLIF(pm.name, ''), NULLIF(p.payment_mode_name_snapshot, ''), NULLIF(p.payment_method, ''), 'Lainnya') as name,
             COUNT(DISTINCT o.id) as qty,
             SUM(p.amount) as amount
      FROM pos_order_payment p
      LEFT JOIN payment_mode pm ON pm.id = p.payment_mode_id OR (p.payment_mode_remote_id IS NOT NULL AND pm.remote_id = p.payment_mode_remote_id)
      INNER JOIN pos_order o ON o.id = p.order_id
      WHERE p.tenant_id = ?
        AND p.deleted_at IS NULL
        AND p.is_refund = 0
        AND p.sync_state IN ('clean', 'dirty_create', 'dirty_update', 'syncing')
        AND o.status_code IN ('2', '4')
        AND (
          o.shift_session_id = ?
          OR (? IS NOT NULL AND o.shift_session_remote_id = ?)
          OR (
            o.shift_session_id IS NULL
            AND substr(replace(o.created_at, 'T', ' '), 1, 19) >= ?
            AND substr(replace(o.created_at, 'T', ' '), 1, 19) <= ?
          )
        )
      GROUP BY COALESCE(NULLIF(pm.name, ''), NULLIF(p.payment_mode_name_snapshot, ''), NULLIF(p.payment_method, ''), 'Lainnya')
      ''', orderArgs(session.tenantId));

    final modeRows = await DatabaseService.instance.rawQuery(
      'SELECT name FROM payment_mode WHERE tenant_id = ? AND deleted_at IS NULL AND is_active = 1',
      <Object?>[session.tenantId],
    );
    final allModeNames = modeRows
        .map((r) => r['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    int totalRevenue = 0;
    int totalTransactions = 0;
    final payments = <Map<String, dynamic>>[];

    for (final mode in allModeNames) {
      payments.add({'name': mode, 'qty': 0, 'amount': 0});
    }

    for (final row in paymentRows) {
      final name = row['name']?.toString() ?? 'Lainnya';
      final amount = int.tryParse(row['amount']?.toString() ?? '0') ?? 0;
      final qty = (double.tryParse(row['qty']?.toString() ?? '0') ?? 0).round();
      totalRevenue += amount;
      totalTransactions += qty;
      final existingIdx = payments.indexWhere((p) => p['name'] == name);
      if (existingIdx != -1) {
        payments[existingIdx]['amount'] =
            (payments[existingIdx]['amount'] as int) + amount;
        payments[existingIdx]['qty'] =
            (payments[existingIdx]['qty'] as int) + qty;
      } else {
        payments.add({'name': name, 'qty': qty, 'amount': amount});
      }
    }
    payments.removeWhere((p) => p['qty'] == 0 && p['amount'] == 0);

    // Fallback: count orders directly if no payment records found
    if (totalTransactions == 0) {
      final orderCountRows = await DatabaseService.instance.rawQuery('''
        SELECT COUNT(id) as cnt, COALESCE(SUM(total_amount),0) as total
        FROM pos_order
        WHERE ${orderWhere('').trim()}
          AND status_code IN ('2', '4')
        ''', orderArgs(session.tenantId));
      if (orderCountRows.isNotEmpty) {
        totalTransactions =
            (double.tryParse(orderCountRows.first['cnt']?.toString() ?? '0') ??
                    0)
                .round();
        if (totalRevenue == 0) {
          totalRevenue =
              int.tryParse(orderCountRows.first['total']?.toString() ?? '0') ??
              0;
        }
      }
    }

    final itemRows = await DatabaseService.instance.rawQuery('''
      SELECT i.product_name_snapshot as name,
             SUM(i.qty) as qty
      FROM pos_order_item i
      INNER JOIN pos_order o ON o.id = i.order_id
      WHERE i.tenant_id = ?
        AND i.deleted_at IS NULL
        AND o.status_code IN ('2', '4')
        AND o.deleted_at IS NULL
        AND (
          o.shift_session_id = ?
          OR (? IS NOT NULL AND o.shift_session_remote_id = ?)
          OR (
            o.shift_session_id IS NULL
            AND substr(replace(o.created_at, 'T', ' '), 1, 19) >= ?
            AND substr(replace(o.created_at, 'T', ' '), 1, 19) <= ?
          )
        )
      GROUP BY i.product_name_snapshot
      ORDER BY SUM(i.qty) DESC
      ''', orderArgs(session.tenantId));

    final items = itemRows
        .map(
          (row) => {
            'name': row['name']?.toString() ?? 'Produk',
            'qty': (double.tryParse(row['qty']?.toString() ?? '0') ?? 0)
                .round(),
          },
        )
        .toList();

    // Query Cash Sales
    final cashSalesRows = await DatabaseService.instance.rawQuery('''
      SELECT COALESCE(SUM(p.amount), 0) as cash_sales
      FROM pos_order_payment p
      LEFT JOIN payment_mode pm ON pm.id = p.payment_mode_id OR (p.payment_mode_remote_id IS NOT NULL AND pm.remote_id = p.payment_mode_remote_id)
      INNER JOIN pos_order o ON o.id = p.order_id
      WHERE p.tenant_id = ?
        AND p.deleted_at IS NULL
        AND p.is_refund = 0
        AND p.sync_state IN ('clean', 'dirty_create', 'dirty_update', 'syncing')
        AND o.status_code IN ('2', '4')
        AND (
          LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, '')) LIKE '%cash%'
          OR LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, '')) LIKE '%tunai%'
        )
        AND (
          o.shift_session_id = ?
          OR (? IS NOT NULL AND o.shift_session_remote_id = ?)
          OR (
            o.shift_session_id IS NULL
            AND substr(replace(o.created_at, 'T', ' '), 1, 19) >= ?
            AND substr(replace(o.created_at, 'T', ' '), 1, 19) <= ?
          )
        )
      ''', orderArgs(session.tenantId));
    final cashSales =
        (double.tryParse(
                  cashSalesRows.first['cash_sales']?.toString() ?? '0',
                ) ??
                0)
            .round();

    // Query Kas Masuk
    final cashInRows = await DatabaseService.instance.rawQuery(
      '''
      SELECT note, amount, created_at
      FROM pos_cash_flow
      WHERE tenant_id = ?
        AND type = 'in'
        AND deleted_at IS NULL
        AND (
          substr(replace(created_at, 'T', ' '), 1, 19) >= ?
          AND substr(replace(created_at, 'T', ' '), 1, 19) <= ?
        )
      ORDER BY created_at DESC
      ''',
      <Object?>[session.tenantId, startStr, endStr],
    );

    int totalCashIn = 0;
    final cashInList = <Map<String, dynamic>>[];
    for (final r in cashInRows) {
      final amt = (double.tryParse(r['amount']?.toString() ?? '0') ?? 0)
          .round();
      totalCashIn += amt;
      cashInList.add({
        'note': r['note']?.toString() ?? 'Kas Masuk',
        'amount': amt,
      });
    }

    // Query Kas Keluar (pengeluaran) during shift
    final cashOutRows = await DatabaseService.instance.rawQuery(
      '''
      SELECT note, amount, created_at
      FROM pos_cash_flow
      WHERE tenant_id = ?
        AND type = 'out'
        AND deleted_at IS NULL
        AND (
          substr(replace(created_at, 'T', ' '), 1, 19) >= ?
          AND substr(replace(created_at, 'T', ' '), 1, 19) <= ?
        )
      ORDER BY created_at DESC
      ''',
      <Object?>[session.tenantId, startStr, endStr],
    );

    int totalCashOut = 0;
    final cashOutList = <Map<String, dynamic>>[];
    for (final r in cashOutRows) {
      final amt = (double.tryParse(r['amount']?.toString() ?? '0') ?? 0)
          .round();
      totalCashOut += amt;
      cashOutList.add({
        'note': r['note']?.toString() ?? 'Kas Keluar',
        'amount': amt,
      });
    }

    final openingBalance = shift.openingBalance;
    final sisaPettyCash = openingBalance + totalCashIn - totalCashOut;
    final expectedCashInDrawer = sisaPettyCash + cashSales;

    if (!context.mounted) return;
    Navigator.of(context).pop(); // close loading

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.52,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFEFEFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rekap shift',
                              style: TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${shift.shiftName} · ${shift.staffName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup rekap',
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    children: [
                      const Text(
                        'RINGKASAN OPERASIONAL',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Section Card Rincian Kas & Petty Cash
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _recapAmountRow(
                              'Modal awal (petty cash)',
                              'Rp ${currencyFmt.format(openingBalance)}',
                            ),
                            if (totalCashIn > 0) ...[
                              const SizedBox(height: 7),
                              _recapAmountRow(
                                'Total kas masuk',
                                '+Rp ${currencyFmt.format(totalCashIn)}',
                                valueColor: const Color(0xFF15803D),
                              ),
                            ],
                            if (totalCashOut > 0) ...[
                              const SizedBox(height: 7),
                              _recapAmountRow(
                                'Total kas keluar',
                                '-Rp ${currencyFmt.format(totalCashOut)}',
                                valueColor: const Color(0xFFDC2626),
                              ),
                            ],
                            const Divider(height: 16),
                            _recapAmountRow(
                              'Sisa petty cash',
                              'Rp ${currencyFmt.format(sisaPettyCash)}',
                              valueColor: sisaPettyCash >= 0
                                  ? const Color(0xFF0369A1)
                                  : const Color(0xFFDC2626),
                              emphasis: true,
                            ),
                            const SizedBox(height: 7),
                            _recapAmountRow(
                              'Penjualan tunai',
                              'Rp ${currencyFmt.format(cashSales)}',
                              valueColor: const Color(0xFF15803D),
                            ),
                            const Divider(height: 16),
                            _recapAmountRow(
                              'Kas seharusnya di laci',
                              'Rp ${currencyFmt.format(expectedCashInDrawer)}',
                              emphasis: true,
                            ),
                            if (shift.closedAt != null ||
                                shift.status == 'closed') ...[
                              const SizedBox(height: 7),
                              _recapAmountRow(
                                'Kas aktual',
                                'Rp ${currencyFmt.format(shift.actualCash)}',
                                emphasis: true,
                              ),
                              const SizedBox(height: 7),
                              _recapAmountRow(
                                'Selisih kas',
                                (shift.actualCash - expectedCashInDrawer) == 0
                                    ? 'Rp 0 · Pas'
                                    : (shift.actualCash -
                                              expectedCashInDrawer) >
                                          0
                                    ? '+Rp ${currencyFmt.format(shift.actualCash - expectedCashInDrawer)} · Surplus'
                                    : '-Rp ${currencyFmt.format((shift.actualCash - expectedCashInDrawer).abs())} · Minus',
                                valueColor:
                                    (shift.actualCash - expectedCashInDrawer) ==
                                        0
                                    ? const Color(0xFF15803D)
                                    : (shift.actualCash -
                                              expectedCashInDrawer) >
                                          0
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFFB91C1C),
                                emphasis: true,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Column(
                          children: [
                            _recapAmountRow(
                              'Total pendapatan',
                              'Rp ${currencyFmt.format(totalRevenue)}',
                              valueColor: const Color(0xFF15803D),
                              emphasis: true,
                            ),
                            const SizedBox(height: 7),
                            _recapAmountRow(
                              'Total transaksi',
                              '$totalTransactions transaksi',
                            ),
                          ],
                        ),
                      ),
                      if (cashInList.isNotEmpty) ...[
                        const Divider(height: 28),
                        const Text(
                          'Kas Masuk (Petty Cash In)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...cashInList.map(
                          (ci) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _recapAmountRow(
                              '${ci['note']}',
                              '+Rp ${currencyFmt.format(ci['amount'])}',
                              valueColor: const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                      if (cashOutList.isNotEmpty) ...[
                        const Divider(height: 28),
                        const Text(
                          'Pengeluaran (Kas Keluar)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...cashOutList.map(
                          (co) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _recapAmountRow(
                              '${co['note']}',
                              '-Rp ${currencyFmt.format(co['amount'])}',
                              valueColor: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 32),
                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (payments.isEmpty)
                        const Text(
                          'Belum ada pembayaran',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      else
                        ...payments.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _recapAmountRow(
                              '${p['name']} (${p['qty']}x)',
                              'Rp ${currencyFmt.format(p['amount'])}',
                            ),
                          ),
                        ),
                      const Divider(height: 32),
                      const Text(
                        'Produk Terjual',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (items.isEmpty)
                        const Text(
                          'Belum ada produk terjual',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      else
                        ...items.map(
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${i['name']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  '${i['qty']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final document = await ShiftReportBuilder.instance.buildReport(
                            tenantId: session.tenantId,
                            shiftSessionId: shift.id,
                            isEod: false,
                          );
                          await PrinterSettingsController.instance.refresh(silent: true);
                          if (document != null && ctx.mounted) {
                            final state = PrinterSettingsController.instance.stateNotifier.value;
                            final printer = state.printers.where((p) => p.isActive && p.roles.contains('cashier')).firstOrNull ??
                                            state.printers.where((p) => p.isActive).firstOrNull;
                            if (printer != null) {
                              final renderResult = await PrinterRenderingService.instance.render(printer, document);
                              final dispatchResult = await PrinterTransportService.instance.dispatch(printer, renderResult);
                              if (!dispatchResult.success && ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text('Gagal mencetak: ${dispatchResult.message}'),
                                  backgroundColor: Colors.red.shade600,
                                ));
                              }
                            } else {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                content: Text('Printer belum diatur.'),
                                backgroundColor: Colors.orange,
                              ));
                            }
                          }
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print Report Shift'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recapAmountRow(
    String label,
    String value, {
    Color? valueColor,
    bool emphasis = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: emphasis
                  ? const Color(0xFF334155)
                  : const Color(0xFF64748B),
              fontSize: emphasis ? 12 : 11.5,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? const Color(0xFF1E293B),
                fontSize: emphasis ? 12.5 : 11.5,
                fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
