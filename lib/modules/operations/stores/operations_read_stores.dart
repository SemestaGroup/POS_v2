import 'package:flutter/foundation.dart';

import '../../../core/services/local/database_service.dart';
import '../../../core/services/sync/pos_v2_runtime_session_store.dart';

class ShiftSummaryRecord {
  const ShiftSummaryRecord({
    required this.id,
    required this.shiftName,
    required this.staffName,
    required this.openedAt,
    required this.openingBalance,
    required this.status,
    this.closedAt,
  });

  final int id;
  final String shiftName;
  final String staffName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final int openingBalance;
  final String status;
}

class RecapSnapshot {
  const RecapSnapshot({
    required this.isLoading,
    required this.shifts,
    required this.totalTransactions,
    required this.totalRevenue,
    this.errorMessage,
  });

  final bool isLoading;
  final List<ShiftSummaryRecord> shifts;
  final int totalTransactions;
  final int totalRevenue;
  final String? errorMessage;

  RecapSnapshot copyWith({
    bool? isLoading,
    List<ShiftSummaryRecord>? shifts,
    int? totalTransactions,
    int? totalRevenue,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecapSnapshot(
      isLoading: isLoading ?? this.isLoading,
      shifts: shifts ?? this.shifts,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class CashFlowEntryRecord {
  const CashFlowEntryRecord({
    required this.type,
    required this.description,
    required this.amount,
    required this.createdAt,
  });

  final String type;
  final String description;
  final int amount;
  final DateTime createdAt;
}

class CashFlowSnapshot {
  const CashFlowSnapshot({
    required this.isLoading,
    required this.entries,
    required this.totalIn,
    required this.totalOut,
    this.errorMessage,
  });

  final bool isLoading;
  final List<CashFlowEntryRecord> entries;
  final int totalIn;
  final int totalOut;
  final String? errorMessage;

  CashFlowSnapshot copyWith({
    bool? isLoading,
    List<CashFlowEntryRecord>? entries,
    int? totalIn,
    int? totalOut,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CashFlowSnapshot(
      isLoading: isLoading ?? this.isLoading,
      entries: entries ?? this.entries,
      totalIn: totalIn ?? this.totalIn,
      totalOut: totalOut ?? this.totalOut,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class KitchenItemRecord {
  const KitchenItemRecord({
    required this.productName,
    required this.quantity,
    this.note,
  });

  final String productName;
  final int quantity;
  final String? note;
}

class KitchenOrderRecord {
  const KitchenOrderRecord({
    required this.id,
    required this.idPos,
    required this.orderTypeCode,
    required this.statusCode,
    required this.createdAt,
    required this.items,
    this.tableCode,
  });

  final int id;
  final String idPos;
  final String orderTypeCode;
  final String statusCode;
  final DateTime createdAt;
  final String? tableCode;
  final List<KitchenItemRecord> items;
}

class KitchenSnapshot {
  const KitchenSnapshot({
    required this.isLoading,
    required this.filter,
    required this.orders,
    this.errorMessage,
  });

  final bool isLoading;
  final String filter;
  final List<KitchenOrderRecord> orders;
  final String? errorMessage;

  KitchenSnapshot copyWith({
    bool? isLoading,
    String? filter,
    List<KitchenOrderRecord>? orders,
    String? errorMessage,
    bool clearError = false,
  }) {
    return KitchenSnapshot(
      isLoading: isLoading ?? this.isLoading,
      filter: filter ?? this.filter,
      orders: orders ?? this.orders,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class RecapStore {
  RecapStore._();

  static final RecapStore instance = RecapStore._();

  final ValueNotifier<RecapSnapshot> snapshotNotifier =
      ValueNotifier<RecapSnapshot>(
    const RecapSnapshot(
      isLoading: false,
      shifts: <ShiftSummaryRecord>[],
      totalTransactions: 0,
      totalRevenue: 0,
    ),
  );

  Future<void> refresh() async {
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final shiftRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT id, shift_name, pos_staff_name_snapshot, opened_at,
               closed_at, opening_balance, status
        FROM shift_session
        WHERE tenant_id = ?
          AND deleted_at IS NULL
        ORDER BY opened_at DESC
        LIMIT 20
        ''',
        <Object?>[session.tenantId],
      );
      final orderRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT COUNT(*) as total_orders,
               COALESCE(SUM(total_amount), 0) as total_revenue
        FROM pos_order
        WHERE tenant_id = ?
          AND status_code IN ('paid', 'posted')
          AND deleted_at IS NULL
        ''',
        <Object?>[session.tenantId],
      );

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        shifts: shiftRows
            .map(
              (row) => ShiftSummaryRecord(
                id: _asInt(row['id']) ?? 0,
                shiftName: row['shift_name']?.toString() ?? '-',
                staffName: row['pos_staff_name_snapshot']?.toString() ?? '-',
                openedAt: _parseDateTime(row['opened_at']) ?? DateTime.now(),
                closedAt: _parseDateTime(row['closed_at']),
                openingBalance: _asInt(row['opening_balance']) ?? 0,
                status: row['status']?.toString() ?? 'unknown',
              ),
            )
            .toList(growable: false),
        totalTransactions: _firstInt(orderRows, 'total_orders'),
        totalRevenue: _firstInt(orderRows, 'total_revenue'),
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class CashFlowStore {
  CashFlowStore._();

  static final CashFlowStore instance = CashFlowStore._();

  final ValueNotifier<CashFlowSnapshot> snapshotNotifier =
      ValueNotifier<CashFlowSnapshot>(
    const CashFlowSnapshot(
      isLoading: false,
      entries: <CashFlowEntryRecord>[],
      totalIn: 0,
      totalOut: 0,
    ),
  );

  Future<void> refresh() async {
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final paymentRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT p.amount, p.payment_mode_name_snapshot, p.created_at,
               o.id_pos as order_ref
        FROM pos_order_payment p
        LEFT JOIN pos_order o ON o.id = p.order_id
        WHERE p.tenant_id = ?
          AND p.deleted_at IS NULL
          AND p.is_refund = 0
          AND p.sync_state IN ('clean', 'dirty_create', 'dirty_update', 'syncing')
        ORDER BY p.created_at DESC
        LIMIT 50
        ''',
        <Object?>[session.tenantId],
      );

      final entries = paymentRows
          .map(
            (row) => CashFlowEntryRecord(
              type: 'in',
              description:
                  '${row['payment_mode_name_snapshot'] ?? 'Pembayaran'} — ${row['order_ref'] ?? '-'}',
              amount: _asInt(row['amount']) ?? 0,
              createdAt: _parseDateTime(row['created_at']) ?? DateTime.now(),
            ),
          )
          .toList(growable: false);

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        entries: entries,
        totalIn: entries.fold<int>(0, (sum, entry) => sum + entry.amount),
        totalOut: 0,
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class KitchenMonitorStore {
  KitchenMonitorStore._();

  static final KitchenMonitorStore instance = KitchenMonitorStore._();

  final ValueNotifier<KitchenSnapshot> snapshotNotifier =
      ValueNotifier<KitchenSnapshot>(
    const KitchenSnapshot(
      isLoading: false,
      filter: 'active',
      orders: <KitchenOrderRecord>[],
    ),
  );

  Future<void> refresh({String? filter}) async {
    final nextFilter = filter ?? snapshotNotifier.value.filter;
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      filter: nextFilter,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final statusFilter = nextFilter == 'active'
          ? "AND o.status_code IN ('draft', 'hold', 'unpaid')"
          : '';
      final orderRows = await DatabaseService.instance.rawQuery(
        '''
        SELECT o.id, o.id_pos, o.status_code, o.created_at,
               o.table_code, o.order_type_code
        FROM pos_order o
        WHERE o.tenant_id = ?
          AND o.deleted_at IS NULL
          $statusFilter
        ORDER BY o.created_at DESC
        LIMIT 30
        ''',
        <Object?>[session.tenantId],
      );

      final orderIds = orderRows
          .map((row) => _asInt(row['id']))
          .whereType<int>()
          .toList(growable: false);
      final itemsByOrder = <int, List<KitchenItemRecord>>{};
      if (orderIds.isNotEmpty) {
        final placeholders = List.filled(orderIds.length, '?').join(',');
        final itemRows = await DatabaseService.instance.rawQuery(
          '''
          SELECT order_id,
                 product_name_snapshot as product_name,
                 CAST(qty AS INTEGER) as quantity,
                 note
          FROM pos_order_item
          WHERE deleted_at IS NULL
            AND order_id IN ($placeholders)
          ORDER BY order_id ASC, sort_order ASC
          ''',
          orderIds.cast<Object?>(),
        );
        for (final row in itemRows) {
          final orderId = _asInt(row['order_id']);
          if (orderId == null) {
            continue;
          }
          itemsByOrder.putIfAbsent(orderId, () => <KitchenItemRecord>[]).add(
                KitchenItemRecord(
                  productName: row['product_name']?.toString() ?? '-',
                  quantity: _asInt(row['quantity']) ?? 1,
                  note: row['note']?.toString(),
                ),
              );
        }
      }

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        orders: orderRows
            .map(
              (row) {
                final id = _asInt(row['id']) ?? 0;
                return KitchenOrderRecord(
                  id: id,
                  idPos: row['id_pos']?.toString() ?? '-',
                  orderTypeCode: row['order_type_code']?.toString() ?? 'dine_in',
                  statusCode: row['status_code']?.toString() ?? 'draft',
                  createdAt: _parseDateTime(row['created_at']) ?? DateTime.now(),
                  tableCode: row['table_code']?.toString(),
                  items: itemsByOrder[id] ?? const <KitchenItemRecord>[],
                );
              },
            )
            .toList(growable: false),
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

Future<PosV2RuntimeSession> _requireSession() async {
  final session = PosV2RuntimeSessionStore.instance.currentSession ??
      await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
  if (session == null) {
    throw Exception('Tidak ada sesi aktif.');
  }
  return session;
}

int _firstInt(List<Map<String, Object?>> rows, String key) {
  if (rows.isEmpty) {
    return 0;
  }
  return _asInt(rows.first[key]) ?? 0;
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString().split('.').first);
}

DateTime? _parseDateTime(Object? raw) {
  final text = raw?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}
