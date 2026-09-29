import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../app/auth/auth_gate.dart';
import '../../../../../core/services/local/database_backup_service.dart';

class BackupRestoreView extends StatefulWidget {
  const BackupRestoreView({super.key});

  @override
  State<BackupRestoreView> createState() => _BackupRestoreViewState();
}

class _BackupRestoreViewState extends State<BackupRestoreView> {
  final DatabaseBackupService _service = DatabaseBackupService.instance;

  bool _busy = false;
  String? _busyLabel;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runBusy(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    try {
      await action();
    } on DatabaseBackupException catch (error) {
      _snack(error.message);
    } catch (error) {
      _snack(
        'Terjadi kesalahan: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<void> _backupAndShare() => _runBusy('Membuat backup...', () async {
    final file = await _service.createBackup();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Backup data FlinkPOS'),
    );
  });

  Future<void> _backupAndSave() => _runBusy('Membuat backup...', () async {
    final file = await _service.createBackup();
    final saved = await FilePicker.saveFile(
      fileName: file.uri.pathSegments.last,
      bytes: await file.readAsBytes(),
    );
    if (saved != null) {
      _snack('Backup tersimpan.');
    }
    await file.delete();
  });

  Future<void> _restore() async {
    final picked = await FilePicker.pickFile(dialogTitle: 'Pilih file backup');
    final path = picked?.path;
    if (path == null || !mounted) return;

    BackupInspection? inspection;
    LocalDataStatus? status;
    await _runBusy('Memeriksa file backup...', () async {
      inspection = await _service.inspect(path);
      status = await _service.currentLocalStatus();
    });
    final found = inspection;
    final local = status;
    if (found == null || local == null || !mounted) return;

    final blocked = _service.blockingReason(found);
    if (blocked != null) {
      await _showInfoDialog('Backup tidak dapat dipulihkan', blocked);
      return;
    }
    if (local.openShiftCount > 0) {
      await _showInfoDialog(
        'Tutup shift terlebih dahulu',
        'Masih ada shift yang berjalan di perangkat ini. Tutup shift lalu '
            'ulangi restore agar data shift tidak tertimpa.',
      );
      return;
    }

    final confirmed = await _confirmRestore(found, local);
    if (confirmed != true || !mounted) return;

    var restored = false;
    await _runBusy('Memulihkan data...', () async {
      await _service.restore(found);
      restored = true;
    });
    if (!restored || !mounted) return;

    await _showInfoDialog(
      'Restore berhasil',
      'Data berhasil dipulihkan. Silakan masuk kembali untuk melanjutkan.',
    );
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  Future<void> _showInfoDialog(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmRestore(
    BackupInspection backup,
    LocalDataStatus local,
  ) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final latest = DateTime.tryParse(backup.latestOrderAt ?? '');
    final sizeMb = (backup.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    var understood = local.pendingSyncCount == 0;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Pulihkan data dari backup?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line('Outlet', backup.tenants.map((t) => t.label).join(', ')),
                _line('Ukuran file', '$sizeMb MB'),
                _line('Jumlah pesanan', '${backup.orderCount}'),
                _line(
                  'Pesanan terakhir',
                  latest == null ? '-' : dateFmt.format(latest.toLocal()),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Seluruh data di perangkat ini akan diganti dengan isi '
                  'backup. Data sebelum restore disimpan otomatis sebagai '
                  'cadangan darurat, dan dikembalikan jika restore gagal. '
                  'Anda akan diminta masuk kembali setelah restore.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                if (local.pendingSyncCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      '${local.pendingSyncCount} data di perangkat ini belum '
                      'terkirim ke server dan akan hilang jika tidak ada di '
                      'backup. Sebaiknya sinkronkan dulu di Sync Center.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    value: understood,
                    onChanged: (v) => setLocal(() => understood = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Saya mengerti dan tetap ingin melanjutkan',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: understood ? () => Navigator.of(ctx).pop(true) : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Pulihkan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _card({
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> actions,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Backup & Restore Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cadangkan seluruh data lokal perangkat ini, atau pulihkan '
                'dari file backup.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(_busyLabel ?? 'Memproses...'),
                    ],
                  ),
                ),
              _card(
                icon: Icons.backup_rounded,
                title: 'Backup',
                description:
                    'File backup berisi data penjualan dan akun staf outlet '
                    'ini, jadi simpan di tempat yang aman. Sesi login tidak '
                    'ikut disimpan. Backup hanya bisa dipulihkan pada outlet '
                    'yang sama.',
                actions: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _backupAndShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 16),
                    label: const Text('Bagikan Backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _backupAndSave,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Simpan ke Perangkat'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _card(
                icon: Icons.settings_backup_restore_rounded,
                title: 'Restore',
                description:
                    'Mengganti seluruh data di perangkat ini dengan isi file '
                    'backup. Restore ditolak jika masih ada shift berjalan. '
                    'Data sebelum restore disimpan otomatis dan dikembalikan '
                    'bila restore gagal.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Pilih File Backup'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
