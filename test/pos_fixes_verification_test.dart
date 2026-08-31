import 'dart:convert';

import 'package:flinkpos_v2/core/services/local/database_service.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_runtime_session_store.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_order_type_pricing_service.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_order_type_store.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_order_type_transition_service.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_promotion_service.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/sales_order_store.dart';
import 'package:flinkpos_v2/modules/sales/orders/shared/order_status_presenter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('P0 — Partial Promo & Bundling Allocation Tests', () {
    test(
      'Promo applying to 1 out of 2 units correctly splits line and only discounts 1 unit',
      () {
        final catalog = [
          {
            'remoteId': 'p1',
            'name': 'Espresso',
            'regularPrice': 20000,
            'price': 'Rp 20.000',
          },
        ];

        final cartItems = <PosCartItem>[
          const PosCartItem(
            id: 'item-1',
            name: 'Espresso',
            displayName: 'Espresso',
            imageUrl: '',
            productRemoteId: 'p1',
            regularUnitPrice: 20000,
            quantity: 2,
          ),
        ];

        final singleUnitPromo = PosPromotionResult(
          remoteId: 'promo-1',
          name: 'Single Unit Discount 5k',
          promoType: 'discount',
          discountAmount: 5000,
          displayAmount: 'Rp 5.000',
          matchedTotal: 1,
          summary: 'Discount 5k on 1 unit',
          isMultiplied: false, // Applies only to 1 unit!
          isStackable: false,
          rawPayload: {
            'items': {
              'detail': [
                {
                  'item_id': 'p1',
                  'discount_type': 'nominal',
                  'discount_value': '5000',
                },
              ],
            },
          },
        );

        final result = PosPromotionService.instance
            .recalculatePosCartPromotions(
              cartItems: cartItems,
              selectedPromotions: [singleUnitPromo],
              catalogProducts: catalog,
              selectedOrderType: 'dinein',
            );

        // Verify total discount is 5,000 (not 10,000)
        expect(result.totalDiscountAmount, 5000);

        // Verify cart items are split into 2 lines: 1 unit with promo, 1 unit without promo
        expect(result.items.length, 2);

        final promoItem = result.items.firstWhere(
          (i) => i.appliedPromoId != null,
        );
        expect(promoItem.quantity, 1);
        expect(promoItem.regularUnitPrice, 20000);
        expect(promoItem.overriddenUnitPrice, 15000);
        expect(promoItem.activeUnitPrice, 15000);
        expect(promoItem.appliedPromoId, 'promo-1');

        final regularItem = result.items.firstWhere(
          (i) => i.appliedPromoId == null,
        );
        expect(regularItem.quantity, 1);
        expect(regularItem.regularUnitPrice, 20000);
        expect(regularItem.overriddenUnitPrice, isNull);
        expect(regularItem.activeUnitPrice, 20000);
      },
    );

    test(
      'Incomplete bundle does NOT lock or tag items and produces 0 discount',
      () {
        // Bundle requires 1 Burger (p-burger) + 1 Drink (p-drink)
        final matchItems = [
          const PosPromotionMatchItem(
            refId: 'line-burger',
            productRemoteId: 'p-burger',
            productName: 'Burger',
            categoryRemoteId: 'cat1',
            brandRemoteId: 'brand1',
            activeUnitPrice: 25000,
            quantity: 1,
          ),
        ];

        final bundlePromo = PosPromotionResult(
          remoteId: 'promo-combo',
          name: 'Combo Burger + Drink 30k',
          promoType: 'bundling',
          discountAmount: 10000,
          displayAmount: 'Rp 30.000',
          matchedTotal: 1,
          summary: 'Combo Burger + Drink',
          isMultiplied: true,
          rawPayload: {
            'items': {
              'total_price': '30000',
              'detail': [
                {'qty': '1', 'target_id': 'p-burger'},
                {'qty': '1', 'target_id': 'p-drink'},
              ],
            },
          },
        );

        final allocation = PosPromotionService.instance.allocatePromotions(
          items: matchItems,
          selectedPromotions: [bundlePromo],
        );

        expect(allocation.totalDiscountAmount, 0);
        expect(allocation.allocatedItems.length, 1);
        expect(allocation.allocatedItems.first.appliedPromoId, isNull);
        expect(allocation.allocatedItems.first.appliedPromoName, isNull);
        expect(allocation.allocatedItems.first.overriddenUnitPrice, isNull);
      },
    );

    test(
      'Bundling discount distribution preserves exact rupiah remainder when qty > 1',
      () {
        // Line item: qty 2, regular price 10000 each (subtotal 20000).
        // Bundle price: 19999 (discount 1).
        final matchItems = [
          const PosPromotionMatchItem(
            refId: 'line-item-1',
            productRemoteId: 'p-item',
            productName: 'Item',
            categoryRemoteId: 'cat1',
            brandRemoteId: 'brand1',
            activeUnitPrice: 10000,
            quantity: 2,
          ),
        ];

        final bundlePromo = PosPromotionResult(
          remoteId: 'promo-bundle-odd',
          name: 'Bundle 2 Items 19999',
          promoType: 'bundling',
          discountAmount: 1,
          displayAmount: 'Rp 19.999',
          matchedTotal: 1,
          summary: 'Bundle 2 Items for 19999',
          isMultiplied: false,
          rawPayload: {
            'items': {
              'total_price': '19999',
              'detail': [
                {'qty': '2', 'target_id': 'p-item'},
              ],
            },
          },
        );

        final allocation = PosPromotionService.instance.allocatePromotions(
          items: matchItems,
          selectedPromotions: [bundlePromo],
        );

        // Total discount must be exactly 1 (not 0)
        expect(allocation.totalDiscountAmount, 1);
        expect(allocation.allocatedItems.length, 2);

        final discountedItem = allocation.allocatedItems.firstWhere(
          (i) => i.overriddenUnitPrice != null,
        );
        expect(discountedItem.quantity, 1);
        expect(discountedItem.activeUnitPrice, 10000);
        expect(discountedItem.overriddenUnitPrice, 9999);

        final remainderItem = allocation.allocatedItems.firstWhere(
          (i) => i.overriddenUnitPrice == null,
        );
        expect(remainderItem.quantity, 1);
        expect(remainderItem.activeUnitPrice, 10000);
      },
    );

    test(
      'Multiplied bundle applies to multiple sets when multiple quantities exist',
      () {
        final matchItems = [
          const PosPromotionMatchItem(
            refId: 'line-burger',
            productRemoteId: 'p-burger',
            productName: 'Burger',
            categoryRemoteId: 'cat1',
            brandRemoteId: 'brand1',
            activeUnitPrice: 25000,
            quantity: 2,
          ),
          const PosPromotionMatchItem(
            refId: 'line-drink',
            productRemoteId: 'p-drink',
            productName: 'Drink',
            categoryRemoteId: 'cat1',
            brandRemoteId: 'brand1',
            activeUnitPrice: 15000,
            quantity: 2,
          ),
        ];

        final bundlePromo = PosPromotionResult(
          remoteId: 'promo-combo',
          name: 'Combo Burger + Drink 30k',
          promoType: 'bundling',
          discountAmount: 10000,
          displayAmount: 'Rp 30.000',
          matchedTotal: 2,
          summary: 'Combo Burger + Drink',
          isMultiplied: true,
          rawPayload: {
            'items': {
              'total_price': '30000',
              'detail': [
                {'qty': '1', 'target_id': 'p-burger'},
                {'qty': '1', 'target_id': 'p-drink'},
              ],
            },
          },
        );

        final allocation = PosPromotionService.instance.allocatePromotions(
          items: matchItems,
          selectedPromotions: [bundlePromo],
        );

        expect(allocation.totalDiscountAmount, 20000);
        final promoItems = allocation.allocatedItems
            .where((i) => i.appliedPromoId != null)
            .toList();
        final totalPromoQty = promoItems.fold<int>(
          0,
          (sum, i) => sum + i.quantity,
        );
        expect(totalPromoQty, 4); // 2 burgers + 2 drinks
      },
    );
  });

  group('P0 — Promo Double Discount & Order Persistence Alignment Tests', () {
    test(
      'Gross subtotal Rp20.000 with Rp1 promo discount yields exact Rp19.999 in UI and SalesOrderRecord without double-discounting',
      () {
        final catalog = [
          {'remoteId': 'p-item', 'name': 'Item', 'regularPrice': 10000},
        ];

        final cartItems = <PosCartItem>[
          const PosCartItem(
            id: 'line-item-1',
            name: 'Item',
            displayName: 'Item',
            imageUrl: '',
            productRemoteId: 'p-item',
            regularUnitPrice: 10000,
            quantity: 2,
          ),
        ];

        final bundlePromo = PosPromotionResult(
          remoteId: 'promo-bundle-odd',
          name: 'Bundle 2 Items 19999',
          promoType: 'bundling',
          discountAmount: 1,
          displayAmount: 'Rp 19.999',
          matchedTotal: 1,
          summary: 'Bundle 2 Items for 19999',
          isMultiplied: false,
          rawPayload: {
            'items': {
              'total_price': '19999',
              'detail': [
                {'qty': '2', 'target_id': 'p-item'},
              ],
            },
          },
        );

        final result = PosPromotionService.instance
            .recalculatePosCartPromotions(
              cartItems: cartItems,
              selectedPromotions: [bundlePromo],
              catalogProducts: catalog,
              selectedOrderType: 'dinein',
            );

        // 1. Check UI Math
        final subtotalGross = result.items.fold<int>(
          0,
          (sum, item) => sum + (item.regularUnitPrice * item.quantity),
        );
        final itemDiscount = result.items.fold<int>(
          0,
          (sum, item) =>
              sum +
              ((item.regularUnitPrice - item.activeUnitPrice) * item.quantity),
        );
        const orderLevelDiscount =
            0; // Item promo is not an order-level discount
        final totalDiscount = itemDiscount + orderLevelDiscount;
        final netAmount = subtotalGross - totalDiscount;
        final totalPay = netAmount; // 0 tax

        expect(subtotalGross, 20000);
        expect(itemDiscount, 1);
        expect(totalDiscount, 1);
        expect(netAmount, 19999);
        expect(totalPay, 19999);

        // 2. Check Line Items conversion
        final lines = result.items.map((item) {
          final effectiveDiscountedPrice =
              item.overriddenUnitPrice ?? item.discountedUnitPrice;
          final hasDiscount =
              effectiveDiscountedPrice != null &&
              effectiveDiscountedPrice < item.regularUnitPrice;
          return SalesOrderLineItem(
            id: item.id,
            name: item.name,
            imageUrl: item.imageUrl,
            regularUnitPrice: item.regularUnitPrice,
            quantity: item.quantity,
            productRemoteId: item.productRemoteId,
            discountedUnitPrice: hasDiscount
                ? effectiveDiscountedPrice
                : item.discountedUnitPrice,
            promoLabel: item.appliedPromoName ?? item.promoLabel,
            isDiscountEnabled: hasDiscount || item.isDiscountEnabled,
            orderType: item.orderType ?? 'dinein',
            note: item.note,
          );
        }).toList();

        // 3. Verify SalesOrderRecord math
        final record = SalesOrderRecord(
          id: 'POS-TEST-DOUBLE-DISCOUNT',
          token: 'token-1',
          customerLocalId: 1,
          customerRemoteId: '1',
          customerName: 'Customer',
          customerPhone: '123',
          customerAddress: 'Address',
          orderType: 'dinein',
          statusCode: 2,
          taxAmount: 0,
          taxPercentage: 0.0,
          orderLevelDiscountAmount: 0,
          items: lines,
          createdAt: DateTime.now(),
        );

        expect(record.subtotalAmount, 20000);
        expect(record.itemDiscountTotal, 1);
        // item discount verified via itemDiscountTotal and totalAmount
        expect(record.totalAmount, 19999); // Exactly 19.999, NOT 19.998!
      },
    );
  });

  group('P1 — Bundling must_be_different Constraint Tests', () {
    test(
      'Bundle requiring 2 different items is NOT fulfilled when cart only has 2 units of the same product',
      () {
        // Pool has 2 units of Coffee A (same product)
        final matchItems = [
          const PosPromotionMatchItem(
            refId: 'line-coffee-a',
            productRemoteId: 'prod_coffee_a',
            productName: 'Coffee A',
            categoryRemoteId: 'cat_beverages',
            brandRemoteId: 'brand_1',
            activeUnitPrice: 20000,
            quantity: 2,
          ),
        ];

        // Bundle: Must pick 2 different products from ['prod_coffee_a', 'prod_coffee_b']
        final bundlePromo = PosPromotionResult(
          remoteId: 'promo-bundle-diff',
          name: 'Pair of Different Coffees 30k',
          promoType: 'bundling',
          discountAmount: 10000,
          displayAmount: 'Rp 30.000',
          matchedTotal: 2,
          summary: '2 Different Coffees',
          isMultiplied: true,
          rawPayload: {
            'items': {
              'total_price': '30000',
              'detail': [
                {
                  'qty': '2',
                  'target_id': ['prod_coffee_a', 'prod_coffee_b'],
                  'must_be_different': '1',
                },
              ],
            },
          },
        );

        final allocation = PosPromotionService.instance.allocatePromotions(
          items: matchItems,
          selectedPromotions: [bundlePromo],
        );

        // Because cart only has Coffee A, bundle cannot be satisfied
        expect(allocation.totalDiscountAmount, 0);
        expect(allocation.allocatedItems.length, 1);
        expect(allocation.allocatedItems.first.appliedPromoId, isNull);
        expect(allocation.allocatedItems.first.overriddenUnitPrice, isNull);
      },
    );

    test(
      'Bundle requiring 2 different items IS fulfilled when cart has 1 unit of Coffee A and 1 unit of Coffee B',
      () {
        final matchItems = [
          const PosPromotionMatchItem(
            refId: 'line-coffee-a',
            productRemoteId: 'prod_coffee_a',
            productName: 'Coffee A',
            categoryRemoteId: 'cat_beverages',
            brandRemoteId: 'brand_1',
            activeUnitPrice: 20000,
            quantity: 1,
          ),
          const PosPromotionMatchItem(
            refId: 'line-coffee-b',
            productRemoteId: 'prod_coffee_b',
            productName: 'Coffee B',
            categoryRemoteId: 'cat_beverages',
            brandRemoteId: 'brand_1',
            activeUnitPrice: 20000,
            quantity: 1,
          ),
        ];

        final bundlePromo = PosPromotionResult(
          remoteId: 'promo-bundle-diff',
          name: 'Pair of Different Coffees 30k',
          promoType: 'bundling',
          discountAmount: 10000,
          displayAmount: 'Rp 30.000',
          matchedTotal: 2,
          summary: '2 Different Coffees',
          isMultiplied: true,
          rawPayload: {
            'items': {
              'total_price': '30000',
              'detail': [
                {
                  'qty': '2',
                  'target_id': ['prod_coffee_a', 'prod_coffee_b'],
                  'must_be_different': '1',
                },
              ],
            },
          },
        );

        final allocation = PosPromotionService.instance.allocatePromotions(
          items: matchItems,
          selectedPromotions: [bundlePromo],
        );

        expect(allocation.totalDiscountAmount, 10000);
        expect(allocation.allocatedItems.length, 2);
        for (final item in allocation.allocatedItems) {
          expect(item.appliedPromoId, 'promo-bundle-diff');
          expect(item.overriddenUnitPrice, 15000); // 30k / 2
        }
      },
    );
  });

  group('P1 — Order Type Pricing & Availability on Transition Tests', () {
    test(
      'Transitioning order type filters out products not available for the new order type',
      () async {
        final catalog = [
          {
            'remoteId': 'p-dinein',
            'name': 'Dine-In Steak',
            'orderTypePrices': {'dinein': 50000},
          },
          {
            'remoteId': 'p-universal',
            'name': 'Mineral Water',
            'orderTypePrices': {'dinein': 10000, 'takeaway': 12000},
          },
        ];

        final currentItems = [
          const PosCartItem(
            id: 'item-steak',
            name: 'Dine-In Steak',
            displayName: 'Dine-In Steak',
            imageUrl: '',
            productRemoteId: 'p-dinein',
            regularUnitPrice: 50000,
            quantity: 1,
            orderType: 'dinein',
          ),
          const PosCartItem(
            id: 'item-water',
            name: 'Mineral Water',
            displayName: 'Mineral Water',
            imageUrl: '',
            productRemoteId: 'p-universal',
            regularUnitPrice: 10000,
            quantity: 1,
            orderType: 'dinein',
          ),
        ];

        final activeOrderTypes = [
          const PosOrderType(code: 'dinein', name: 'Dine In'),
          const PosOrderType(code: 'takeaway', name: 'Take Away'),
        ];

        final result =
            await PosOrderTypeTransitionService.transitionPosCartOrderType(
              currentOrderType: 'dinein',
              targetOrderType: 'takeaway',
              currentItems: currentItems,
              currentPromotions: const [],
              catalogProducts: catalog,
              activeOrderTypes: activeOrderTypes,
            );

        expect(result.isChanged, isTrue);
        expect(result.orderType, 'takeaway');
        // Dine-in only steak must be removed; only Mineral Water remains
        expect(result.items.length, 1);
        expect(result.items.first.productRemoteId, 'p-universal');
        expect(result.items.first.regularUnitPrice, 12000);
        expect(result.items.first.orderType, 'takeaway');
      },
    );

    test(
      'PosOrderTypePricingService.createCartItem applies pricing and availability correctly',
      () {
        final product = {
          'remoteId': 'p2',
          'name': 'Americano',
          'price': 'Rp 18.000',
          'regularPrice': 18000,
          'orderTypePrices': {'takeaway': 22000, 'gofood': 26000},
        };

        final dineInItem = PosOrderTypePricingService.createCartItem(
          id: 'line-1',
          product: product,
          orderType: 'dinein',
        );
        expect(dineInItem.regularUnitPrice, 18000);

        final takeawayItem = PosOrderTypePricingService.createCartItem(
          id: 'line-2',
          product: product,
          orderType: 'takeaway',
        );
        expect(takeawayItem.regularUnitPrice, 22000);
      },
    );
  });

  group('P1 & P2 — Sync Queue Real SQLite Insertion & JSON Payload Tests', () {
    late Database db;
    const testTenantId = 202;
    const testSession = PosV2RuntimeSession(
      tenantId: testTenantId,
      tenantKey: 'tenant-key-202',
      baseUrl: 'https://api.test.flinkpos.com',
      authToken: 'auth-token-202',
      locationId: 'LOC-02',
      staffId: '2',
      staffEmail: 'cashier2@test.com',
      deviceId: 'DEVICE-02',
    );

    setUp(() async {
      db = await DatabaseService.instance.database;
      await db.delete('sync_queue');
      await db.delete('pos_order_item');
      await db.delete('pos_order');
      await db.delete('order_type');
      await db.delete('app_tenant');

      await db.insert('app_tenant', {
        'id': testTenantId,
        'tenant_key': 'tenant-key-202',
        'tenant_name': 'Test Tenant 202',
        'base_url': 'https://api.test.flinkpos.com',
        'location_id': 'LOC-02',
        'is_active': 1,
      });

      await db.insert('order_type', {
        'id': 1,
        'tenant_id': testTenantId,
        'code': 'dinein',
        'name': 'Dine In',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      await db.insert('order_type', {
        'id': 2,
        'tenant_id': testTenantId,
        'code': 'takeaway',
        'name': 'Take Away',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      PosV2RuntimeSessionStore.instance.setSession(testSession);
      PosOrderTypeStore.instance.snapshotNotifier.value =
        const PosOrderTypeSnapshot(
          orderTypes: [
            PosOrderType(code: 'dinein', name: 'Dine In'),
            PosOrderType(code: 'takeaway', name: 'Take Away'),
          ],
        );
    });

    tearDown(() async {
      await db.delete('sync_queue');
      await db.delete('pos_order_item');
      await db.delete('pos_order');
      await db.delete('order_type');
      await db.delete('app_tenant');
      PosV2RuntimeSessionStore.instance.setSession(null);
    });

    test(
      'buildOrderPayload produces exact JSON with order_type and note in newitems',
      () {
        final record = SalesOrderRecord(
          id: 'POS-TEST-12345',
          token: 'token-abc',
          customerLocalId: 1,
          customerRemoteId: '10',
          customerName: 'Budi Walk-In',
          customerPhone: '0812345678',
          customerAddress: 'Jl. Sudirman No. 1',
          orderType: 'dinein',
          statusCode: 1,
          taxAmount: 0,
          taxPercentage: 0.0,
          orderLevelDiscountAmount: 0,
          items: const [
            SalesOrderLineItem(
              id: 'line-1',
              name: 'Burger Dine In',
              imageUrl: '',
              regularUnitPrice: 50000,
              quantity: 1,
              productRemoteId: 'p-101',
              orderType: 'dinein',
              note: 'No pickle',
            ),
            SalesOrderLineItem(
              id: 'line-2',
              name: 'Coffee Takeaway',
              imageUrl: '',
              regularUnitPrice: 40000,
              quantity: 1,
              productRemoteId: 'p-102',
              orderType: 'takeaway',
              note: 'Less ice, oat milk',
            ),
          ],
          createdAt: DateTime(2026, 8, 21, 10, 0, 0),
        );

        final payload = SalesOrderStore.instance.buildOrderPayload(record, [
          'cash',
          'qris',
        ], isCreate: true);

        expect(payload['id_pos'], 'POS-TEST-12345');
        expect(payload['order_type'], 'dinein');

        final newitems = payload['newitems'] as List<dynamic>;
        expect(newitems.length, 2);

        final item1 = newitems[0] as Map<String, Object?>;
        expect(item1['itemid'], 'p-101');
        expect(item1['description'], 'Burger Dine In');
        expect(item1['qty'], 1);
        expect(item1['rate'], 50000);
        expect(item1['order_type'], 'dinein');
        expect(item1['note'], 'No pickle');
        expect(item1['order'], 1);

        final item2 = newitems[1] as Map<String, Object?>;
        expect(item2['itemid'], 'p-102');
        expect(item2['description'], 'Coffee Takeaway');
        expect(item2['qty'], 1);
        expect(item2['rate'], 40000);
        expect(item2['order_type'], 'takeaway');
        expect(item2['note'], 'Less ice, oat milk');
        expect(item2['order'], 2);
      },
    );

    test(
      'createOrder inserts real row into SQLite sync_queue table with order_type and note in request_body_json newitems',
      () async {
        final order = await SalesOrderStore.instance.createOrder(
          statusCode: 2,
          orderType: 'dinein',
          customerRemoteId: '10',
          items: const [
            SalesOrderLineItem(
              id: 'line-sqlite-1',
              name: 'Fried Rice',
              imageUrl: '',
              regularUnitPrice: 35000,
              quantity: 2,
              productRemoteId: 'prod-rice-01',
              orderType: 'dinein',
              note: 'Extra spicy',
            ),
            SalesOrderLineItem(
              id: 'line-sqlite-2',
              name: 'Iced Tea',
              imageUrl: '',
              regularUnitPrice: 10000,
              quantity: 1,
              productRemoteId: 'prod-tea-02',
              orderType: 'takeaway',
              note: 'No sugar',
            ),
          ],
          customerName: 'Budi Test',
          customerPhone: '08123456789',
          processQueueNow: false, // Keep in sync_queue for inspection
        );

        expect(order, isNotNull);

        // Query real SQLite sync_queue table
        final queueRows = await db.query(
          'sync_queue',
          where: 'tenant_id = ? AND entity_type = ?',
          whereArgs: [testTenantId, 'pos_order'],
        );

        expect(queueRows.isNotEmpty, isTrue);
        final queueRow = queueRows.first;
        final rawBody = queueRow['request_body_json']?.toString();
        expect(rawBody, isNotNull);

        final decoded = jsonDecode(rawBody!) as Map<String, dynamic>;
        expect(decoded['id_pos'], order!.id);
        expect(decoded['order_type'], 'dinein');

        final newitems = decoded['newitems'] as List<dynamic>;
        expect(newitems.length, 2);

        final item1 = newitems[0] as Map<String, dynamic>;
        expect(item1['itemid'], 'prod-rice-01');
        expect(item1['description'], 'Fried Rice');
        expect(item1['qty'], 2);
        expect(item1['rate'], 35000);
        expect(item1['order_type'], 'dinein');
        expect(item1['note'], 'Extra spicy');

        final item2 = newitems[1] as Map<String, dynamic>;
        expect(item2['itemid'], 'prod-tea-02');
        expect(item2['description'], 'Iced Tea');
        expect(item2['qty'], 1);
        expect(item2['rate'], 10000);
        expect(item2['order_type'], 'takeaway');
        expect(item2['note'], 'No sugar');
      },
    );
  });
  group('Promotion Service Robustness & Real Matching Tests', () {
    test('getApplicablePromotions parses promo_type and order types correctly from SQLite', () async {
      final db = await DatabaseService.instance.database;
      const tenantId = 505;
      const testSession = PosV2RuntimeSession(
        tenantId: tenantId,
        tenantKey: 'tenant-key-505',
        baseUrl: 'https://api.test.flinkpos.com',
        authToken: 'auth-token-505',
        locationId: 'LOC-505',
        staffId: '5',
        staffEmail: 'cashier5@test.com',
        deviceId: 'DEVICE-505',
      );
      await db.delete('promotion');
      await db.delete('app_tenant');
      await db.insert('app_tenant', {
        'id': tenantId,
        'tenant_key': 'tenant-key-505',
        'tenant_name': 'Test Tenant 505',
        'base_url': 'https://api.test.flinkpos.com',
        'location_id': 'LOC-505',
        'is_active': 1,
      });
      PosV2RuntimeSessionStore.instance.setSession(testSession);
      PosOrderTypeStore.instance.snapshotNotifier.value =
        const PosOrderTypeSnapshot(
          orderTypes: [
            PosOrderType(code: 'dinein', name: 'Dine In'),
            PosOrderType(code: 'takeaway', name: 'Take Away'),
          ],
        );

      // Insert promotions into promotion table
      await db.insert('promotion', {
        'tenant_id': tenantId,
        'remote_id': 'promo-percent-10',
        'name': '10% All Coffee',
        'promo_type': 'discount',
        'status': 'active',
        'is_multiplied': 1,
        'is_stackable': 0,
        'raw_payload_json': jsonEncode({
          'id': 'promo-percent-10',
          'name': '10% All Coffee',
          'promo_type': 'discount',
          'order_types': ['dine_in', 'take_away'],
          'items': {
            'detail': [
              {
                'item_id': 'prod-coffee-01',
                'discount_type': 'percent',
                'discount_value': '10',
              }
            ]
          }
        }),
      });

      final matchItems = [
        const PosPromotionMatchItem(
          refId: 'line-1',
          productRemoteId: 'prod-coffee-01',
          productName: 'Coffee Cup',
          categoryRemoteId: 'cat-1',
          brandRemoteId: 'brand-1',
          activeUnitPrice: 20000,
          quantity: 2,
        ),
      ];

      final promos = await PosPromotionService.instance.getApplicablePromotions(
        items: matchItems,
        orderTypeCode: 'dinein',
      );

      expect(promos.any((p) => p.remoteId == 'promo-percent-10'), isTrue);
      final percentPromo = promos.firstWhere((p) => p.remoteId == 'promo-percent-10');
      expect(percentPromo.isApplicable, isTrue);
      // 10% of 20000 * 2 = 4000
      expect(percentPromo.discountAmount, 4000);

      // Allocate promo
      final allocation = PosPromotionService.instance.allocatePromotions(
        items: matchItems,
        selectedPromotions: [percentPromo],
      );

      expect(allocation.totalDiscountAmount, 4000);
      expect(allocation.allocatedItems.length, 1);
      expect(allocation.allocatedItems.first.overriddenUnitPrice, 18000);
    });
    test('Deleting active order marks SQLite deleted_at, clears sync_queue, and does NOT reappear on refresh', () async {
      final db = await DatabaseService.instance.database;
      const tenantId = 606;
      const testSession = PosV2RuntimeSession(
        tenantId: tenantId,
        tenantKey: 'tenant-key-606',
        baseUrl: 'https://api.test.flinkpos.com',
        authToken: 'auth-token-606',
        locationId: 'LOC-606',
        staffId: '6',
        staffEmail: 'cashier6@test.com',
        deviceId: 'DEVICE-606',
      );
      await db.delete('sync_queue');
      await db.delete('pos_order_payment');
      await db.delete('pos_order_item');
      await db.delete('pos_order');
      await db.delete('order_type');
      await db.delete('app_tenant');
      await db.insert('app_tenant', {
        'id': tenantId,
        'tenant_key': 'tenant-key-606',
        'tenant_name': 'Test Tenant 606',
        'base_url': 'https://api.test.flinkpos.com',
        'location_id': 'LOC-606',
        'is_active': 1,
      });
      await db.insert('order_type', {
        'id': 1,
        'tenant_id': tenantId,
        'code': 'dinein',
        'name': 'Dine In',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      PosV2RuntimeSessionStore.instance.setSession(testSession);
      PosOrderTypeStore.instance.snapshotNotifier.value =
          const PosOrderTypeSnapshot(
            orderTypes: [
              PosOrderType(code: 'dinein', name: 'Dine In'),
            ],
          );

      // 1. Create order
      final created = await SalesOrderStore.instance.createOrder(
        customerName: 'Customer Test',
        customerRemoteId: '1',
        statusCode: 1,
        orderType: 'dinein',
        items: [
          const SalesOrderLineItem(
            id: 'item-1',
            name: 'Nasi Goreng',
            imageUrl: '',
            regularUnitPrice: 25000,
            quantity: 2,
            orderType: 'dinein',
          ),
        ],
        paymentModeRemoteId: '1',
        paymentModeName: 'Cash',
      );

      expect(created, isNotNull);
      final orderId = created!.id;

      // Verify in memory and in SQLite
      expect(SalesOrderStore.instance.recordsNotifier.value.any((r) => r.id == orderId), isTrue);

      final initialDbRows = await db.query(
        'pos_order',
        where: 'tenant_id = ? AND id_pos = ? AND deleted_at IS NULL',
        whereArgs: [tenantId, orderId],
      );
      expect(initialDbRows.length, 1);

      final initialQueue = await db.query(
        'sync_queue',
        where: 'tenant_id = ? AND entity_type = ?',
        whereArgs: [tenantId, 'pos_order'],
      );
      expect(initialQueue.length, 1);

      // 2. Delete the order
      SalesOrderStore.instance.deleteOrder(orderId);

      // Wait brief moment for async _markOrderDeleted to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // In-memory list no longer has the order
      expect(SalesOrderStore.instance.recordsNotifier.value.any((r) => r.id == orderId), isFalse);

      // SQLite pos_order has deleted_at set
      final activeDbRows = await db.query(
        'pos_order',
        where: 'tenant_id = ? AND id_pos = ? AND deleted_at IS NULL',
        whereArgs: [tenantId, orderId],
      );
      expect(activeDbRows.isEmpty, isTrue);

      final deletedRows = await db.query(
        'pos_order',
        where: 'tenant_id = ? AND id_pos = ? AND deleted_at IS NOT NULL',
        whereArgs: [tenantId, orderId],
      );
      expect(deletedRows.length, 1);

      // Sync queue item for pending creation is removed
      final pendingCreationQueue = await db.query(
        'sync_queue',
        where: 'tenant_id = ? AND entity_type = ? AND operation = ?',
        whereArgs: [tenantId, 'pos_order', 'create'],
      );
      expect(pendingCreationQueue.isEmpty, isTrue);

      // 3. Trigger refreshFromPersistence() - order MUST NOT reappear!
      await SalesOrderStore.instance.refreshFromPersistence();
      expect(SalesOrderStore.instance.recordsNotifier.value.any((r) => r.id == orderId), isFalse);
    });
  });

  group('OrderStatusPresenter Format Tests', () {
    test('formatRupiah formats whole numbers and decimal floats correctly with ID locale separator', () {
      expect(OrderStatusPresenter.formatRupiah(0), 'Rp 0');
      expect(OrderStatusPresenter.formatRupiah(500), 'Rp 500');
      expect(OrderStatusPresenter.formatRupiah(5000), 'Rp 5.000');
      expect(OrderStatusPresenter.formatRupiah(50000), 'Rp 50.000');
      expect(OrderStatusPresenter.formatRupiah(1250000), 'Rp 1.250.000');
      expect(OrderStatusPresenter.formatRupiah(1250000.75), 'Rp 1.250.000');
    });

    test('formatTime formats DateTime into HH:mm with zero padding', () {
      final dt1 = DateTime(2026, 8, 31, 9, 5);
      expect(OrderStatusPresenter.formatTime(dt1), '09:05');
      final dt2 = DateTime(2026, 8, 31, 14, 30);
      expect(OrderStatusPresenter.formatTime(dt2), '14:30');
    });
  });
}
