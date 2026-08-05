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
  final PurchaseOrderRequestStore _requestStore = PurchaseOrderRequestStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestStore.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFmt = NumberFormat('#,###', 'id_ID');

    return ValueListenableBuilder<MasterDataListSnapshot<PurchaseOrderRequestRecord>>(
      valueListenable: _requestStore.snapshotNotifier,
      builder: (context, snapshot, _) {
        final requests = snapshot.records;
        if (snapshot.isLoading && requests.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.errorMessage != null && requests.isEmpty) {
          return MasterDataErrorView(message: snapshot.errorMessage!);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase Orders',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Lihat status permintaan pembelian dan kirim ulang jika perlu.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: requests.isEmpty
                  ? const MasterDataEmptyState(
                      icon: Icons.list_alt_outlined,
                      title: 'Belum ada permintaan pembelian.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    request.productName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: request.queueStatus == 'pending'
                                          ? const Color(0xFFFEE2E2)
                                          : request.queueStatus == 'failed'
                                              ? const Color(0xFFFEF3C7)
                                              : const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      request.queueStatus.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: request.queueStatus == 'pending'
                                            ? const Color(0xFFB91C1C)
                                            : request.queueStatus == 'failed'
                                                ? const Color(0xFF92400E)
                                                : const Color(0xFF0369A1),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('SKU: ${request.productSku}'),
                              const SizedBox(height: 4),
                              Text('Jumlah: ${request.quantity.toStringAsFixed(0)}'),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Dibuat: ${request.createdAt}'),
                                  TextButton(
                                    onPressed: () {},
                                    child: const Text('Detail'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
