import 'package:flutter/foundation.dart';

import 'base_v2_sync_adapter.dart';
import 'pos_v2_runtime_session_store.dart';
import 'v2_sync_context.dart';

typedef WaReportRequestPost =
    Future<Map<String, dynamic>> Function(
      String endpoint,
      Map<String, dynamic> body,
    );

class WaReportRequestException implements Exception {
  const WaReportRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WaReportRequestService extends BaseV2SyncAdapter {
  WaReportRequestService({super.databaseService, this.postRequest});

  static final WaReportRequestService instance = WaReportRequestService();

  static const String _endpoint = 'api/v2/pos-options';
  static const String targetPhone = '6282322494484';
  static const Duration qrDuration = Duration(minutes: 5);

  @visibleForTesting
  final WaReportRequestPost? postRequest;

  /// Requests a server-issued, short-lived credential for one report QR.
  ///
  /// A QR is never generated offline: only the backend can issue a key that it
  /// can later validate and expire.
  Future<String> generateAuthKey() async {
    final session = await _activeSession();
    final response = await _post(session.toSyncContext(), <String, dynamic>{});
    final authKey = _extractAuthKey(response);
    if (authKey == null) {
      throw const WaReportRequestException(
        'Server tidak mengembalikan auth key untuk QR laporan.',
      );
    }
    return authKey;
  }

  /// Best-effort cleanup for the tenant's active report-request key.
  ///
  /// This is intentionally separate from the normal POS-option PUT flow; the
  /// QR lifecycle is owned by the dedicated POST contract.
  Future<bool> revokeAuthKey() async {
    try {
      final session = await _activeSession();
      final response = await _post(session.toSyncContext(), <String, dynamic>{
        'auth_key': '',
      });
      return response['status'] == true;
    } catch (error) {
      debugPrint('Report-request QR cleanup failed: $error');
      return false;
    }
  }

  Future<PosV2RuntimeSession> _activeSession() async {
    final session =
        PosV2RuntimeSessionStore.instance.currentSession ??
        await PosV2RuntimeSessionStore.instance.restoreFromDatabase();
    if (session == null || session.authToken.trim().isEmpty) {
      throw const WaReportRequestException(
        'Sesi POS tidak tersedia. Silakan masuk ulang lalu coba lagi.',
      );
    }
    return session;
  }

  Future<Map<String, dynamic>> _post(
    V2SyncContext context,
    Map<String, dynamic> body,
  ) {
    final override = postRequest;
    if (override != null) {
      return override(_endpoint, body);
    }
    return buildClient(context).postEnvelope(_endpoint, body: body);
  }

  String? _extractAuthKey(Map<String, dynamic> response) {
    if (response['status'] != true) {
      return null;
    }
    final data = response['data'];
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return null;
  }

  /// Builds the WhatsApp deep-link that is encoded into the QR image.
  String buildWaPayload({
    required String location,
    required String authKey,
    required String requestType,
  }) {
    final reportMessage =
        'id mitra : $location dengan kode : $authKey request : $requestType';

    return Uri.https('wa.me', '/$targetPhone', <String, String>{
      'text': reportMessage,
    }).toString();
  }
}
