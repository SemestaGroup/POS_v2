import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../../core/services/local/database_service.dart';
import '../../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../../../../../../core/printing/services/printer_rendering_service.dart';
import '../../../../../../core/printing/services/printer_transport_service.dart';
import '../../../../../settings/printers/controllers/printer_settings_controller.dart';
import '../../../services/shift_report_builder.dart';
import '../../../services/shift_report_calculations.dart';

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
  final int totalNonCash;
  final int cashSales;

  bool get isClosed => status == 'closed' || closedAt != null;

  int get variance => isClosed
      ? ShiftReportCalculations.cashVariance(
          actualCash: actualCash,
          expectedCash: expectedCash,
        )
      : 0;
  int get transactionVariance => variance;
  int get totalShiftSales => cashSales + totalNonCash;

  String formatVariance(NumberFormat fmt) {
    if (!isClosed) return 'Shift Berjalan';
    if (transactionVariance == 0) return 'Pas (Rp 0)';
    if (transactionVariance < 0) {
      return 'Kurang Rp ${fmt.format(transactionVariance.abs())}';
    }
    return 'Lebih Rp ${fmt.format(transactionVariance)}';
  }

  Color getVarianceColor() {
    if (!isClosed) return const Color(0xFF0284C7);
    if (transactionVariance == 0) return const Color(0xFF15803D);
    if (transactionVariance < 0) return const Color(0xFFB91C1C);
    return const Color(0xFFB45309);
  }

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
    required this.totalNonCash,
    required this.cashSales,
  });
}

class ShiftHistoryMobilePortraitView extends StatefulWidget {
  const ShiftHistoryMobilePortraitView({super.key});

  @override
  State<ShiftHistoryMobilePortraitView> createState() =>
      _ShiftHistoryMobilePortraitViewState();
}

