import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';

class SyncCenterView extends StatelessWidget {
  const SyncCenterView({super.key});

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
                      l10n.syncCenterMenu,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kelola sinkronisasi data POS dengan server pusat.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Mulai Sinkronisasi'),
                style: FilledButton.styleFrom(
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
              _buildSyncCard(
                context: context,
                title: 'Data Master (Katalog)',
                description: 'Produk, Kategori, Promo, Staf, Pelanggan',
                lastSyncTime: 'Hari ini, 10:30',
                status: 'Sukses',
                isSuccess: true,
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 16),
              _buildSyncCard(
                context: context,
                title: 'Data Transaksi',
                description: 'Penjualan, Shift, Kas, Laporan',
                lastSyncTime: 'Hari ini, 11:45',
                status: 'Menunggu',
                isSuccess: null, // neutral
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncCard({
    required BuildContext context,
    required String title,
    required String description,
    required String lastSyncTime,
    required String status,
    required bool? isSuccess,
    required IconData icon,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    Color statusColor;
    if (isSuccess == true) {
      statusColor = Colors.green;
    } else if (isSuccess == false) {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Terakhir Sync: $lastSyncTime',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
