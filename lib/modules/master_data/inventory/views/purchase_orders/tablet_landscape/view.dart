import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flinkpos_v2/modules/master_data/shared/widgets/master_data_page_widgets.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/stores/inventory_read_stores.dart';
import 'package:flinkpos_v2/modules/master_data/stores/master_data_read_stores.dart';

class PurchaseOrdersView extends StatefulWidget {
  const PurchaseOrdersView({super.key});

  @override
  State<PurchaseOrdersView> createState() => _PurchaseOrdersViewState();
}

class _PurchaseOrdersViewState extends State<PurchaseOrdersView> {
  final PurchaseOrderStore _poStore = PurchaseOrderStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _poStore.refresh();
      PurchaseOrderRequestStore.instance.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFmt = NumberFormat('#,###', 'id_ID');

    return ValueListenableBuilder<MasterDataListSnapshot<PurchaseOrderRecord>>(
      valueListenable: _poStore.snapshotNotifier,
      builder: (context, snapshot, _) {
        final orders = snapshot.records;
        if (snapshot.isLoading && orders.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.errorMessage != null && orders.isEmpty) {
          return MasterDataErrorView(message: snapshot.errorMessage!);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${orders.length} purchase order',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _poStore.refresh,
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    color: theme.colorScheme.primary,
                  ),
                  const Spacer(),
                  // Flexible + a horizontally scrolling row keeps the legend
                  // on one line (no header height change) instead of
                  // overflowing this Row on narrower detail panes (e.g. the
                  // Data Master master-detail layout) or wrapping to a
                  // second line and growing the header.
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildLegend(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            if (orders.isEmpty)
              const Expanded(
                child: MasterDataEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum ada purchase order.',
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildTableHeader(theme),
                    const SizedBox(height: 6),
                    for (final order in orders) ...[
                      _buildTableRow(
                        theme: theme,
                        order: order,
                        currencyFmt: currencyFmt,
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLegend() {
    final statuses = <_PoStatusInfo>[
      _PoStatusInfo('pending', 'Dipesan', const Color(0xFFF59E0B)),
      _PoStatusInfo('processing', 'Diproses', const Color(0xFF3B82F6)),
      _PoStatusInfo('completed', 'Selesai', const Color(0xFF22C55E)),
      _PoStatusInfo('failed', 'Gagal', const Color(0xFFEF4444)),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in statuses) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(s.label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          if (s != statuses.last) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _buildTableHeader(ThemeData theme) {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: Color(0xFF6B7280),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('KODE PO', style: headerStyle)),
          Expanded(flex: 3, child: Text('TANGGAL', style: headerStyle)),
          Expanded(flex: 2, child: Text('ITEM', style: headerStyle)),
          Expanded(flex: 3, child: Text('TOTAL', style: headerStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: headerStyle)),
          SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required ThemeData theme,
    required PurchaseOrderRecord order,
    required NumberFormat currencyFmt,
  }) {
    final status = _statusInfo(order.status);
    return InkWell(
      onTap: () => _showOrderDetail(order),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                order.poCode,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _formatDate(order.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${order.itemCount} unit',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Rp ${currencyFmt.format(order.totalAmount)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: status.color,
                  ),
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _showOrderDetail(PurchaseOrderRecord order) async {
    final lines = await _poStore.loadLines(order.id);
    if (!mounted) return;

    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final status = _statusInfo(order.status);
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.poCode,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dibuat: ${_formatDate(order.createdAt)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: status.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (lines.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Tidak ada detail item.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: lines.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final line = lines[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.productName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    if (line.productSku.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU: ${line.productSku}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      '${line.quantity.toStringAsFixed(0)} × Rp ${currencyFmt.format(line.unitCostAmount)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Rp ${currencyFmt.format(line.subtotalAmount)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        'Jumlah item: ${order.itemCount} unit',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      Text(
                        'Total',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Rp ${currencyFmt.format(order.totalAmount)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '-';
    final parsed = DateTime.tryParse(iso.replaceFirst(' ', 'T'));
    if (parsed == null) return iso;
    return DateFormat('dd MMM yyyy, HH:mm').format(parsed.toLocal());
  }
}

class _PoStatusInfo {
  const _PoStatusInfo(this.code, this.label, this.color);

  final String code;
  final String label;
  final Color color;
}

_PoStatusInfo _statusInfo(String code) {
  switch (code) {
    case 'pending':
      return const _PoStatusInfo('pending', 'Dipesan', Color(0xFFF59E0B));
    case 'processing':
      return const _PoStatusInfo('processing', 'Diproses', Color(0xFF3B82F6));
    case 'completed':
      return const _PoStatusInfo('completed', 'Selesai', Color(0xFF22C55E));
    case 'failed':
      return const _PoStatusInfo('failed', 'Gagal', Color(0xFFEF4444));
    default:
      return const _PoStatusInfo('pending', 'Dipesan', Color(0xFFF59E0B));
  }
}