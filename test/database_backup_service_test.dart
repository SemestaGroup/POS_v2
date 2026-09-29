import 'dart:io';

import 'package:flinkpos_v2/core/services/local/database_backup_service.dart';
import 'package:flinkpos_v2/core/services/local/database_service.dart';
import 'package:flinkpos_v2/core/services/sync/pos_v2_runtime_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/db_reset.dart';

const _session = PosV2RuntimeSession(
  tenantId: 1,
  tenantKey: 'tenant-a',
  baseUrl: 'https://a.example.com',
  authToken: 'secret-token',
  locationId: 'LOC-1',
  tenantName: 'Outlet A',
);

Future<void> _insertOrder(Database db, String idPos) async {
  await db.insert('pos_order', {
    'tenant_id': 1,
    'id_pos': idPos,
    'created_at': '2026-09-01T10:00:00Z',
    'updated_at': '2026-09-01T10:00:00Z',
  });
}

Future<int> _orderCount(Database db) async =>
    Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM pos_order'),
    ) ??
    0;

void main() {
  late Directory workDir;
  late DatabaseBackupService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('backup_test_');
    service = DatabaseBackupService(
      temporaryDirectory: () async =>
          Directory('${workDir.path}/tmp')..createSync(recursive: true),
      documentsDirectory: () async =>
          Directory('${workDir.path}/docs')..createSync(recursive: true),
    );

    await resetDatabaseFile();

    final db = await DatabaseService.instance.database;
    await db.insert('app_tenant', {
      'id': 1,
      'tenant_key': 'tenant-a',
      'tenant_name': 'Outlet A',
      'base_url': 'https://a.example.com',
      'location_id': 'LOC-1',
    });
    await db.insert('app_session', {
      'tenant_id': 1,
      'status': 'active',
      'auth_token': 'secret-token',
      'refresh_token': 'refresh-token',
    });
    await _insertOrder(db, 'ORD-1');
    await _insertOrder(db, 'ORD-2');
    PosV2RuntimeSessionStore.instance.setSession(_session);
  });

  tearDown(() async {
    PosV2RuntimeSessionStore.instance.setSession(null);
    await DatabaseService.instance.close();
    await workDir.delete(recursive: true);
  });

  test('backup strips login tokens from the copy only', () async {
    final file = await service.createBackup();
    expect(await file.exists(), isTrue);

    final copy = await openDatabase(file.path, readOnly: true);
    final copied = await copy.query('app_session');
    await copy.close();
    expect(copied.single['auth_token'], isNull);
    expect(copied.single['refresh_token'], isNull);

    final live = await DatabaseService.instance.database;
    final liveRow = (await live.query('app_session')).single;
    expect(liveRow['auth_token'], 'secret-token');
  });

  test('inspect reads outlet and order count from a valid backup', () async {
    final file = await service.createBackup();
    final info = await service.inspect(file.path);

    expect(info.orderCount, 2);
    expect(info.tenants.single.tenantKey, 'tenant-a');
    expect(service.blockingReason(info), isNull);
  });

  test('inspect rejects a file that is not a SQLite database', () async {
    final bogus = File('${workDir.path}/notes.db')
      ..writeAsStringSync('this is not a database at all');

    expect(
      () => service.inspect(bogus.path),
      throwsA(isA<DatabaseBackupException>()),
    );
  });

  test('backup from another outlet is blocked', () async {
    final file = await service.createBackup();
    final info = await service.inspect(file.path);

    PosV2RuntimeSessionStore.instance.setSession(
      const PosV2RuntimeSession(
        tenantId: 2,
        tenantKey: 'tenant-b',
        baseUrl: 'https://b.example.com',
        authToken: 't',
        locationId: 'LOC-2',
        tenantName: 'Outlet B',
      ),
    );

    expect(service.blockingReason(info), contains('outlet lain'));
  });

  test('restore swaps data, logs out, and keeps an emergency copy', () async {
    final backup = await service.createBackup();
    final info = await service.inspect(backup.path);

    // Data created after the backup was taken must disappear on restore.
    final live = await DatabaseService.instance.database;
    await _insertOrder(live, 'ORD-3');
    expect(await _orderCount(live), 3);

    await service.restore(info);

    final restored = await DatabaseService.instance.database;
    expect(await _orderCount(restored), 2);
    final session = (await restored.query('app_session')).single;
    expect(session['status'], 'logged_out');
    expect(session['auth_token'], isNull);
    expect(PosV2RuntimeSessionStore.instance.currentSession, isNull);

    final emergency = Directory(
      '${workDir.path}/docs/emergency_backups',
    ).listSync().whereType<File>().toList();
    expect(emergency, hasLength(1));
    final kept = await openDatabase(emergency.single.path, readOnly: true);
    expect(await _orderCount(kept), 3);
    await kept.close();
  });

  test('restore is refused for a backup from a newer schema', () async {
    final backup = await service.createBackup();
    final newer = await openDatabase(backup.path, singleInstance: false);
    await newer.execute('PRAGMA user_version = 9999');
    await newer.close();

    final info = await service.inspect(backup.path);
    expect(service.blockingReason(info), contains('lebih baru'));
    await expectLater(
      service.restore(info),
      throwsA(isA<DatabaseBackupException>()),
    );
  });

  test(
    'a restore that fails to open rolls back to the previous data',
    () async {
      final candidate = File('${workDir.path}/old_backup.db');
      final old = await openDatabase(
        candidate.path,
        version: 1,
        singleInstance: false,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE app_tenant (id INTEGER PRIMARY KEY, tenant_key TEXT, '
            'tenant_name TEXT, tenant_code TEXT, location_id TEXT)',
          );
          await db.execute('CREATE TABLE pos_order (id INTEGER PRIMARY KEY)');
          await db.insert('app_tenant', {'tenant_key': 'tenant-a'});
        },
      );
      await old.close();

      final info = await service.inspect(candidate.path);
      expect(service.blockingReason(info), isNull);

      await expectLater(
        service.restore(info),
        throwsA(
          isA<DatabaseBackupException>().having(
            (e) => e.message,
            'message',
            contains('dikembalikan'),
          ),
        ),
      );

      final live = await DatabaseService.instance.database;
      expect(await _orderCount(live), 2);
      expect((await live.query('app_session')).single['status'], 'active');
    },
  );
}
