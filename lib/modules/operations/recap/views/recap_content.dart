import 'package:flutter/material.dart';
import '../../../../../core/widgets/responsive/responsive_context.dart';
import 'package:intl/intl.dart';

import '../../stores/operations_read_stores.dart';
import '../../../../core/printing/services/printer_rendering_service.dart';
import '../../../../core/printing/services/printer_transport_service.dart';
import '../../../settings/printers/controllers/printer_settings_controller.dart';
import '../../shift/services/shift_report_builder.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';

class RecapContent extends StatefulWidget {
  const RecapContent({super.key});

  @override
  State<RecapContent> createState() => _RecapContentState();
}

class _RecapContentState extends State<RecapContent> {
  final RecapStore _store = RecapStore.instance;
  DateTime _selectedArchiveDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
      _store.fetchArchives(_selectedArchiveDate);
    });
  }

  Future<void> _handleEod(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.fact_check_rounded,
                color: Colors.red.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'End of Day (EOD)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const SizedBox(
          width: 320,
          child: Text(
            'Aksi ini akan mencetak struk rekapitulasi semua shift tertutup saat ini dan mengarsipkannya. Apakah Anda yakin ingin melanjutkan?',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(fontSize: 12)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Proses EOD', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _store.executeEndOfDay();
    if (mounted) {
      if (_store.snapshotNotifier.value.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_store.snapshotNotifier.value.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End of Day berhasil diproses.'),
            backgroundColor: Colors.green,
          ),
        );
        _store.fetchArchives(_selectedArchiveDate);
      }
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedArchiveDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      setState(() {
        _selectedArchiveDate = date;
      });
      _store.fetchArchives(date);
    }
  }

  Future<void> _printArchive(EodArchiveRecord archive) async {
    try {
      await PrinterSettingsController.instance.refresh(silent: true);
      final state = PrinterSettingsController.instance.stateNotifier.value;
      final printer =
          state.printers
              .where((p) => p.isActive && p.roles.contains('cashier'))
              .firstOrNull ??
          state.printers.where((p) => p.isActive).firstOrNull;

      if (printer == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada printer terdaftar. Silakan atur printer terlebih dahulu.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final documentData = await ShiftReportBuilder.instance
          .buildFromEodArchive(
            archive: archive,
            tenantId:
                PosV2RuntimeSessionStore.instance.currentSession!.tenantId,
          );

      final renderer = PrinterRenderingService.instance;
      final renderOutput = await renderer.render(printer, documentData);

      final dispatchResult = await PrinterTransportService.instance.dispatch(
        printer,
        renderOutput,
      );

      if (!mounted) return;
      if (!dispatchResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak: ${dispatchResult.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final currencyFmt = NumberFormat('#,###', 'id_ID');

    final isMobile = context.isMobile;

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.history_rounded, color: primaryColor, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Rekap & EOD',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        _store.refresh();
                        _store.fetchArchives(_selectedArchiveDate);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text(
                        'Refresh',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TabBar(
                  labelColor: primaryColor,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: primaryColor,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Rekap Saat Ini'),
                    Tab(text: 'Arsip EOD'),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: ValueListenableBuilder<RecapSnapshot>(
              valueListenable: _store.snapshotNotifier,
              builder: (context, snapshot, _) {
                return TabBarView(
                  children: [
                    _buildCurrentRecap(
                      snapshot,
                      currencyFmt,
                      primaryColor,
                      isMobile,
                    ),
                    _buildArchive(
                      snapshot,
                      currencyFmt,
                      primaryColor,
                      isMobile,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentRecap(
    RecapSnapshot snapshot,
    NumberFormat currencyFmt,
    Color primaryColor,
    bool isMobile,
  ) {
    if (snapshot.isLoading && snapshot.shifts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snapshot.errorMessage != null && snapshot.shifts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      snapshot.errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                isMobile
                    ? Column(
                        children: [
                          _card(
                            'Total Transaksi',
                            '${snapshot.totalTransactions}',
                            Icons.receipt_long_rounded,
                            primaryColor,
                          ),
                          const SizedBox(height: 8),
                          _card(
                            'Total Pendapatan',
                            'Rp ${currencyFmt.format(snapshot.totalRevenue)}',
                            Icons.payments_rounded,
                            const Color(0xFF10B981),
                          ),
                          const SizedBox(height: 8),
                          _card(
                            'Shift Tertutup',
                            '${snapshot.shifts.length}',
                            Icons.access_time_rounded,
                            const Color(0xFFF59E0B),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _card(
                              'Total Transaksi',
                              '${snapshot.totalTransactions}',
                              Icons.receipt_long_rounded,
                              primaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _card(
                              'Total Pendapatan',
                              'Rp ${currencyFmt.format(snapshot.totalRevenue)}',
                              Icons.payments_rounded,
                              const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _card(
                              'Shift Tertutup',
                              '${snapshot.shifts.length}',
                              Icons.access_time_rounded,
                              const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 18),
                isMobile
                    ? _buildMobileShiftList(snapshot, currencyFmt)
                    : _shiftTable(snapshot, currencyFmt),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: isMobile
                ? MainAxisAlignment.center
                : MainAxisAlignment.end,
            children: [
              Expanded(
                flex: isMobile ? 1 : 0,
                child: FilledButton.icon(
                  onPressed: () => _handleEod(context),
                  icon: const Icon(Icons.print_rounded, size: 16),
                  label: const Text(
                    'Cetak & Akhiri Hari (EOD)',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileShiftList(
    RecapSnapshot snapshot,
    NumberFormat currencyFmt,
  ) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    if (snapshot.shifts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada shift tertutup.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: snapshot.shifts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final shift = snapshot.shifts[index];
        final isOpen = shift.status == 'open';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    shift.shiftName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isOpen ? 'Open' : 'Closed',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isOpen
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              _rowDetail('Staf Kasir', shift.staffName),
              const SizedBox(height: 6),
              _rowDetail(
                'Saldo Awal',
                'Rp ${currencyFmt.format(shift.openingBalance)}',
              ),
              const SizedBox(height: 6),
              _rowDetail('Waktu Buka', dateFmt.format(shift.openedAt)),
              if (shift.closedAt != null) ...[
                const SizedBox(height: 6),
                _rowDetail('Waktu Tutup', dateFmt.format(shift.closedAt!)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _rowDetail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  Widget _buildArchive(
    RecapSnapshot snapshot,
    NumberFormat currencyFmt,
    Color primaryColor,
    bool isMobile,
  ) {
    final dateFmt = DateFormat('dd MMM yyyy', 'id_ID');
    final timeFmt = DateFormat('HH:mm', 'id_ID');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Text(
                'Filter Tanggal:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _pickDate(context),
                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                label: Text(
                  dateFmt.format(_selectedArchiveDate),
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        Expanded(
          child: snapshot.isLoading && snapshot.archivedEods.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : snapshot.archivedEods.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada arsip EOD pada tanggal ini.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(isMobile ? 12 : 20),
                  itemCount: snapshot.archivedEods.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final archive = snapshot.archivedEods[index];

                    if (isMobile) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.fact_check_rounded,
                                    color: Colors.red.shade600,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        archive.eodCode,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1D2E),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Waktu EOD: ${timeFmt.format(archive.createdAt)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Pendapatan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'Rp ${currencyFmt.format(archive.totalRevenue)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Transaksi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${archive.totalTransactions} Transaksi',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Fitur cetak ulang segera hadir.',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.print_rounded, size: 14),
                                label: const Text(
                                  'Cetak Struk Rekap',
                                  style: TextStyle(fontSize: 11),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.fact_check_rounded,
                              color: Colors.red.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  archive.eodCode,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Waktu EOD: ${timeFmt.format(archive.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rp ${currencyFmt.format(archive.totalRevenue)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${archive.totalTransactions} Transaksi',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          OutlinedButton.icon(
                            onPressed: () => _printArchive(archive),
                            icon: const Icon(Icons.print_rounded, size: 14),
                            label: const Text(
                              'Cetak',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
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
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  Widget _shiftTable(RecapSnapshot snapshot, NumberFormat currencyFmt) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    if (snapshot.shifts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada shift tertutup untuk direkap.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: Colors.grey.shade100),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
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
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: Colors.grey.shade100),
              right: BorderSide(color: Colors.grey.shade100),
              bottom: BorderSide(color: Colors.grey.shade100),
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: snapshot.shifts.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final shift = snapshot.shifts[index];
              final isOpen = shift.status == 'open';
              return Container(
                color: index.isOdd
                    ? Colors.transparent
                    : const Color(0xFFFAFAFB),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    _ShiftCell(shift.shiftName, 3, bold: true),
                    _ShiftCell(shift.staffName, 2),
                    _ShiftCell(dateFmt.format(shift.openedAt), 3),
                    _ShiftCell(
                      shift.closedAt != null
                          ? dateFmt.format(shift.closedAt!)
                          : '—',
                      3,
                    ),
                    _ShiftCell(
                      'Rp ${currencyFmt.format(shift.openingBalance)}',
                      2,
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isOpen
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF6B7280),
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
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
        ),
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
