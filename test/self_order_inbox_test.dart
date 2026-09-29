
import 'package:flinkpos_v2/core/services/local/database_service.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_runtime_session_store.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_service_table_service.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_sync_orchestrator.dart';
import 'package:flinkpos_v2/core/services/sync/v2_sync_context.dart';
import 'package:flinkpos_v2/core/services/sync/v2_sync_result.dart';
import 'package:flinkpos_v2/modules/sales/self_order/self_order_inbox_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/db_reset.dart';

const _session = PosV2RuntimeSession(
  tenantId: 1,
  tenantKey: 'tenant-a',
  baseUrl: 'https://a.example.com',
  authToken: 'token',
  locationId: '1078',
  staffId: '7',
);

/// Stands in for the server: [onSessions] and [onDetail] write to SQLite what
/// a real sync would have stored.
class _FakeOrchestrator extends PosV2SyncOrchestrator {
  _FakeOrchestrator({required this.onSessions, required this.onDetail});

  final Future<int> Function() onSessions;
  final Future<void> Function(String orderId) onDetail;
  final List<String> detailRequests = [];

  @override
  Future<V2SyncResult> syncSelfOrderSessions(
    V2SyncContext context, {
    Map<String, dynamic>? query,
  }) async {
    final fetched = await onSessions();
    return V2SyncResult(
      endpointName: 'pos-self-order-sessions',
      fetchedCount: fetched,
    );
  }

  @override
  Future<V2SyncResult> syncOrderDetail(
    V2SyncContext context,
    String orderId,
  ) async {
    detailRequests.add(orderId);
    await onDetail(orderId);
    return const V2SyncResult(endpointName: 'pos-order-detail');
  }
}

String _today() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}';
}

