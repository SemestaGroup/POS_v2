import 'package:flinkpos_v2/core/services/sync/pos_v2_runtime_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _baseSession = PosV2RuntimeSession(
  tenantId: 1,
  tenantKey: 'tenant-key',
  baseUrl: 'https://tenant.example',
  authToken: 'session-token',
  locationId: 'LOC01',
  staffId: '42',
  staffEmail: 'cashier@example.com',
  deviceId: 'device-1',
);

void main() {
  final store = PosV2RuntimeSessionStore.instance;

  setUp(() => store.setSession(null));
  tearDown(() => store.setSession(null));

  test('maps a runtime session to the sync context exactly', () {
    final context = _baseSession.toSyncContext();

    expect(context.baseUrl, 'https://tenant.example');
    expect(context.authToken, 'session-token');
    expect(context.locationId, 'LOC01');
    expect(context.staffId, '42');
  });

  test('notifies when the first bootstrap completion changes gate state', () {
    var notifications = 0;
    void listener() => notifications++;
    store.sessionNotifier.addListener(listener);
    addTearDown(() => store.sessionNotifier.removeListener(listener));

    store.setSession(_baseSession);
    store.setSession(
      _baseSession.copyWith(lastBootstrapAt: '2026-08-13T10:00:00Z'),
    );

    expect(notifications, 2);
    expect(store.currentSession!.lastBootstrapAt, '2026-08-13T10:00:00Z');
  });

  test(
    'silently refreshes later bootstrap timestamps without UI notification',
    () {
      store.setSession(
        _baseSession.copyWith(lastBootstrapAt: '2026-08-13T10:00:00Z'),
      );
      var notifications = 0;
      void listener() => notifications++;
      store.sessionNotifier.addListener(listener);
      addTearDown(() => store.sessionNotifier.removeListener(listener));

      store.setSession(
        _baseSession.copyWith(lastBootstrapAt: '2026-08-13T10:05:00Z'),
      );

      expect(notifications, 0);
      expect(store.currentSession!.lastBootstrapAt, '2026-08-13T10:05:00Z');
    },
  );

  test(
    'notifies when a different session identity replaces the current session',
    () {
      store.setSession(_baseSession);
      var notifications = 0;
      void listener() => notifications++;
      store.sessionNotifier.addListener(listener);
      addTearDown(() => store.sessionNotifier.removeListener(listener));

      store.setSession(_baseSession.copyWith(deviceId: 'device-2'));

      expect(notifications, 1);
      expect(store.currentSession!.deviceId, 'device-2');
    },
  );
}
