import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentationView extends StatelessWidget {
  const DocumentationView({super.key});

  static final Uri docsUri = Uri.parse('https://docs.flinkaja.com/');

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(docsUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak dapat membuka dokumentasi. Periksa koneksi internet dan '
            'pastikan ada aplikasi browser.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tutorial & Dokumentasi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Panduan penggunaan FlinkPOS, mulai dari transaksi, shift, '
                'hingga laporan.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.menu_book_rounded, color: primary),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'docs.flinkaja.com',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Dibuka di browser. Membutuhkan koneksi internet.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _open(context),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Buka'),
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
}
