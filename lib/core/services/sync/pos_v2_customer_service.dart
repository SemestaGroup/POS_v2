import 'dart:async';
import 'dart:convert';

import '../../network/v2_api_client.dart';
import '../../network/v2_api_fixed_auth.dart';
import '../local/database_service.dart';
import 'pos_v2_runtime_session_store.dart';

class PosCustomerRecord {
  const PosCustomerRecord({
    required this.localId,
    required this.remoteId,
    required this.name,
    this.phone,
    this.address,
    this.isDefaultWalkIn = false,
  });

  final int? localId;
  final String remoteId;
  final String name;
  final String? phone;
  final String? address;
  final bool isDefaultWalkIn;
}

class PosV2CustomerService {
  PosV2CustomerService._();

  static final PosV2CustomerService instance = PosV2CustomerService._();

  static const String defaultWalkInName = 'Walk-In Customer';

  Future<List<PosCustomerRecord>> searchLocal(String keyword) async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      return const <PosCustomerRecord>[];
    }

    final trimmed = keyword.trim();
    final rows = await DatabaseService.instance.query(
      'customer',
      where: trimmed.isEmpty
          ? 'tenant_id = ? AND deleted_at IS NULL'
          : '''
            tenant_id = ? AND deleted_at IS NULL AND (
              display_name LIKE ? OR company_name LIKE ? OR phone_number LIKE ?
            )
          ''',
      whereArgs: trimmed.isEmpty
          ? <Object?>[session.tenantId]
          : <Object?>[
              session.tenantId,
              '%$trimmed%',
              '%$trimmed%',
              '%$trimmed%',
            ],
      orderBy: 'display_name ASC, company_name ASC',
      limit: trimmed.isEmpty ? 20 : 30,
    );

    return rows.map(_recordFromRow).toList(growable: false);
  }

  Future<List<PosCustomerRecord>> searchRemote(String keyword) async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      return const <PosCustomerRecord>[];
    }

    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return const <PosCustomerRecord>[];
    }

    final client = V2ApiClient(
      baseUrl: session.baseUrl,
      authToken: kFlinkV2FixedAuthToken,
    );

    dynamic payload;
    try {
      payload = await client.getJson(
        'api/v2/pos-customers/search/${Uri.encodeComponent(trimmed)}',
      );
    } catch (error) {
      // Catch any network errors (like 403) so offline search doesn't crash
      return const <PosCustomerRecord>[];
    }

    List<Map<String, dynamic>> rows;
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is List) {
        rows = data
            .whereType<Map>()
            .map(
              (item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)),
            )
            .toList(growable: false);
      } else {
        rows = const <Map<String, dynamic>>[];
      }
    } else if (payload is List) {
      rows = payload
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);
    } else {
      rows = const <Map<String, dynamic>>[];
    }

    if (rows.isEmpty) {
      return const <PosCustomerRecord>[];
    }

    final upserted = <PosCustomerRecord>[];
    await DatabaseService.instance.transaction((txn) async {
      for (final row in rows) {
        final saved = await _upsertRemoteCustomerRow(
          txn,
          session.tenantId,
          row,
        );
        if (saved != null) {
          upserted.add(saved);
        }
      }
    });

    return upserted;
  }

  Future<PosCustomerRecord> createCustomer({
    required String name,
    String? phone,
    String? address,
    bool isDefaultWalkIn = false,
  }) async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found for customer creation');
    }

    final client = V2ApiClient(
      baseUrl: session.baseUrl,
      authToken: kFlinkV2FixedAuthToken,
    );
    final envelope = await client.postEnvelope(
      'api/v2/pos-customers',
      body: <String, dynamic>{
        'company': name.trim(),
        if (phone != null && phone.trim().isNotEmpty)
          'phonenumber': phone.trim(),
        if (address != null && address.trim().isNotEmpty)
          'address': address.trim(),
      },
    );

    final row =
        (envelope['data'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    PosCustomerRecord? record;
    await DatabaseService.instance.transaction((txn) async {
      record = await _upsertRemoteCustomerRow(
        txn,
        session.tenantId,
        row,
        isDefaultWalkIn: isDefaultWalkIn,
      );
    });

    if (record == null) {
      throw Exception('Customer created but could not be stored locally');
    }
    return record!;
  }

  Future<PosCustomerRecord> ensureDefaultWalkInCustomer() async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found for default customer');
    }

    final localRows = await DatabaseService.instance.query(
      'customer',
      where: 'tenant_id = ? AND deleted_at IS NULL AND (remote_id = ? OR company_name = ?)',
      whereArgs: <Object?>[session.tenantId, '1', defaultWalkInName],
      limit: 1,
    );
    if (localRows.isNotEmpty) {
      return _recordFromRow(localRows.first, isDefaultWalkIn: true);
    }

    // Force create Walk-in locally mapped to remote_id '1' to prevent duplicating it on backend.
    final now = DateTime.now().toUtc().toIso8601String();
    final database = await DatabaseService.instance.database;
    final localId = await DatabaseService.instance.upsertByUnique(
      database,
      'customer',
      where: 'tenant_id = ? AND remote_id = ?',
      whereArgs: <Object?>[session.tenantId, '1'],
      insertValues: <String, Object?>{
        'tenant_id': session.tenantId,
        'remote_id': '1',
        'display_name': defaultWalkInName,
        'company_name': defaultWalkInName,
        'created_at': now,
        'updated_at': now,
      },
      updateValues: <String, Object?>{
        'display_name': defaultWalkInName,
        'company_name': defaultWalkInName,
        'updated_at': now,
      },
    );

    return PosCustomerRecord(
      localId: localId,
      remoteId: '1',
      name: defaultWalkInName,
      isDefaultWalkIn: true,
    );
  }

  Future<PosCustomerRecord?> _upsertRemoteCustomerRow(
    dynamic txn,
    int tenantId,
    Map<String, dynamic> row, {
    bool isDefaultWalkIn = false,
  }) async {
    final remoteId = row['id']?.toString();
    if (remoteId == null || remoteId.isEmpty) {
      return null;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final localId = await DatabaseService.instance.upsertByUnique(
      txn,
      'customer',
      where: 'tenant_id = ? AND remote_id = ?',
      whereArgs: <Object?>[tenantId, remoteId],
      insertValues: <String, Object?>{
        'tenant_id': tenantId,
        'remote_id': remoteId,
        'display_name': row['nama']?.toString() ?? row['company']?.toString(),
        'company_name': row['nama']?.toString() ?? row['company']?.toString(),
        'phone_number':
            row['no_hp']?.toString() ?? row['phonenumber']?.toString(),
        'address_line1':
            row['alamat']?.toString() ?? row['address']?.toString(),
        'billing_street': row['billing_street']?.toString(),
        'billing_city': row['billing_city']?.toString(),
        'billing_state': row['billing_state']?.toString(),
        'billing_postal_code': row['billing_zip']?.toString(),
        'billing_country': row['billing_country']?.toString(),
        'shipping_street': row['shipping_street']?.toString(),
        'shipping_city': row['shipping_city']?.toString(),
        'shipping_state': row['shipping_state']?.toString(),
        'shipping_postal_code': row['shipping_zip']?.toString(),
        'shipping_country': row['shipping_country']?.toString(),
        'points_balance':
            int.tryParse(
              (row['value_pts'] ?? row['points'] ?? '0').toString(),
            ) ??
            0,
        'raw_payload_json': jsonEncode(row),
        'last_synced_at': now,
        'created_at': now,
        'updated_at': now,
      },
      updateValues: <String, Object?>{
        'display_name': row['nama']?.toString() ?? row['company']?.toString(),
        'company_name': row['nama']?.toString() ?? row['company']?.toString(),
        'phone_number':
            row['no_hp']?.toString() ?? row['phonenumber']?.toString(),
        'address_line1':
            row['alamat']?.toString() ?? row['address']?.toString(),
        'billing_street': row['billing_street']?.toString(),
        'billing_city': row['billing_city']?.toString(),
        'billing_state': row['billing_state']?.toString(),
        'billing_postal_code': row['billing_zip']?.toString(),
        'billing_country': row['billing_country']?.toString(),
        'shipping_street': row['shipping_street']?.toString(),
        'shipping_city': row['shipping_city']?.toString(),
        'shipping_state': row['shipping_state']?.toString(),
        'shipping_postal_code': row['shipping_zip']?.toString(),
        'shipping_country': row['shipping_country']?.toString(),
        'points_balance':
            int.tryParse(
              (row['value_pts'] ?? row['points'] ?? '0').toString(),
            ) ??
            0,
        'raw_payload_json': jsonEncode(row),
        'last_synced_at': now,
        'updated_at': now,
        'deleted_at': null,
      },
    );

    return PosCustomerRecord(
      localId: localId,
      remoteId: remoteId,
      name: row['nama']?.toString() ?? row['company']?.toString() ?? '',
      phone: row['no_hp']?.toString() ?? row['phonenumber']?.toString(),
      address: row['alamat']?.toString() ?? row['address']?.toString(),
      isDefaultWalkIn: isDefaultWalkIn,
    );
  }

  PosCustomerRecord _recordFromRow(
    Map<String, Object?> row, {
    bool isDefaultWalkIn = false,
  }) {
    return PosCustomerRecord(
      localId: row['id'] is int
          ? row['id'] as int
          : int.tryParse(row['id'].toString()),
      remoteId: row['remote_id']?.toString() ?? '',
      name:
          row['display_name']?.toString() ??
          row['company_name']?.toString() ??
          '',
      phone: row['phone_number']?.toString(),
      address: row['address_line1']?.toString(),
      isDefaultWalkIn: isDefaultWalkIn,
    );
  }
}
