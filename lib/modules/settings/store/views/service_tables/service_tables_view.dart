import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../../core/services/sync/pos_v2_service_table_service.dart';

class ServiceTablesView extends StatefulWidget {
  const ServiceTablesView({super.key});

  @override
  State<ServiceTablesView> createState() => _ServiceTablesViewState();
}

class _ServiceTablesViewState extends State<ServiceTablesView> {
  final PosV2ServiceTableService _service = PosV2ServiceTableService.instance;

  List<ServiceTableRecord> _tables = const [];
  bool _loading = true;
  bool _busy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notice = null;
    });
    try {
      final cached = await _service.loadLocal();
      if (mounted) setState(() => _tables = cached);
    } catch (_) {}

    try {
      await _service.refreshFromServer();
    } catch (error) {
      _notice =
          'Tidak dapat memuat dari server, menampilkan data tersimpan. '
          '(${_message(error)})';
    }

    try {
      final tables = await _service.loadLocal();
      if (mounted) setState(() => _tables = tables);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      final tables = await _service.loadLocal();
      if (mounted) setState(() => _tables = tables);
      if (success != null) _snack(success);
    } catch (error) {
      _snack(_message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addTable() async {
    final input = await showDialog<_TableInput>(
      context: context,
      builder: (_) => const _TableFormDialog(),
    );
    if (input == null) return;
    await _run(
      () => _service.createTable(
        tableCode: input.code,
        tableName: input.name,
        areaName: input.area,
        capacity: input.capacity,
      ),
      success: 'Meja ${input.name} ditambahkan.',
    );
  }

  Future<void> _editTable(ServiceTableRecord table) async {
    final input = await showDialog<_TableInput>(
      context: context,
      builder: (_) => _TableFormDialog(existing: table),
    );
    if (input == null) return;
    await _run(
      () => _service.updateTable(
        table,
        tableName: input.name,
        areaName: input.area ?? '',
        capacity: input.capacity,
      ),
      success: 'Meja diperbarui.',
    );
  }

  Future<void> _showQr(ServiceTableRecord table) async {
    if ((table.qrToken ?? '').isEmpty) {
      _snack('Meja ini belum memiliki token QR dari server.');
      return;
    }
    final regenerate = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ServiceTableQrDialog(table: table, url: _service.qrUrlFor(table)),
    );
    if (regenerate == true) {
      await _run(
        () => _service.updateTable(table, regenerateQrToken: true),
        success:
            'QR baru dibuat. QR lama yang sudah tercetak tidak berlaku lagi.',
      );
    }
  }

  Future<void> _printAll() async {
    final printable = _tables.where((t) => t.canOrder).toList();
    if (printable.isEmpty) {
      _snack('Belum ada meja aktif yang bisa dicetak.');
      return;
    }
    await _run(() async {
      final bytes = await buildServiceTablesPdf(printable, _service.qrUrlFor);
      await Printing.layoutPdf(name: 'QR Meja', onLayout: (_) async => bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meja & QR Pesan Mandiri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pelanggan memindai QR di meja, memesan lewat browser, dan '
                  'pesanan masuk ke kasir sebagai pesanan belum bayar.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _addTable,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Tambah Meja'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _printAll,
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Cetak Semua QR'),
                    ),
                    IconButton(
                      tooltip: 'Muat ulang',
                      onPressed: _busy || _loading ? null : _load,
                      icon: Icon(Icons.refresh_rounded, color: primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                _notice!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
              ),
            ),
          if (_busy || _loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _tables.isEmpty && !_loading
                ? const Center(
                    child: Text(
                      'Belum ada meja. Tekan "Tambah Meja" untuk membuat QR '
                      'pertama.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: _tables.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _tableRow(_tables[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(ServiceTableRecord table) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  table.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kode ${table.tableCode}'
                  '${table.capacity > 0 ? ' · ${table.capacity} kursi' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          _chip(
            table.isActive ? 'Aktif' : 'Nonaktif',
            table.isActive ? const Color(0xFF047857) : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 6),
          _chip(
            table.selfOrderEnabled ? 'Pesan mandiri' : 'Pesan mandiri mati',
            table.selfOrderEnabled
                ? const Color(0xFF4338CA)
                : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 8),
          Switch(
            value: table.isActive && table.selfOrderEnabled,
            onChanged: _busy
                ? null
                : (on) => _run(
                    () => _service.updateTable(
                      table,
                      active: on ? true : null,
                      selfOrderEnabled: on,
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'Lihat QR',
            onPressed: _busy ? null : () => _showQr(table),
            icon: const Icon(Icons.qr_code_2_rounded),
          ),
          IconButton(
            tooltip: 'Ubah',
            onPressed: _busy ? null : () => _editTable(table),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _TableInput {
  const _TableInput({
    required this.code,
    required this.name,
    required this.capacity,
    this.area,
  });

  final String code;
  final String name;
  final String? area;
  final int capacity;
}

class _TableFormDialog extends StatefulWidget {
  const _TableFormDialog({this.existing});

  final ServiceTableRecord? existing;

  @override
  State<_TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends State<_TableFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: widget.existing?.tableCode ?? '',
  );
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.tableName ?? '',
  );
  late final TextEditingController _area = TextEditingController(
    text: widget.existing?.areaName ?? '',
  );
  late final TextEditingController _capacity = TextEditingController(
    text: (widget.existing?.capacity ?? 0) > 0
        ? '${widget.existing!.capacity}'
        : '',
  );

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _area.dispose();
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      // Scrolls when the on-screen keyboard leaves little room (landscape).
      scrollable: true,
      title: Text(editing ? 'Ubah Meja' : 'Tambah Meja'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _code,
                enabled: !editing,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Kode meja *',
                  helperText: editing
                      ? 'Kode tidak bisa diubah agar QR tetap berlaku'
                      : 'Contoh: A1, T05. Dipakai di alamat QR.',
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Kode meja wajib diisi';
                  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
                    return 'Hanya huruf, angka, - dan _';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nama meja *'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nama meja wajib diisi' : null,
              ),
              TextFormField(
                controller: _area,
                decoration: const InputDecoration(labelText: 'Area (opsional)'),
              ),
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kapasitas (opsional)',
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  return int.tryParse(value) == null ? 'Angka saja' : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final area = _area.text.trim();
            Navigator.of(context).pop(
              _TableInput(
                code: _code.text.trim(),
                name: _name.text.trim(),
                area: area.isEmpty ? null : area,
                capacity: int.tryParse(_capacity.text.trim()) ?? 0,
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

@visibleForTesting
class ServiceTableQrDialog extends StatelessWidget {
  const ServiceTableQrDialog({
    required this.table,
    required this.url,
    super.key,
  });

  final ServiceTableRecord table;
  final String url;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text('QR ${table.label}'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              // A painter rather than QrImageView: AlertDialog measures its
              // content intrinsically and QrImageView (a LayoutBuilder) cannot
              // be measured that way, which made the whole dialog vanish.
              child: CustomPaint(
                size: const Size(240, 240),
                painter: QrPainter(
                  data: url,
                  version: QrVersions.auto,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              url,
              style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            if (!table.canOrder)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Meja ini sedang nonaktif atau pesan mandiri dimatikan, '
                  'jadi QR-nya belum bisa dipakai memesan.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _confirmRegenerate(context),
          child: const Text(
            'Buat Ulang QR',
            style: TextStyle(color: Color(0xFFDC2626)),
          ),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Alamat disalin.')));
            }
          },
          child: const Text('Salin Alamat'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Future<void> _confirmRegenerate(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat ulang QR?'),
        content: const Text(
          'QR yang sudah dicetak atau ditempel di meja ini akan berhenti '
          'berfungsi. Lakukan ini hanya jika QR lama bocor atau disalahgunakan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Buat Ulang'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

/// One A4 sheet of table cards, each holding the table's ordering QR code.
@visibleForTesting
Future<Uint8List> buildServiceTablesPdf(
  List<ServiceTableRecord> tables,
  String Function(ServiceTableRecord table) urlFor,
) async {
  final doc = pw.Document();
  final cards = tables
      .map(
        (table) => pw.Container(
          width: 240,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                table.label,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: urlFor(table),
                width: 170,
                height: 170,
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Scan untuk memesan',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      )
      .toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => [pw.Wrap(spacing: 16, runSpacing: 16, children: cards)],
    ),
  );
  return doc.save();
}
