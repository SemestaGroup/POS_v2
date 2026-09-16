import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flinkpos_v2/core/services/local/database_service.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_runtime_session_store.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/sales_order_store.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_order_type_store.dart';
import 'package:flinkpos_v2/modules/master_data/stores/master_data_read_stores.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('End-to-End Customer Points Integration Test', () {
    test('createOrder with paid status immediately increments customer points in SQLite', () async {
      await DatabaseService.instance.close();
      final db = await DatabaseService.instance.database;

      // Seed dummy session
      const testTenantId = 999;
      const testSession = PosV2RuntimeSession(
        tenantId: testTenantId,
        tenantKey: 'tenant-key-999',
        staffId: 'staff-1',
        locationId: 'loc-1',
        deviceId: 'device-1',
        registerId: 'reg-1',
        baseUrl: 'https://test.example.com',
        authToken: 'test-auth',
      );
      PosV2RuntimeSessionStore.instance.setSession(testSession);
      // Seed tenant
      await db.delete('app_tenant', where: 'id = ?', whereArgs: [testTenantId]);
      await db.insert('app_tenant', {
        'id': testTenantId,
        'tenant_key': 'tenant-key-999',
        'tenant_name': 'Test Tenant POS',
        'base_url': 'https://test.example.com',
        'location_id': 'loc-1',
        'is_active': 1,
      });
      // Seed order type master
      await db.delete('order_type', where: 'tenant_id = ?', whereArgs: [testTenantId]);
      await db.insert('order_type', {
        'tenant_id': testTenantId,
        'code': 'dinein',
        'name': 'Dine In',
        'is_active': 1,
      });
      await PosOrderTypeStore.instance.ensureLoaded(forceRefresh: true);

      // Seed customer with 100 points
      await db.delete('customer', where: 'tenant_id = ?', whereArgs: [testTenantId]);
      final customerLocalId = await db.insert('customer', {
        'tenant_id': testTenantId,
        'remote_id': 'cust-999',
        'display_name': 'Pelanggan Setia',
        'points_balance': 100,
        'created_at': '2026-09-04 10:00:00',
        'updated_at': '2026-09-04 10:00:00',
      });

      // Verify initial balance
      var customerRows = await db.query(
        'customer',
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [customerLocalId, testTenantId],
      );
      expect(customerRows.first['points_balance'], 100);

      // Create paid order of Rp 50.000 for this customer
      final orderRecord = await SalesOrderStore.instance.createOrder(
        orderType: 'dinein',
        customerName: 'Pelanggan Setia',
        customerRemoteId: 'cust-999',
        customerLocalId: customerLocalId,
        statusCode: 2, // Paid
        items: const [
          SalesOrderLineItem(
            id: 'item-1',
            name: 'Menu Special',
            imageUrl: '',
            regularUnitPrice: 50000,
            quantity: 1,
          ),
        ],
      );

      expect(orderRecord, isNotNull);

      // Verify pos_order awarded_points in SQLite
      final orderRows = await db.query(
        'pos_order',
        where: 'id_pos = ? AND tenant_id = ?',
        whereArgs: [orderRecord!.id, testTenantId],
      );
      expect(orderRows.isNotEmpty, isTrue);
      expect(orderRows.first['awarded_points'], 5); // 50.000 ~/ 10000 = 5 points
      expect(orderRows.first['total_amount'], 50000);

      // Verify customer points_balance in SQLite is immediately 105
      customerRows = await db.query(
        'customer',
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [customerLocalId, testTenantId],
      );
      expect(customerRows.first['points_balance'], 105);

      // Verify CustomerListStore loads the updated points
      final records = await CustomerListStore.instance.loadRecords(testSession);
      final updatedCustomer = records.firstWhere((c) => c.id == customerLocalId);
      expect(updatedCustomer.pointsBalance, 105);
    });
  });
}
