import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/network/v2_api_client.dart';
import '../../../../../core/services/local/database_service.dart';
import '../../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../stores/inventory_read_stores.dart';
import '../../../stores/master_data_read_stores.dart';

class InventoryMobileView extends StatefulWidget {
  const InventoryMobileView({super.key});

  @override
  State<InventoryMobileView> createState() => _InventoryMobileViewState();
}

class _InventoryMobileViewState extends State<InventoryMobileView> {
  final _inventoryStore = InventoryListStore.instance;
  final _requestStore = PurchaseOrderRequestStore.instance;
  List<_MarketplaceItem> _marketplaceItems = const [];
  bool _isMarketplaceLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inventoryStore.refresh();
      _requestStore.refresh();
      _loadMarketplace();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      _inventoryStore.refresh(),
      _requestStore.refresh(),
      _loadMarketplace(),
    ]);
  }

  Future<void> _loadMarketplace() async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null) {
      if (mounted) {
        setState(() => _isMarketplaceLoading = false);
      }
      return;
    }
    final rows = await DatabaseService.instance.query(
      'marketplace_item',
      where: 'tenant_id = ?',
      whereArgs: [session.tenantId],
      orderBy: 'updated_at DESC',
    );
    final cachedItems = rows.map(_MarketplaceItem.fromRow).toList();
    if (mounted) {
      setState(() => _marketplaceItems = cachedItems);
    }

    try {
      final client = V2ApiClient(
        baseUrl: session.baseUrl,
        authToken: session.authToken,
      );
      final data = await client.getJson(
        'api/items',
        query: const {'type': 'can_be_purchased'},
      );
      if (data is List) {
        final remoteItems = data
            .whereType<Map>()
            .map(
              (item) =>
                  _MarketplaceItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
        await DatabaseService.instance.transaction((txn) async {
          for (final item in remoteItems) {
            await DatabaseService.instance.upsertByUnique(
              txn,
              'marketplace_item',
              where: 'tenant_id = ? AND item_remote_id = ?',
              whereArgs: [session.tenantId, item.remoteId],
              insertValues: item.toDatabaseRow(session.tenantId),
              updateValues: item.toDatabaseRow(session.tenantId),
            );
          }
        });
        if (mounted) {
          setState(() => _marketplaceItems = remoteItems);
        }
      }
    } catch (_) {
      // Retain the local cache while the central marketplace is unavailable.
    } finally {
      if (mounted) {
        setState(() => _isMarketplaceLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: ColoredBox(
        color: const Color(0xFFF7F9FC),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventori',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Stok & pembelian toko',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Muat ulang',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                labelColor: Color(0xFF155EEF),
                unselectedLabelColor: Color(0xFF667085),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                tabs: [
                  Tab(text: 'Stok'),
                  Tab(text: 'Marketplace'),
                  Tab(text: 'Permintaan'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildInventory(),
                  _buildMarketplace(),
                  _buildRequests(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventory() {
    return ValueListenableBuilder<MasterDataListSnapshot<InventoryItemRecord>>(
      valueListenable: _inventoryStore.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.errorMessage != null && snapshot.records.isEmpty) {
          return _ErrorState(
            message: snapshot.errorMessage!,
            onRetry: _inventoryStore.refresh,
          );
        }
        final lowStock = snapshot.records
            .where((item) => item.isLowStock)
            .length;
        return RefreshIndicator(
          onRefresh: _inventoryStore.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: snapshot.records.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SummaryCard(
                  count: snapshot.records.length,
                  lowStock: lowStock,
                );
              }
              return _InventoryCard(item: snapshot.records[index - 1]);
            },
          ),
        );
      },
    );
  }

  Widget _buildMarketplace() {
    if (_isMarketplaceLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_marketplaceItems.isEmpty) {
      return const _EmptyState(
        icon: Icons.storefront_outlined,
        message:
            'Katalog marketplace belum tersedia. Segarkan data saat online.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMarketplace,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: _marketplaceItems.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _MarketplaceHeroCard(itemCount: _marketplaceItems.length);
          }
          final item = _marketplaceItems[index - 1];
          return _MarketplaceCard(
            item: item,
            onOrder: () => _requestMarketplacePurchase(item),
          );
        },
      ),
    );
  }

  Widget _buildRequests() {
    return ValueListenableBuilder<
      MasterDataListSnapshot<PurchaseOrderRequestRecord>
    >(
      valueListenable: _requestStore.snapshotNotifier,
      builder: (context, snapshot, _) {
        if (snapshot.isLoading && snapshot.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.records.isEmpty) {
          return const _EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'Belum ada permintaan pembelian.',
          );
        }
        return RefreshIndicator(
          onRefresh: _requestStore.refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: snapshot.records.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _RequestCard(request: snapshot.records[index]),
          ),
        );
      },
    );
  }

  Future<void> _requestPurchase(InventoryItemRecord item) async {
    final quantity = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PurchaseRequestSheet(itemName: item.displayName),
    );
    if (quantity == null || quantity <= 0 || !mounted) return;
    try {
      await _requestStore.createRequest(item, quantity);
      await _requestStore.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permintaan ${item.displayName} disimpan.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat permintaan: $error')),
        );
      }
    }
  }

  Future<void> _requestMarketplacePurchase(_MarketplaceItem item) {
    return _requestPurchase(
      InventoryItemRecord(
        id: int.tryParse(item.remoteId) ?? 0,
        name: item.name,
        sku: item.sku,
        remoteId: item.remoteId,
        categoryName: item.groupName,
        costAmount: item.price,
        priceAmount: item.price,
        stockQuantity: 0,
        minStockLevel: 0,
        status: 'active',
        isAvailable: true,
      ),
    );
  }
}

