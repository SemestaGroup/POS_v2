import 'package:flinkpos_v2/core/network/v2_api_client.dart';
import 'package:flinkpos_v2/core/services/local/database_service.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_runtime_session_store.dart';
import '../../stores/master_data_read_stores.dart';

class InventoryItemRecord {
  const InventoryItemRecord({
    required this.id,
    required this.name,
    required this.sku,
    this.remoteId,
    required this.categoryName,
    required this.costAmount,
    required this.priceAmount,
    required this.stockQuantity,
    required this.minStockLevel,
    required this.status,
    required this.isAvailable,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String sku;
  final String? remoteId;
  final String categoryName;
  final int costAmount;
  final int priceAmount;
  final double stockQuantity;
  final double minStockLevel;
  final String status;
  final bool isAvailable;
  final String? imageUrl;

  bool get isLowStock => stockQuantity <= minStockLevel;
  bool get isOutOfStock => stockQuantity <= 0;

  String get displayName => name.isNotEmpty ? name : sku;
}

class InventoryListStore extends BaseMasterDataStore<InventoryItemRecord> {
  InventoryListStore._();

  static final InventoryListStore instance = InventoryListStore._();

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int? _categoryId;
  int? get categoryId => _categoryId;

  int? _brandId;
  int? get brandId => _brandId;

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      refresh();
    }
  }

  void setFilter({int? categoryId, int? brandId, bool clearCategory = false, bool clearBrand = false}) {
    var changed = false;
    if (clearCategory) {
      if (_categoryId != null) changed = true;
      _categoryId = null;
    } else if (categoryId != null && _categoryId != categoryId) {
      _categoryId = categoryId;
      changed = true;
    }

    if (clearBrand) {
      if (_brandId != null) changed = true;
      _brandId = null;
    } else if (brandId != null && _brandId != brandId) {
      _brandId = brandId;
      changed = true;
    }

    if (changed) {
      refresh();
    }
  }

