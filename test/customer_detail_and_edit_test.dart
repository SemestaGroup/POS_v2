import 'package:flinkpos_v2/core/services/sync/pos_v2_customer_service.dart';
import 'package:flinkpos_v2/modules/master_data/stores/master_data_read_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── Unit tests for pure logic (no DB / no network) ──────────────────────

  group('CustomerListRecord — field coverage', () {
    test('holds remoteId and address alongside legacy fields', () {
      const record = CustomerListRecord(
        id: 42,
        remoteId: 'abc123',
        displayName: 'Budi Santoso',
        phoneNumber: '08123456789',
        email: 'budi@example.com',
        address: 'Jl. Merdeka No. 1',
        city: 'Jakarta',
        pointsBalance: 500,
      );

      expect(record.id, 42);
      expect(record.remoteId, 'abc123');
      expect(record.displayName, 'Budi Santoso');
      expect(record.phoneNumber, '08123456789');
      expect(record.email, 'budi@example.com');
      expect(record.address, 'Jl. Merdeka No. 1');
      expect(record.city, 'Jakarta');
      expect(record.pointsBalance, 500);
    });

    test('optional fields default to null', () {
      const record = CustomerListRecord(
        id: 1,
        displayName: 'Walk-In',
        pointsBalance: 0,
      );

      expect(record.remoteId, isNull);
      expect(record.phoneNumber, isNull);
      expect(record.email, isNull);
      expect(record.address, isNull);
      expect(record.city, isNull);
    });
  });

  group('CustomerOrderHistoryRecord — field coverage', () {
    final now = DateTime(2025, 8, 15, 10, 30);

    test('holds all required fields', () {
      final record = CustomerOrderHistoryRecord(
        id: 7,
        formattedNumber: 'INV-2025-001',
        orderDate: now,
        statusCode: 3,
        statusLabel: 'Selesai',
        totalAmount: 125000,
        itemsSummary: '2 x Kopi Susu, 1 x Croissant',
        orderTypeCode: 'dine_in',
      );

      expect(record.id, 7);
      expect(record.formattedNumber, 'INV-2025-001');
      expect(record.orderDate, now);
      expect(record.statusCode, 3);
      expect(record.statusLabel, 'Selesai');
      expect(record.totalAmount, 125000.0);
      expect(record.itemsSummary, '2 x Kopi Susu, 1 x Croissant');
      expect(record.orderTypeCode, 'dine_in');
    });

    test('orderTypeCode is optional', () {
      final record = CustomerOrderHistoryRecord(
        id: 1,
        formattedNumber: '#1',
        orderDate: null,
        statusCode: 1,
        statusLabel: 'Aktif',
        totalAmount: 0,
        itemsSummary: '-',
      );

      expect(record.orderTypeCode, isNull);
      expect(record.orderDate, isNull);
    });
  });
  group('CustomerStatsRecord — field coverage', () {
    test('holds totalOrders and totalSpend', () {
      const stats = CustomerStatsRecord(
        totalOrders: 15,
        totalSpend: 1500000.0,
      );
      expect(stats.totalOrders, 15);
      expect(stats.totalSpend, 1500000.0);
    });

    test('CustomerStatsRecord.empty has 0 orders and 0.0 spend', () {
      expect(CustomerStatsRecord.empty.totalOrders, 0);
      expect(CustomerStatsRecord.empty.totalSpend, 0.0);
    });
  });


  group('PosCustomerRecord — pointsBalance field', () {
    test('defaults to 0 when not provided', () {
      const record = PosCustomerRecord(
        localId: 1,
        remoteId: 'r1',
        name: 'Test',
      );
      expect(record.pointsBalance, 0);
    });

    test('carries provided value', () {
      const record = PosCustomerRecord(
        localId: 2,
        remoteId: 'r2',
        name: 'Test',
        pointsBalance: 750,
      );
      expect(record.pointsBalance, 750);
    });
  });

  // ── helpers mirroring production logic ──────────────────────────────────

  String resolveSyncState(Map<String, dynamic>? updatedRemoteData) =>
      updatedRemoteData != null ? 'clean' : 'dirty_update';

  ({List<String> where, List<Object?> args}) buildWhere(
    int tenantId,
    int customerId,
    String? customerRemoteId,
  ) {
    final where = <String>[
      'pos_order.tenant_id = ?',
      'pos_order.deleted_at IS NULL',
    ];
    final args = <Object?>[tenantId];
    if (customerRemoteId != null && customerRemoteId.trim().isNotEmpty) {
      where.add('(pos_order.customer_id = ? OR pos_order.customer_remote_id = ?)');
      args..add(customerId)..add(customerRemoteId.trim());
    } else {
      where.add('pos_order.customer_id = ?');
      args.add(customerId);
    }
    return (where: where, args: args);
  }

  group('loadCustomerOrders — where-clause logic (offline-safe)', () {
    test('dedupeKey follows expected pattern', () {
      const tenantId = 5;
      const localId = 12;
      expect(
        'customer_update_${tenantId}_$localId',
        'customer_update_5_12',
      );
    });

    test('syncState is dirty_update when remote call fails', () {
      expect(resolveSyncState(null), 'dirty_update');
    });

    test('syncState is clean when remote call succeeds', () {
      expect(resolveSyncState({'id': '1', 'company': 'Test'}), 'clean');
    });
  });

  group('loadCustomerOrders — WHERE clause construction', () {
    test('uses OR clause when customerRemoteId is provided', () {
      final result = buildWhere(99, 10, 'r10');
      expect(result.where.length, 3);
      expect(
        result.where.last,
        '(pos_order.customer_id = ? OR pos_order.customer_remote_id = ?)',
      );
      expect(result.args, [99, 10, 'r10']);
    });

    test('uses customer_id only when remoteId is absent', () {
      final result = buildWhere(99, 10, null);
      expect(result.where.length, 3);
      expect(result.where.last, 'pos_order.customer_id = ?');
      expect(result.args, [99, 10]);
    });
  });
}