class _PurchaseRequestSheet extends StatefulWidget {
  const _PurchaseRequestSheet({required this.itemName});
  final String itemName;

  @override
  State<_PurchaseRequestSheet> createState() => _PurchaseRequestSheetState();
}

class _PurchaseRequestSheetState extends State<_PurchaseRequestSheet> {
  final _quantityController = TextEditingController(text: '1');

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pesan ${widget.itemName}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _quantityController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Jumlah'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(_quantityController.text),
            ),
            child: const Text('Buat permintaan'),
          ),
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count, required this.lowStock});
  final int count;
  final int lowStock;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF155EEF), Color(0xFF2E90FA)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 25,
          backgroundColor: Color(0x33FFFFFF),
          child: Icon(Icons.inventory_2_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count barang terpantau',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                lowStock == 0
                    ? 'Semua stok aman.'
                    : '$lowStock barang perlu perhatian.',
                style: const TextStyle(color: Color(0xDFFFFFFF)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item});
  final InventoryItemRecord item;
  @override
  Widget build(BuildContext context) {
    final low = item.isLowStock;
    final color = item.isOutOfStock
        ? Colors.red
        : low
        ? Colors.orange
        : Colors.green;
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductThumbnail(
                  imageUrl: item.imageUrl,
                  label: item.displayName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.categoryName} • ${item.sku}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _Pill(
                  label: item.isOutOfStock
                      ? 'Habis'
                      : low
                      ? 'Menipis'
                      : 'Normal',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _Metric(
                    label: 'Stok',
                    value: item.stockQuantity.toStringAsFixed(0),
                  ),
                  _Metric(
                    label: 'Minimum',
                    value: item.minStockLevel.toStringAsFixed(0),
                  ),
                  _Metric(label: 'Harga beli', value: _rupiah(item.costAmount)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({required this.item, required this.onOrder});
  final _MarketplaceItem item;
  final VoidCallback onOrder;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        _ProductThumbnail(imageUrl: item.imageUrl, label: item.name, size: 62),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.groupName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                _rupiah(item.price),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: onOrder,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          child: const Text('Pesan'),
        ),
      ],
    ),
  );
}

