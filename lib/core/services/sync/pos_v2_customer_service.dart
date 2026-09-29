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
    this.pointsBalance = 0,
    this.isDefaultWalkIn = false,
  });

  final int? localId;
  final String remoteId;
  final String name;
  final String? phone;
  final String? address;
  final int pointsBalance;
  final bool isDefaultWalkIn;
}

class PosV2CustomerService {
  PosV2CustomerService._();

  static final PosV2CustomerService instance = PosV2CustomerService._();

  static const String defaultWalkInName = 'Walk-In Customer';

  /// Extracts the core phone digits by stripping non-digit chars and leading
  /// country/area code prefixes ('+62', '62', '0').
  /// e.g. '082112345678' -> '82112345678', '+62 821-1234-5678' -> '82112345678'
  static String extractPhoneCore(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) {
      return digits.substring(2);
    } else if (digits.startsWith('0')) {
      return digits.substring(1);
    }
    return digits;
  }

  /// Determines whether [input] is likely a phone number rather than a customer name.
  static bool isLikelyPhoneNumber(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 3) return false;

    // If it contains letters (e.g. "Budi 08"), treat as name
    if (RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return false;
    }

    // If input consists mostly of digits and phone formatting symbols (+, -, space, parens)
    return RegExp(r'^[\d\s+\-().]+$').hasMatch(trimmed);
  }

  Future<List<PosCustomerRecord>> searchLocal(String keyword) async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      return const <PosCustomerRecord>[];
    }

    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      final rows = await DatabaseService.instance.query(
        'customer',
        where: 'tenant_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[session.tenantId],
        orderBy: 'display_name ASC, company_name ASC',
        limit: 20,
      );
      return rows.map(_recordFromRow).toList(growable: false);
    }

    final phoneCore = extractPhoneCore(trimmed);
    final isPhone = isLikelyPhoneNumber(trimmed) && phoneCore.length >= 3;

    final whereClauses = <String>[
      'display_name LIKE ?',
      'company_name LIKE ?',
      'phone_number LIKE ?',
    ];
    final whereArgs = <Object?>[
      session.tenantId,
      '%$trimmed%',
      '%$trimmed%',
      '%$trimmed%',
    ];

    if (isPhone) {
      // Match phone variants: with leading 0, with leading 62, with +62, or raw core digits
      whereClauses.add('phone_number LIKE ?');
      whereArgs.add('%$phoneCore%');
      whereClauses.add('phone_number LIKE ?');
      whereArgs.add('%0$phoneCore%');
      whereClauses.add('phone_number LIKE ?');
      whereArgs.add('%62$phoneCore%');
      whereClauses.add('phone_number LIKE ?');
      whereArgs.add('%+62$phoneCore%');
    }

    final rows = await DatabaseService.instance.query(
      'customer',
      where: 'tenant_id = ? AND deleted_at IS NULL AND (${whereClauses.join(' OR ')})',
      whereArgs: whereArgs,
      orderBy: 'display_name ASC, company_name ASC',
      limit: 30,
    );

    final records = rows.map(_recordFromRow).toList(growable: false);

    if (isPhone) {
      // Rank direct core phone matches first
      final sorted = List<PosCustomerRecord>.from(records);
      sorted.sort((a, b) {
        final aPhoneCore = extractPhoneCore(a.phone ?? '');
        final bPhoneCore = extractPhoneCore(b.phone ?? '');
        final aMatches = aPhoneCore.contains(phoneCore);
        final bMatches = bPhoneCore.contains(phoneCore);
        if (aMatches && !bMatches) return -1;
        if (!aMatches && bMatches) return 1;
        return 0;
      });
      return sorted;
    }

    return records;
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

  Future<PosCustomerRecord> updateCustomer({
    required int localId,
    required String name,
    String? phone,
    String? address,
    String? email,
  }) async {
    final session = await PosV2RuntimeSessionStore.instance
        .restoreFromDatabase();
    if (session == null) {
      throw Exception('No active session found for customer update');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    // 1. Fetch current local record to get remote_id
    final existing = await DatabaseService.instance.query(
      'customer',
      where: 'id = ? AND tenant_id = ?',
      whereArgs: <Object?>[localId, session.tenantId],
      limit: 1,
    );

    if (existing.isEmpty) {
      throw Exception('Customer with ID $localId not found');
    }

    final current = existing.first;
    final remoteId = current['remote_id']?.toString();

    // 2. Try remote update if remoteId exists
    Map<String, dynamic>? updatedRemoteData;
    if (remoteId != null && remoteId.isNotEmpty) {
      try {
        final client = V2ApiClient(
          baseUrl: session.baseUrl,
          authToken: kFlinkV2FixedAuthToken,
        );
        final envelope = await client.putEnvelope(
          'api/v2/pos-customers/$remoteId',
          body: <String, dynamic>{
            'company': name.trim(),
            if (phone != null && phone.trim().isNotEmpty)
              'phonenumber': phone.trim(),
            if (address != null && address.trim().isNotEmpty)
              'address': address.trim(),
            if (email != null && email.trim().isNotEmpty)
              'email': email.trim(),
          },
        );
        if (envelope['data'] is Map) {
          updatedRemoteData = (envelope['data'] as Map).cast<String, dynamic>();
        }
      } catch (_) {
        // Offline or server error: continue with local update & dirty sync_state
      }
    }
    // 3. Update SQLite record + conditionally enqueue sync_queue (offline case)
    final syncState = updatedRemoteData != null ? 'clean' : 'dirty_update';
    final requestBody = <String, dynamic>{
      'company': name.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phonenumber': phone.trim(),
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    };

    await DatabaseService.instance.transaction((txn) async {
      await txn.update(
        'customer',
        <String, Object?>{
          'display_name': name.trim(),
          'company_name': name.trim(),
          if (phone != null) 'phone_number': phone.trim(),
          if (address != null) 'address_line1': address.trim(),
          if (email != null) 'email': email.trim(),
          'sync_state': syncState,
          'updated_at': now,
        },
        where: 'id = ? AND tenant_id = ?',
        whereArgs: <Object?>[localId, session.tenantId],
      );

      // Enqueue for background sync if remote update didn't succeed
      if (syncState == 'dirty_update' &&
          remoteId != null &&
          remoteId.isNotEmpty) {
        final dedupeKey = 'customer_update_${session.tenantId}_$localId';
        await DatabaseService.instance.upsertByUnique(
          txn,
          'sync_queue',
          where: 'tenant_id = ? AND dedupe_key = ?',
          whereArgs: <Object?>[session.tenantId, dedupeKey],
          insertValues: <String, Object?>{
            'tenant_id': session.tenantId,
            'entity_type': 'customer',
            'entity_local_id': localId,
            'entity_remote_id': remoteId,
            'operation': 'update',
            'method': 'PUT',
            'endpoint': 'api/v2/pos-customers/$remoteId',
            'base_url': session.baseUrl,
            'request_headers_json': jsonEncode(<String, Object?>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'authtoken': kFlinkV2FixedAuthToken,
            }),
            'request_body_json': jsonEncode(requestBody),
            'dedupe_key': dedupeKey,
            'priority': 100,
            'status': 'pending',
            'retry_count': 0,
            'next_retry_at': null,
            'created_at': now,
            'updated_at': now,
          },
          updateValues: <String, Object?>{
            'request_body_json': jsonEncode(requestBody),
            'status': 'pending',
            'retry_count': 0,
            'next_retry_at': null,
            'updated_at': now,
          },
        );
      }
    });

    return PosCustomerRecord(
      localId: localId,
      remoteId: remoteId ?? '',
      name: name.trim(),
      phone: phone?.trim(),
      address: address?.trim(),
      pointsBalance: (current['points_balance'] as num?)?.toInt() ?? 0,
      isDefaultWalkIn: remoteId == '1',
    );
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
        if (row['email'] != null) 'email': row['email']?.toString(),
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
        if (row['email'] != null) 'email': row['email']?.toString(),
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
