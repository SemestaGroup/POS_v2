import 'dart:async';

import '../../network/v2_api_client.dart';
import 'pos_v2_auth_service.dart';
import 'pos_v2_runtime_session_store.dart';
import 'pos_v2_sync_queue_processor.dart';

class PosV2SessionMonitorService {
  PosV2SessionMonitorService._();

  static final PosV2SessionMonitorService instance = PosV2SessionMonitorService._();

  Timer? _pollingTimer;
  bool _isChecking = false;

  void init() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  void _onSessionChanged() {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) {
      _stopPolling();
    } else {
      _startPolling();
    }
  }

  void _startPolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) {
      return;
    }
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkSessionStatus();
      PosV2SyncQueueProcessor.instance.flushPending();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _checkSessionStatus() async {
    if (_isChecking) return;

    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return;

    _isChecking = true;
    try {
      final authService = PosV2AuthService();
      final sessionCode = await authService.resolveActiveDeviceSessionCode(session);

      if (sessionCode == null || sessionCode.isEmpty) {
        _isChecking = false;
        return;
      }

      final client = V2ApiClient(
        baseUrl: session.baseUrl,
        authToken: session.authToken,
      );

      final response = await client.getEnvelope(
        'api/v2/pos-auth/session',
        query: <String, dynamic>{
          'session_code': sessionCode,
          'staff_id': session.staffId,
          'device_id': session.deviceId,
        },
      );

      final status = response['status'];
      
      bool shouldForceLogout = false;
      
      if (status == true) {
        final data = response['data'] as Map<String, dynamic>?;
        if (data != null && data['forced_out_by_staff_id'] != null) {
          shouldForceLogout = true;
        }
      }

      if (shouldForceLogout) {
        await authService.forceLogoutLocally();
      }

    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('active device session not found')) {
        final authService = PosV2AuthService();
        await authService.forceLogoutLocally();
      }
      // Ignore other network errors to avoid crashing while offline
    } finally {
      _isChecking = false;
    }
  }
}
