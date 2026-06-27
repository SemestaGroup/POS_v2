import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/services/local/database_service.dart';
import '../../../../../../core/services/sync/pos_v2_runtime_session_store.dart';

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

      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
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
              Icon(Icons.history_toggle_off_rounded,
                  color: primaryColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Riwayat Shift',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Refresh',
                    style: TextStyle(fontSize: 11)),
                style:
                    TextButton.styleFrom(foregroundColor: primaryColor),
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
                          separatorBuilder: (_, __) =>
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
              Icon(Icons.error_outline_rounded,
                  size: 36, color: Colors.red.shade400),
              const SizedBox(height: 10),
              Text(_errorMessage ?? 'Error',
                  style: TextStyle(
                      fontSize: 12, color: Colors.red.shade600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: _load,
                  child: const Text('Coba Lagi',
                      style: TextStyle(fontSize: 12))),
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
              Icon(Icons.inbox_rounded,
                  size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text('Belum ada riwayat shift.',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade500)),
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
    final statusColor =
        isOpen ? Colors.green.shade600 : Colors.grey.shade600;
    final statusBg =
        isOpen ? Colors.green.shade50 : Colors.grey.shade100;
    final variance = shift.variance;
    final varianceColor = variance < 0
        ? Colors.red.shade600
        : (variance > 0
            ? Colors.orange.shade600
            : Colors.green.shade600);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded,
                    color: primaryColor, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.staffName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      shift.shiftName +
                          (shift.registerId != null
                              ? ' · ${shift.registerId}'
                              : ''),
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOpen ? 'AKTIF' : 'TUTUP',
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
          Row(
            children: [
              Expanded(
                  child: _infoCol(
                      'Buka', dateFmt.format(shift.openedAt))),
              Expanded(
                child: _infoCol(
                  'Tutup',
                  shift.closedAt != null
                      ? dateFmt.format(shift.closedAt!)
                      : '—',
                ),
              ),
              Expanded(
                child: _infoCol(
                  'Saldo Awal',
                  'Rp ${currencyFmt.format(shift.openingBalance)}',
                ),
              ),
              if (!isOpen) ...[
                Expanded(
                  child: _infoCol(
                    'Est. Kas',
                    'Rp ${currencyFmt.format(shift.expectedCash)}',
                  ),
                ),
                Expanded(
                  child: _infoCol(
                    'Kas Aktual',
                    'Rp ${currencyFmt.format(shift.actualCash)}',
                  ),
                ),
                Expanded(
                  child: _infoCol(
                    'Selisih',
                    'Rp ${currencyFmt.format(variance)}',
                    valueColor: varianceColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCol(String label, String value, {Color? valueColor}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF1F2937),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}
