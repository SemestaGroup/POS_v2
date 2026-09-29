import 'dart:convert';

import 'package:flinkpos_v2/core/services/local/database_service.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_runtime_session_store.dart';
import 'package:flinkpos_v2/modules/reports/stores/report_read_stores.dart';
import 'package:flinkpos_v2/modules/sales/shared/models/sales_order_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/db_reset.dart';

const _session = PosV2RuntimeSession(
  tenantId: 1,
  tenantKey: 'tenant-a',
  baseUrl: 'https://a.example.com',
  authToken: 'token',
  locationId: 'LOC-1',
);

String _serverPayload(List<Map<String, Object?>> promotions) =>
    jsonEncode(<String, Object?>{'id': 1, 'promotions': promotions});

String _customFields({
  required String ids,
  required String names,
  String types = '',
  String amounts = '',
}) => jsonEncode(<String, Object?>{
  'order_promotion': <String, Object?>{
    'remote_id': ids,
    'name': names,
    'promo_type': types,
    'discount_amounts': amounts,
  },
});

Map<String, Object?> _row(
  int id, {
  String? raw,
  String? custom,
  int total = 10000,
}) => <String, Object?>{
  'id': id,
  'label': 'INV-$id',
  'ordered_at': '2026-09-20T10:00:00',
  'subtotal_amount': total + 2000,
  'total_amount': total,
  'raw_payload_json': raw,
  'custom_fields_json': custom,
};

