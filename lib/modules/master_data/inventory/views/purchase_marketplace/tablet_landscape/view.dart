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

class _PurchaseMarketplaceViewState extends State<PurchaseMarketplaceView> {
  final InventoryListStore _store = InventoryListStore.instance;
  final PurchaseOrderRequestStore _requestStore = PurchaseOrderRequestStore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<MarketplaceItem> _remoteItems = <MarketplaceItem>[];
  bool _remoteLoading = false;
  static const int _cacheTTLHours = 24;
  static const int _pruneDays = 30;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyFmt = NumberFormat('#,###', 'id_ID');
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return ValueListenableBuilder<MasterDataListSnapshot<InventoryItemRecord>>(
      valueListenable: _store.snapshotNotifier,
      builder: (context, snapshot, _) {
        final records = snapshot.records;

        if (snapshot.isLoading && records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.errorMessage != null && records.isEmpty) {
          return MasterDataErrorView(message: snapshot.errorMessage!);
        }

        // If remote marketplace items are available, show them instead of local records
        if (_remoteLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_remoteItems.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.purchaseMarketplaceTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.purchaseMarketplaceSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _remoteItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final itm = _remoteItems[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: itm.imageUrl != null && itm.imageUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: itm.imageUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              color: primaryColor.withOpacity(0.08),
                                              child: Center(
                                                child: Text(
                                                  itm.displayName.isNotEmpty ? itm.displayName[0].toUpperCase() : '?',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              color: primaryColor.withOpacity(0.08),
                                              child: Center(
                                                child: Text(
                                                  itm.displayName.isNotEmpty ? itm.displayName[0].toUpperCase() : '?',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              itm.displayName.isNotEmpty ? itm.displayName[0].toUpperCase() : '?',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itm.displayName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  itm.groupName ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Harga: Rp ${itm.rateFormatted}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _showPurchaseRequestFromRemote(itm),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 12,
                                        ),
                                        backgroundColor: primaryColor.withOpacity(0.08),
                                        foregroundColor: primaryColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Pesan'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase Marketplace',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Semua pembelian hanya dari vendor pusat. Item ini tersedia untuk pemesanan ulang.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            MasterDataSearchHeader(
              searchController: _searchController,
              searchHint: l10n.marketplaceSearchHint,
              onSearchChanged: _store.setSearchQuery,
              countText: '${records.length} listing',
              onRefresh: _store.refresh,
            ),
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
                            l10n.marketplaceOfflineNotice,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF92400E),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? MasterDataEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: l10n.marketplaceEmptyTitle,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = records[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    item.displayName.isNotEmpty
                                        ? item.displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.displayName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.categoryName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Harga pusat',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Stok pusat',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Rp ${currencyFmt.format(item.costAmount)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.stockQuantity.toStringAsFixed(0),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _showPurchaseRequest(item),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  backgroundColor: primaryColor.withOpacity(0.08),
                                  foregroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Pesan'),
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

  Future<void> _showPurchaseRequest(InventoryItemRecord item) async {
    final l10n = AppLocalizations.of(context)!;
    final qtyController = TextEditingController(text: '1');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.purchaseMarketplaceTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l10n.purchaseMarketplaceSubtitle}'),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.quantity,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.continueAction),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final quantity = double.tryParse(qtyController.text) ?? 0;
      if (quantity <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.quantityMustBeGreaterThanZero),
          ),
        );
        return;
      }

      try {
        await _requestStore.createRequest(item, quantity);
        _requestStore.refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseRequestSavedMessage(item.displayName)),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseRequestFailedMessage(error.toString())),
          ),
        );
      }
    }
  }

  Future<void> _showPurchaseRequestFromRemote(MarketplaceItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final qtyController = TextEditingController(text: '1');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.purchaseMarketplaceTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l10n.purchaseMarketplaceSubtitle}'),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.quantity,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.continueAction),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final quantity = double.tryParse(qtyController.text) ?? 0;
      if (quantity <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.quantityMustBeGreaterThanZero),
          ),
        );
        return;
      }

      try {
        // Create a local purchase request using available remote id if present
        final localItem = InventoryItemRecord(
          id: int.tryParse(item.itemId) ?? 0,
          name: item.displayName,
          sku: item.commodityCode ?? '',
          remoteId: item.itemId,
          categoryName: item.groupName ?? '',
          costAmount: item.rateCents,
          priceAmount: item.rateCents,
          stockQuantity: 0,
          minStockLevel: 0,
          status: 'active',
          isAvailable: true,
        );

        await _requestStore.createRequest(localItem, quantity);
        _requestStore.refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseRequestSavedMessage(item.displayName)),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.purchaseRequestFailedMessage(error.toString())),
          ),
        );
      }
    }
  }

  Future<void> _fetchMarketplace() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return;
    setState(() {
      _remoteLoading = true;
    });

    try {
      final client = V2ApiClient(baseUrl: session.baseUrl, authToken: session.authToken);
      final data = await client.getJson('api/items', query: {'type': 'can_be_purchased'});
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

        setState(() {
          _remoteItems = items;
        });
      }
    } catch (e) {
      // ignore and keep local fallback
    } finally {
      if (mounted) {
        setState(() {
          _remoteLoading = false;
        });
      }
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
 