class _ShiftHistoryMobilePortraitViewState
    extends State<ShiftHistoryMobilePortraitView> {
  List<_ShiftRow> _allRows = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all';
  int? _printingShiftId;

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
          _allRows = [];
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
          _allRows = [];
        });
        return;
      }
      final tenantId = tenantRows.first['id'];

      try {
        await PosV2SyncOrchestrator().syncShiftHistory(session.toSyncContext());
      } catch (_) {}

      final raw = await DatabaseService.instance.rawQuery(
        '''
        SELECT s.id, s.shift_name, s.pos_staff_name_snapshot, s.register_id,
               s.status, s.opened_at, s.closed_at, s.remote_id,
               s.opening_balance, s.expected_cash, s.actual_cash, s.total_non_cash,
               s.reconciliation_json,
               COALESCE((
                 SELECT SUM(cf.amount)
                 FROM pos_cash_flow cf
                 WHERE cf.tenant_id = s.tenant_id
                   AND cf.type IN ('in', 'cash_in')
                   AND cf.deleted_at IS NULL
                   AND (
                     cf.shift_session_id = s.id
                     OR (
                       cf.shift_session_id IS NULL
                       AND
                       substr(replace(cf.created_at, 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                       AND (s.closed_at IS NULL OR substr(replace(cf.created_at, 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
                     )
                   )
               ), 0) AS total_cash_in,
               COALESCE((
                 SELECT SUM(cf.amount)
                 FROM pos_cash_flow cf
                 WHERE cf.tenant_id = s.tenant_id
                   AND cf.type IN ('out', 'cash_out')
                   AND cf.deleted_at IS NULL
                   AND (
                     cf.shift_session_id = s.id
                     OR (
                       cf.shift_session_id IS NULL
                       AND
                       substr(replace(cf.created_at, 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                       AND (s.closed_at IS NULL OR substr(replace(cf.created_at, 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
                     )
                   )
               ), 0) AS total_cash_out,
               COALESCE((
                 SELECT SUM(p.amount)
                 FROM pos_order_payment p
                 JOIN pos_order o ON p.order_id = o.id
                 LEFT JOIN payment_mode pm ON pm.id = p.payment_mode_id OR (p.payment_mode_remote_id IS NOT NULL AND pm.remote_id = p.payment_mode_remote_id)
                 WHERE o.tenant_id = s.tenant_id
                   AND o.status_code IN ('2', '4')
                   AND p.deleted_at IS NULL
                   AND p.is_refund = 0
                   AND (
                     o.shift_session_id = s.id
                     OR (o.shift_session_remote_id IS NOT NULL AND o.shift_session_remote_id != '' AND s.remote_id IS NOT NULL AND s.remote_id != '' AND o.shift_session_remote_id = s.remote_id)
                     OR (
                       o.shift_session_id IS NULL
                       AND
                       substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                       AND (s.closed_at IS NULL OR substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
                     )
                   )
                   AND (
                     LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), '')) LIKE '%cash%'
                     OR LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), '')) LIKE '%tunai%'
                     OR COALESCE(p.payment_mode_name_snapshot, pm.name, p.payment_method, '') = ''
                   )
               ), 0) AS cash_sales,
               COALESCE((
                 SELECT SUM(p.amount)
                 FROM pos_order_payment p
                 JOIN pos_order o ON p.order_id = o.id
                 LEFT JOIN payment_mode pm ON pm.id = p.payment_mode_id OR (p.payment_mode_remote_id IS NOT NULL AND pm.remote_id = p.payment_mode_remote_id)
                 WHERE o.tenant_id = s.tenant_id
                   AND o.status_code IN ('2', '4')
                   AND p.deleted_at IS NULL
                   AND p.is_refund = 0
                   AND (
                     o.shift_session_id = s.id
                     OR (o.shift_session_remote_id IS NOT NULL AND o.shift_session_remote_id != '' AND s.remote_id IS NOT NULL AND s.remote_id != '' AND o.shift_session_remote_id = s.remote_id)
                     OR (
                       o.shift_session_id IS NULL
                       AND
                       substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) >= substr(replace(s.opened_at, 'T', ' '), 1, 19)
                       AND (s.closed_at IS NULL OR substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) <= substr(replace(s.closed_at, 'T', ' '), 1, 19))
                     )
                   )
                   AND NOT (
                     LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), '')) LIKE '%cash%'
                     OR LOWER(COALESCE(NULLIF(p.payment_mode_name_snapshot, ''), pm.name, NULLIF(p.payment_method, ''), '')) LIKE '%tunai%'
                     OR COALESCE(p.payment_mode_name_snapshot, pm.name, p.payment_method, '') = ''
                   )
               ), 0) AS non_cash_sales
        FROM shift_session s
        WHERE s.tenant_id = ? AND s.deleted_at IS NULL
        ORDER BY s.opened_at DESC
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
        final isClosed =
            (closedStr != null && closedStr.isNotEmpty) ||
            r['status'] == 'closed';
        int expectedCash = asInt(r['expected_cash']);
        int actualCash = asInt(r['actual_cash']);
        int nonCash = asInt(r['total_non_cash']);
        int cashSales = asInt(r['cash_sales']);
        int calculatedNonCash = asInt(r['non_cash_sales']);
        int openingBalance = asInt(r['opening_balance']);
        int totalCashIn = asInt(r['total_cash_in']);
        int totalCashOut = asInt(r['total_cash_out']);

        if (r['reconciliation_json'] != null) {
          try {
            final reconc = r['reconciliation_json'] is String
                ? jsonDecode(r['reconciliation_json'] as String)
                : r['reconciliation_json'];
            if (reconc is Map) {
              if (expectedCash == 0) {
                expectedCash = asInt(
                  reconc['expected_cash'] ??
                      reconc['expectedCash'] ??
                      reconc['expected_cash_amount'],
                );
              }
              if (actualCash == 0) {
                actualCash = asInt(
                  reconc['actual_cash'] ??
                      reconc['actualCash'] ??
                      reconc['actual_cash_amount'] ??
                      reconc['closing_balance'],
                );
              }
              if (nonCash == 0) {
                nonCash = asInt(
                  reconc['total_non_cash'] ??
                      reconc['totalNonCash'] ??
                      reconc['total_non_cash_amount'],
                );
                if (nonCash == 0 && reconc['payment_modes'] is List) {
                  int sum = 0;
                  for (final pm in reconc['payment_modes']) {
                    if (pm is Map) {
                      final modeName =
                          (pm['name'] ?? pm['payment_mode_name'] ?? '')
                              .toString()
                              .toLowerCase();
                      if (!modeName.contains('cash') &&
                          !modeName.contains('tunai')) {
                        sum += asInt(pm['amount'] ?? pm['estimated_amount']);
                      }
                    }
                  }
                  if (sum > 0) nonCash = sum;
                }
              }
            }
          } catch (_) {}
        }

        final calculatedExpectedCash = ShiftReportCalculations.expectedCash(
          openingBalance: openingBalance,
          cashIn: totalCashIn,
          cashOut: totalCashOut,
          cashSales: cashSales,
        );
        final finalExpectedCash = (isClosed && expectedCash > 0)
            ? expectedCash
            : calculatedExpectedCash;
        final finalNonCash = calculatedNonCash > 0
            ? calculatedNonCash
            : nonCash;

        return _ShiftRow(
          id: asInt(r['id']),
          shiftName: r['shift_name']?.toString() ?? '—',
          staffName: r['pos_staff_name_snapshot']?.toString() ?? '—',
          registerId: r['register_id']?.toString(),
          status: isClosed ? 'closed' : (r['status']?.toString() ?? 'open'),
          openedAt: parseDate(r['opened_at']),
          closedAt: (closedStr != null && closedStr.isNotEmpty)
              ? DateTime.tryParse(closedStr.replaceFirst(' ', 'T'))
              : null,
          openingBalance: openingBalance,
          expectedCash: finalExpectedCash,
          actualCash: actualCash,
          totalNonCash: finalNonCash,
          cashSales: cashSales,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _allRows = rows;
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

  List<_ShiftRow> get _filteredRows {
    if (_selectedFilter == 'open') {
      return _allRows.where((r) => r.status == 'open').toList();
    } else if (_selectedFilter == 'closed') {
      return _allRows.where((r) => r.status != 'open').toList();
    }
    return _allRows;
  }

  Future<void> _printThermalReport(_ShiftRow shift) async {
    if (_printingShiftId != null) return;
    setState(() => _printingShiftId = shift.id);

    try {
      final session = PosV2RuntimeSessionStore.instance.currentSession;
      final tenantId = session?.tenantId ?? 1;

      final document = await ShiftReportBuilder.instance.buildReport(
        shiftSessionId: shift.id,
        tenantId: tenantId,
        isEod: false,
      );

      if (document != null && mounted) {
        final state = PrinterSettingsController.instance.stateNotifier.value;
        final printer =
            state.printers
                .where((p) => p.isActive && p.roles.contains('cashier'))
                .firstOrNull ??
            state.printers.where((p) => p.isActive).firstOrNull;

        if (printer != null) {
          final renderResult = await PrinterRenderingService.instance.render(
            printer,
            document,
          );
          final dispatchResult = await PrinterTransportService.instance
              .dispatch(printer, renderResult);

          if (!dispatchResult.success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Gagal mencetak: ${dispatchResult.message ?? "Printer error"}',
                ),
                backgroundColor: Colors.red.shade600,
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Laporan Shift #${shift.id} berhasil dicetak'),
                backgroundColor: const Color(0xFF16A34A),
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Printer thermal belum diatur di Pengaturan.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mencetak: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _printingShiftId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    final displayRows = _filteredRows;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.history_toggle_off_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Riwayat Shift Kasir',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Histori sesi kasir & rekonsiliasi kas',
                          style: TextStyle(
                            fontSize: 12,
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
                      onTap: _load,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
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
                              size: 14,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Refresh',
                              style: TextStyle(
                                fontSize: 11.5,
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

            // Horizontal Filter Chips Segment
            Container(
              height: 48,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip(
                    'all',
                    'Semua Sesi (${_allRows.length})',
                    primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'open',
                    'Shift Aktif (${_allRows.where((r) => r.status == 'open').length})',
                    primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'closed',
                    'Selesai (${_allRows.where((r) => r.status != 'open').length})',
                    primaryColor,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Shift Card List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : _errorMessage != null
                  ? _buildError()
                  : displayRows.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayRows.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) => _buildPremiumCard(
                          displayRows[index],
                          primaryColor,
                          currencyFmt,
                          dateFmt,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, Color primaryColor) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF475569),
        ),
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = key);
      },
      selectedColor: primaryColor,
      backgroundColor: const Color(0xFFF1F5F9),
      showCheckmark: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildPremiumCard(
    _ShiftRow shift,
    Color primaryColor,
    NumberFormat currencyFmt,
    DateFormat dateFmt,
  ) {
    final isOpen = shift.status == 'open';
    final isPrintingThis = _printingShiftId == shift.id;

    final staffInitials = shift.staffName.trim().isNotEmpty
        ? shift.staffName
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'KS';

    final compactDateFmt = DateFormat('dd MMM yy · HH:mm', 'id_ID');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0.5,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showExecutiveDetailSheet(shift, currencyFmt, dateFmt),
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
                            shift.shiftName +
                                (shift.registerId != null
                                    ? ' · Reg #${shift.registerId}'
                                    : ''),
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
                            valueColor: shift.getVarianceColor(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Timestamps & Action Footer with matching bottom radius
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isOpen
                            ? 'Buka: ${compactDateFmt.format(shift.openedAt)}'
                            : '${compactDateFmt.format(shift.openedAt)} - ${shift.closedAt != null ? DateFormat('HH:mm', 'id_ID').format(shift.closedAt!) : '—'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: isPrintingThis
                          ? null
                          : () => _printThermalReport(shift),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            if (isPrintingThis)
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

  Widget _buildMetricTile(String label, String value, {Color? valueColor}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExecutiveDetailSheet(
    _ShiftRow shift,
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

    String fmtSql(DateTime? dt) {
      if (dt == null) return '9999-12-31 23:59:59';
      final local = dt.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    }

    final shiftRemoteRows = await DatabaseService.instance.rawQuery(
      'SELECT remote_id FROM shift_session WHERE id = ? LIMIT 1',
      <Object?>[shift.id],
    );
    final shiftRemoteId = shiftRemoteRows.isNotEmpty
        ? shiftRemoteRows.first['remote_id']?.toString()
        : null;

    final startStr = fmtSql(shift.openedAt);
    final endStr = fmtSql(shift.closedAt);

    List<Object?> orderArgs(int tenantId) => [
      tenantId,
      shift.id,
      shiftRemoteId,
      shiftRemoteId,
      startStr,
      endStr,
    ];

    final orderSummaryRows = await DatabaseService.instance.rawQuery('''
      SELECT subtotal_amount, discount_total_amount, manual_discount_value, total_amount, custom_fields_json
      FROM pos_order o
      WHERE o.tenant_id = ?
        AND o.deleted_at IS NULL
        AND o.status_code IN ('2', '4')
        AND (
          o.shift_session_id = ?
          OR (? IS NOT NULL AND o.shift_session_remote_id = ?)
          OR (
            o.shift_session_id IS NULL
            AND substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) >= ?
            AND substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) <= ?
          )
        )
      ''', orderArgs(session.tenantId));

    int grossSales = 0;
    int totalDiscount = 0;
    int netSales = 0;
    int totalTax = 0;

    for (final row in orderSummaryRows) {
      final sub = int.tryParse(row['subtotal_amount']?.toString() ?? '0') ?? 0;
      final discTot =
          int.tryParse(row['discount_total_amount']?.toString() ?? '0') ?? 0;
      final discMan =
          int.tryParse(row['manual_discount_value']?.toString() ?? '0') ?? 0;
      final tot = int.tryParse(row['total_amount']?.toString() ?? '0') ?? 0;

      final effDisc = discTot > 0 ? discTot : discMan;
      grossSales += sub > 0 ? sub : (tot + effDisc);
      totalDiscount += effDisc;
      netSales += tot;

      int rowTax = 0;
      final customFields = row['custom_fields_json']?.toString();
      if (customFields != null && customFields.isNotEmpty) {
        try {
          final decoded = jsonDecode(customFields);
          if (decoded is Map<String, dynamic>) {
            rowTax =
                int.tryParse(decoded['tax_amount']?.toString() ?? '0') ?? 0;
          }
        } catch (_) {}
      }
      if (rowTax == 0 && sub > 0 && tot > (sub - effDisc)) {
        rowTax = tot - (sub - effDisc);
      }
      totalTax += rowTax;
    }

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
        AND o.status_code IN ('2', '4')
        AND (
          o.shift_session_id = ?
          OR (? IS NOT NULL AND o.shift_session_remote_id = ?)
          OR (
            o.shift_session_id IS NULL
            AND substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) >= ?
            AND substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) <= ?
          )
        )
      GROUP BY COALESCE(NULLIF(pm.name, ''), NULLIF(p.payment_mode_name_snapshot, ''), NULLIF(p.payment_method, ''), 'Lainnya')
      ''', orderArgs(session.tenantId));

    int totalRevenue = 0;
    final totalTransactions = orderSummaryRows.length;
    final payments = <Map<String, dynamic>>[];

    for (final row in paymentRows) {
      final name = row['name']?.toString() ?? 'Lainnya';
      final amount = int.tryParse(row['amount']?.toString() ?? '0') ?? 0;
      final qty = (double.tryParse(row['qty']?.toString() ?? '0') ?? 0).round();
      totalRevenue += amount;
      payments.add({'name': name, 'qty': qty, 'amount': amount});
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
            AND substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) >= ?
            AND substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) <= ?
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

    final cashSalesRows = await DatabaseService.instance.rawQuery('''
      SELECT COALESCE(SUM(p.amount), 0) as cash_sales
      FROM pos_order_payment p
      LEFT JOIN payment_mode pm ON pm.id = p.payment_mode_id OR (p.payment_mode_remote_id IS NOT NULL AND pm.remote_id = p.payment_mode_remote_id)
      INNER JOIN pos_order o ON o.id = p.order_id
      WHERE p.tenant_id = ?
        AND p.deleted_at IS NULL
        AND p.is_refund = 0
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
            AND substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) >= ?
            AND substr(replace(COALESCE(NULLIF(o.order_date, ''), o.created_at), 'T', ' '), 1, 19) <= ?
          )
        )
      ''', orderArgs(session.tenantId));
    final cashSales =
        (double.tryParse(
                  cashSalesRows.first['cash_sales']?.toString() ?? '0',
                ) ??
                0)
            .round();

    final cashInRows = await DatabaseService.instance.rawQuery(
      '''
      SELECT note, amount, created_at
      FROM pos_cash_flow
      WHERE tenant_id = ?
        AND type IN ('in', 'cash_in')
        AND deleted_at IS NULL
        AND (
            shift_session_id = ?
            OR (
              shift_session_id IS NULL
              AND substr(replace(created_at, 'T', ' '), 1, 19) >= ?
            AND substr(replace(created_at, 'T', ' '), 1, 19) <= ?
          )
        )
      ORDER BY created_at DESC
      ''',
      <Object?>[session.tenantId, shift.id, startStr, endStr],
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

    final cashOutRows = await DatabaseService.instance.rawQuery(
      '''
      SELECT note, amount, created_at
      FROM pos_cash_flow
      WHERE tenant_id = ?
        AND type IN ('out', 'cash_out')
        AND deleted_at IS NULL
        AND (
            shift_session_id = ?
            OR (
              shift_session_id IS NULL
              AND substr(replace(created_at, 'T', ' '), 1, 19) >= ?
            AND substr(replace(created_at, 'T', ' '), 1, 19) <= ?
          )
        )
      ORDER BY created_at DESC
      ''',
      <Object?>[session.tenantId, shift.id, startStr, endStr],
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
    final calculatedExpectedCash = ShiftReportCalculations.expectedCash(
      openingBalance: openingBalance,
      cashIn: totalCashIn,
      cashOut: totalCashOut,
      cashSales: cashSales,
    );
    final expectedCashInDrawer =
        (shift.closedAt != null && shift.expectedCash > 0)
        ? shift.expectedCash
        : calculatedExpectedCash;

    if (!mounted) return;
    Navigator.of(context).pop();

    final staffInitials = shift.staffName.trim().isNotEmpty
        ? shift.staffName
              .trim()
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'KS';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DefaultTabController(
          length: 3,
          child: DraggableScrollableSheet(
            initialChildSize: 0.90,
            minChildSize: 0.55,
            maxChildSize: 0.96,
            expand: true,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),

                  // Sheet Header Banner Card
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          child: Text(
                            staffInitials,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      shift.staffName,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: shift.status == 'open'
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      shift.status == 'open'
                                          ? 'AKTIF'
                                          : 'SELESAI',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        color: shift.status == 'open'
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Shift #${shift.id} · ${shift.shiftName}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),

                  // Segmented Tab Bar Navigation
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: TabBar(
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: const Color(0xFF64748B),
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      indicatorWeight: 2.5,
                      labelStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(text: 'Ringkasan Kas'),
                        Tab(text: 'Pembayaran'),
                        Tab(text: 'Item Terjual'),
                      ],
                    ),
                  ),

                  // Tab Body Views
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Ringkasan Penjualan & Audit Kas
                        ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: [
                            // Overview Twin KPI Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailKpiCard(
                                    label: 'Total Omset',
                                    value:
                                        'Rp ${currencyFmt.format(netSales > 0 ? netSales : totalRevenue)}',
                                    icon: Icons.payments_outlined,
                                    color: const Color(0xFF0284C7),
                                    bg: const Color(0xFFF0F9FF),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildDetailKpiCard(
                                    label: 'Total Transaksi',
                                    value: '$totalTransactions Transaksi',
                                    icon: Icons.shopping_bag_outlined,
                                    color: const Color(0xFF16A34A),
                                    bg: const Color(0xFFF0FDF4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Financial Summary (Gross, Discount, Tax)
                            const Text(
                              'RINGKASAN PENJUALAN & PAJAK',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _recapAmountRow(
                                    'Penjualan kotor (gross sales)',
                                    'Rp ${currencyFmt.format(grossSales > 0 ? grossSales : totalRevenue)}',
                                  ),
                                  if (totalDiscount > 0) ...[
                                    const SizedBox(height: 8),
                                    _recapAmountRow(
                                      '(-) Total diskon produk & manual',
                                      '-Rp ${currencyFmt.format(totalDiscount)}',
                                      valueColor: const Color(0xFFDC2626),
                                    ),
                                  ],
                                  const Divider(height: 18),
                                  _recapAmountRow(
                                    'Penjualan bersih (net sales)',
                                    'Rp ${currencyFmt.format(netSales > 0 ? netSales : totalRevenue)}',
                                    emphasis: true,
                                  ),
                                  if (totalTax > 0) ...[
                                    const SizedBox(height: 8),
                                    _recapAmountRow(
                                      '(+) Total pajak (tax)',
                                      '+Rp ${currencyFmt.format(totalTax)}',
                                      valueColor: const Color(0xFF0284C7),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Rincian Operasional & Audit Kas Card
                            const Text(
                              'REKONSILIASI & AUDIT KAS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x08000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _recapAmountRow(
                                    'Modal awal kasir (petty cash)',
                                    'Rp ${currencyFmt.format(openingBalance)}',
                                  ),
                                  if (totalCashIn > 0) ...[
                                    const SizedBox(height: 8),
                                    _recapAmountRow(
                                      '(+) Total kas masuk',
                                      '+Rp ${currencyFmt.format(totalCashIn)}',
                                      valueColor: const Color(0xFF15803D),
                                    ),
                                  ],
                                  if (totalCashOut > 0) ...[
                                    const SizedBox(height: 8),
                                    _recapAmountRow(
                                      '(-) Total kas keluar',
                                      '-Rp ${currencyFmt.format(totalCashOut)}',
                                      valueColor: const Color(0xFFDC2626),
                                    ),
                                  ],
                                  const Divider(height: 18),
                                  _recapAmountRow(
                                    'Sisa petty cash',
                                    'Rp ${currencyFmt.format(sisaPettyCash)}',
                                    valueColor: sisaPettyCash >= 0
                                        ? const Color(0xFF0369A1)
                                        : const Color(0xFFDC2626),
                                    emphasis: true,
                                  ),
                                  const SizedBox(height: 8),
                                  _recapAmountRow(
                                    '(+) Penjualan tunai',
                                    'Rp ${currencyFmt.format(cashSales)}',
                                    valueColor: const Color(0xFF15803D),
                                  ),
                                  const Divider(height: 18),
                                  _recapAmountRow(
                                    'Kas seharusnya di laci',
                                    'Rp ${currencyFmt.format(expectedCashInDrawer)}',
                                    emphasis: true,
                                  ),
                                  if (shift.closedAt != null ||
                                      shift.status == 'closed') ...[
                                    const SizedBox(height: 8),
                                    _recapAmountRow(
                                      'Kas aktual (fisik)',
                                      'Rp ${currencyFmt.format(shift.actualCash)}',
                                      emphasis: true,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildVarianceAuditBanner(
                                      shift.actualCash - expectedCashInDrawer,
                                      currencyFmt,
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFDCFCE7),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            size: 18,
                                            color: Color(0xFF15803D),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Shift sedang aktif. Rekonsiliasi kas aktual dilakukan saat tutup shift.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF15803D),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Tab 2: Metode Pembayaran (With Progress Bar & Ratios)
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'RINCIAN METODE PEMBAYARAN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (payments.isEmpty)
                              const Center(
                                child: Text(
                                  'Belum ada transaksi pembayaran',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              )
                            else
                              ...payments.map((p) {
                                final modeName = p['name'].toString();
                                final amt = (p['amount'] as int);
                                final qty = (p['qty'] as int);
                                final double pct = totalRevenue > 0
                                    ? (amt / totalRevenue)
                                    : 0.0;
                                final pctString = (pct * 100).toStringAsFixed(
                                  0,
                                );

                                IconData modeIcon = Icons.payments_outlined;
                                if (modeName.toLowerCase().contains('qris') ||
                                    modeName.toLowerCase().contains('qr')) {
                                  modeIcon = Icons.qr_code_2_rounded;
                                } else if (modeName.toLowerCase().contains(
                                      'edc',
                                    ) ||
                                    modeName.toLowerCase().contains('card') ||
                                    modeName.toLowerCase().contains('debit')) {
                                  modeIcon = Icons.credit_card_rounded;
                                } else if (modeName.toLowerCase().contains(
                                      'transfer',
                                    ) ||
                                    modeName.toLowerCase().contains('bank')) {
                                  modeIcon = Icons.account_balance_rounded;
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.10),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              modeIcon,
                                              size: 18,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  modeName,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$qty Transaksi',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Rp ${currencyFmt.format(amt)}',
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$pctString% dari total',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          minHeight: 5,
                                          backgroundColor: const Color(
                                            0xFFF1F5F9,
                                          ),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),

                        // Tab 3: Produk Terjual
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'DAFTAR PRODUK TERJUAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (items.isEmpty)
                              const Center(
                                child: Text(
                                  'Belum ada produk terjual pada shift ini',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  children: items
                                      .map(
                                        (it) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.shopping_bag_outlined,
                                                size: 16,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '${it['name']}',
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF1F5F9,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '${it['qty']} pcs',
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Sticky Print Button Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _printThermalReport(shift);
                        },
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text(
                          'Cetak Laporan Thermal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
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
    );
  }

  Widget _buildVarianceAuditBanner(int diff, NumberFormat currencyFmt) {
    Color bg;
    Color border;
    Color textCol;
    String textLabel;
    IconData icon;

    if (diff == 0) {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFFDCFCE7);
      textCol = const Color(0xFF15803D);
      textLabel = 'Uang kas di laci pas (selisih Rp 0).';
      icon = Icons.check_circle_rounded;
    } else if (diff < 0) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      textCol = const Color(0xFFDC2626);
      textLabel =
          'Uang kas di laci kurang Rp ${currencyFmt.format(diff.abs())} dari yang seharusnya.';
      icon = Icons.error_rounded;
    } else {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      textCol = const Color(0xFFB45309);
      textLabel =
          'Uang kas di laci lebih Rp ${currencyFmt.format(diff)} dari yang seharusnya.';
      icon = Icons.info_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textCol),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              textLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textCol,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recapAmountRow(
    String label,
    String value, {
    Color? valueColor,
    bool emphasis = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasis ? 12.5 : 12,
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
              color: emphasis
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasis ? 13 : 12,
            fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildError() => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (constraints.maxHeight - 48)
              .clamp(0.0, double.infinity)
              .toDouble(),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Terjadi kesalahan.',
                style: TextStyle(fontSize: 13, color: Colors.red.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          const Text(
            'Belum Ada Riwayat Shift',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Data riwayat shift akan muncul di sini.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
