import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flinkpos_v2/modules/master_data/shared/widgets/master_data_page_widgets.dart';
import 'package:flinkpos_v2/modules/master_data/inventory/stores/inventory_read_stores.dart';
import 'package:flinkpos_v2/modules/master_data/stores/master_data_read_stores.dart';
import 'dart:convert';

import 'package:flinkpos_v2/core/network/v2_api_client.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_runtime_session_store.dart';
import 'package:flinkpos_v2/core/services/local/database_service.dart';
import 'package:flinkpos_v2/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class PurchaseMarketplaceView extends StatefulWidget {
  const PurchaseMarketplaceView({super.key});

  @override
  State<PurchaseMarketplaceView> createState() => _PurchaseMarketplaceViewState();
}

class _CartEntry {
  _CartEntry({
    required this.key,
    required this.name,
    required this.sku,
    this.productId,
    this.remoteId,
    required this.unitCost,
    this.imageUrl,
    this.group,
  });

  final String key;
  final String name;
  final String sku;
  final int? productId;
  final String? remoteId;
  final int unitCost;
  final String? imageUrl;
  final String? group;

  PurchaseOrderInputLine toInputLine(int qty) => PurchaseOrderInputLine(
        productId: productId,
        productRemoteId: remoteId,
        productName: name,
        productSku: sku,
        quantity: qty.toDouble(),
        unitCostAmount: unitCost,
      );
}

class _PurchaseMarketplaceViewState extends State<PurchaseMarketplaceView> {
  final InventoryListStore _store = InventoryListStore.instance;
  final PurchaseOrderRequestStore _requestStore = PurchaseOrderRequestStore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<MarketplaceItem> _remoteItems = <MarketplaceItem>[];
  bool _submitting = false;
  static const int _pruneDays = 30;

  final Map<String, int> _cartQty = <String, int>{};
  final Map<String, _CartEntry> _cartEntries = <String, _CartEntry>{};

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

  void _addToCart(_CartEntry entry) {
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
                .whereType<_CartEntry>()
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

  Widget _buildItemCard(ThemeData theme, Color primaryColor, _CartEntry entry) {
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                      height: 34,
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
                      height: 34,
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

  Widget _buildItemImage(_CartEntry entry, Color primaryColor) {
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

  _CartEntry _entryFromRemote(MarketplaceItem item) {
    return _CartEntry(
      key: 'r:${item.itemId}',
      name: item.displayName,
      sku: item.commodityCode ?? item.skuCode ?? '',
      remoteId: item.itemId,
      unitCost: item.rateCents,
      imageUrl: item.imageUrl,
      group: item.groupName,
    );
  }

  _CartEntry? _entryFromLocal(InventoryItemRecord item) {
    return _CartEntry(
      key: 'l:${item.id}',
      name: item.name,
      sku: item.sku,
      productId: item.id,
      remoteId: item.remoteId,
      unitCost: item.costAmount,
      group: item.displayName,
    );
  }

  Future<void> _fetchMarketplace() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return;

    try {
      final client = V2ApiClient(baseUrl: session.baseUrl, authToken: session.authToken);
      final data = await client
          .getJson('api/items', query: {'type': 'can_be_purchased'})
          .timeout(const Duration(seconds: 15));
      if (data is List) {
        final items = data.map((e) {
          final map = e as Map<String, dynamic>;
          return MarketplaceItem.fromJson(map);
        }).toList(growable: false);
        // persist into local cache
        try {
          await DatabaseService.instance.transaction((txn) async {
            for (final itm in items) {
              await DatabaseService.instance.upsertByUnique(
                txn,
                'marketplace_item',
                where: 'tenant_id = ? AND item_remote_id = ?',
                whereArgs: <Object?>[session.tenantId, itm.itemId],
                insertValues: <String, Object?>{
                  'tenant_id': session.tenantId,
                  'item_remote_id': itm.itemId,
                  'description': itm.description,
                  'rate': itm.rate,
                  'commodity_code': itm.commodityCode,
                  'sku_code': itm.skuCode,
                  'group_name': itm.groupName,
                  'image_url': itm.imageUrl,
                  'can_be_inventory': itm.canBeInventory ? '1' : '0',
                  'images_json': jsonEncode(itm.images ?? []),
                  'raw_payload_json': itmRawJson(itm),
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                },
                updateValues: <String, Object?>{
                  'description': itm.description,
                  'rate': itm.rate,
                  'commodity_code': itm.commodityCode,
                  'sku_code': itm.skuCode,
                  'group_name': itm.groupName,
                  'image_url': itm.imageUrl,
                  'can_be_inventory': itm.canBeInventory ? '1' : '0',
                  'images_json': jsonEncode(itm.images ?? []),
                  'raw_payload_json': itmRawJson(itm),
                  'updated_at': DateTime.now().toIso8601String(),
                },
              );
            }
            // prune old cache entries older than _pruneDays
            try {
              final cutoff = DateTime.now().subtract(Duration(days: _pruneDays)).toIso8601String();
              await txn.delete(
                'marketplace_item',
                where: 'tenant_id = ? AND updated_at < ?',
                whereArgs: <Object?>[session.tenantId, cutoff],
              );
            } catch (_) {}
          });
        } catch (_) {
          // ignore DB write errors
        }

        if (!mounted) return;
        setState(() {
          _remoteItems = items;
        });
      }
    } catch (e) {
      // ignore and keep local fallback
    }
  }

  static String itmRawJson(MarketplaceItem itm) {
    return '''{"itemid":"${itm.itemId}","rate":"${itm.rate}","group_name":"${itm.groupName ?? ''}","description":"${itm.description}","commodity_code":"${itm.commodityCode ?? ''}"}''';
  }

  Future<void> _loadCachedMarketplace() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return;
    try {
      final rows = await DatabaseService.instance.query(
        'marketplace_item',
        where: 'tenant_id = ?',
        whereArgs: <Object?>[session.tenantId],
        orderBy: 'created_at DESC',
      );

      final items = rows.map((r) {
        return MarketplaceItem.fromDbRow(r);
      }).toList(growable: false);

      if (mounted) {
        setState(() {
          _remoteItems = items;
        });
      }
    } catch (_) {
      // ignore
    }
  }
}

class MarketplaceItem {
  MarketplaceItem({
    required this.itemId,
    required this.rate,
    this.groupName,
    required this.description,
    this.commodityCode,
    this.skuCode,
    this.imageUrl,
    this.images,
    this.canBeInventory = false,
  });

