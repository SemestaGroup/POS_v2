import 'base_v2_sync_adapter.dart';
import 'pos_v2_runtime_session_store.dart';
import 'service_tables_sync_adapter.dart';
import 'v2_sync_utils.dart';

class ServiceTableException implements Exception {
  const ServiceTableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ServiceTableRecord {
  const ServiceTableRecord({
    required this.localId,
    required this.remoteId,
    required this.tableCode,
    required this.tableName,
    required this.capacity,
    required this.selfOrderEnabled,
    required this.isActive,
    this.areaName,
    this.qrToken,
  });

  final int localId;
  final String? remoteId;
  final String tableCode;
  final String tableName;
  final String? areaName;
  final int capacity;
  final String? qrToken;
  final bool selfOrderEnabled;
  final bool isActive;

  String get label {
    final area = (areaName ?? '').trim();
    return area.isEmpty ? tableName : '$area - $tableName';
  }

  /// A table can only take orders when it is active, allows self order and
  /// the server has issued its QR token.
  bool get canOrder =>
      isActive && selfOrderEnabled && (qrToken ?? '').trim().isNotEmpty;
}

/// Manages the tables customers scan to order by themselves.
///
/// The public order page lives on the tenant's own domain at
/// `/order?table=<code>&token=<qr_token>`. The API's own `entry_url` points at
/// a different path (`/online-store?table_qr_token=...`) that does not exist,
/// so the URL is always built here.
class PosV2ServiceTableService extends BaseV2SyncAdapter {
  PosV2ServiceTableService({super.databaseService});

  static final PosV2ServiceTableService instance = PosV2ServiceTableService();

  static const String _endpoint = 'api/v2/backoffice/pos-service-tables';

  /// Builds the address encoded in a table's QR code.
  static String buildOrderUrl({
    required String baseUrl,
    required String tableCode,
    required String qrToken,
  }) {
    final parsed = Uri.parse(baseUrl.trim());
    final host = parsed.host;
    if (host.isEmpty) {
      throw const ServiceTableException('Alamat outlet tidak valid.');
    }
    // Customers scan with their own phones, so always use https.
    return Uri(
      scheme: 'https',
      host: host,
      port: parsed.hasPort && parsed.port != 80 && parsed.port != 443
          ? parsed.port
          : null,
      path: '/order',
      queryParameters: <String, String>{'table': tableCode, 'token': qrToken},
    ).toString();
  }

  String qrUrlFor(ServiceTableRecord table) {
    final session = _requireSession();
    return buildOrderUrl(
      baseUrl: session.baseUrl,
      tableCode: table.tableCode,
      qrToken: table.qrToken ?? '',
    );
  }

  Future<List<ServiceTableRecord>> loadLocal() async {
    final session = _requireSession();
    final rows = await databaseService.rawQuery(
      '''
      SELECT id, remote_id, table_code, table_name, area_name, capacity,
             qr_token, self_order_enabled, is_active
      FROM service_table
      WHERE tenant_id = ? AND deleted_at IS NULL
      ORDER BY COALESCE(area_name, ''), table_code
      ''',
      <Object?>[session.tenantId],
    );
    return rows
        .map(
          (row) => ServiceTableRecord(
            localId: V2SyncUtils.asInt(row['id']),
            remoteId: V2SyncUtils.asString(row['remote_id']),
            tableCode: row['table_code']?.toString() ?? '',
            tableName: row['table_name']?.toString() ?? '',
            areaName: V2SyncUtils.asString(row['area_name']),
            capacity: V2SyncUtils.asInt(row['capacity']),
            qrToken: V2SyncUtils.asString(row['qr_token']),
            selfOrderEnabled:
                (V2SyncUtils.asInt(row['self_order_enabled'])) == 1,
            isActive: (V2SyncUtils.asInt(row['is_active'])) == 1,
          ),
        )
        .toList(growable: false);
  }

  /// Pulls the table list from the server, then drops local rows the server no
  /// longer returns (tables deleted elsewhere).
  Future<void> refreshFromServer() async {
    final session = _requireSession();
    final actingStaffId = _actingStaffId(session);
    final startedAt = V2SyncUtils.nowIso();

    await ServiceTablesSyncAdapter(
      databaseService: databaseService,
    ).syncBackofficeList(
      session.toSyncContext(),
      actingStaffId: actingStaffId,
      query: <String, dynamic>{
        if (_locationId(session) != null) 'location_id': _locationId(session),
        'limit': 500,
      },
    );

    await databaseService.transaction((txn) async {
      await txn.update(
        'service_table',
        <String, Object?>{'deleted_at': V2SyncUtils.nowIso()},
        where:
            'tenant_id = ? AND remote_id IS NOT NULL AND deleted_at IS NULL '
            'AND (last_synced_at IS NULL OR last_synced_at < ?)',
        whereArgs: <Object?>[session.tenantId, startedAt],
      );
    });
  }

  Future<void> createTable({
    required String tableCode,
    required String tableName,
    String? areaName,
    int capacity = 0,
  }) async {
    final session = _requireSession();
    final locationId = _locationId(session);
    if (locationId == null) {
      throw const ServiceTableException(
        'ID lokasi outlet tidak ditemukan. Silakan masuk ulang.',
      );
    }

    await buildClient(session.toSyncContext()).postEnvelope(
      _endpoint,
      body: <String, dynamic>{
        'acting_staff_id': _actingStaffId(session),
        'location_id': locationId,
        'table_code': tableCode.trim(),
        'table_name': tableName.trim(),
        if ((areaName ?? '').trim().isNotEmpty) 'area_name': areaName!.trim(),
        'capacity': capacity,
        'self_order_enabled': true,
        'active': true,
      },
    );
    await refreshFromServer();
  }

  Future<void> updateTable(
    ServiceTableRecord table, {
    String? tableName,
    String? areaName,
    int? capacity,
    bool? selfOrderEnabled,
    bool? active,
    bool regenerateQrToken = false,
  }) async {
    final remoteId = table.remoteId;
    if (remoteId == null) {
      throw const ServiceTableException('Meja belum tersinkron ke server.');
    }
    final session = _requireSession();

    await buildClient(session.toSyncContext()).putEnvelope(
      '$_endpoint/$remoteId',
      body: <String, dynamic>{
        'acting_staff_id': _actingStaffId(session),
        if (tableName != null) 'table_name': tableName.trim(),
        if (areaName != null) 'area_name': areaName.trim(),
        'capacity': ?capacity,
        'self_order_enabled': ?selfOrderEnabled,
        'active': ?active,
        if (regenerateQrToken) 'regenerate_qr_token': true,
      },
    );
    await refreshFromServer();
  }

  PosV2RuntimeSession _requireSession() {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) {
      throw const ServiceTableException('Tidak ada sesi aktif.');
    }
    return session;
  }

  int _actingStaffId(PosV2RuntimeSession session) {
    final id = int.tryParse(session.staffId ?? '');
    if (id == null || id <= 0) {
      throw const ServiceTableException(
        'Akun staf tidak dikenali. Silakan masuk ulang.',
      );
    }
    return id;
  }

  int? _locationId(PosV2RuntimeSession session) {
    final id = int.tryParse(session.locationId);
    return id == null || id <= 0 ? null : id;
  }
}
