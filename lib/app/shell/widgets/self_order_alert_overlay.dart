import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../modules/sales/self_order/self_order_inbox_service.dart';

/// Floating cards announcing orders customers placed from a table QR.
class SelfOrderAlertOverlay extends StatelessWidget {
  const SelfOrderAlertOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SelfOrderInboxService.instance;

    return ValueListenableBuilder<List<SelfOrderAlert>>(
      valueListenable: service.alerts,
      builder: (context, alerts, _) {
        if (alerts.isEmpty) return const SizedBox.shrink();
        final visible = alerts.take(3).toList();
        final hidden = alerts.length - visible.length;

        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final alert in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AlertCard(alert: alert),
                      ),
                    if (hidden > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Material(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              '+$hidden pesanan lain',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final SelfOrderAlert alert;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final money = NumberFormat('#,###', 'id_ID');

    return Material(
      elevation: 6,
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.isUpdate
                        ? '${alert.title} menambah pesanan'
                        : 'Pesanan baru - ${alert.title}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => SelfOrderInboxService.instance.dismiss(alert),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${alert.itemCount} item - Rp ${money.format(alert.totalAmount)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 2),
            Text(
              alert.kitchenStatus,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _showDetail(context, alert),
                  child: const Text('Lihat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, SelfOrderAlert alert) {
    final money = NumberFormat('#,###', 'id_ID');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(alert.title),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in alert.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${line.quantity}x ${line.name}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (line.note != null)
                          Text(
                            'Catatan: ${line.note}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                  ),
                const Divider(),
                Text(
                  'Total Rp ${money.format(alert.totalAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (alert.orderNote != null) ...[
                  const SizedBox(height: 8),
                  Text('Catatan pesanan: ${alert.orderNote}'),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Pesanan ini belum dibayar dan ada di daftar pesanan. Proses '
                  'pembayaran dari sana.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () =>
                SelfOrderInboxService.instance.printKitchen(alert, all: true),
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Cetak Dapur'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