class _MarketplaceHeroCard extends StatelessWidget {
  const _MarketplaceHeroCard({required this.itemCount});
  final int itemCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEEF4FF), Color(0xFFDDEBFF)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFC7DCFF)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF155EEF),
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33155EEF),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Marketplace pusat',
                style: TextStyle(
                  color: Color(0xFF12336D),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih item untuk membuat permintaan pembelian ke vendor pusat.',
                style: TextStyle(
                  color: Color(0xFF365483),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$itemCount item tersedia',
                  style: const TextStyle(
                    color: Color(0xFF155EEF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final PurchaseOrderRequestRecord request;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                request.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            _Pill(
              label: request.queueStatus == 'pending'
                  ? 'Menunggu sync'
                  : request.queueStatus,
              color: request.queueStatus == 'failed'
                  ? Colors.red
                  : request.queueStatus == 'pending'
                  ? Colors.orange
                  : Colors.blue,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(request.productSku, style: Theme.of(context).textTheme.bodySmall),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        Row(
          children: [
            _Metric(
              label: 'Jumlah',
              value: '${request.quantity.toStringAsFixed(0)} unit',
            ),
            _Metric(
              label: 'Dibuat',
              value: _formatRequestDate(request.createdAt),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40),
        const SizedBox(height: 12),
        Text(message),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

class _MarketplaceItem {
  const _MarketplaceItem({
    required this.remoteId,
    required this.name,
    required this.sku,
    required this.groupName,
    required this.price,
    this.imageUrl,
  });
  final String remoteId;
  final String name;
  final String sku;
  final String groupName;
  final int price;
  final String? imageUrl;
  factory _MarketplaceItem.fromRow(Map<String, Object?> row) =>
      _MarketplaceItem(
        remoteId: row['item_remote_id']?.toString() ?? '',
        name: row['description']?.toString() ?? '-',
        sku:
            row['sku_code']?.toString() ??
            row['commodity_code']?.toString() ??
            '-',
        groupName: row['group_name']?.toString() ?? '—',
        price: (double.tryParse(row['rate']?.toString() ?? '') ?? 0).round(),
        imageUrl: row['image_url']?.toString(),
      );
  factory _MarketplaceItem.fromJson(Map<String, dynamic> json) =>
      _MarketplaceItem(
        remoteId: json['itemid']?.toString() ?? '',
        name: json['description']?.toString() ?? '-',
        sku:
            json['sku_code']?.toString() ??
            json['commodity_code']?.toString() ??
            '-',
        groupName: json['group_name']?.toString() ?? '—',
        price: (double.tryParse(json['rate']?.toString() ?? '') ?? 0).round(),
        imageUrl: json['image_url']?.toString(),
      );
  Map<String, Object?> toDatabaseRow(int tenantId) => {
    'tenant_id': tenantId,
    'item_remote_id': remoteId,
    'description': name,
    'rate': price.toString(),
    'sku_code': sku,
    'commodity_code': sku,
    'group_name': groupName,
    'image_url': imageUrl,
    'can_be_inventory': '1',
    'images_json': jsonEncode(const []),
    'updated_at': DateTime.now().toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
  };
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({
    required this.imageUrl,
    required this.label,
    this.size = 54,
  });
  final String? imageUrl;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFEAF2FF),
      alignment: Alignment.center,
      child: Text(
        label.isEmpty ? '?' : label[0].toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: size * .32,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: (imageUrl ?? '').trim().isEmpty
            ? fallback
            : ColoredBox(
                color: Colors.white,
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
              ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0xFFE9EEF5)),
  boxShadow: const [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4)),
  ],
);

String _formatRequestDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value.isEmpty ? '—' : value;
  return DateFormat('d MMM, HH:mm', 'id_ID').format(date);
}

String _rupiah(int value) =>
    'Rp ${NumberFormat.decimalPattern('id_ID').format(value)}';