void main() {
  late Database db;
  late _FakeOrchestrator fake;
  late SelfOrderInboxService inbox;

  // What the "server" currently holds.
  var activity = '2026-09-29 10:00:00';
  var businessDate = _today();
  var sessionOpen = true;
  var items = <(String, int)>[];
  var orderNote = '';

  Future<void> writeSession() async {
    await db.delete('self_order_session');
    if (!sessionOpen) return;
    await db.insert('self_order_session', {
      'tenant_id': 1,
      'remote_id': '50',
      'session_code': 'SOS-1',
      'table_code': 'a1',
      'status': 'submitted',
      'business_date': businessDate,
      'last_activity_at': activity,
      'current_order_remote_id': '900',
    });
  }

  Future<void> writeOrder() async {
    await db.delete('pos_order_item');
    await db.delete('pos_order');
    final orderId = await db.insert('pos_order', {
      'tenant_id': 1,
      'remote_id': '900',
      'id_pos': 'uuid-900',
      'status_code': '1',
      'total_amount': items.fold<int>(0, (s, i) => s + i.$2 * 10000),
      'order_note': orderNote,
    });
    var order = 0;
    for (final (name, qty) in items) {
      await db.insert('pos_order_item', {
        'tenant_id': 1,
        'order_id': orderId,
        'product_name_snapshot': name,
        'qty': qty,
        'sort_order': order++,
      });
    }
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await resetDatabaseFile();
    db = await DatabaseService.instance.database;
    await db.insert('app_tenant', {
      'id': 1,
      'tenant_key': 'tenant-a',
      'base_url': 'https://a.example.com',
      'location_id': '1078',
    });
    PosV2RuntimeSessionStore.instance.setSession(_session);

    activity = '2026-09-29 10:00:00';
    businessDate = _today();
    sessionOpen = true;
    items = [('Es Krim Vanila', 2)];
    orderNote = '';

    fake = _FakeOrchestrator(
      onSessions: () async {
        await writeSession();
        return sessionOpen ? 1 : 0;
      },
      onDetail: (_) => writeOrder(),
    );
    inbox = SelfOrderInboxService.forTesting(
      orchestrator: fake,
      databaseService: DatabaseService.instance,
    );
    // A previous poll on this device, so nothing below counts as a baseline.
    await db.insert('sync_checkpoint', {
      'tenant_id': 1,
      'endpoint_name': 'self_order_inbox',
      'scope_key': 'baseline',
    });
  });

  tearDown(() async {
    await inbox.settle();
    PosV2RuntimeSessionStore.instance.setSession(null);
    await DatabaseService.instance.close();
  });

  test('a new customer order raises one alert with its lines', () async {
    orderNote = 'Tanpa sedotan';

    final raised = await inbox.pollOnce();

    expect(raised, hasLength(1));
    final alert = raised.single;
    expect(alert.tableCode, 'A1');
    expect(alert.title, 'Meja A1');
    expect(alert.isUpdate, isFalse);
    expect(alert.itemCount, 2);
    expect(alert.totalAmount, 20000);
    expect(alert.orderNote, 'Tanpa sedotan');
    expect(alert.newLines.single.name, 'Es Krim Vanila');
    expect(inbox.alerts.value, hasLength(1));
    expect(fake.detailRequests, ['900']);

    // No kitchen printer is configured here; the alert must say so instead of
    // failing.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(alert.kitchenStatus, 'Tidak ada printer dapur');
  });

  test('polling again without changes stays quiet', () async {
    await inbox.pollOnce();
    final second = await inbox.pollOnce();

    expect(second, isEmpty);
    expect(fake.detailRequests, hasLength(1));
  });

  test('items added later alert with only the new lines', () async {
    await inbox.pollOnce();

    activity = '2026-09-29 10:05:00';
    items = [('Es Krim Vanila', 3), ('Kopi Susu', 1)];
    final raised = await inbox.pollOnce();

    expect(raised, hasLength(1));
    final alert = raised.single;
    expect(alert.isUpdate, isTrue);
    expect(alert.lines.map((l) => '${l.quantity}x ${l.name}'), [
      '3x Es Krim Vanila',
      '1x Kopi Susu',
    ]);
    expect(alert.newLines.map((l) => '${l.quantity}x ${l.name}'), [
      '1x Es Krim Vanila',
      '1x Kopi Susu',
    ]);
  });

  test('a session change that adds no items raises nothing', () async {
    await inbox.pollOnce();

    activity = '2026-09-29 10:06:00';
    final raised = await inbox.pollOnce();

    expect(raised, isEmpty);
  });

  test(
    'the first poll on a device flags old orders instead of printing',
    () async {
      await db.delete('sync_checkpoint');

      final raised = await inbox.pollOnce();
      expect(raised, hasLength(1));
      expect(raised.single.kitchenStatus, contains('tidak dicetak otomatis'));

      // The marker is stored, so the next order is treated as live.
      final marker = await db.query(
        'sync_checkpoint',
        where: "endpoint_name = 'self_order_inbox'",
      );
      expect(marker, hasLength(1));
    },
  );

  test('sessions from days ago are ignored', () async {
    businessDate = '2020-01-01';

    final raised = await inbox.pollOnce();

    expect(raised, isEmpty);
    expect(fake.detailRequests, isEmpty);
  });

  test('nothing happens while signed out', () async {
    PosV2RuntimeSessionStore.instance.setSession(null);

    expect(await inbox.pollOnce(), isEmpty);
    expect(fake.detailRequests, isEmpty);
  });

  group('diffLines', () {
    SelfOrderLine line(String name, int qty) =>
        SelfOrderLine(name: name, quantity: qty);

    test('reports only quantities that grew', () {
      final added = SelfOrderInboxService.diffLines(
        [line('A', 1), line('B', 2)],
        [line('A', 1), line('B', 5), line('C', 1)],
      );
      expect(added.map((l) => '${l.quantity}x ${l.name}'), ['3x B', '1x C']);
    });

    test('splits a repeated name across lines without double counting', () {
      final added = SelfOrderInboxService.diffLines(
        [line('A', 2)],
        [line('A', 1), line('A', 3)],
      );
      expect(added.fold<int>(0, (s, l) => s + l.quantity), 2);
    });

    test('nothing new means an empty list', () {
      expect(
        SelfOrderInboxService.diffLines([line('A', 2)], [line('A', 2)]),
        isEmpty,
      );
    });
  });

  group('table QR address', () {
    test('uses https on the outlet domain with the table and token', () {
      expect(
        PosV2ServiceTableService.buildOrderUrl(
          baseUrl: 'http://aurynloud.flinkaja.com/',
          tableCode: 'A1',
          qrToken: 'TBL-ABC123',
        ),
        'https://aurynloud.flinkaja.com/order?table=A1&token=TBL-ABC123',
      );
    });

    test('encodes unusual table codes and keeps a custom port', () {
      expect(
        PosV2ServiceTableService.buildOrderUrl(
          baseUrl: 'http://localhost:8080/',
          tableCode: 'VIP 1',
          qrToken: 'TBL-X',
        ),
        'https://localhost:8080/order?table=VIP+1&token=TBL-X',
      );
    });

    test('rejects an address without a host', () {
      expect(
        () => PosV2ServiceTableService.buildOrderUrl(
          baseUrl: '',
          tableCode: 'A1',
          qrToken: 'T',
        ),
        throwsA(isA<ServiceTableException>()),
      );
    });
  });
}
