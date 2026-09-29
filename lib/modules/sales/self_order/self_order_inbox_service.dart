import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/printing/models/printer_render_models.dart';
import '../../../core/printing/services/printer_rendering_service.dart';
import '../../../core/printing/services/printer_transport_service.dart';
import '../../../core/services/local/database_service.dart';
import '../../../core/services/sync/pos_v2_runtime_session_store.dart';
import '../../../core/services/sync/pos_v2_sync_orchestrator.dart';
import '../../settings/printers/controllers/printer_settings_controller.dart';
import '../shared/models/sales_order_store.dart';

/// One line of an order a customer placed from a table QR.
class SelfOrderLine {
  const SelfOrderLine({
    required this.name,
    required this.quantity,
    this.note,
    this.brandRemoteId,
  });

  final String name;
  final int quantity;
  final String? note;
  final String? brandRemoteId;
}

/// A customer order (or top-up to one) that the cashier should look at.
class SelfOrderAlert {
  SelfOrderAlert({
    required this.sessionRemoteId,
    required this.orderRemoteId,
    required this.tableCode,
    required this.isUpdate,
    required this.lines,
    required this.newLines,
    required this.totalAmount,
    required this.receivedAt,
    this.orderNote,
    this.kitchenStatus = 'Belum dicetak',
  });

  final String sessionRemoteId;
  final String orderRemoteId;
  final String tableCode;

  /// True when the customer added items to an order that already existed.
  final bool isUpdate;
  final List<SelfOrderLine> lines;

  /// Lines that are new since the cashier last saw this order.
  final List<SelfOrderLine> newLines;
  final int totalAmount;
  final DateTime receivedAt;
  final String? orderNote;
  String kitchenStatus;

  String get key => '$sessionRemoteId:${receivedAt.microsecondsSinceEpoch}';
  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);
  String get title =>
      tableCode.isEmpty ? 'Pesanan pelanggan' : 'Meja $tableCode';
}

/// Watches for orders customers submit through the table QR page.
///
/// The page creates an unpaid invoice on the server and links it to a
/// self-order session. Nothing pushes that to the tablet, so this polls the
/// (small) sessions table, pulls the linked order, and raises an alert plus a
/// kitchen ticket for what is new.
class SelfOrderInboxService {
  SelfOrderInboxService._({
    PosV2SyncOrchestrator? orchestrator,
    DatabaseService? databaseService,
  }) : _orchestrator = orchestrator ?? PosV2SyncOrchestrator(),
       _db = databaseService ?? DatabaseService.instance;

  static final SelfOrderInboxService instance = SelfOrderInboxService._();

  @visibleForTesting
  factory SelfOrderInboxService.forTesting({
    required PosV2SyncOrchestrator orchestrator,
    required DatabaseService databaseService,
  }) => SelfOrderInboxService._(
    orchestrator: orchestrator,
    databaseService: databaseService,
  );

  static const Duration _activeInterval = Duration(seconds: 20);
  static const Duration _idleInterval = Duration(seconds: 60);
  static const int _idlePollsBeforeSlowing = 6;

  final PosV2SyncOrchestrator _orchestrator;
  final DatabaseService _db;

  final List<Future<void>> _inflight = <Future<void>>[];

  /// Waits for kitchen prints started by earlier polls. For tests.
  @visibleForTesting
  Future<void> settle() async {
    await Future.wait(List<Future<void>>.of(_inflight));
    _inflight.clear();
  }

  final ValueNotifier<List<SelfOrderAlert>> alerts =
      ValueNotifier<List<SelfOrderAlert>>(const <SelfOrderAlert>[]);

  Timer? _timer;
  bool _running = false;
  int _emptyPolls = 0;

  void start() {
    if (_timer != null) return;
    _schedule(const Duration(seconds: 3));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    alerts.value = const <SelfOrderAlert>[];
    _emptyPolls = 0;
  }

