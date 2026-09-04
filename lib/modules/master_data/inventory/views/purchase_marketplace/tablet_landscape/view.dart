import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flinkpos_v2/modules/master_data/shared/widgets/master_data_page_widgets.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/stores/inventory_read_stores.dart';
import 'package:flinkpos_v2/modules/master_data/stores/master_data_read_stores.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/models/marketplace_item.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/services/marketplace_service.dart';
import 'package:flinkpos_v2/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PurchaseMarketplaceView extends StatefulWidget {
  const PurchaseMarketplaceView({super.key});

  @override
  State<PurchaseMarketplaceView> createState() => _PurchaseMarketplaceViewState();
}


class _PurchaseMarketplaceViewState extends State<PurchaseMarketplaceView> {
  final InventoryListStore _store = InventoryListStore.instance;
  final PurchaseOrderRequestStore _requestStore = PurchaseOrderRequestStore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<MarketplaceItem> _remoteItems = <MarketplaceItem>[];
  bool _submitting = false;

  final Map<String, int> _cartQty = <String, int>{};
  final Map<String, CartEntry> _cartEntries = <String, CartEntry>{};

  int get _cartTotalQty =>
      _cartQty.values.fold(0, (sum, v) => sum + v);

  int get _cartTotalAmount {
    var total = 0;
    _cartQty.forEach((key, qty) {
      total += (_cartEntries[key]?.unitCost ?? 0) * qty;
    });
    return total;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.refresh();
      _loadCachedMarketplace();
      _fetchMarketplace();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _addToCart(CartEntry entry) {
    setState(() {
      _cartEntries[entry.key] = entry;
      _cartQty[entry.key] = (_cartQty[entry.key] ?? 0) + 1;
    });
  }

  void _increment(String key) {
    setState(() {
      _cartQty[key] = (_cartQty[key] ?? 0) + 1;
    });
  }

  void _decrement(String key) {
    setState(() {
      final current = _cartQty[key] ?? 0;
      if (current <= 1) {
        _cartQty.remove(key);
        _cartEntries.remove(key);
      } else {
        _cartQty[key] = current - 1;
      }
    });
  }

  int _qtyFor(String key) => _cartQty[key] ?? 0;

  Future<void> _submitOrder() async {
    if (_submitting || _cartQty.isEmpty) return;
    setState(() => _submitting = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final lines = <PurchaseOrderInputLine>[
        for (final entry in _cartEntries.entries)
          if ((_cartQty[entry.key] ?? 0) > 0)
            entry.value.toInputLine(_cartQty[entry.key]!),
      ];
      final poCode = await _requestStore.createOrder(lines: lines);
      _requestStore.refresh();
      PurchaseOrderStore.instance.refresh();
      setState(() {
        _cartQty.clear();
        _cartEntries.clear();
        _submitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase order $poCode berhasil dibuat.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      setState(() => _submitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.purchaseRequestFailedMessage(error.toString())),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<MasterDataListSnapshot<InventoryItemRecord>>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        final records = snapshot.records;

        if (snapshot.isLoading && records.isEmpty && _remoteItems.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasRemote = _remoteItems.isNotEmpty;
        final entries = hasRemote
            ? _remoteItems.map(_entryFromRemote).toList(growable: false)
            : records
                .map((r) => _entryFromLocal(r))
                .whereType<CartEntry>()
                .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MasterDataSearchHeader(
              searchController: _searchController,
              searchHint: hasRemote
                  ? 'Cari item marketplace'
                  : 'Cari stok inventory',
              onSearchChanged: _store.setSearchQuery,
              countText:
                  hasRemote ? '${entries.length} listing' : '${entries.length} stok',
              onRefresh: _store.refresh,
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            if (!hasRemote)
              Container(
                width: double.infinity,
                color: const Color(0xFFFEF3C7),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.warehouse_rounded, size: 18, color: Color(0xFF92400E)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Marketplace sedang offline. Menggunakan katalog lokal untuk pemesanan.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: entries.isEmpty
                  ? MasterDataEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Tidak ada item untuk dipesan.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 320,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.92,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _buildItemCard(theme, primaryColor, entry);
                      },
                    ),
            ),
            if (_cartTotalQty > 0) _buildCartBar(theme, primaryColor),
          ],
        );
      },
    );
  }

  Widget _buildItemCard(ThemeData theme, Color primaryColor, CartEntry entry) {
    final qty = _qtyFor(entry.key);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: _buildItemImage(entry, primaryColor),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (entry.group != null && entry.group!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      entry.group!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Rp ${NumberFormat('#,###', 'id_ID').format(entry.unitCost)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  const Spacer(),
                  if (qty == 0)
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _addToCart(entry),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor.withValues(alpha: 0.10),
                          foregroundColor: primaryColor,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                        label: const Text(
                          'Tambahkan ke Keranjang',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: IconButton(
                              onPressed: () => _decrement(entry.key),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minHeight: 32),
                              icon: Icon(Icons.remove_rounded, size: 18, color: primaryColor),
                            ),
                          ),
                          Text(
                            '$qty',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                          Expanded(
                            child: IconButton(
                              onPressed: () => _increment(entry.key),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minHeight: 32),
                              icon: Icon(Icons.add_rounded, size: 18, color: primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(CartEntry entry, Color primaryColor) {
    final hasImage = entry.imageUrl != null && entry.imageUrl!.isNotEmpty;
    final initial = entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?';
    return Container(
      color: primaryColor.withValues(alpha: 0.07),
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: entry.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  Center(child: Text(initial, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor))),
              errorWidget: (context, url, error) =>
                  Center(child: Text(initial, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor))),
            )
          : Center(
              child: Icon(Icons.inventory_2_outlined, size: 28, color: primaryColor.withValues(alpha: 0.5)),
            ),
    );
  }

  Widget _buildCartBar(ThemeData theme, Color primaryColor) {
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shopping_cart_outlined, size: 20, color: primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_cartTotalQty item dipilih',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp ${currencyFmt.format(_cartTotalAmount)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primaryColor),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: _submitting ? null : _submitOrder,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Buat Purchase Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  CartEntry _entryFromRemote(MarketplaceItem item) {
    return CartEntry(
      key: 'r:${item.itemId}',
      name: item.displayName,
      sku: item.commodityCode ?? item.skuCode ?? '',
      remoteId: item.itemId,
      unitCost: item.rateCents,
      imageUrl: item.imageUrl,
      group: item.groupName,
    );
  }

  CartEntry? _entryFromLocal(InventoryItemRecord item) {
    return CartEntry(
      key: 'l:${item.id}',
      name: item.name,
      sku: item.sku,
      productId: item.id,
      remoteId: item.remoteId,
      unitCost: item.costAmount,
      group: item.categoryName,
    );
  }

  Future<void> _fetchMarketplace() async {
    final items = await MarketplaceService.instance.fetchRemoteItems();
    if (items != null && mounted) {
      setState(() {
        _remoteItems = items;
      });
    }
  }

  Future<void> _loadCachedMarketplace() async {
    final items = await MarketplaceService.instance.loadCachedItems();
    if (mounted) {
      setState(() {
        _remoteItems = items;
      });
    }
  }

}

