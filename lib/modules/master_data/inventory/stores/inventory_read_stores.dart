import 'dart:convert';

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
             sq.status AS queue_status,
             r.created_at,
             r.updated_at
      FROM purchase_order_request r
      LEFT JOIN sync_queue sq
        ON sq.tenant_id = r.tenant_id
       AND sq.entity_type = 'purchase_order_request'
       AND sq.entity_local_id = r.id
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
              queueStatus: r['queue_status']?.toString() ?? 'pending',
              createdAt: r['created_at']?.toString() ?? '',
              updatedAt: r['updated_at']?.toString(),
            ))
        .toList(growable: false);
  }

  /// Creates a purchase order header + line items and enqueues each line for
  /// sync. Returns the generated PO code.
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

    await DatabaseService.instance.transaction((txn) async {
      final poId = await txn.insert('purchase_order', <String, Object?>{
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
        final requestId = await txn.insert('purchase_order_request', <String, Object?>{
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

        final requestBody = <String, Object?>{
          'product_id': line.productRemoteId ?? line.productId,
          'product_remote_id': line.productRemoteId,
          'product_sku': line.productSku,
          'product_name': line.productName,
          'quantity': line.quantity,
          'unit_cost_amount': line.unitCostAmount,
          'po_code': poCode,
          'location_id': session.locationId,
          'requested_by': session.staffId,
          'requested_at': now,
        };

        await DatabaseService.instance.upsertByUnique(
          txn,
          'sync_queue',
          where: 'tenant_id = ? AND dedupe_key = ?',
          whereArgs: <Object?>[
            session.tenantId,
            'purchase-order-request:$requestId',
          ],
          insertValues: <String, Object?>{
            'tenant_id': session.tenantId,
            'entity_type': 'purchase_order_request',
            'entity_local_id': requestId,
            'entity_remote_id': null,
            'operation': 'create',
            'method': 'POST',
            'endpoint': 'api/v2/purchase-order-request',
            'base_url': session.baseUrl,
            'request_headers_json': jsonEncode(<String, Object?>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'authtoken': session.authToken,
            }),
            'request_body_json': jsonEncode(requestBody),
            'dedupe_key': 'purchase-order-request:$requestId',
            'priority': 110,
            'status': 'pending',
            'retry_count': 0,
            'next_retry_at': null,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'entity_type': 'purchase_order_request',
            'entity_local_id': requestId,
            'operation': 'create',
            'method': 'POST',
            'endpoint': 'api/v2/purchase-order-request',
            'base_url': session.baseUrl,
            'request_headers_json': jsonEncode(<String, Object?>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'authtoken': session.authToken,
            }),
            'request_body_json': jsonEncode(requestBody),
            'status': 'pending',
            'next_retry_at': null,
            'updated_at': now,
          },
        );
      }
    });

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
             COUNT(r.id) AS line_count,
             COALESCE(SUM(CASE WHEN r.deleted_at IS NULL THEN 1 ELSE 0 END), 0) AS active_line_count,
             COALESCE(SUM(r.quantity), 0) AS item_count,
             COALESCE(SUM(r.quantity * r.unit_cost_amount), 0) AS total_amount,
             COALESCE(SUM(CASE WHEN sq.status = 'failed' THEN 1 ELSE 0 END), 0) AS failed_count,
             COALESCE(SUM(CASE WHEN sq.status = 'processed' THEN 1 ELSE 0 END), 0) AS processed_count,
             o.created_at,
             o.updated_at
      FROM purchase_order o
      LEFT JOIN purchase_order_request r
        ON r.purchase_order_id = o.id
       AND r.tenant_id = o.tenant_id
       AND r.deleted_at IS NULL
      LEFT JOIN sync_queue sq
        ON sq.tenant_id = r.tenant_id
       AND sq.entity_type = 'purchase_order_request'
       AND sq.entity_local_id = r.id
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
          final totalLines = _asInt(r['active_line_count']) ?? 0;
          final failed = _asInt(r['failed_count']) ?? 0;
          final processed = _asInt(r['processed_count']) ?? 0;
          final status = _derivePoStatus(
            totalLines: totalLines,
            failed: failed,
            processed: processed,
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

  String _derivePoStatus({
    required int totalLines,
    required int failed,
    required int processed,
  }) {
    if (totalLines == 0) return 'pending';
    if (failed > 0) return 'failed';
    if (processed >= totalLines) return 'completed';
    if (processed > 0) return 'processing';
    return 'pending';
  }
}
