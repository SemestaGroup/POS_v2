import '../../network/v2_api_client.dart';
import '../local/database_service.dart';
import 'pos_v2_runtime_session_store.dart';
import 'pos_v2_sync_orchestrator.dart';

/// Create/update/deactivate for staff accounts against `POST/PUT/DELETE
/// /api/v2/pos-staff`, used by the Data Master "Daftar Staf" screen.
///
/// Unlike [PosV2CustomerService], staff writes always need connectivity:
/// creating an account requires the server to hash the password and
/// validate the role, so there is no offline-create path. Update and
/// deactivate do write locally first so the UI reflects the change
/// immediately and works offline, matching the customer service pattern.
class PosV2StaffService {
  PosV2StaffService._();

  static final PosV2StaffService instance = PosV2StaffService._();

  Future<void> createStaff({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String roleId,
    required String roleName,
    required String pin,
  }) async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found for staff creation');
    }

    final client = V2ApiClient(
      baseUrl: session.baseUrl,
      authToken: session.authToken,
    );
    final envelope = await client.postEnvelope(
      'api/v2/pos-staff',
      body: <String, dynamic>{
        'firstname': firstName,
        'lastname': lastName,
        'email': email,
        'password': password,
        'role_id': int.tryParse(roleId) ?? roleId,
        'role': roleName,
        'pin': pin,
        'active': 1,
        'admin': 0,
      },
    );
    if (envelope['status'] != true) {
      throw Exception(envelope['message']?.toString() ?? 'Gagal menambahkan staf');
    }

    // Pull the authoritative row (with its remote_id and normalized role)
    // back from the server rather than guessing the local row shape here —
    // this is the same call the Switch Staff "Tambah Staf" flow already
    // relies on to make a newly created account show up locally.
    await PosV2SyncOrchestrator().syncStaff(session.toSyncContext());
  }

  Future<void> updateStaff({
    required int localId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? roleId,
    String? roleName,
    String? password,
    String? pin,
  }) async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found for staff update');
    }

    final existing = await DatabaseService.instance.query(
      'staff',
      where: 'id = ? AND tenant_id = ?',
      whereArgs: <Object?>[localId, session.tenantId],
      limit: 1,
    );
    if (existing.isEmpty) {
      throw Exception('Staff with ID $localId not found');
    }
    final remoteId = existing.first['remote_id']?.toString();

    var synced = false;
    if (remoteId != null && remoteId.isNotEmpty) {
      try {
        final client = V2ApiClient(
          baseUrl: session.baseUrl,
          authToken: session.authToken,
        );
        await client.putEnvelope(
          'api/v2/pos-staff/$remoteId',
          body: <String, dynamic>{
            if (firstName != null) 'firstname': firstName,
            if (lastName != null) 'lastname': lastName,
            if (email != null) 'email': email,
            if (phone != null) 'phonenumber': phone,
            if (roleId != null) 'role_id': int.tryParse(roleId) ?? roleId,
            if (roleName != null) 'role': roleName,
            if (password != null && password.isNotEmpty) 'password': password,
            if (pin != null && pin.isNotEmpty) 'pin': pin,
          },
        );
        synced = true;
      } catch (_) {
        // Offline or server error: fall through to a local-only update.
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await DatabaseService.instance.transaction((txn) async {
      final fullName = (firstName != null || lastName != null)
          ? [
              firstName ?? existing.first['first_name']?.toString() ?? '',
              lastName ?? existing.first['last_name']?.toString() ?? '',
            ].where((s) => s.isNotEmpty).join(' ').trim()
          : null;

      await txn.update(
        'staff',
        <String, Object?>{
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
          if (email != null) 'email': email,
          if (phone != null) 'phone_number': phone,
          if (roleName != null) 'role_name': roleName,
          if (roleId != null) 'role_remote_id': roleId,
          'sync_state': synced ? 'clean' : 'dirty_update',
          'updated_at': now,
        },
        where: 'id = ? AND tenant_id = ?',
        whereArgs: <Object?>[localId, session.tenantId],
      );
    });

    if (!synced) {
      // No generic sync_queue replay path exists for `staff` (the queue
      // processor only special-cases pos_order/pos_transaction), so surface
      // the failure instead of silently leaving it stuck dirty forever.
      throw Exception(
        'Perubahan tersimpan di perangkat ini, tetapi belum tersinkron ke server (tidak ada koneksi). Coba lagi saat online.',
      );
    }
  }

  /// Deactivates a staff account (`DELETE /pos-staff/{id}` sets `active =
  /// 0` server-side rather than hard-deleting, per the API contract).
  Future<void> deactivateStaff({required int localId}) async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found for staff deactivation');
    }

    final existing = await DatabaseService.instance.query(
      'staff',
      where: 'id = ? AND tenant_id = ?',
      whereArgs: <Object?>[localId, session.tenantId],
      limit: 1,
    );
    if (existing.isEmpty) {
      throw Exception('Staff with ID $localId not found');
    }
    final remoteId = existing.first['remote_id']?.toString();
    if (remoteId == null || remoteId.isEmpty) {
      throw Exception('Staf ini belum tersinkron ke server, coba muat ulang.');
    }

    final client = V2ApiClient(
      baseUrl: session.baseUrl,
      authToken: session.authToken,
    );
    await client.deleteEnvelope('api/v2/pos-staff/$remoteId');

    final now = DateTime.now().toUtc().toIso8601String();
    await DatabaseService.instance.transaction((txn) async {
      await txn.update(
        'staff',
        <String, Object?>{
          'is_active': 0,
          'sync_state': 'clean',
          'updated_at': now,
        },
        where: 'id = ? AND tenant_id = ?',
        whereArgs: <Object?>[localId, session.tenantId],
      );
    });
  }
}