  void dismiss(SelfOrderAlert alert) {
    alerts.value = alerts.value
        .where((a) => a.key != alert.key)
        .toList(growable: false);
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () async {
      try {
        await pollOnce();
      } catch (error) {
        debugPrint('[SELF_ORDER] poll failed: $error');
      }
      if (_timer != null) {
        _schedule(
          _emptyPolls >= _idlePollsBeforeSlowing
              ? _idleInterval
              : _activeInterval,
        );
      }
    });
  }

  /// Runs one poll. Returns the alerts raised by it. Exposed for tests.
  Future<List<SelfOrderAlert>> pollOnce({DateTime? now}) async {
    if (_running) return const <SelfOrderAlert>[];
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null || session.authToken.trim().isEmpty) {
      return const <SelfOrderAlert>[];
    }

    _running = true;
    try {
      final context = session.toSyncContext();
      final before = await _knownSessions(session.tenantId);
      final isBaseline = !await _hasBaseline(session.tenantId);

      final synced = await _orchestrator.syncSelfOrderSessions(
        context,
        query: const <String, dynamic>{'status': 'submitted', 'limit': 50},
      );

      final open = await _openSessions(session.tenantId);
      final today = now ?? DateTime.now();
      final candidates = open.where((row) {
        if (!_isRecent(row['business_date']?.toString(), today)) return false;
        final previous = before[row['remote_id']?.toString()];
        return previous == null || previous != _fingerprint(row);
      }).toList();

      _emptyPolls = synced.fetchedCount == 0 ? _emptyPolls + 1 : 0;
      if (isBaseline) await _markBaseline(session.tenantId);
      if (candidates.isEmpty) return const <SelfOrderAlert>[];

      final raised = <SelfOrderAlert>[];
      for (final row in candidates) {
        final alert = await _ingest(session, context, row, before, today);
        if (alert != null) raised.add(alert);
      }

      if (raised.isNotEmpty) {
        await SalesOrderStore.instance.refreshFromPersistence();
        alerts.value = <SelfOrderAlert>[...raised, ...alerts.value];
        unawaited(SystemSound.play(SystemSoundType.alert));
        unawaited(HapticFeedback.heavyImpact());
        for (final alert in raised) {
          if (isBaseline) {
            // First look at this outlet on this device: whatever is open now
            // was placed before we were watching and is likely already made.
            alert.kitchenStatus = 'Pesanan lama - tidak dicetak otomatis';
          } else {
            _inflight.add(_printKitchen(alert));
          }
        }
      }
      return raised;
    } finally {
      _running = false;
    }
  }

  Future<SelfOrderAlert?> _ingest(
    PosV2RuntimeSession session,
    dynamic context,
    Map<String, Object?> sessionRow,
    Map<String?, String> before,
    DateTime now,
  ) async {
    final orderRemoteId = sessionRow['current_order_remote_id']?.toString();
    if (orderRemoteId == null || orderRemoteId.isEmpty) return null;

    final previousLines = await _orderLines(session.tenantId, orderRemoteId);
    try {
      await _orchestrator.syncOrderDetail(context, orderRemoteId);
    } catch (error) {
      debugPrint('[SELF_ORDER] order $orderRemoteId not pulled: $error');
      return null;
    }
    final lines = await _orderLines(session.tenantId, orderRemoteId);
    if (lines.isEmpty) return null;

    final isUpdate = previousLines.isNotEmpty;
    final fresh = isUpdate ? diffLines(previousLines, lines) : lines;
    // A change that only touched the session (e.g. status) adds nothing new.
    if (isUpdate && fresh.isEmpty) return null;

    final header = await _orderHeader(session.tenantId, orderRemoteId);
    return SelfOrderAlert(
      sessionRemoteId: sessionRow['remote_id']?.toString() ?? '',
      orderRemoteId: orderRemoteId,
      tableCode: (sessionRow['table_code']?.toString() ?? '').toUpperCase(),
      isUpdate: isUpdate,
      lines: lines,
      newLines: fresh,
      totalAmount: header?['total_amount'] is int
          ? header!['total_amount'] as int
          : int.tryParse('${header?['total_amount']}') ?? 0,
      receivedAt: now,
      orderNote: _firstNonEmpty([
        header?['order_note'],
        header?['client_note'],
      ]),
    );
  }

  /// Quantities that grew between two snapshots of the same order.
  static List<SelfOrderLine> diffLines(
    List<SelfOrderLine> before,
    List<SelfOrderLine> after,
  ) {
    final previous = <String, int>{};
    for (final line in before) {
      previous[line.name] = (previous[line.name] ?? 0) + line.quantity;
    }
    final added = <SelfOrderLine>[];
    final consumed = <String, int>{};
    for (final line in after) {
      final alreadySeen = previous[line.name] ?? 0;
      final usedSoFar = consumed[line.name] ?? 0;
      final available = (alreadySeen - usedSoFar).clamp(0, line.quantity);
      consumed[line.name] = usedSoFar + available;
      final delta = line.quantity - available;
      if (delta > 0) {
        added.add(
          SelfOrderLine(
            name: line.name,
            quantity: delta,
            note: line.note,
            brandRemoteId: line.brandRemoteId,
          ),
        );
      }
    }
    return added;
  }

  static const String _baselineEndpoint = 'self_order_inbox';

  Future<bool> _hasBaseline(int tenantId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT 1 FROM sync_checkpoint
      WHERE tenant_id = ? AND endpoint_name = ? AND scope_key = 'baseline'
      LIMIT 1
      ''',
      <Object?>[tenantId, _baselineEndpoint],
    );
    return rows.isNotEmpty;
  }

  Future<void> _markBaseline(int tenantId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      await txn.rawInsert(
        '''
        INSERT OR IGNORE INTO sync_checkpoint
          (tenant_id, endpoint_name, scope_key, last_success_at, last_attempt_at, notes)
        VALUES (?, ?, 'baseline', ?, ?, 'First self-order poll on this device.')
        ''',
        <Object?>[tenantId, _baselineEndpoint, now, now],
      );
    });
  }

  bool _isRecent(String? businessDate, DateTime now) {
    final parsed = DateTime.tryParse(businessDate ?? '');
    if (parsed == null) return true;
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    return today.difference(day).inDays.abs() <= 1;
  }

  String _fingerprint(Map<String, Object?> row) =>
      '${row['last_activity_at']}|${row['current_order_remote_id']}';

  Future<Map<String?, String>> _knownSessions(int tenantId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT remote_id, last_activity_at, current_order_remote_id
      FROM self_order_session
      WHERE tenant_id = ? AND deleted_at IS NULL AND status = 'submitted'
      ''',
      <Object?>[tenantId],
    );
    return <String?, String>{
      for (final row in rows) row['remote_id']?.toString(): _fingerprint(row),
    };
  }

  Future<List<Map<String, Object?>>> _openSessions(int tenantId) {
    return _db.rawQuery(
      '''
      SELECT remote_id, table_code, business_date, last_activity_at,
             current_order_remote_id
      FROM self_order_session
      WHERE tenant_id = ? AND deleted_at IS NULL AND status = 'submitted'
        AND COALESCE(current_order_remote_id, '') != ''
      ORDER BY last_activity_at
      ''',
      <Object?>[tenantId],
    );
  }

  Future<List<SelfOrderLine>> _orderLines(
    int tenantId,
    String orderRemoteId,
  ) async {
    final rows = await _db.rawQuery(
      '''
      SELECT i.product_name_snapshot AS name, i.qty, i.note,
             i.brand_remote_id_snapshot AS brand
      FROM pos_order_item i
      INNER JOIN pos_order o ON o.id = i.order_id
      WHERE o.tenant_id = ? AND o.remote_id = ?
        AND i.deleted_at IS NULL AND o.deleted_at IS NULL
      ORDER BY i.sort_order, i.id
      ''',
      <Object?>[tenantId, orderRemoteId],
    );
    return rows
        .map(
          (row) => SelfOrderLine(
            name: row['name']?.toString() ?? '-',
            quantity: (num.tryParse('${row['qty']}') ?? 0).round(),
            note: _firstNonEmpty([row['note']]),
            brandRemoteId: _firstNonEmpty([row['brand']]),
          ),
        )
        .where((line) => line.quantity > 0)
        .toList(growable: false);
  }

  Future<Map<String, Object?>?> _orderHeader(
    int tenantId,
    String orderRemoteId,
  ) async {
    final rows = await _db.rawQuery(
      '''
      SELECT total_amount, order_note, client_note
      FROM pos_order
      WHERE tenant_id = ? AND remote_id = ? AND deleted_at IS NULL
      LIMIT 1
      ''',
      <Object?>[tenantId, orderRemoteId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  Future<bool> _kitchenPrintEnabled() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return true;
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT option_value_text FROM pos_option
        WHERE tenant_id = ? AND option_name = 'pos_self_order_settings'
        LIMIT 1
        ''',
        <Object?>[session.tenantId],
      );
      if (rows.isEmpty) return true;
      final decoded = jsonDecode(
        rows.first['option_value_text']?.toString() ?? '',
      );
      if (decoded is Map && decoded['kitchen_print_on_each_submit'] != null) {
        final value = decoded['kitchen_print_on_each_submit'];
        return value == true || value == 1 || value == '1' || value == 'true';
      }
    } catch (_) {}
    return true;
  }

  /// Prints the new lines of [alert] to every kitchen printer on this device.
  /// With [all] set it prints the whole order (used for manual reprints).
  Future<void> printKitchen(SelfOrderAlert alert, {bool all = false}) async {
    await _printKitchen(alert, all: all, force: all);
  }

  Future<void> _printKitchen(
    SelfOrderAlert alert, {
    bool all = false,
    bool force = false,
  }) async {
    try {
      if (!force && !await _kitchenPrintEnabled()) {
        alert.kitchenStatus = 'Cetak otomatis dimatikan';
        _touch();
        return;
      }

      await PrinterSettingsController.instance.refresh(silent: true);
      final printers = PrinterSettingsController
          .instance
          .stateNotifier
          .value
          .printers
          .where((p) => p.isActive && p.roles.contains('kitchen'))
          .toList();
      if (printers.isEmpty) {
        alert.kitchenStatus = 'Tidak ada printer dapur';
        _touch();
        return;
      }

      final brands = await _brandNames();
      final lines = all ? alert.lines : alert.newLines;
      var printed = false;
      final failures = <String>[];

      for (final printer in printers) {
        final allowed = printer.roleBrandFilters['kitchen'] ?? <String>[];
        final forPrinter = lines.where((line) {
          if (allowed.isEmpty) return true;
          final brand = brands[line.brandRemoteId];
          return brand == null || allowed.contains(brand);
        }).toList();
        if (forPrinter.isEmpty) continue;

        final doc = PrinterDocumentData(
          type: PrinterDocumentType.kitchenTicket,
          title: alert.isUpdate && !all
              ? 'TIKET DAPUR (TAMBAHAN)'
              : 'TIKET DAPUR (${printer.displayName})',
          subtitle: 'Pesan Mandiri - ${alert.title}',
          infoRows: [
            PrinterInfoRow(label: 'Meja', value: alert.tableCode),
            PrinterInfoRow(label: 'Waktu', value: _clock(alert.receivedAt)),
            if (alert.orderNote != null)
              PrinterInfoRow(label: 'Catatan', value: alert.orderNote!),
          ],
          items: [
            for (final line in forPrinter)
              PrinterLineItem(
                label: line.name,
                quantity: line.quantity,
                note: line.note,
              ),
          ],
          footerLines: const ['Sinkronisasi Dapur FlinkPOS'],
        );

        try {
          final output = await PrinterRenderingService.instance.render(
            printer,
            doc,
          );
          final result = await PrinterTransportService.instance.dispatch(
            printer,
            output,
          );
          if (result.success) {
            printed = true;
          } else {
            failures.add(
              '${printer.displayName}: ${result.message ?? 'gagal'}',
            );
          }
        } catch (error) {
          failures.add('${printer.displayName}: $error');
        }
      }

      alert.kitchenStatus = failures.isNotEmpty
          ? 'Gagal cetak dapur (${failures.first})'
          : printed
          ? 'Tiket dapur tercetak'
          : 'Tidak ada item untuk printer dapur';
    } catch (error) {
      alert.kitchenStatus = 'Gagal cetak dapur ($error)';
    }
    _touch();
  }

  Future<Map<String?, String>> _brandNames() async {
    final session = PosV2RuntimeSessionStore.instance.currentSession;
    if (session == null) return const <String?, String>{};
    try {
      final rows = await _db.rawQuery(
        'SELECT remote_id, name FROM brand WHERE tenant_id = ?',
        <Object?>[session.tenantId],
      );
      return <String?, String>{
        for (final row in rows)
          row['remote_id']?.toString(): row['name']?.toString() ?? '',
      };
    } catch (_) {
      return const <String?, String>{};
    }
  }

  /// Re-publishes the list so listeners rebuild after a status change.
  void _touch() {
    alerts.value = List<SelfOrderAlert>.of(alerts.value);
  }

  String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
