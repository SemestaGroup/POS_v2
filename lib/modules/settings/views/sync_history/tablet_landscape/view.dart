import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';

class SyncHistoryView extends StatelessWidget {
  const SyncHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // ── Controls ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.syncHistoryMenu,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Riwayat aktivitas sinkronisasi data POS dengan server.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Unduh Log'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade100),

        // ── Content ───────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHistoryItem(
                context,
                title: 'Sinkronisasi Transaksi Selesai',
                date: 'Hari ini, 12:45',
                details: 'Berhasil mengunggah 5 transaksi penjualan dan 2 arus kas.',
                isSuccess: true,
              ),
              const Divider(height: 32),
              _buildHistoryItem(
                context,
                title: 'Sinkronisasi Data Master Selesai',
                date: 'Hari ini, 10:30',
                details: 'Berhasil mengunduh pembaruan untuk 10 produk dan 2 kategori.',
                isSuccess: true,
              ),
              const Divider(height: 32),
              _buildHistoryItem(
                context,
                title: 'Gagal Sinkronisasi',
                date: 'Kemarin, 21:00',
                details: 'Koneksi ke server terputus saat mencoba sinkronisasi penutupan shift.',
                isSuccess: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(
    BuildContext context, {
    required String title,
    required String date,
    required String details,
    required bool isSuccess,
  }) {
    final color = isSuccess ? Colors.green : Colors.red;
    final icon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                details,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