  @override
  Future<List<InventoryItemRecord>> loadRecords(PosV2RuntimeSession session) async {
    final tenantId = session.tenantId;
    var query = '''
      SELECT p.id, p.name, p.sku, p.remote_id, p.price_amount, p.cost_amount,
             p.stock_quantity, p.min_stock_level, p.status, p.is_available,
             c.name as category_name, p.image_url
      FROM product p
      LEFT JOIN category c ON c.id = p.category_id
      WHERE p.tenant_id = ?
        AND p.deleted_at IS NULL
    ''';
    final args = <Object?>[tenantId];

    if (_searchQuery.isNotEmpty) {
      query += ' AND (p.name LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)';
      final searchTerm = '%$_searchQuery%';
      args.addAll([searchTerm, searchTerm, searchTerm]);
    }

    if (_categoryId != null) {
      query += ' AND p.category_id = ?';
      args.add(_categoryId);
    }

    if (_brandId != null) {
      query += ' AND p.primary_brand_id = ?';
      args.add(_brandId);
    }

    query += ' ORDER BY p.name ASC LIMIT 250';

    final rows = await DatabaseService.instance.rawQuery(query, args);
    return rows
        .map((r) => InventoryItemRecord(
              id: _asInt(r['id']) ?? 0,
              name: r['name']?.toString() ?? '-',
              sku: r['sku']?.toString() ?? '-',
              remoteId: r['remote_id']?.toString(),
              categoryName: r['category_name']?.toString() ?? '—',
              costAmount: _asInt(r['cost_amount']) ?? 0,
              priceAmount: _asInt(r['price_amount']) ?? 0,
              stockQuantity: _asDouble(r['stock_quantity']),
              minStockLevel: _asDouble(r['min_stock_level']),
              status: r['status']?.toString() ?? 'active',
              isAvailable: _isTruthyFlag(r['is_available']),
              imageUrl: r['image_url']?.toString(),
            ))
        .toList(growable: false);
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

bool _isTruthyFlag(Object? value) {
  if (value is int) return value == 1;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }
  return false;
}

class PurchaseOrderRequestRecord {
  const PurchaseOrderRequestRecord({
    required this.id,
    required this.productId,
    required this.productRemoteId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.unitCostAmount,
    required this.status,
    required this.queueStatus,
    required this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int? productId;
  final String? productRemoteId;
  final String productName;
  final String productSku;
  final double quantity;
  final int unitCostAmount;
  final String status;
  final String queueStatus;
  final String createdAt;
  final String? updatedAt;

  int get subtotalAmount => (quantity * unitCostAmount).round();
}

class PurchaseOrderRecord {
  const PurchaseOrderRecord({
    required this.id,
    required this.poCode,
    required this.itemCount,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String poCode;
  final int itemCount;
  final int totalAmount;
  final String status;
  final String createdAt;
  final String? updatedAt;
}

class PurchaseOrderLineRecord {
  const PurchaseOrderLineRecord({
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.unitCostAmount,
  });

  final String productName;
  final String productSku;
  final double quantity;
  final int unitCostAmount;

  int get subtotalAmount => (quantity * unitCostAmount).round();
}

class PurchaseOrderInputLine {
  const PurchaseOrderInputLine({
    this.productId,
    this.productRemoteId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.unitCostAmount,
  });

  final int? productId;
  final String? productRemoteId;
  final String productName;
  final String productSku;
  final double quantity;
  final int unitCostAmount;
}

class PurchaseOrderRequestStore extends BaseMasterDataStore<PurchaseOrderRequestRecord> {
  PurchaseOrderRequestStore._();

  static final PurchaseOrderRequestStore instance = PurchaseOrderRequestStore._();

  @override
  Future<List<PurchaseOrderRequestRecord>> loadRecords(PosV2RuntimeSession session) async {
    final tenantId = session.tenantId;
    const query = '''
      SELECT r.id,
             r.product_id,
             r.product_remote_id,
             r.product_name,
             r.product_sku,
             r.quantity,
             r.unit_cost_amount,
             r.status,
             o.remote_id AS po_remote_id,
             o.last_sync_error AS po_last_sync_error,
             r.created_at,
             r.updated_at
      FROM purchase_order_request r
      LEFT JOIN purchase_order o
        ON o.id = r.purchase_order_id
       AND o.tenant_id = r.tenant_id
      WHERE r.tenant_id = ?
        AND r.deleted_at IS NULL
      ORDER BY r.created_at DESC
      LIMIT 200
    ''';

    final rows = await DatabaseService.instance.rawQuery(query, <Object?>[tenantId]);
    return rows
        .map((r) => PurchaseOrderRequestRecord(
              id: _asInt(r['id']) ?? 0,
              productId: _asInt(r['product_id']),
              productRemoteId: r['product_remote_id']?.toString(),
              productName: r['product_name']?.toString() ?? '-',
              productSku: r['product_sku']?.toString() ?? '-',
              quantity: _asDouble(r['quantity']),
              unitCostAmount: _asInt(r['unit_cost_amount']) ?? 0,
              status: r['status']?.toString() ?? 'pending',
              queueStatus: _derivePoStatus(
                remoteId: r['po_remote_id']?.toString(),
                lastSyncError: r['po_last_sync_error']?.toString(),
              ),
              createdAt: r['created_at']?.toString() ?? '',
              updatedAt: r['updated_at']?.toString(),
            ))
        .toList(growable: false);
  }

  /// Creates a purchase order header + line items locally, then submits the
  /// whole order in one call to `POST /v2/pos-purchase` (the real backend
  /// endpoint — items travel together as a single `items[]` array; there is
  /// no per-line purchase-order-request endpoint). If offline or the call
  /// fails, the order is kept locally with no `remote_id` and picked up by
  /// [syncPendingOrders] on the next retry. Returns the generated PO code.
  Future<String> createOrder({required List<PurchaseOrderInputLine> lines}) async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) {
      throw Exception('No active session available for purchase order.');
    }
    if (lines.isEmpty) {
      throw Exception('Keranjang masih kosong.');
    }

    final now = DateTime.now().toIso8601String();
    final poCode = _buildPoCode(DateTime.now());
    final totalAmount = lines.fold<int>(
      0,
      (sum, l) => sum + (l.quantity * l.unitCostAmount).round(),
    );

    late int poId;
    await DatabaseService.instance.transaction((txn) async {
      poId = await txn.insert('purchase_order', <String, Object?>{
        'tenant_id': session.tenantId,
        'po_code': poCode,
        'item_count': lines.length,
        'total_amount': totalAmount,
        'status': 'pending',
        'sync_state': 'dirty',
        'created_at': now,
        'updated_at': now,
      });

      for (final line in lines) {
        await txn.insert('purchase_order_request', <String, Object?>{
          'tenant_id': session.tenantId,
          'purchase_order_id': poId,
          'product_id': line.productId,
          'product_remote_id': line.productRemoteId,
          'product_name': line.productName,
          'product_sku': line.productSku,
          'quantity': line.quantity,
          'unit_cost_amount': line.unitCostAmount,
          'status': 'pending',
          'sync_state': 'dirty',
          'created_at': now,
          'updated_at': now,
        });
      }
    });

    await _submitOrder(session: session, poId: poId, poCode: poCode, lines: lines);
    return poCode;
  }

  Future<void> createRequest(InventoryItemRecord item, double quantity) async {
    await createOrder(
      lines: [
        PurchaseOrderInputLine(
          productId: item.id,
          productRemoteId: item.remoteId,
          productName: item.name,
          productSku: item.sku,
          quantity: quantity,
          unitCostAmount: item.costAmount,
        ),
      ],
    );
  }

  /// Retries submitting any purchase order that was created offline and has
  /// never reached the server (`remote_id IS NULL`). Safe to call
  /// opportunistically (e.g. from the periodic sync orchestrator); each
  /// attempt is independent and swallows its own error so one failing order
  /// doesn't block the rest.
  Future<void> syncPendingOrders() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return;

    final rows = await DatabaseService.instance.query(
      'purchase_order',
      where: 'tenant_id = ? AND remote_id IS NULL AND deleted_at IS NULL',
      whereArgs: <Object?>[session.tenantId],
    );

    for (final row in rows) {
      final poId = _asInt(row['id']);
      if (poId == null) continue;
      final lineRows = await DatabaseService.instance.query(
        'purchase_order_request',
        where: 'tenant_id = ? AND purchase_order_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[session.tenantId, poId],
      );
      final lines = lineRows
          .map((r) => PurchaseOrderInputLine(
                productId: _asInt(r['product_id']),
                productRemoteId: r['product_remote_id']?.toString(),
                productName: r['product_name']?.toString() ?? '-',
                productSku: r['product_sku']?.toString() ?? '-',
                quantity: _asDouble(r['quantity']),
                unitCostAmount: _asInt(r['unit_cost_amount']) ?? 0,
              ))
          .toList(growable: false);
      if (lines.isEmpty) continue;

      try {
        await _submitOrder(
          session: session,
          poId: poId,
          poCode: row['po_code']?.toString() ?? '',
          lines: lines,
        );
      } catch (_) {
        // Left pending; the next sync pass will retry.
      }
    }
  }

  Future<void> _submitOrder({
    required PosV2RuntimeSession session,
    required int poId,
    required String poCode,
    required List<PurchaseOrderInputLine> lines,
  }) async {
    final client = V2ApiClient(
      baseUrl: session.baseUrl,
      authToken: session.authToken,
    );

    try {
      final envelope = await client.postEnvelope(
        'api/v2/pos-purchase',
        body: <String, dynamic>{
          'vendornote': 'PO $poCode dari aplikasi kasir',
          'items': lines
              .map((line) => <String, dynamic>{
                    'item_code': int.tryParse(line.productRemoteId ?? '') ??
                        line.productId,
                    'quantity': line.quantity,
                    'unit_price': line.unitCostAmount,
                    'item_name': line.productName,
                  })
              .toList(growable: false),
        },
      ).timeout(const Duration(seconds: 20));

      final data = envelope['data'];
      final remoteId = (data is Map ? data['id'] : null)?.toString();
      if (remoteId == null || remoteId.isEmpty) {
        throw Exception('Purchase order response missing id');
      }

      await DatabaseService.instance.transaction((txn) async {
        await txn.update(
          'purchase_order',
          <String, Object?>{
            'remote_id': remoteId,
            'status': 'completed',
            'sync_state': 'clean',
            'last_sync_error': null,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: <Object?>[poId],
        );
      });
    } catch (error) {
      await DatabaseService.instance.transaction((txn) async {
        await txn.update(
          'purchase_order',
          <String, Object?>{
            'last_sync_error': error.toString(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: <Object?>[poId],
        );
      });
      rethrow;
    }
  }

  /// Cancels a purchase order. If it already reached the server
  /// (`remote_id` set), the matching PO and its Sales Invoice at Pusat are
  /// deleted first via `DELETE /v2/pos-purchase/{id}` — that call must
  /// succeed before the local row is removed, so a still-existing remote PO
  /// never silently disappears from just this device's view. If the order
  /// never left this device, it is only ever local, so it's removed
  /// immediately with no network call.
  Future<void> cancelOrder(int poId) async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) {
      throw Exception('No active session available.');
    }

    final rows = await DatabaseService.instance.query(
      'purchase_order',
      columns: const <String>['remote_id'],
      where: 'tenant_id = ? AND id = ?',
      whereArgs: <Object?>[session.tenantId, poId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('Purchase order not found.');
    }
    final remoteId = rows.first['remote_id']?.toString();

    if (remoteId != null && remoteId.isNotEmpty) {
      final client = V2ApiClient(
        baseUrl: session.baseUrl,
        authToken: session.authToken,
      );
      await client
          .deleteEnvelope('api/v2/pos-purchase/$remoteId')
          .timeout(const Duration(seconds: 20));
    }

    final now = DateTime.now().toIso8601String();
    await DatabaseService.instance.transaction((txn) async {
      await txn.update(
        'purchase_order',
        <String, Object?>{'deleted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: <Object?>[poId],
      );
      await txn.update(
        'purchase_order_request',
        <String, Object?>{'deleted_at': now, 'updated_at': now},
        where: 'purchase_order_id = ?',
        whereArgs: <Object?>[poId],
      );
    });
  }

  static String _buildPoCode(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'PO-${dt.year}${two(dt.month)}${two(dt.day)}-'
        '${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
  }
}

class PurchaseOrderStore extends BaseMasterDataStore<PurchaseOrderRecord> {
  PurchaseOrderStore._();

  static final PurchaseOrderStore instance = PurchaseOrderStore._();

  /// Order-line rows grouped by purchase_order_request. We reuse the same
  /// table, but the historical view is aggregated per PO header.
  @override
  Future<List<PurchaseOrderRecord>> loadRecords(PosV2RuntimeSession session) async {
    final tenantId = session.tenantId;
    final query = '''
      SELECT o.id,
             o.po_code,
             o.remote_id,
             o.last_sync_error,
             COALESCE(SUM(r.quantity), 0) AS item_count,
             COALESCE(SUM(r.quantity * r.unit_cost_amount), 0) AS total_amount,
             o.created_at,
             o.updated_at
      FROM purchase_order o
      LEFT JOIN purchase_order_request r
        ON r.purchase_order_id = o.id
       AND r.tenant_id = o.tenant_id
       AND r.deleted_at IS NULL
      WHERE o.tenant_id = ?
        AND o.deleted_at IS NULL
      GROUP BY o.id
      ORDER BY o.created_at DESC
      LIMIT 200
    ''';

    final rows = await DatabaseService.instance.rawQuery(
      query,
      <Object?>[tenantId],
    );
    return rows
        .map((r) {
          final status = _derivePoStatus(
            remoteId: r['remote_id']?.toString(),
            lastSyncError: r['last_sync_error']?.toString(),
          );
          return PurchaseOrderRecord(
            id: _asInt(r['id']) ?? 0,
            poCode: r['po_code']?.toString() ?? '-',
            itemCount: _asDouble(r['item_count']).round(),
            totalAmount: _asInt(r['total_amount']) ?? 0,
            status: status,
            createdAt: r['created_at']?.toString() ?? '',
            updatedAt: r['updated_at']?.toString(),
          );
        })
        .toList(growable: false);
  }

  Future<List<PurchaseOrderLineRecord>> loadLines(int purchaseOrderId) async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) {
      return <PurchaseOrderLineRecord>[];
    }
    final rows = await DatabaseService.instance.rawQuery(
      '''
      SELECT product_name, product_sku, quantity, unit_cost_amount
      FROM purchase_order_request
      WHERE tenant_id = ?
        AND purchase_order_id = ?
        AND deleted_at IS NULL
      ORDER BY id ASC
      ''',
      <Object?>[session.tenantId, purchaseOrderId],
    );
    return rows
        .map((r) => PurchaseOrderLineRecord(
              productName: r['product_name']?.toString() ?? '-',
              productSku: r['product_sku']?.toString() ?? '-',
              quantity: _asDouble(r['quantity']),
              unitCostAmount: _asInt(r['unit_cost_amount']) ?? 0,
            ))
        .toList(growable: false);
  }

}

/// A PO submits atomically in one call now (see `_submitOrder`), so there is
/// no more partial per-line "processing" state: either the server has
/// assigned it a `remote_id` (completed), a submit attempt has failed
/// (failed), or it hasn't been attempted/succeeded yet (pending, e.g. still
/// offline).
String _derivePoStatus({required String? remoteId, required String? lastSyncError}) {
  if (remoteId != null && remoteId.isNotEmpty) return 'completed';
  if (lastSyncError != null && lastSyncError.isNotEmpty) return 'failed';
  return 'pending';
}