  final String itemId;
  final String rate;
  final String? groupName;
  final String description;
  final String? commodityCode;
  final String? skuCode;
  final String? imageUrl;
  final List<dynamic>? images;
  final bool canBeInventory;

  String get displayName => description;

  int get rateCents {
    // rate provided as decimal string like "20000.00"
    final asDouble = double.tryParse(rate) ?? 0.0;
    return asDouble.toInt();
  }

  String get rateFormatted {
    try {
      final v = double.tryParse(rate) ?? 0.0;
      final rounded = v.toInt();
      return rounded.toString();
    } catch (_) {
      return rate;
    }
  }

  factory MarketplaceItem.fromJson(Map<String, dynamic> json) {
    return MarketplaceItem(
      itemId: json['itemid']?.toString() ?? '',
      rate: json['rate']?.toString() ?? '0',
      groupName: json['group_name']?.toString(),
      description: json['description']?.toString() ?? '',
      commodityCode: json['commodity_code']?.toString(),
      skuCode: json['sku_code']?.toString(),
      imageUrl: json['image_url']?.toString(),
      images: json['images'] is List ? json['images'] as List<dynamic> : null,
      canBeInventory: (json['can_be_inventory']?.toString() ?? '').isNotEmpty,
    );
  }

  factory MarketplaceItem.fromDbRow(Map<String, Object?> row) {
    return MarketplaceItem(
      itemId: row['item_remote_id']?.toString() ?? '',
      rate: row['rate']?.toString() ?? '0',
      groupName: row['group_name']?.toString(),
      description: row['description']?.toString() ?? '',
      commodityCode: row['commodity_code']?.toString(),
      skuCode: row['sku_code']?.toString(),
      imageUrl: row['image_url']?.toString(),
      images: row['images_json'] != null && row['images_json'] is String && (row['images_json'] as String).isNotEmpty
          ? jsonDecode(row['images_json'] as String) as List<dynamic>
          : null,
      canBeInventory: row['can_be_inventory']?.toString() == '1',
    );
  }
}
