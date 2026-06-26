import 'package:flutter/foundation.dart';

import '../local/database_service.dart';
import 'v2_sync_context.dart';
import '../../../app/role_access/role_manager.dart';

class PosV2RuntimeSession {
  const PosV2RuntimeSession({
    required this.tenantId,
    required this.tenantKey,
    required this.baseUrl,
    required this.authToken,
    required this.locationId,
    this.tenantCode,
    this.tenantName,
    this.deviceId,
    this.registerId,
    this.deviceName,
    this.staffId,
    this.staffEmail,
    this.staffFullName,
    this.staffRoleCode,
    this.lastBootstrapAt,
  });

  final int tenantId;
  final String tenantKey;
  final String baseUrl;
  final String authToken;
  final String locationId;
  final String? tenantCode;
  final String? tenantName;
  final String? deviceId;
  final String? registerId;
  final String? deviceName;
  final String? staffId;
  final String? staffEmail;
  final String? staffFullName;
  final String? staffRoleCode;
  final String? lastBootstrapAt;

  V2SyncContext toSyncContext() {
    return V2SyncContext(
      baseUrl: baseUrl,
      authToken: authToken,
      locationId: locationId,
      tenantCode: tenantCode,
      tenantName: tenantName,
      deviceId: deviceId,
      registerId: registerId,
      staffId: staffId,
      staffEmail: staffEmail,
      staffFullName: staffFullName,
    );
  }
}

/// A ValueNotifier that supports a silent write which updates the stored value
/// without calling notifyListeners(). Used to update lastBootstrapAt after
/// background sync without triggering UI rebuilds.
class _SilentValueNotifier<T> extends ChangeNotifier
    implements ValueListenable<T> {
  _SilentValueNotifier(this._value);

  T _value;

  @override
  T get value => _value;

  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }

  /// Update the stored value WITHOUT notifying listeners.
  void silentSet(T newValue) {
    _value = newValue;
    // Intentionally no notifyListeners() call.
  }
}

class PosV2RuntimeSessionStore {
  PosV2RuntimeSessionStore._();

  static final PosV2RuntimeSessionStore instance = PosV2RuntimeSessionStore._();

  final _sessionNotifier = _SilentValueNotifier<PosV2RuntimeSession?>(null);

  ValueListenable<PosV2RuntimeSession?> get sessionNotifier => _sessionNotifier;

  PosV2RuntimeSession? get currentSession => _sessionNotifier.value;

  /// Set a new session. If the session identity (tenant/staff/device) is the
  /// same as the current one, only lastBootstrapAt is updated silently so
  /// listeners are NOT fired (preventing UI blink from background sync).
  void setSession(PosV2RuntimeSession? session) {
    if (_isSameSession(_sessionNotifier.value, session)) {
      if (session != null &&
          _sessionNotifier.value?.lastBootstrapAt != session.lastBootstrapAt) {
        final current = _sessionNotifier.value!;
        final isCompletingInitialBootstrap =
            current.lastBootstrapAt == null && session.lastBootstrapAt != null;

        final newSession = PosV2RuntimeSession(
          tenantId: current.tenantId,
          tenantKey: current.tenantKey,
          baseUrl: current.baseUrl,
          authToken: current.authToken,
          locationId: current.locationId,
          tenantCode: current.tenantCode,
          tenantName: current.tenantName,
          deviceId: current.deviceId,
          registerId: current.registerId,
          deviceName: current.deviceName,
          staffId: current.staffId,
          staffEmail: current.staffEmail,
          staffFullName: current.staffFullName,
          staffRoleCode: current.staffRoleCode,
          lastBootstrapAt: session.lastBootstrapAt,
        );

        if (isCompletingInitialBootstrap) {
          // If this is the FIRST time bootstrap completes, we MUST notify listeners 
          // so AuthGate can navigate away from the SyncBootstrapScreen.
          _sessionNotifier.value = newSession;
        } else {
          // Silently update lastBootstrapAt in-memory without firing listeners
          // to prevent UI blinking during background syncs.
          _sessionNotifier.silentSet(newSession);
        }
      }
      return;
    }
    _sessionNotifier.value = session;
    if (session?.staffRoleCode case final roleCode?) {
      RoleManager.changeRole(RoleManager.fromCode(roleCode));
    }
  }

  Future<PosV2RuntimeSession?> restoreFromDatabase() async {
    if (kIsWeb) {
      return null;
    }

    try {
      final rows = await DatabaseService.instance.rawQuery('''
        SELECT
          app_session.tenant_id,
          app_session.base_url,
          app_session.auth_token,
          app_session.location_id,
          app_session.device_id,
          app_session.register_id,
          app_session.device_name,
          app_session.staff_remote_id,
          app_session.staff_email,
          app_session.staff_full_name,
          app_session.staff_role_code,
          app_tenant.tenant_key,
          app_tenant.tenant_code,
          app_tenant.tenant_name,
          app_tenant.last_bootstrap_at
        FROM app_session
        INNER JOIN app_tenant ON app_tenant.id = app_session.tenant_id
        WHERE app_session.status = 'active'
        ORDER BY COALESCE(app_session.updated_at, app_session.logged_in_at) DESC
        LIMIT 1
        ''');

      if (rows.isEmpty) {
        setSession(null);
        return null;
      }

      final row = rows.first;
      final tenantId = row['tenant_id'] is int
          ? row['tenant_id'] as int
          : int.tryParse(row['tenant_id'].toString());
      if (tenantId == null) {
        setSession(null);
        return null;
      }

      final session = PosV2RuntimeSession(
        tenantId: tenantId,
        tenantKey: row['tenant_key']?.toString() ?? '',
        baseUrl: row['base_url']?.toString() ?? '',
        authToken: row['auth_token']?.toString() ?? '',
        locationId: row['location_id']?.toString() ?? '',
        tenantCode: row['tenant_code']?.toString(),
        tenantName: row['tenant_name']?.toString(),
        deviceId: row['device_id']?.toString(),
        registerId: row['register_id']?.toString(),
        deviceName: row['device_name']?.toString(),
        staffId: row['staff_remote_id']?.toString(),
        staffEmail: row['staff_email']?.toString(),
        staffFullName: row['staff_full_name']?.toString(),
        staffRoleCode: row['staff_role_code']?.toString(),
        lastBootstrapAt: row['last_bootstrap_at']?.toString(),
      );

      setSession(session);
      return session;
    } catch (e) {
      setSession(null);
      return null;
    }
  }

  /// Compares session identity fields only.
  /// lastBootstrapAt is intentionally excluded — it is updated by every
  /// background bootstrap sync and must NOT cause sessionNotifier to fire,
  /// as that would trigger AuthGate to rebuild and blink back to the dashboard.
  bool _isSameSession(PosV2RuntimeSession? current, PosV2RuntimeSession? next) {
    if (identical(current, next)) {
      return true;
    }
    if (current == null || next == null) {
      return current == next;
    }
    return current.tenantId == next.tenantId &&
        current.tenantKey == next.tenantKey &&
        current.baseUrl == next.baseUrl &&
        current.locationId == next.locationId &&
        current.deviceId == next.deviceId &&
        current.registerId == next.registerId &&
        current.staffId == next.staffId &&
        current.staffEmail == next.staffEmail &&
        current.staffRoleCode == next.staffRoleCode;
  }
}
