import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/services/local/database_service.dart';
import '../../../../core/services/sync/pos_v2_runtime_session_store.dart';
import 'order_type_presenter.dart';
import 'order_type_resolver.dart';
import 'pos_order_type.dart';

export 'pos_order_type.dart';

class PosOrderTypeSnapshot {
  const PosOrderTypeSnapshot({
    this.orderTypes = const <PosOrderType>[],
    this.allOrderTypes = const <PosOrderType>[],
    this.tenantId,
    this.isLoading = false,
    this.isLoaded = false,
    this.errorMessage,
  });

  /// Active order types for POS workspace and active order creation.
  final List<PosOrderType> orderTypes;

  /// All order types (including inactive) for name resolution in historical orders.
  final List<PosOrderType> allOrderTypes;

  final int? tenantId;
  final bool isLoading;
  final bool isLoaded;
  final String? errorMessage;

  bool get hasData => orderTypes.isNotEmpty;

  PosOrderTypeSnapshot copyWith({
    List<PosOrderType>? orderTypes,
    List<PosOrderType>? allOrderTypes,
    int? tenantId,
    bool? isLoading,
    bool? isLoaded,
    String? errorMessage,
  }) {
    return PosOrderTypeSnapshot(
      orderTypes: orderTypes ?? this.orderTypes,
      allOrderTypes: allOrderTypes ?? this.allOrderTypes,
      tenantId: tenantId ?? this.tenantId,
      isLoading: isLoading ?? this.isLoading,
      isLoaded: isLoaded ?? this.isLoaded,
      errorMessage: errorMessage,
    );
  }
}

class PosOrderTypeStore {
  PosOrderTypeStore._() {
    PosV2RuntimeSessionStore.instance.sessionNotifier.addListener(refresh);
    unawaited(ensureLoaded());
  }

  static final PosOrderTypeStore instance = PosOrderTypeStore._();

  final ValueNotifier<PosOrderTypeSnapshot> snapshotNotifier =
      ValueNotifier<PosOrderTypeSnapshot>(const PosOrderTypeSnapshot());

  Completer<PosOrderTypeSnapshot>? _loadingCompleter;

  PosOrderTypeSnapshot get snapshot => snapshotNotifier.value;

  Future<PosOrderTypeSnapshot> ensureLoaded({bool forceRefresh = false}) async {
    if (!forceRefresh && snapshot.isLoaded && !snapshot.isLoading) {
      return snapshot;
    }

    if (_loadingCompleter != null) {
      return _loadingCompleter!.future;
    }

    _loadingCompleter = Completer<PosOrderTypeSnapshot>();

    snapshotNotifier.value = snapshot.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final session =
          PosV2RuntimeSessionStore.instance.currentSession ??
          await PosV2RuntimeSessionStore.instance.restoreFromDatabase();

      final tenantId = session?.tenantId;
      if (tenantId == null) {
        final result = const PosOrderTypeSnapshot(
          isLoaded: true,
          isLoading: false,
        );
        snapshotNotifier.value = result;
        _loadingCompleter?.complete(result);
        _loadingCompleter = null;
        return result;
      }

      final db = await DatabaseService.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT code, name, description, is_active
        FROM order_type
        WHERE tenant_id = ?
          AND deleted_at IS NULL
          AND code IS NOT NULL
          AND TRIM(code) != ''
        ORDER BY id ASC
        ''',
        <Object?>[tenantId],
      );

      final activeOrderTypes = <PosOrderType>[];
      final allOrderTypes = <PosOrderType>[];
      for (final row in rows) {
        final code = row['code']?.toString().trim();
        final name = row['name']?.toString().trim();
        if (code == null || code.isEmpty) continue;
        final ot = PosOrderType(
          code: code,
          name: (name != null && name.isNotEmpty) ? name : code,
          description: row['description']?.toString(),
        );
        allOrderTypes.add(ot);

        final rawIsActive = row['is_active'];
        final isActive =
            rawIsActive == 1 || rawIsActive == '1' || rawIsActive == true;
        if (isActive) {
          activeOrderTypes.add(ot);
        }
      }

      // Also auto-discover any order types defined on products or promotions
      try {
        if (db.isOpen) {
          final productOrderTypeRows = await db.rawQuery(
          '''
          SELECT DISTINCT order_type_code
          FROM product_order_type
          WHERE tenant_id = ?
            AND order_type_code IS NOT NULL
            AND TRIM(order_type_code) != ''
          ''',
          <Object?>[tenantId],
        );
        for (final row in productOrderTypeRows) {
          final code = row['order_type_code']?.toString().trim();
          if (code == null || code.isEmpty) continue;
          if (!allOrderTypes.any((ot) => ot.code.toLowerCase() == code.toLowerCase())) {
            final ot = PosOrderType(
              code: code,
              name: OrderTypePresenter.getDisplayName(code, const []),
            );
            allOrderTypes.add(ot);
            activeOrderTypes.add(ot);
          }
        }
        }
      } catch (e) {
        debugPrint('PosOrderTypeStore product_order_type discovery error: $e');
      }

      final result = PosOrderTypeSnapshot(
        orderTypes: List<PosOrderType>.unmodifiable(activeOrderTypes),
        allOrderTypes: List<PosOrderType>.unmodifiable(allOrderTypes),
        tenantId: tenantId,
        isLoading: false,
        isLoaded: true,
      );

      snapshotNotifier.value = result;
      _loadingCompleter?.complete(result);
      _loadingCompleter = null;
      return result;
    } catch (e, stackTrace) {
      debugPrint('PosOrderTypeStore load error: $e\n$stackTrace');
      final result = snapshot.copyWith(
        isLoading: false,
        isLoaded: true,
        errorMessage: e.toString(),
      );
      snapshotNotifier.value = result;
      _loadingCompleter?.complete(result);
      _loadingCompleter = null;
      return result;
    }
  }

  void refresh() {
    ensureLoaded(forceRefresh: true);
  }

  PosOrderType? findByCode(String? code, {bool includeInactive = true}) {
    if (code == null || code.trim().isEmpty) return null;
    final normalized = code.trim().toLowerCase();
    final canonical = OrderTypeResolver.legacyCodeMap[normalized] ?? normalized;
    final source = includeInactive
        ? (snapshot.allOrderTypes.isNotEmpty
              ? snapshot.allOrderTypes
              : snapshot.orderTypes)
        : snapshot.orderTypes;
    for (final ot in source) {
      final otCode = ot.code.trim().toLowerCase();
      if (otCode == normalized || otCode == canonical) {
        return ot;
      }
    }
    return null;
  }

  String reconcileSelectedOrderType(
    String? currentSelected, {
    String fallback = 'dinein',
  }) {
    return OrderTypeResolver.reconcileSelected(
      currentSelected: currentSelected,
      activeTypes: snapshot.orderTypes,
      fallback: fallback,
    );
  }
}