Future<void> _insertOrder(
  Database db, {
  required String idPos,
  int? customerId,
  String? customerRemoteId,
  int total = 10000,
  String status = '2',
  String? raw,
  String? custom,
}) async {
  final now = DateTime.now().toIso8601String();
  await db.insert('pos_order', {
    'tenant_id': 1,
    'id_pos': idPos,
    'customer_id': customerId,
    'customer_remote_id': customerRemoteId,
    'status_code': status,
    'subtotal_amount': total + 2000,
    'total_amount': total,
    'order_date': now,
    'created_at': now,
    'raw_payload_json': raw,
    'custom_fields_json': custom,
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PromoSalesReportStore.buildPromoRecords', () {
    test('uses the server promotions list and groups by promotion id', () {
      final records = PromoSalesReportStore.buildPromoRecords([
        _row(
          1,
          raw: _serverPayload([
            {
              'promotion_id': 7,
              'promo_name_snapshot': 'Diskon Kemerdekaan',
              'promo_type_snapshot': 'discount',
              'discount_amount': '2000.00',
            },
          ]),
        ),
        _row(
          2,
          total: 20000,
          raw: _serverPayload([
            {
              'promotion_id': 7,
              'promo_name_snapshot': 'Diskon Kemerdekaan',
              'promo_type_snapshot': 'discount',
              'discount_amount': '3000.00',
            },
          ]),
        ),
      ]);

      expect(records, hasLength(1));
      final promo = records.single;
      expect(promo.name, 'Diskon Kemerdekaan');
      expect(promo.orderCount, 2);
      expect(promo.totalDiscount, 5000);
      expect(promo.netSales, 30000);
    });

    test('falls back to the local order_promotion field', () {
      final records = PromoSalesReportStore.buildPromoRecords([
        _row(
          1,
          custom: _customFields(
            ids: '9',
            names: 'Buy 1, Get 1',
            types: 'bogo',
            amounts: '4500',
          ),
        ),
      ]);

      // A single promo keeps its whole name even though it contains a comma.
      expect(records.single.name, 'Buy 1, Get 1');
      expect(records.single.type, 'bogo');
      expect(records.single.totalDiscount, 4500);
    });

    test('splits several local promos only when the counts line up', () {
      final aligned = PromoSalesReportStore.buildPromoRecords([
        _row(
          1,
          custom: _customFields(
            ids: '1,2',
            names: 'Promo A,Promo B',
            amounts: '1000,2000',
          ),
        ),
      ]);
      expect(aligned.map((r) => r.name), ['Promo B', 'Promo A']);
      expect(aligned.first.totalDiscount, 2000);

      final ambiguous = PromoSalesReportStore.buildPromoRecords([
        _row(
          1,
          custom: _customFields(
            ids: '1,2',
            names: 'Hemat, Banget,Promo B',
            amounts: '1000,2000',
          ),
        ),
      ]);
      expect(ambiguous.map((r) => r.name).toSet(), {'Promo #1', 'Promo #2'});
    });

    test('server data wins over the local field, but empty falls through', () {
      final serverWins = PromoSalesReportStore.buildPromoRecords([
        _row(
          1,
          raw: _serverPayload([
            {
              'promotion_id': 5,
              'promo_name_snapshot': 'Dari Server',
              'discount_amount': '1000',
            },
          ]),
          custom: _customFields(ids: '9', names: 'Lokal', amounts: '999'),
        ),
      ]);
      expect(serverWins.single.name, 'Dari Server');

      final emptyServer = PromoSalesReportStore.buildPromoRecords([
        _row(
          1,
          raw: _serverPayload([]),
          custom: _customFields(ids: '9', names: 'Lokal', amounts: '999'),
        ),
      ]);
      expect(emptyServer.single.name, 'Lokal');
    });

    test('ignores corrupt json instead of throwing', () {
      final records = PromoSalesReportStore.buildPromoRecords([
        _row(1, raw: '{not json', custom: 'also broken'),
      ]);
      expect(records, isEmpty);
    });
  });

  group('report stores against SQLite', () {
    late Database db;

    setUp(() async {
      await resetDatabaseFile();
      db = await DatabaseService.instance.database;
      await db.insert('app_tenant', {
        'id': 1,
        'tenant_key': 'tenant-a',
        'base_url': 'https://a.example.com',
        'location_id': 'LOC-1',
      });
      await db.insert('customer', {
        'id': 10,
        'tenant_id': 1,
        'remote_id': '55',
        'display_name': 'Budi',
        'phone_number': '0811',
      });
      await db.insert('customer', {
        'id': 11,
        'tenant_id': 1,
        'remote_id': '56',
        'display_name': 'Sari',
        'phone_number': '0822',
      });
      PosV2RuntimeSessionStore.instance.setSession(_session);
    });

    tearDown(() async {
      PosV2RuntimeSessionStore.instance.setSession(null);
      await DatabaseService.instance.close();
    });

    test('top customers rank by spend and pool walk-in orders', () async {
      await _insertOrder(
        db,
        idPos: 'A1',
        customerId: 10,
        customerRemoteId: '55',
        total: 30000,
      );
      await _insertOrder(
        db,
        idPos: 'A2',
        customerId: 10,
        customerRemoteId: '55',
        total: 20000,
      );
      await _insertOrder(
        db,
        idPos: 'B1',
        customerId: 11,
        customerRemoteId: '56',
        total: 15000,
      );
      // Walk-in as remote id 1 and as no customer at all land in one bucket.
      await _insertOrder(db, idPos: 'W1', customerRemoteId: '1', total: 8000);
      await _insertOrder(db, idPos: 'W2', total: 7000);
      // Unpaid orders never count.
      await _insertOrder(
        db,
        idPos: 'X1',
        customerId: 11,
        customerRemoteId: '56',
        total: 99999,
        status: '1',
      );

      await TopCustomersReportStore.instance.refresh(period: 'month');
      final snapshot = TopCustomersReportStore.instance.snapshotNotifier.value;

      expect(snapshot.errorMessage, isNull);
      final byKey = {for (final c in snapshot.customers) c.key: c};
      expect(snapshot.customers.first.name, 'Budi');
      expect(byKey['55']!.visitCount, 2);
      expect(byKey['55']!.totalSpent, 50000);
      expect(byKey['55']!.averageSpent, 25000);
      expect(byKey['56']!.totalSpent, 15000);
      final walkIn = byKey[TopCustomersReportStore.walkInKey]!;
      expect(walkIn.isWalkIn, isTrue);
      expect(walkIn.visitCount, 2);
      expect(walkIn.totalSpent, 15000);
      expect(snapshot.customers, hasLength(3));
    });

    test('promo report counts an order once in the totals', () async {
      await _insertOrder(
        db,
        idPos: 'P1',
        total: 40000,
        raw: _serverPayload([
          {
            'promotion_id': 1,
            'promo_name_snapshot': 'Promo A',
            'discount_amount': '1000',
          },
          {
            'promotion_id': 2,
            'promo_name_snapshot': 'Promo B',
            'discount_amount': '2000',
          },
        ]),
      );
      await _insertOrder(
        db,
        idPos: 'P2',
        total: 10000,
        custom: _customFields(ids: '1', names: 'Promo A', amounts: '500'),
      );
      await _insertOrder(db, idPos: 'NOPROMO', total: 77777);
      await _insertOrder(
        db,
        idPos: 'UNPAID',
        status: '1',
        raw: _serverPayload([
          {'promotion_id': 1, 'discount_amount': '1'},
        ]),
      );

      await PromoSalesReportStore.instance.refresh(period: 'month');
      final snapshot = PromoSalesReportStore.instance.snapshotNotifier.value;

      expect(snapshot.errorMessage, isNull);
      expect(snapshot.promos.map((p) => p.name), ['Promo B', 'Promo A']);
      // P1 carries two promos but is one transaction and one sale.
      expect(snapshot.promoOrderCount, 2);
      expect(snapshot.promoNetSales, 50000);
      expect(snapshot.totalDiscount, 3500);
      final promoA = snapshot.promos.firstWhere((p) => p.name == 'Promo A');
      expect(promoA.orderCount, 2);
    });
  });

  group('order payload promotions', () {
    SalesOrderRecord record({
      String? ids,
      String? name,
      String? type,
      String? amounts,
    }) => SalesOrderRecord(
      id: 'ID-1',
      token: 'T',
      createdAt: DateTime(2026, 9, 20),
      statusCode: 1,
      customerName: 'Budi',
      customerRemoteId: '55',
      orderType: 'dinein',
      items: const [],
      appliedPromotionRemoteId: ids,
      appliedPromotionName: name,
      appliedPromotionType: type,
      appliedPromotionDiscountAmounts: amounts,
    );

    test('no promo sends an empty list so removed promos are cleared', () {
      expect(
        SalesOrderStore.instance.buildPromotionsPayload(record()),
        isEmpty,
      );
    });

    test('a single promo carries its name and type', () {
      final payload = SalesOrderStore.instance.buildPromotionsPayload(
        record(
          ids: '12',
          name: 'Hemat, Banget',
          type: 'discount',
          amounts: '5000',
        ),
      );
      expect(payload, [
        {
          'promotion_id': 12,
          'discount_amount': 5000,
          'promo_name': 'Hemat, Banget',
          'promo_type': 'discount',
        },
      ]);
    });

    test('several promos send ids and amounts only', () {
      final payload = SalesOrderStore.instance.buildPromotionsPayload(
        record(ids: '1,2', name: 'A,B', type: 'x,y', amounts: '100,200'),
      );
      expect(payload, [
        {'promotion_id': 1, 'discount_amount': 100},
        {'promotion_id': 2, 'discount_amount': 200},
      ]);
    });

    test('non numeric ids are skipped', () {
      final payload = SalesOrderStore.instance.buildPromotionsPayload(
        record(ids: 'abc,3', amounts: '1,2'),
      );
      expect(payload, [
        {'promotion_id': 3, 'discount_amount': 2},
      ]);
    });
  });
}
