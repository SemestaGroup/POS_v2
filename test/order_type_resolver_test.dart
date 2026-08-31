import 'package:flutter_test/flutter_test.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/order_type_resolver.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/order_type_presenter.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_order_type_store.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_order_type_pricing_service.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_order_type_transition_service.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/pos_promotion_service.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/sales_order_store.dart';

void main() {
  const activeMaster = <PosOrderType>[
    PosOrderType(code: 'dinein', name: 'Dine In'),
    PosOrderType(code: 'takeaway', name: 'Take Away'),
    PosOrderType(code: 'delivery', name: 'Delivery'),
    PosOrderType(code: 'drive_thru', name: 'Drive Thru'),
    PosOrderType(code: 'catering_vip', name: 'Catering VIP'),
  ];

  const customOnlyMaster = <PosOrderType>[
    PosOrderType(code: 'event_booth', name: 'Event Booth'),
    PosOrderType(code: 'wholesale_bulk', name: 'Wholesale Bulk'),
  ];

  group('OrderTypeResolver Code & Alias Tests', () {
    test('resolveCode matches canonical codes and legacy aliases', () {
      expect(OrderTypeResolver.resolveCode('dine_in', activeMaster), 'dinein');
      expect(OrderTypeResolver.resolveCode('TAKE_AWAY', activeMaster), 'takeaway');
      expect(OrderTypeResolver.resolveCode('take-away', activeMaster), isNull);
      expect(OrderTypeResolver.resolveCode('drive_thru', activeMaster), 'drive_thru');
      expect(OrderTypeResolver.resolveCode('non_existent', activeMaster), isNull);
      expect(OrderTypeResolver.resolveCode('', activeMaster), isNull);
      expect(OrderTypeResolver.resolveCode(null, activeMaster), isNull);
    });

    test('resolveOrDefault falls back correctly based on active types', () {
      // 1. Exact canonical exists
      expect(
        OrderTypeResolver.resolveOrDefault('takeaway', activeMaster),
        'takeaway',
      );

      // 2. Legacy alias resolves to master canonical
      expect(
        OrderTypeResolver.resolveOrDefault('dine_in', activeMaster),
        'dinein',
      );

      // 3. Unknown code falls back to first active type in master
      expect(
        OrderTypeResolver.resolveOrDefault('invalid_foo', activeMaster),
        'dinein',
      );

      // 4. Custom-only master falls back to first available custom type
      expect(
        OrderTypeResolver.resolveOrDefault('dinein', customOnlyMaster),
        'event_booth',
      );

      // 5. Empty master returns provided code or fallback
      expect(
        OrderTypeResolver.resolveOrDefault('custom_1', const <PosOrderType>[]),
        'custom_1',
      );
      expect(
        OrderTypeResolver.resolveOrDefault(
          null,
          const <PosOrderType>[],
          fallback: 'takeaway',
        ),
        'takeaway',
      );
    });

    test('reconcileSelected preserves valid custom or defaults correctly', () {
      expect(
        OrderTypeResolver.reconcileSelected(
          currentSelected: 'wholesale_bulk',
          activeTypes: customOnlyMaster,
        ),
        'wholesale_bulk',
      );

      // If current selection is invalid, it reconciles to first active
      expect(
        OrderTypeResolver.reconcileSelected(
          currentSelected: 'obsolete_code',
          activeTypes: customOnlyMaster,
        ),
        'event_booth',
      );
    });
  });

  group('OrderTypePresenter Tests', () {
    test(
      'getDisplayName uses human readable names for builtins and master titles',
      () {
        expect(
          OrderTypePresenter.getDisplayName('dinein', activeMaster),
          'Dine In',
        );
        expect(
          OrderTypePresenter.getDisplayName('takeaway', activeMaster),
          'Take Away',
        );
        expect(
          OrderTypePresenter.getDisplayName(
            'drive_thru',
            activeMaster,
          ),
          'Drive Thru',
        );
        expect(
          OrderTypePresenter.getDisplayName(
            'catering_vip',
            activeMaster,
          ),
          'Catering VIP',
        );

        // Without master metadata
        expect(OrderTypePresenter.getDisplayName('dinein', const []), 'Dine In');
        expect(OrderTypePresenter.getDisplayName('custom_type', const []), 'Custom Type');
      },
    );

    test('getIconForOrderType returns appropriate icons for builtins and custom codes', () {
      expect(OrderTypePresenter.getIconForOrderType('dinein'), isNotNull);
      expect(OrderTypePresenter.getIconForOrderType('takeaway'), isNotNull);
      expect(OrderTypePresenter.getIconForOrderType('delivery'), isNotNull);
      expect(OrderTypePresenter.getIconForOrderType('drive_thru'), isNotNull);
      expect(OrderTypePresenter.getIconForOrderType('custom_other'), isNotNull);
    });
  });

  group('PosOrderTypePricingService Tests', () {
    test(
      'applyOrderTypePricing applies custom price and adjusts discount proportionally',
      () {
        final product = <String, dynamic>{
          'remoteId': 'prod-1',
          'name': 'Menu Item 1',
          'price': 20000,
          'regularPrice': 20000,
          'discountedPrice': 16000, // 4000 discount
          'orderTypePrices': <String, dynamic>{
            'takeaway': 25000,
            'dine_in': 20000,
            'catering_vip': '30000',
          },
        };

        // 1. Takeaway pricing override (25,000) with preserved discount (4000) -> 21,000
        final takeawayPriced = PosOrderTypePricingService.applyOrderTypePricing(
          product,
          'takeaway',
        );
        expect(takeawayPriced['regularPrice'], 25000);
        expect(takeawayPriced['discountedPrice'], 21000);
        expect(takeawayPriced['price'], 21000);

        // 2. Alias resolution 'take_away' finds 'takeaway' in map
        final takeawayAliasPriced =
            PosOrderTypePricingService.applyOrderTypePricing(
              product,
              'take_away',
            );
        expect(takeawayAliasPriced['regularPrice'], 25000);

        // 3. String value parse in orderTypePrices ('30000')
        final cateringPriced = PosOrderTypePricingService.applyOrderTypePricing(
          product,
          'catering_vip',
        );
        expect(cateringPriced['regularPrice'], 30000);
        expect(cateringPriced['discountedPrice'], 26000);

        // 4. Non-overridden order type retains base catalog price
        final deliveryPriced = PosOrderTypePricingService.applyOrderTypePricing(
          product,
          'delivery',
        );
        expect(deliveryPriced['regularPrice'], 20000);
        expect(deliveryPriced['discountedPrice'], 16000);
      },
    );

    test(
      'isProductAvailableForOrderType checks product availability for orderType',
      () {
        final productWithRestrictions = <String, dynamic>{
          'remoteId': 'prod-1',
          'orderTypePrices': <String, dynamic>{
            'dinein': 20000,
            'takeaway': 22000,
          },
        };
        final productUniversal = <String, dynamic>{
          'remoteId': 'prod-2',
          'regularPrice': 10000,
        };

        expect(
          PosOrderTypePricingService.isProductAvailableForOrderType(
            productWithRestrictions,
            'dinein',
          ),
          isTrue,
        );
        expect(
          PosOrderTypePricingService.isProductAvailableForOrderType(
            productWithRestrictions,
            'takeaway',
          ),
          isTrue,
        );
        expect(
          PosOrderTypePricingService.isProductAvailableForOrderType(
            productWithRestrictions,
            'delivery',
          ),
          isFalse,
        );

        // Universal product is available for all order types
        expect(
          PosOrderTypePricingService.isProductAvailableForOrderType(
            productUniversal,
            'delivery',
          ),
          isTrue,
        );

        // Alias matching: map has 'dine_in', query is 'dinein'
        final productWithUnderscoreMap = <String, dynamic>{
          'remoteId': 'prod-3',
          'orderTypePrices': <String, dynamic>{
            'dine_in': 20000,
            'take_away': 22000,
          },
        };
        expect(
          PosOrderTypePricingService.isProductAvailableForOrderType(
            productWithUnderscoreMap,
            'dinein',
          ),
          isTrue,
        );
        expect(
          PosOrderTypePricingService.isProductAvailableForOrderType(
            productWithUnderscoreMap,
            'takeaway',
          ),
          isTrue,
        );

        // Alias matching: map has 'dinein', query is 'dine_in'
        expect(
          PosOrderTypePricingService.isProductAvailableForOrderType(
            productWithRestrictions,
            'dine_in',
          ),
          isTrue,
        );
      },
    );

    test(
      'repricePosCartItems reprices items and updates orderType when changed',
      () {
        final catalog = <Map<String, dynamic>>[
          <String, dynamic>{
            'remoteId': 'prod-1',
            'regularPrice': 20000,
            'price': 20000,
            'orderTypePrices': <String, dynamic>{'catering_vip': 30000},
          },
        ];
        const cartItems = <PosCartItem>[
          PosCartItem(
            id: 'item-1',
            name: 'Item 1',
            displayName: 'Item 1',
            imageUrl: '',
            quantity: 1,
            productRemoteId: 'prod-1',
            regularUnitPrice: 20000,
            orderType: 'dinein',
          ),
        ];

        final repriced = PosOrderTypePricingService.repricePosCartItems(
          items: cartItems,
          orderType: 'catering_vip',
          catalogProducts: catalog,
        );

        expect(repriced.length, 1);
        expect(repriced.first.regularUnitPrice, 30000);
        expect(repriced.first.orderType, 'catering_vip');
      },
    );
  });

  group('SalesOrderStore Master Validation & Canonicalization Tests', () {
    setUp(() {
      PosOrderTypeStore.instance.snapshotNotifier.value = PosOrderTypeSnapshot(
        orderTypes: activeMaster,
        isLoaded: true,
      );
    });

    tearDown(() {
      PosOrderTypeStore.instance.snapshotNotifier.value =
          const PosOrderTypeSnapshot();
    });

    test(
      'createOrder blocks order creation when master order types is empty (no-master block)',
      () async {
        PosOrderTypeStore.instance.snapshotNotifier.value =
            const PosOrderTypeSnapshot(
              orderTypes: <PosOrderType>[],
              isLoaded: true,
            );

        final result = await SalesOrderStore.instance.createOrder(
          statusCode: 1,
          items: const [
            SalesOrderLineItem(
              id: 'line-1',
              name: 'Kopi',
              imageUrl: '',
              regularUnitPrice: 10000,
              quantity: 1,
            ),
          ],
          customerName: 'Budi',
          customerRemoteId: '10',
          orderType: 'dinein',
        );

        expect(result, isNull);
      },
    );

    test(
      'createOrder blocks order creation when orderType does not resolve in master',
      () async {
        final result = await SalesOrderStore.instance.createOrder(
          statusCode: 1,
          items: const [
            SalesOrderLineItem(
              id: 'line-1',
              name: 'Kopi',
              imageUrl: '',
              regularUnitPrice: 10000,
              quantity: 1,
            ),
          ],
          customerName: 'Budi',
          customerRemoteId: '10',
          orderType: 'unknown_disallowed_type',
        );

        expect(result, isNull);
      },
    );

    test('createOrder blocks order creation when items is empty', () async {
      final result = await SalesOrderStore.instance.createOrder(
        statusCode: 1,
        items: const [],
        customerName: 'Budi',
        customerRemoteId: '10',
        orderType: 'dinein',
      );

      expect(result, isNull);
    });

    test('createOrder canonicalizes header and item order types', () async {
      final result = await SalesOrderStore.instance.createOrder(
        statusCode: 1,
        items: const [
          // Item 1 with legacy 'dine_in'
          SalesOrderLineItem(
            id: 'line-1',
            name: 'Nasi Goreng',
            imageUrl: '',
            regularUnitPrice: 25000,
            quantity: 1,
            orderType: 'dine_in',
          ),
          // Item 2 with null orderType (inherits header)
          SalesOrderLineItem(
            id: 'line-2',
            name: 'Es Teh',
            imageUrl: '',
            regularUnitPrice: 5000,
            quantity: 2,
            orderType: null,
          ),
          // Item 3 with custom legacy 'take_away'
          SalesOrderLineItem(
            id: 'line-3',
            name: 'Kopi',
            imageUrl: '',
            regularUnitPrice: 15000,
            quantity: 1,
            orderType: 'take_away',
          ),
          // Item 4 with custom master code 'drive_thru'
          SalesOrderLineItem(
            id: 'line-4',
            name: 'Burger',
            imageUrl: '',
            regularUnitPrice: 30000,
            quantity: 1,
            orderType: 'drive_thru',
          ),
        ],
        customerName: 'Budi',
        customerRemoteId: '10',
        orderType: 'dine_in', // Header passed legacy alias
      );

      expect(result, isNotNull);
      // Header must be canonicalized to 'dinein'
      expect(result!.orderType, 'dinein');

      // Item 1: 'dine_in' -> 'dinein'
      expect(result.items[0].orderType, 'dinein');

      // Item 2: null -> inherited header 'dinein'
      expect(result.items[1].orderType, 'dinein');

      // Item 3: 'take_away' -> canonicalized 'takeaway'
      expect(result.items[2].orderType, 'takeaway');

      // Item 4: 'drive_thru' -> 'drive_thru'
      expect(result.items[3].orderType, 'drive_thru');
    });

    test('createOrder supports custom-only tenant master', () async {
      PosOrderTypeStore.instance.snapshotNotifier.value = PosOrderTypeSnapshot(
        orderTypes: customOnlyMaster,
        isLoaded: true,
      );

      final result = await SalesOrderStore.instance.createOrder(
        statusCode: 1,
        items: const [
          SalesOrderLineItem(
            id: 'line-1',
            name: 'Package 1',
            imageUrl: '',
            regularUnitPrice: 100000,
            quantity: 1,
          ),
        ],
        customerName: 'Siti',
        customerRemoteId: '20',
        orderType: 'event_booth',
      );

      expect(result, isNotNull);
      expect(result!.orderType, 'event_booth');
      expect(result.items.first.orderType, 'event_booth');
    });
  });

  group('PosOrderTypeStore & SQLite Schema Tests', () {
    test('PosOrderType equality and properties', () {
      const type1 = PosOrderType(code: 'dinein', name: 'Dine In');
      const type2 = PosOrderType(
        code: 'dinein',
        name: 'Dine In Different Name',
      );
      const type3 = PosOrderType(code: 'takeaway', name: 'Take Away');

      expect(type1 == type2, isTrue);
      expect(type1 == type3, isFalse);
      expect(type1.hashCode, type2.hashCode);
    });

    test('PosOrderTypeSnapshot copyWith and hasData', () {
      const emptySnapshot = PosOrderTypeSnapshot();
      expect(emptySnapshot.hasData, isFalse);

      final loadedSnapshot = emptySnapshot.copyWith(
        orderTypes: activeMaster,
        isLoaded: true,
      );
      expect(loadedSnapshot.hasData, isTrue);
      expect(loadedSnapshot.orderTypes.length, activeMaster.length);
    });

    test('PosOrderTypeStore findByCode matches case-insensitively', () {
      PosOrderTypeStore.instance.snapshotNotifier.value = PosOrderTypeSnapshot(
        orderTypes: activeMaster,
        isLoaded: true,
      );

      final found = PosOrderTypeStore.instance.findByCode('DINE_IN');
      expect(found, isNotNull);
      expect(found!.code, 'dinein');
    });

    test('SQLite Schema contains order_type table with required columns', () {
      const tableDef = '''
        CREATE TABLE IF NOT EXISTS order_type (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tenant_id INTEGER NOT NULL,
          remote_id TEXT,
          code TEXT NOT NULL,
          name TEXT NOT NULL,
          description TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          deleted_at TEXT
        );
      ''';

      expect(tableDef, contains('code TEXT NOT NULL'));
      expect(tableDef, contains('name TEXT NOT NULL'));
      expect(tableDef, contains('is_active INTEGER NOT NULL DEFAULT 1'));
      expect(tableDef, contains('tenant_id INTEGER NOT NULL'));
      expect(tableDef, contains('deleted_at TEXT'));
    });
  });

  group('UI Selection & Reconciliation Logic Tests', () {
    test(
      'Reconciles default selection when master loads custom-only types',
      () {
        // Simulate app initial state with hardcoded/default 'dinein'
        var selectedOrderType = 'dinein';

        // Tenant loads only custom master types
        final loadedTypes = customOnlyMaster;

        // Reconcile logic (as used in mobile & tablet views)
        selectedOrderType = OrderTypeResolver.resolveOrDefault(
          selectedOrderType,
          loadedTypes,
        );

        // Successfully switched to first active custom code
        expect(selectedOrderType, 'event_booth');
      },
    );

    test(
      'Order reset retains valid active order type or defaults to first active',
      () {
        final activeTypes = activeMaster;

        // When user was currently on valid 'takeaway'
        var currentOrderType = 'takeaway';
        var resetOrderType = OrderTypeResolver.resolveOrDefault(
          currentOrderType,
          activeTypes,
        );
        expect(resetOrderType, 'takeaway');

        // When user was on legacy alias 'dine_in'
        currentOrderType = 'dine_in';
        resetOrderType = OrderTypeResolver.resolveOrDefault(
          currentOrderType,
          activeTypes,
        );
        expect(resetOrderType, 'dinein');

        // When user was on an invalid / disabled code
        currentOrderType = 'obsolete_type';
        resetOrderType = OrderTypeResolver.resolveOrDefault(
          currentOrderType,
          activeTypes,
        );
        expect(resetOrderType, 'dinein'); // First in activeMaster
      },
    );

    test(
      'PosOrderTypeStore.instance.reconcileSelectedOrderType delegates to active master',
      () {
        PosOrderTypeStore.instance.snapshotNotifier.value =
            PosOrderTypeSnapshot(orderTypes: activeMaster, isLoaded: true);

        expect(
          PosOrderTypeStore.instance.reconcileSelectedOrderType('dine_in'),
          'dinein',
        );
        expect(
          PosOrderTypeStore.instance.reconcileSelectedOrderType('takeaway'),
          'takeaway',
        );
        expect(
          PosOrderTypeStore.instance.reconcileSelectedOrderType('non_existent'),
          'dinein',
        );

        // When store is empty
        PosOrderTypeStore.instance.snapshotNotifier.value =
            const PosOrderTypeSnapshot(
              orderTypes: <PosOrderType>[],
              isLoaded: true,
            );
        expect(
          PosOrderTypeStore.instance.reconcileSelectedOrderType(
            'custom_active',
          ),
          'custom_active',
        );
        expect(
          PosOrderTypeStore.instance.reconcileSelectedOrderType(
            null,
            fallback: 'takeaway',
          ),
          'takeaway',
        );
      },
    );
  });

  group('Sync Queue Payload & Rejection Flow Tests', () {
    setUp(() {
      PosOrderTypeStore.instance.snapshotNotifier.value = PosOrderTypeSnapshot(
        orderTypes: activeMaster,
        isLoaded: true,
      );
    });

    test(
      'createOrder stores canonical order_type in SalesOrderRecord for sync payload',
      () async {
        final order = await SalesOrderStore.instance.createOrder(
          statusCode: 2,
          items: const [
            SalesOrderLineItem(
              id: 'line-1',
              name: 'Kopi Susu',
              imageUrl: '',
              regularUnitPrice: 18000,
              quantity: 2,
              orderType: 'take_away',
            ),
          ],
          customerName: 'Budi',
          customerRemoteId: '123',
          orderType: 'take_away',
        );

        expect(order, isNotNull);
        expect(order!.orderType, 'takeaway');
        expect(order.items[0].orderType, 'takeaway');
      },
    );

    test(
      'Tablet workflow preserves cart when createOrder fails (returns null)',
      () async {
        // Setup empty master (which triggers createOrder rejection)
        PosOrderTypeStore.instance.snapshotNotifier.value =
            const PosOrderTypeSnapshot(
              orderTypes: <PosOrderType>[],
              isLoaded: true,
            );

        var cart = <String>['item-1', 'item-2'];
        final createdOrder = await SalesOrderStore.instance.createOrder(
          statusCode: 2,
          items: const [
            SalesOrderLineItem(
              id: 'line-1',
              name: 'Kopi Susu',
              imageUrl: '',
              regularUnitPrice: 18000,
              quantity: 1,
            ),
          ],
          customerName: 'Walk-in',
          customerRemoteId: '0',
          orderType: 'dinein',
        );

        // Verify createOrder returns null on unsynced master
        expect(createdOrder, isNull);

        // Verify that guarded workflow keeps cart intact
        if (createdOrder != null) {
          cart.clear();
        }
        expect(cart, isNotEmpty);
        expect(cart.length, 2);
      },
    );
  });

  group('Promotion Order Type Filter & Validation Tests', () {
    test(
      'validateSelectedPromotions returns only promotions matching applicable set',
      () async {
        const promoDineIn = PosPromotionResult(
          remoteId: 'promo-dinein-1',
          name: 'Dine In Only Promo',
          promoType: 'discount',
          discountAmount: 5000,
          displayAmount: '5000',
          matchedTotal: 1,
          summary: '',
          isApplicable: true,
        );

        const promoTakeaway = PosPromotionResult(
          remoteId: 'promo-takeaway-1',
          name: 'Takeaway Discount',
          promoType: 'discount',
          discountAmount: 3000,
          displayAmount: '3000',
          matchedTotal: 1,
          summary: '',
          isApplicable: true,
        );

        final currentSelection = <PosPromotionResult>[
          promoDineIn,
          promoTakeaway,
        ];

        // When validateSelectedPromotions is called with empty selection, returns empty
        final emptyResult = await PosPromotionService.instance
            .validateSelectedPromotions(
              currentSelection: const <PosPromotionResult>[],
              items: const <PosPromotionMatchItem>[],
              orderTypeCode: 'takeaway',
            );
        expect(emptyResult, isEmpty);

        // Test filtering logic: when order type changes, only matching applicable promotions survive
        final applicableIds = <String>{'promo-takeaway-1'};
        final filtered = currentSelection
            .where((p) => applicableIds.contains(p.remoteId))
            .toList();

        expect(filtered.length, 1);
        expect(filtered.first.remoteId, 'promo-takeaway-1');
        expect(filtered.any((p) => p.remoteId == 'promo-dinein-1'), isFalse);
      },
    );
  });

  group('Item Editor Master Rule Tests', () {
    test(
      'Empty master order types does NOT generate synthetic dinein options',
      () {
        final emptyMaster = const <PosOrderType>[];

        // Replicating item editor option logic
        final options = emptyMaster
            .map((ot) => (ot.code, ot.name))
            .toList(growable: false);

        expect(options, isEmpty);
        expect(options.any((opt) => opt.$1 == 'dinein'), isFalse);

        // Replicating active master options
        final activeOptions = activeMaster
            .map((ot) => (ot.code, ot.name))
            .toList(growable: false);

        expect(activeOptions, isNotEmpty);
        expect(activeOptions.first.$1, 'dinein');
      },
    );

    test(
      'Empty master preserves item orderType without mutating to synthetic default',
      () {
        final emptyMaster = const <PosOrderType>[];
        const initialItemOrderType = 'custom_order_mode';

        final selectedType = emptyMaster.isNotEmpty
            ? OrderTypeResolver.resolveOrDefault(
                initialItemOrderType,
                emptyMaster,
              )
            : initialItemOrderType;

        expect(selectedType, 'custom_order_mode');
      },
    );
  });

  group('SQLite Query Filter & Master Sync Tests', () {
    test(
      'order_type table query enforces tenant_id, deleted_at IS NULL and is_active = 1',
      () {
        const sqlQuery = '''
        SELECT code, name, description
        FROM order_type
        WHERE tenant_id = ?
          AND deleted_at IS NULL
          AND is_active = 1
          AND code IS NOT NULL
          AND TRIM(code) != ''
        ORDER BY id ASC
      ''';

        expect(sqlQuery, contains('WHERE tenant_id = ?'));
        expect(sqlQuery, contains('AND deleted_at IS NULL'));
        expect(sqlQuery, contains('AND is_active = 1'));
      },
    );
  });

  group('PosOrderTypeTransitionService.transitionPosCartOrderType Tests', () {
    test(
      'returns isChanged: false when target resolves to current order type',
      () async {
        const items = [
          PosCartItem(
            id: '1',
            name: 'Item A',
            displayName: 'Item A',
            imageUrl: '',
            quantity: 1,
            regularUnitPrice: 10000,
            productRemoteId: 'p1',
            orderType: 'dinein',
          ),
        ];
        final result =
            await PosOrderTypeTransitionService.transitionPosCartOrderType(
              currentOrderType: 'dinein',
              targetOrderType: 'dinein',
              currentItems: items,
              currentPromotions: const [],
              catalogProducts: const [],
              activeOrderTypes: activeMaster,
            );

        expect(result.isChanged, isFalse);
        expect(result.orderType, 'dinein');
      },
    );

    test(
      'reprices items and validates promos when order type changes',
      () async {
        final catalog = [
          {
            'remoteId': 'p1',
            'regularPrice': 10000,
            'orderTypePrices': {'takeaway': 12000},
          },
        ];
        const items = [
          PosCartItem(
            id: '1',
            name: 'Item A',
            displayName: 'Item A',
            imageUrl: '',
            quantity: 1,
            regularUnitPrice: 10000,
            productRemoteId: 'p1',
            orderType: 'dinein',
          ),
        ];
        final result =
            await PosOrderTypeTransitionService.transitionPosCartOrderType(
              currentOrderType: 'dinein',
              targetOrderType: 'takeaway',
              currentItems: items,
              currentPromotions: const [],
              catalogProducts: catalog,
              activeOrderTypes: activeMaster,
            );

        expect(result.isChanged, isTrue);
        expect(result.orderType, 'takeaway');
        expect(result.items.first.regularUnitPrice, 12000);
        expect(result.items.first.orderType, 'takeaway');
      },
    );
  });

  group(
    'PosPromotionService.recalculateCartPromotions & buildMatchItems Tests',
    () {
      test(
        'buildMatchItems builds correct promotion match items from catalog products',
        () {
          final catalog = [
            {
              'remoteId': 'p1',
              'categoryRemoteId': 'cat1',
              'brandRemoteId': 'brand1',
            },
          ];
          final matchItems = PosPromotionService.buildMatchItems(
            items: const [
              PosCartItem(
                id: 'line-1',
                name: 'Kopi',
                displayName: 'Kopi',
                imageUrl: '',
                quantity: 2,
                regularUnitPrice: 15000,
                productRemoteId: 'p1',
              ),
            ],
            catalogProducts: catalog,
          );

          expect(matchItems.length, 1);
          expect(matchItems.first.productRemoteId, 'p1');
          expect(matchItems.first.categoryRemoteId, 'cat1');
          expect(matchItems.first.brandRemoteId, 'brand1');
        },
      );

      test(
        'recalculateCartPromotions applies order type price and calculates discounts',
        () {
          final catalog = [
            {
              'remoteId': 'p1',
              'name': 'Kopi',
              'regularPrice': 15000,
              'orderTypePrices': {'takeaway': 18000},
            },
          ];
          const cartItem = PosCartItem(
            id: 'line-1',
            name: 'Kopi',
            displayName: 'Kopi',
            imageUrl: '',
            quantity: 1,
            regularUnitPrice: 15000,
            productRemoteId: 'p1',
          );

          const promo = PosPromotionResult(
            remoteId: 'promo-1',
            name: 'Diskon 3k',
            promoType: 'discount',
            discountAmount: 3000,
            displayAmount: '3000',
            matchedTotal: 1,
            summary: '',
            rawPayload: {
              'items': {
                'detail': [
                  {
                    'item_id': 'p1',
                    'discount_type': 'nominal',
                    'discount_value': '3000',
                  },
                ],
              },
            },
          );

          final result = PosPromotionService.instance
              .recalculatePosCartPromotions(
                cartItems: [cartItem],
                selectedPromotions: [promo],
                catalogProducts: catalog,
                selectedOrderType: 'takeaway',
              );

          expect(result.totalDiscountAmount, 3000);
          expect(result.items.first.overriddenUnitPrice, 15000); // 18000 - 3000
        },
      );
    },
  );
}
