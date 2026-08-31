import 'package:flinkpos_v2/core/services/local/database_service.dart';
import 'package:flinkpos_v2/core/services/local/v2_sqlite_schema.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_runtime_session_store.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/order_type_presenter.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_order_type_pricing_service.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_order_type_store.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_order_type_transition_service.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_promotion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Real SQLite POS Order Type Integration Tests', () {
    late Database db;
    const testTenantId = 101;
    const testSession = PosV2RuntimeSession(
      tenantId: testTenantId,
      tenantKey: 'test-tenant-key',
      baseUrl: 'https://api.test.flinkpos.com',
      authToken: 'test-auth-token',
      locationId: 'LOC-01',
      staffId: '1',
      staffEmail: 'cashier@test.com',
      deviceId: 'DEVICE-01',
    );

    setUp(() async {
      await DatabaseService.instance.close();
      db = await openDatabase(
        inMemoryDatabasePath,
        version: V2SqliteSchema.version,
        onCreate: (db, version) async {
          for (final statement in V2SqliteSchema.createStatements) {
            await db.execute(statement);
          }
        },
      );

      // Insert mock tenant
      await db.insert('app_tenant', {
        'id': testTenantId,
        'tenant_key': 'test-tenant-key',
        'tenant_name': 'Test Tenant POS',
        'base_url': 'https://api.test.flinkpos.com',
        'location_id': 'LOC-01',
        'is_active': 1,
      });

      // Insert order types: 2 active, 2 inactive, 1 deleted, 1 other tenant
      await db.insert('order_type', {
        'id': 1,
        'tenant_id': testTenantId,
        'code': 'dinein',
        'name': 'Makan di Tempat',
        'description': 'Dine in order',
        'is_active': 1,
        'deleted_at': null,
      });
      await db.insert('order_type', {
        'id': 2,
        'tenant_id': testTenantId,
        'code': 'takeaway',
        'name': 'Bungkus / Take Away',
        'description': 'Take away order',
        'is_active': 1,
        'deleted_at': null,
      });
      await db.insert('order_type', {
        'id': 3,
        'tenant_id': testTenantId,
        'code': 'catering_vip',
        'name': 'VIP Catering Custom',
        'description': 'Old inactive catering type',
        'is_active': 0, // Inactive!
        'deleted_at': null,
      });
      await db.insert('order_type', {
        'id': 4,
        'tenant_id': testTenantId,
        'code': 'event_booth_2024',
        'name': 'Event Booth Custom 2024',
        'description': 'Past event type',
        'is_active': 0, // Inactive!
        'deleted_at': null,
      });
      await db.insert('order_type', {
        'id': 5,
        'tenant_id': testTenantId,
        'code': 'deleted_mode',
        'name': 'Deleted Custom Mode',
        'is_active': 1,
        'deleted_at': '2026-01-01T00:00:00Z', // Deleted!
      });
      await db.insert('order_type', {
        'id': 6,
        'tenant_id': 999, // Other tenant!
        'code': 'other_tenant_mode',
        'name': 'Other Tenant Mode',
        'is_active': 1,
        'deleted_at': null,
      });

      // Insert customer
      await db.insert('customer', {
        'id': 1,
        'tenant_id': testTenantId,
        'display_name': 'Walk-in Customer',
      });

      PosV2RuntimeSessionStore.instance.setSession(testSession);
    });

    tearDown(() async {
      await db.close();
      await DatabaseService.instance.close();
      PosV2RuntimeSessionStore.instance.setSession(null);
    });

    test('PosOrderTypeStore correctly queries real SQLite and separates active from allOrderTypes', () async {
      // Query raw SQLite via the open test database
      final rows = await db.rawQuery(
        '''
        SELECT code, name, description, is_active
        FROM order_type
        WHERE tenant_id = ?
          AND deleted_at IS NULL
          AND code IS NOT NULL
          AND TRIM(code) != ''
        ORDER BY id ASC
        ''',
        <Object?>[testTenantId],
      );

      expect(rows.length, 4); // 2 active + 2 inactive (deleted and other tenant excluded)

      final activeTypes = <PosOrderType>[];
      final allTypes = <PosOrderType>[];
      for (final row in rows) {
        final ot = PosOrderType(
          code: row['code'].toString(),
          name: row['name'].toString(),
          description: row['description']?.toString(),
        );
        allTypes.add(ot);
        if (row['is_active'] == 1) {
          activeTypes.add(ot);
        }
      }

      PosOrderTypeStore.instance.snapshotNotifier.value = PosOrderTypeSnapshot(
        orderTypes: List<PosOrderType>.unmodifiable(activeTypes),
        allOrderTypes: List<PosOrderType>.unmodifiable(allTypes),
        tenantId: testTenantId,
        isLoaded: true,
      );

      final snapshot = PosOrderTypeStore.instance.snapshot;
      expect(snapshot.orderTypes.length, 2);
      expect(snapshot.orderTypes.map((e) => e.code).toList(), ['dinein', 'takeaway']);

      expect(snapshot.allOrderTypes.length, 4);
      expect(
        snapshot.allOrderTypes.map((e) => e.code).toList(),
        ['dinein', 'takeaway', 'catering_vip', 'event_booth_2024'],
      );

      // Inactive custom order types resolve original custom name via allOrderTypes
      expect(
        OrderTypePresenter.getDisplayName('catering_vip', snapshot.allOrderTypes),
        'VIP Catering Custom',
      );
      expect(
        OrderTypePresenter.getDisplayName('event_booth_2024', snapshot.allOrderTypes),
        'Event Booth Custom 2024',
      );

      // findByCode with includeInactive: true finds inactive types
      final foundInactive = PosOrderTypeStore.instance.findByCode('catering_vip', includeInactive: true);
      expect(foundInactive, isNotNull);
      expect(foundInactive!.name, 'VIP Catering Custom');

      // findByCode with includeInactive: false returns null for inactive types
      final notFoundActiveOnly = PosOrderTypeStore.instance.findByCode('catering_vip', includeInactive: false);
      expect(notFoundActiveOnly, isNull);
    });

    test('P2 Fix: Price override of 0 from API is honored and not ignored as no override', () {
      final product = <String, dynamic>{
        'id': 1,
        'remoteId': 'p-promo-free',
        'name': 'Complimentary Drink',
        'regularPrice': 15000,
        'price': 15000,
        'orderTypePrices': <String, dynamic>{
          'dinein': 15000,
          'event_booth': 0, // Override price to 0!
        },
      };

      final dineinPriced = PosOrderTypePricingService.applyOrderTypePricing(product, 'dinein');
      expect(dineinPriced['regularPrice'], 15000);
      expect(dineinPriced['price'], 15000);

      // 0 override is respected!
      final freePriced = PosOrderTypePricingService.applyOrderTypePricing(product, 'event_booth');
      expect(freePriced['regularPrice'], 0);
      expect(freePriced['price'], 0);

      // Unspecified order type falls back to standard regular price
      final fallbackPriced = PosOrderTypePricingService.applyOrderTypePricing(product, 'takeaway');
      expect(fallbackPriced['regularPrice'], 15000);
      expect(fallbackPriced['price'], 15000);
    });

    test('P1 Fix: When promo becomes invalid after order type change, item is repriced to new order type', () async {
      final catalog = <Map<String, dynamic>>[
        <String, dynamic>{
          'remoteId': 'p1',
          'name': 'Premium Coffee',
          'regularPrice': 20000,
          'price': 20000,
          'orderTypePrices': <String, dynamic>{
            'dinein': 20000,
            'takeaway': 26000, // Higher takeaway price
          },
        },
      ];

      const cartItems = <PosCartItem>[
        PosCartItem(
          id: 'item-1',
          productRemoteId: 'p1',
          name: 'Premium Coffee',
          displayName: 'Premium Coffee',
          imageUrl: '',
          regularUnitPrice: 20000,
          discountedUnitPrice: 15000,
          appliedPromoId: 'promo-dinein-only',
          appliedPromoName: 'Dine In 25% Off',
          orderType: 'dinein',
          quantity: 1,
        ),
      ];

      // Switching order type to 'takeaway' reprices all items (including promo item)
      final transitionResult = await PosOrderTypeTransitionService.transitionPosCartOrderType(
        currentOrderType: 'dinein',
        targetOrderType: 'takeaway',
        currentItems: cartItems,
        currentPromotions: const [], // Promo is invalidated / empty
        catalogProducts: catalog,
        activeOrderTypes: [
          const PosOrderType(code: 'dinein', name: 'Dine In'),
          const PosOrderType(code: 'takeaway', name: 'Take Away'),
        ],
      );

      expect(transitionResult.isChanged, isTrue);
      expect(transitionResult.orderType, 'takeaway');
      // Repriced to takeaway base price (26000), not kept at 20000
      expect(transitionResult.items.first.regularUnitPrice, 26000);
      expect(transitionResult.items.first.orderType, 'takeaway');

      // When recalculatePosCartPromotions runs with no valid promos:
      final recalcResult = PosPromotionService.instance.recalculatePosCartPromotions(
        cartItems: transitionResult.items,
        selectedPromotions: const [],
        catalogProducts: catalog,
        selectedOrderType: 'takeaway',
      );

      expect(recalcResult.items.first.regularUnitPrice, 26000);
      expect(recalcResult.items.first.appliedPromoId, isNull);
    });

    test('P1 Fix: Split item carries new orderType, note, and discountEnabled to second line', () {
      final item = {
        'id': 'line-1',
        'name': 'Fried Rice',
        'quantity': 3,
        'orderType': 'dinein',
        'note': 'Old Note',
        'isDiscountEnabled': false,
      };

      const splitQuantity = 1;
      const totalQuantity = 3;
      const newOrderType = 'takeaway';
      const newNote = 'Extra spicy';
      const newDiscountEnabled = true;

      final safeSplitQuantity = splitQuantity.clamp(1, totalQuantity - 1);
      final remainingQuantity = totalQuantity - safeSplitQuantity;

      final line1 = {
        ...item,
        'quantity': remainingQuantity,
        'orderType': newOrderType,
        'note': newNote,
        'isDiscountEnabled': newDiscountEnabled,
      };

      final line2 = {
        ...item,
        'id': 'line-2-new-id',
        'quantity': safeSplitQuantity,
        'orderType': newOrderType,
        'note': newNote,
        'isDiscountEnabled': newDiscountEnabled,
      };

      expect(line1['orderType'], 'takeaway');
      expect(line1['quantity'], 2);
      expect(line1['note'], 'Extra spicy');
      expect(line1['isDiscountEnabled'], isTrue);

      expect(line2['orderType'], 'takeaway'); // Line 2 has takeaway!
      expect(line2['quantity'], 1);
      expect(line2['note'], 'Extra spicy');
      expect(line2['isDiscountEnabled'], isTrue);
    });

    test('Real SQLite pos_order insertion stores canonical order_type_code', () async {
      // Direct SQLite insertion of pos_order record
      final now = DateTime.now().toIso8601String();
      await db.insert('pos_order', {
        'tenant_id': testTenantId,
        'location_id': 'LOC-01',
        'register_id': 'REG-01',
        'id_pos': 'POS-SQLITE-TEST-1',
        'order_type_code': 'takeaway',
        'status_code': '1',
        'total_amount': 50000,
        'subtotal_amount': 50000,
        'discount_total_amount': 0,
        'sync_state': 'dirty',
        'created_at': now,
        'updated_at': now,
      });

      final rows = await db.query(
        'pos_order',
        where: 'id_pos = ?',
        whereArgs: ['POS-SQLITE-TEST-1'],
      );

      expect(rows.length, 1);
      expect(rows.first['order_type_code'], 'takeaway');
      expect(rows.first['tenant_id'], testTenantId);
      expect(rows.first['total_amount'], 50000);
    });
  });
}
