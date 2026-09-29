part of 'report_read_stores.dart';

// Top customers and promo sales reports. These are `part` of the report
// stores library so they can share its private period/session helpers.

// ── Top customers ───────────────────────────────────────────────────────────

class TopCustomerRecord {
  const TopCustomerRecord({
    required this.key,
    required this.name,
    required this.isWalkIn,
    required this.visitCount,
    required this.totalSpent,
    this.phone,
    this.lastOrderAt,
  });

  final String key;
  final String name;
  final String? phone;
  final bool isWalkIn;
  final int visitCount;
  final int totalSpent;
  final DateTime? lastOrderAt;

  int get averageSpent =>
      visitCount == 0 ? 0 : (totalSpent / visitCount).round();
}

class TopCustomersSnapshot {
  const TopCustomersSnapshot({
    required this.isLoading,
    required this.period,
    required this.customers,
    this.errorMessage,
  });

  final bool isLoading;
  final String period;
  final List<TopCustomerRecord> customers;
  final String? errorMessage;

  TopCustomersSnapshot copyWith({
    bool? isLoading,
    String? period,
    List<TopCustomerRecord>? customers,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TopCustomersSnapshot(
      isLoading: isLoading ?? this.isLoading,
      period: period ?? this.period,
      customers: customers ?? this.customers,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class TopCustomersReportStore {
  TopCustomersReportStore._();

  static final TopCustomersReportStore instance = TopCustomersReportStore._();

  /// Anonymous checkouts are one bucket: every walk-in order shares the same
  /// customer record (remote id `1`) or has none at all.
  static const String walkInKey = 'walk-in';
  static const String walkInName = 'Pelanggan Umum (Walk-in)';

  final ValueNotifier<TopCustomersSnapshot> snapshotNotifier =
      ValueNotifier<TopCustomersSnapshot>(
        const TopCustomersSnapshot(
          isLoading: false,
          period: 'month',
          customers: <TopCustomerRecord>[],
        ),
      );

  Future<void> refresh({String? period}) async {
    final nextPeriod = period ?? snapshotNotifier.value.period;
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      period: nextPeriod,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final startDate = _formatSqlDate(_startDateForPeriod(nextPeriod));
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT CASE WHEN COALESCE(o.customer_remote_id, '') IN ('', '1')
                    THEN '$walkInKey'
                    ELSE o.customer_remote_id END AS customer_key,
               MAX(c.display_name) AS customer_name,
               MAX(c.phone_number) AS customer_phone,
               COUNT(*) AS visit_count,
               COALESCE(SUM(o.total_amount), 0) AS total_spent,
               MAX(COALESCE(NULLIF(o.order_date, ''), o.created_at)) AS last_order_at
        FROM pos_order o
        LEFT JOIN customer c ON c.id = o.customer_id
        WHERE o.tenant_id = ?
          AND (o.status_code IN ('2', '4', 2, 4) OR LOWER(CAST(o.status_code AS TEXT)) IN ('paid', 'completed'))
          AND o.deleted_at IS NULL
          AND COALESCE(NULLIF(o.order_date, ''), o.created_at) >= ?
        GROUP BY customer_key
        ORDER BY total_spent DESC
        LIMIT 500
        ''',
        <Object?>[session.tenantId, startDate],
      );

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        customers: rows
            .map((row) {
              final key = row['customer_key']?.toString() ?? walkInKey;
              final isWalkIn = key == walkInKey;
              return TopCustomerRecord(
                key: key,
                isWalkIn: isWalkIn,
                name: isWalkIn
                    ? walkInName
                    : (_nullableEmpty(row['customer_name']?.toString()) ??
                          'Pelanggan #$key'),
                phone: isWalkIn
                    ? null
                    : _nullableEmpty(row['customer_phone']?.toString()),
                visitCount: _asInt(row['visit_count']) ?? 0,
                totalSpent: _asInt(row['total_spent']) ?? 0,
                lastOrderAt: _parseDateTime(row['last_order_at']),
              );
            })
            .toList(growable: false),
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

// ── Promo sales ─────────────────────────────────────────────────────────────

class PromoSalesOrderRecord {
  const PromoSalesOrderRecord({
    required this.orderId,
    required this.label,
    required this.totalAmount,
    required this.subtotalAmount,
    required this.discountAmount,
    this.orderedAt,
  });

  final int orderId;
  final String label;
  final DateTime? orderedAt;
  final int subtotalAmount;
  final int totalAmount;

  /// The part of the discount that came from the promo this row belongs to.
  final int discountAmount;
}

class PromoSalesRecord {
  const PromoSalesRecord({
    required this.key,
    required this.name,
    required this.type,
    required this.orders,
  });

  final String key;
  final String name;
  final String type;
  final List<PromoSalesOrderRecord> orders;

  int get orderCount => orders.length;
  int get totalDiscount => orders.fold(0, (sum, o) => sum + o.discountAmount);
  int get netSales => orders.fold(0, (sum, o) => sum + o.totalAmount);
}

class PromoSalesSnapshot {
  const PromoSalesSnapshot({
    required this.isLoading,
    required this.period,
    required this.promos,
    this.promoOrderCount = 0,
    this.totalDiscount = 0,
    this.promoNetSales = 0,
    this.errorMessage,
  });

  final bool isLoading;
  final String period;
  final List<PromoSalesRecord> promos;

  /// Distinct orders that used at least one promo, so an order carrying two
  /// promos is counted once here even though it appears under both.
  final int promoOrderCount;
  final int totalDiscount;
  final int promoNetSales;
  final String? errorMessage;

  PromoSalesSnapshot copyWith({
    bool? isLoading,
    String? period,
    List<PromoSalesRecord>? promos,
    int? promoOrderCount,
    int? totalDiscount,
    int? promoNetSales,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PromoSalesSnapshot(
      isLoading: isLoading ?? this.isLoading,
      period: period ?? this.period,
      promos: promos ?? this.promos,
      promoOrderCount: promoOrderCount ?? this.promoOrderCount,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      promoNetSales: promoNetSales ?? this.promoNetSales,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class _OrderPromo {
  const _OrderPromo({
    required this.promotionId,
    required this.name,
    required this.type,
    required this.discountAmount,
  });

  final String promotionId;
  final String name;
  final String type;
  final int discountAmount;
}

class _PromoAccumulator {
  _PromoAccumulator(this.key, this.name, this.type);

  final String key;
  final String name;
  final String type;
  final List<PromoSalesOrderRecord> orders = <PromoSalesOrderRecord>[];
}

class PromoSalesReportStore {
  PromoSalesReportStore._();

  static final PromoSalesReportStore instance = PromoSalesReportStore._();

  final ValueNotifier<PromoSalesSnapshot> snapshotNotifier =
      ValueNotifier<PromoSalesSnapshot>(
        const PromoSalesSnapshot(
          isLoading: false,
          period: 'month',
          promos: <PromoSalesRecord>[],
        ),
      );

  Future<void> refresh({String? period}) async {
    final nextPeriod = period ?? snapshotNotifier.value.period;
    snapshotNotifier.value = snapshotNotifier.value.copyWith(
      isLoading: true,
      period: nextPeriod,
      clearError: true,
    );

    try {
      final session = await _requireSession();
      final startDate = _formatSqlDate(_startDateForPeriod(nextPeriod));
      // Only orders that mention a promo are pulled, since raw payloads are
      // large. The LIKE patterns match how jsonEncode writes the two sources.
      final rows = await DatabaseService.instance.rawQuery(
        '''
        SELECT o.id,
               COALESCE(NULLIF(o.formatted_number, ''), NULLIF(o.invoice_number, ''), o.id_pos, '#' || o.id) AS label,
               COALESCE(NULLIF(o.order_date, ''), o.created_at) AS ordered_at,
               o.subtotal_amount,
               o.total_amount,
               o.raw_payload_json,
               o.custom_fields_json
        FROM pos_order o
        WHERE o.tenant_id = ?
          AND (o.status_code IN ('2', '4', 2, 4) OR LOWER(CAST(o.status_code AS TEXT)) IN ('paid', 'completed'))
          AND o.deleted_at IS NULL
          AND COALESCE(NULLIF(o.order_date, ''), o.created_at) >= ?
          AND (o.raw_payload_json LIKE '%"promotions":[{%'
               OR o.custom_fields_json LIKE '%"order_promotion"%')
        ORDER BY ordered_at DESC
        ''',
        <Object?>[session.tenantId, startDate],
      );

      final promos = buildPromoRecords(rows);
      final distinctOrders = <int, int>{};
      var totalDiscount = 0;
      for (final promo in promos) {
        totalDiscount += promo.totalDiscount;
        for (final order in promo.orders) {
          distinctOrders[order.orderId] = order.totalAmount;
        }
      }

      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        promos: promos,
        promoOrderCount: distinctOrders.length,
        totalDiscount: totalDiscount,
        promoNetSales: distinctOrders.values.fold<int>(0, (sum, v) => sum + v),
      );
    } catch (error) {
      snapshotNotifier.value = snapshotNotifier.value.copyWith(
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Items of one order, for the promo drill-down.
  Future<List<String>> loadOrderItems(int orderId) async {
    final rows = await DatabaseService.instance.rawQuery(
      '''
      SELECT product_name_snapshot AS name, qty
      FROM pos_order_item
      WHERE order_id = ? AND deleted_at IS NULL
      ORDER BY sort_order, id
      ''',
      <Object?>[orderId],
    );
    return rows
        .map((row) {
          final qty = _asInt(row['qty']) ?? 0;
          return '${qty}x ${row['name'] ?? '-'}';
        })
        .toList(growable: false);
  }

  /// Groups per-order promo usage into one record per promotion, biggest
  /// discount first. Exposed for tests.
  static List<PromoSalesRecord> buildPromoRecords(
    List<Map<String, Object?>> rows,
  ) {
    final byKey = <String, _PromoAccumulator>{};

    for (final row in rows) {
      final orderId = _asInt(row['id']);
      if (orderId == null) continue;

      final promos = _parseOrderPromos(
        row['raw_payload_json'],
        row['custom_fields_json'],
      );
      for (final promo in promos) {
        final key = promo.promotionId.isNotEmpty
            ? 'id:${promo.promotionId}'
            : 'name:${promo.name}';
        final accumulator = byKey.putIfAbsent(
          key,
          () => _PromoAccumulator(key, promo.name, promo.type),
        );
        accumulator.orders.add(
          PromoSalesOrderRecord(
            orderId: orderId,
            label: row['label']?.toString() ?? '#$orderId',
            orderedAt: _parseDateTime(row['ordered_at']),
            subtotalAmount: _asInt(row['subtotal_amount']) ?? 0,
            totalAmount: _asInt(row['total_amount']) ?? 0,
            discountAmount: promo.discountAmount,
          ),
        );
      }
    }

    final records = byKey.values
        .map(
          (a) => PromoSalesRecord(
            key: a.key,
            name: a.name,
            type: a.type,
            orders: a.orders,
          ),
        )
        .toList();
    records.sort((a, b) => b.totalDiscount.compareTo(a.totalDiscount));
    return records;
  }

  /// Server rows carry the authoritative `promotions` list. Orders that were
  /// rung up here but not yet re-synced (or synced before promos were sent)
  /// only have the local `order_promotion` custom field.
  static List<_OrderPromo> _parseOrderPromos(
    Object? rawPayload,
    Object? customFields,
  ) {
    final fromServer = _promosFromServerPayload(rawPayload);
    if (fromServer.isNotEmpty) return fromServer;
    return _promosFromCustomFields(customFields);
  }

  static List<_OrderPromo> _promosFromServerPayload(Object? rawPayload) {
    final list = _decodeJsonMap(rawPayload)?['promotions'];
    if (list is! List) return const <_OrderPromo>[];

    final promos = <_OrderPromo>[];
    for (final entry in list) {
      if (entry is! Map) continue;
      final id = entry['promotion_id']?.toString().trim() ?? '';
      final name =
          _nullableEmpty(
            (entry['promo_name_snapshot'] ??
                    entry['promo_name'] ??
                    entry['name'])
                ?.toString(),
          ) ??
          (id.isEmpty ? 'Promo' : 'Promo #$id');
      promos.add(
        _OrderPromo(
          promotionId: id,
          name: name,
          type:
              _nullableEmpty(
                (entry['promo_type_snapshot'] ?? entry['promo_type'])
                    ?.toString(),
              ) ??
              '',
          discountAmount: _asInt(entry['discount_amount']) ?? 0,
        ),
      );
    }
    return promos;
  }

  static List<_OrderPromo> _promosFromCustomFields(Object? customFields) {
    final promotion = _decodeJsonMap(customFields)?['order_promotion'];
    if (promotion is! Map) return const <_OrderPromo>[];

    List<String> split(Object? value) => (value?.toString() ?? '')
        .split(',')
        .map((part) => part.trim())
        .toList(growable: false);

    final ids = split(promotion['remote_id']);
    final names = split(promotion['name']);
    final types = split(promotion['promo_type']);
    final amounts = split(promotion['discount_amounts']);
    final wholeName = _nullableEmpty(promotion['name']?.toString());
    final wholeType = _nullableEmpty(promotion['promo_type']?.toString());

    final promos = <_OrderPromo>[];
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      if (id.isEmpty) continue;
      // Names are comma-joined and may themselves contain commas, so they are
      // only split when the counts line up with the ids.
      final String name;
      final String type;
      if (ids.length == 1) {
        name = wholeName ?? 'Promo #$id';
        type = wholeType ?? '';
      } else {
        name = names.length == ids.length && names[i].isNotEmpty
            ? names[i]
            : 'Promo #$id';
        type = types.length == ids.length ? types[i] : '';
      }
      promos.add(
        _OrderPromo(
          promotionId: id,
          name: name,
          type: type,
          discountAmount: i < amounts.length ? (_asInt(amounts[i]) ?? 0) : 0,
        ),
      );
    }
    return promos;
  }

  static Map<String, dynamic>? _decodeJsonMap(Object? raw) {
    final text = raw?.toString();
    if (text == null || text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
