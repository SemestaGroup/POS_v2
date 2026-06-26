import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../stores/operations_read_stores.dart';

class KitchenMonitorView extends StatefulWidget {
  const KitchenMonitorView({super.key});

  @override
  State<KitchenMonitorView> createState() => _KitchenMonitorViewState();
}

class _KitchenMonitorViewState extends State<KitchenMonitorView> {
  final KitchenMonitorStore _store = KitchenMonitorStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh(filter: _store.snapshotNotifier.value.filter);
    });
  }

  Color _statusColor(String statusCode) {
    switch (statusCode) {
      case 'draft':
        return const Color(0xFFF59E0B);
      case 'hold':
        return const Color(0xFF6366F1);
      case 'unpaid':
        return const Color(0xFF3B82F6);
      case 'paid':
      case 'posted':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String statusCode) {
    switch (statusCode) {
      case 'draft':
        return 'Baru';
      case 'hold':
        return 'Ditahan';
      case 'unpaid':
        return 'Menunggu Bayar';
      case 'paid':
      case 'posted':
        return 'Selesai';
      default:
        return statusCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<KitchenSnapshot>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.orders.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.orders.isEmpty) {
          return Center(
            child: Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Icon(Icons.restaurant_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Monitor Dapur',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${snapshot.orders.length} Pesanan',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: primaryColor),
                    ),
                  ),
                  const Spacer(),
                  _filterChip('Aktif', 'active', primaryColor, snapshot),
                  const SizedBox(width: 6),
                  _filterChip('Semua', 'all', primaryColor, snapshot),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _store.refresh(filter: snapshot.filter),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: 'Refresh',
                    color: primaryColor,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: snapshot.orders.isEmpty
                  ? Center(
                      child: Text(
                        'Tidak ada pesanan aktif di dapur.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: snapshot.orders.length,
                        itemBuilder: (context, index) =>
                            _buildOrderCard(snapshot.orders[index], primaryColor),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String label, String value, Color color, KitchenSnapshot snapshot) {
    final active = snapshot.filter == value;
    return InkWell(
      onTap: () => _store.refresh(filter: value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(KitchenOrderRecord order, Color primaryColor) {
    final statusColor = _statusColor(order.statusCode);
    final timeDiff = DateTime.now().difference(order.createdAt);
    final minutes = timeDiff.inMinutes;
    final isUrgent = minutes > 15;
    final dateFmt = DateFormat('HH:mm', 'id_ID');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent ? Colors.orange.shade300 : Colors.grey.shade100,
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    order.idPos,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(order.statusCode),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.tableCode == null || order.tableCode!.isEmpty ? order.orderTypeCode : 'Table ${order.tableCode}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                    const Spacer(),
                    Text(
                      dateFmt.format(order.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isUrgent ? '$minutes menit • prioritas' : '$minutes menit',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isUrgent ? const Color(0xFFF59E0B) : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 12),
                ...order.items.take(6).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.quantity}x ${item.productName}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                              ),
                              if ((item.note ?? '').trim().isNotEmpty)
                                Text(
                                  item.note!,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (order.items.length > 6)
                  Text(
                    '+${order.items.length - 6} item lainnya',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
