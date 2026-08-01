import '../../network/v2_api_client.dart';
import 'base_v2_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';
import 'v2_sync_utils.dart';

class TaxesSyncAdapter extends BaseV2SyncAdapter {
  TaxesSyncAdapter({super.databaseService});

  Future<V2SyncResult> sync(V2SyncContext context) async {
    final client = V2ApiClient(
      baseUrl: 'https://flinkaja.com/',
      authToken: context.authToken,
    );
    final envelope = await client.getEnvelope('api/v2/taxes');
    final rows = V2SyncUtils.asMapList(envelope['data'] ?? envelope['taxes']);
    var upsertedCount = 0;

    await databaseService.transaction((txn) async {
      final tenantId = await ensureTenantId(txn, context);

      // Pastikan tabel ada jika pengguna belum reset database
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS pos_tax (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          remote_id TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          taxrate TEXT NOT NULL
        );
      ''');

      await txn.delete('pos_tax'); // simple full replace strategy
      
      for (final row in rows) {
        final remoteId = V2SyncUtils.asString(row['id']);
        if (remoteId == null || remoteId.isEmpty) continue;

        await txn.insert('pos_tax', {
          'remote_id': remoteId,
          'name': V2SyncUtils.asString(row['name']) ?? '',
          'taxrate': V2SyncUtils.asString(row['taxrate']) ?? '0.00',
        });
        upsertedCount++;
      }

      await touchCheckpoint(
        txn,
        tenantId,
        endpointName: 'taxes',
        scopeKey: 'default',
        notes: 'Tax master synced from api/v2/taxes.',
      );
    });

    return V2SyncResult(
      endpointName: 'taxes',
      fetchedCount: rows.length,
      upsertedCount: upsertedCount,
    );
  }
}
