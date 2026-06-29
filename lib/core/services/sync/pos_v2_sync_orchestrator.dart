import '../local/database_service.dart';
import 'approval_requests_sync_adapter.dart';
import 'bootstrap_sync_adapter.dart';
import 'brands_sync_adapter.dart';
import 'categories_sync_adapter.dart';
import 'customers_sync_adapter.dart';
import 'items_sync_adapter.dart';
import 'orders_sync_adapter.dart';
import 'payments_sync_adapter.dart';
import 'promotions_sync_adapter.dart';
import 'self_order_sync_adapter.dart';
import 'service_tables_sync_adapter.dart';
import 'shift_sync_adapter.dart';
import 'staff_sync_adapter.dart';
import 'v2_sync_context.dart';
import 'v2_sync_result.dart';

class PosV2SyncOrchestrator {
  PosV2SyncOrchestrator({DatabaseService? databaseService})
    : databaseService = databaseService ?? DatabaseService.instance,
      _bootstrap = BootstrapSyncAdapter(databaseService: databaseService),
      _brands = BrandsSyncAdapter(databaseService: databaseService),
      _categories = CategoriesSyncAdapter(databaseService: databaseService),
      _items = ItemsSyncAdapter(databaseService: databaseService),
      _customers = CustomersSyncAdapter(databaseService: databaseService),
      _orders = OrdersSyncAdapter(databaseService: databaseService),
      _payments = PaymentsSyncAdapter(databaseService: databaseService),
      _shift = ShiftSyncAdapter(databaseService: databaseService),
      _staff = StaffSyncAdapter(databaseService: databaseService),
      _selfOrder = SelfOrderSyncAdapter(databaseService: databaseService),
      _promotions = PromotionsSyncAdapter(databaseService: databaseService),
      _serviceTables = ServiceTablesSyncAdapter(
        databaseService: databaseService,
      ),
      _approvals = ApprovalRequestsSyncAdapter(
        databaseService: databaseService,
      );

  final DatabaseService databaseService;
  final BootstrapSyncAdapter _bootstrap;
  final BrandsSyncAdapter _brands;
  final CategoriesSyncAdapter _categories;
  final ItemsSyncAdapter _items;
  final CustomersSyncAdapter _customers;
  final OrdersSyncAdapter _orders;
  final PaymentsSyncAdapter _payments;
  final ShiftSyncAdapter _shift;
  final StaffSyncAdapter _staff;
  final SelfOrderSyncAdapter _selfOrder;
  final PromotionsSyncAdapter _promotions;
  final ServiceTablesSyncAdapter _serviceTables;
  final ApprovalRequestsSyncAdapter _approvals;

  Future<V2SyncResult> syncBootstrap(V2SyncContext context) {
    return _bootstrap.sync(context);
  }

  Future<V2SyncResult> syncItems(
    V2SyncContext context, {
    Map<String, dynamic>? query,
  }) {
    return _items.sync(context, query: query);
  }

  Future<V2SyncResult> syncBrands(V2SyncContext context) {
    return _brands.sync(context);
  }

  Future<V2SyncResult> syncCategories(V2SyncContext context) {
    return _categories.sync(context);
  }

  Future<V2SyncResult> syncCustomers(
    V2SyncContext context, {
    Map<String, dynamic>? query,
  }) {
    return _customers.sync(context, query: query);
  }

  Future<V2SyncResult> syncOrders(
    V2SyncContext context, {
    Map<String, dynamic>? query,
    bool pullDetails = false,
    int detailLimit = 25,
  }) {
    return _orders.sync(
      context,
      query: query,
      pullDetails: pullDetails,
      detailLimit: detailLimit,
    );
  }

  Future<V2SyncResult> syncOrderDetail(V2SyncContext context, String orderId) {
    return _orders.syncDetail(context, orderId);
  }

  Future<V2SyncResult> syncPayments(
    V2SyncContext context, {
    Map<String, dynamic>? query,
  }) {
    return _payments.sync(context, query: query);
  }

  Future<V2SyncResult> syncShiftSessions(
    V2SyncContext context, {
    Map<String, dynamic>? query,
  }) {
    return _shift.sync(context, query: query);
  }

  Future<V2SyncResult> syncStaff(V2SyncContext context) {
    return _staff.sync(context);
  }

  Future<V2SyncResult> syncActiveShiftForContext(V2SyncContext context) {
    return _shift.sync(
      context,
      path: 'api/v2/pos-shift-sessions/active',
      query: <String, dynamic>{
        if (context.staffId?.isNotEmpty == true)
          'pos_staff_id': context.staffId,
        if (context.deviceId?.isNotEmpty == true) 'device_id': context.deviceId,
        if (context.registerId?.isNotEmpty == true)
          'register_id': context.registerId,
      },
      allowNotFoundEmpty: true,
    );
  }

  Future<V2SyncResult> openShift(
    V2SyncContext context, {
    required int locationId,
    required int staffId,
    required String staffName,
    required String shiftName,
    required int openingBalance,
    String? deviceId,
    String? registerId,
  }) {
    return _shift.openShift(
      context,
      locationId: locationId,
      staffId: staffId,
      staffName: staffName,
      shiftName: shiftName,
      openingBalance: openingBalance,
      deviceId: deviceId,
      registerId: registerId,
    );
  }

  Future<V2SyncResult> closeShift(
    V2SyncContext context, {
    required int shiftRemoteId,
    required int actualCash,
    int? expectedCash,
    int? totalNonCash,
    Map<String, dynamic>? reconciliationJson,
  }) {
    return _shift.closeShift(
      context,
      shiftRemoteId: shiftRemoteId,
      actualCash: actualCash,
      expectedCash: expectedCash,
      totalNonCash: totalNonCash,
      reconciliationJson: reconciliationJson,
    );
  }

  Future<V2SyncResult> syncActiveShift(V2SyncContext context) {
    return _shift.sync(context, path: 'api/v2/pos-shift-sessions/active');
  }

  Future<V2SyncResult> syncShiftHistory(V2SyncContext context) {
    return _shift.sync(context, path: 'api/v2/pos-shift-sessions/history');
  }

  Future<V2SyncResult> syncSelfOrderSessions(
    V2SyncContext context, {
    Map<String, dynamic>? query,
  }) {
    return _selfOrder.syncSessions(context, query: query);
  }

  Future<V2SyncResult> openSelfOrderSession(
    V2SyncContext context, {
    required int locationId,
    String? tableQrToken,
    String? sourceChannel,
    String? businessDate,
    String? tableCode,
    String? orderType,
    int? createdByStaffId,
    int? queueNumber,
    String? customerName,
    String? paymentStage,
    String? status,
    Map<String, dynamic>? metadataJson,
  }) {
    return _selfOrder.open(
      context,
      locationId: locationId,
      tableQrToken: tableQrToken,
      sourceChannel: sourceChannel,
      businessDate: businessDate,
      tableCode: tableCode,
      orderType: orderType,
      createdByStaffId: createdByStaffId,
      queueNumber: queueNumber,
      customerName: customerName,
      paymentStage: paymentStage,
      status: status,
      metadataJson: metadataJson,
    );
  }

  Future<V2SyncResult> linkSelfOrderSessionOrder(
    V2SyncContext context, {
    required int sessionRemoteId,
    int? invoiceId,
    String? idPos,
    int? queueNumber,
    String? orderType,
    String? paymentStage,
    String? status,
    int? updatedByStaffId,
  }) {
    return _selfOrder.linkOrder(
      context,
      sessionRemoteId: sessionRemoteId,
      invoiceId: invoiceId,
      idPos: idPos,
      queueNumber: queueNumber,
      orderType: orderType,
      paymentStage: paymentStage,
      status: status,
      updatedByStaffId: updatedByStaffId,
    );
  }

  Future<V2SyncResult> closeSelfOrderSession(
    V2SyncContext context, {
    required int sessionRemoteId,
    int? updatedByStaffId,
    String? status,
    String? paymentStage,
    String? reason,
  }) {
    return _selfOrder.closeSession(
      context,
      sessionRemoteId: sessionRemoteId,
      updatedByStaffId: updatedByStaffId,
      status: status,
      paymentStage: paymentStage,
      reason: reason,
    );
  }

  Future<V2SyncResult> syncPromotions(
    V2SyncContext context, {
    Map<String, dynamic>? query,
    bool allowNotFoundEmpty = false,
  }) {
    return _promotions.sync(
      context,
      query: query,
      allowNotFoundEmpty: allowNotFoundEmpty,
    );
  }

  Future<V2SyncResult> syncServiceTables(
    V2SyncContext context, {
    required int actingStaffId,
    Map<String, dynamic>? query,
  }) {
    return _serviceTables.syncBackofficeList(
      context,
      actingStaffId: actingStaffId,
      query: query,
    );
  }

  Future<V2SyncResult> syncServiceTableLookup(
    V2SyncContext context, {
    String? qrToken,
    String? tableCode,
  }) {
    return _serviceTables.syncLookup(
      context,
      qrToken: qrToken,
      tableCode: tableCode,
    );
  }

  Future<V2SyncResult> syncApprovalRequests(
    V2SyncContext context, {
    Map<String, dynamic>? query,
    String path = 'api/v2/pos-approval-requests',
  }) {
    return _approvals.sync(context, query: query, path: path);
  }

  Future<V2SyncResult> resolveSelfOrderSession(
    V2SyncContext context, {
    String? accessToken,
    String? sessionCode,
    String? publicCode,
    String? queueNumber,
    String? businessDate,
    String? tableCode,
  }) {
    return _selfOrder.resolve(
      context,
      accessToken: accessToken,
      sessionCode: sessionCode,
      publicCode: publicCode,
      queueNumber: queueNumber,
      businessDate: businessDate,
      tableCode: tableCode,
    );
  }

  Future<List<V2SyncResult>> syncCoreSnapshot(
    V2SyncContext context, {
    bool pullOrderDetails = false,
  }) async {
    return <V2SyncResult>[
      await syncBootstrap(context),
      await syncBrands(context),
      await syncCategories(context),
      await syncItems(context),
      await syncPromotions(context),
      await syncStaff(context),
      await syncCustomers(context),
      await syncOrders(context, pullDetails: pullOrderDetails),
      await syncPayments(context),
      await syncShiftSessions(context),
      await syncSelfOrderSessions(context),
    ];
  }

  Future<List<V2SyncResult>> syncPartialStartup(
    V2SyncContext context, {
    int initialCatalogPages = 1,
    int initialCatalogPageSize = 500,
  }) async {
    final results = <V2SyncResult>[];
    results.add(await syncBootstrap(context));

    // Partial startup: Options, Active Shift, Categories, Promotions, Active Orders, and Products.
    results.addAll(
      await Future.wait<V2SyncResult>([
        syncActiveShiftForContext(context),
        syncCategories(context),
      ]),
    );

    results.addAll(
      await syncItemsPaged(
        context,
        baseQuery: <String, dynamic>{'status': 'active'},
        itemPerPage: initialCatalogPageSize,
        startPage: 1,
        maxPages: initialCatalogPages,
      ),
    );

    results.add(
      await syncPromotions(
        context,
        query: <String, dynamic>{
          'status': '1',
          if (context.locationId.isNotEmpty) 'id_location': context.locationId,
        },
        allowNotFoundEmpty: true,
      ),
    );

    results.add(
      await syncOrders(
        context,
        query: <String, dynamic>{'status': 'active', 'limit': 200, 'page': 1},
        pullDetails: false,
        detailLimit: 50,
      ),
    );

    return results;
  }

  Future<List<V2SyncResult>> syncRemainingMasterData(
    V2SyncContext context, {
    int remainingCatalogStartPage = 2,
    int remainingCatalogPageSize = 500,
    Duration delayBetweenCatalogPages = const Duration(milliseconds: 220),
  }) async {
    final results = <V2SyncResult>[];
    results.addAll(
      await Future.wait<V2SyncResult>([
        syncBrands(context),
        syncStaff(context),
        syncCustomers(context),
        syncShiftHistory(context),
        syncSelfOrderSessions(context),
      ]),
    );

    // History Orders
    results.add(
      await syncOrders(
        context,
        query: <String, dynamic>{'status': 'completed', 'limit': 50, 'page': 1},
        pullDetails: false,
        detailLimit: 12,
      ),
    );

    results.addAll(
      await syncItemsPaged(
        context,
        baseQuery: <String, dynamic>{'status': 'active'},
        itemPerPage: remainingCatalogPageSize,
        startPage: remainingCatalogStartPage,
        maxPages: 25,
        delayBetweenPages: delayBetweenCatalogPages,
      ),
    );
    return results;
  }

  Future<List<V2SyncResult>> syncHistoryOnDemand(
    V2SyncContext context, {
    int orderLimit = 50,
    int paymentLimit = 50,
  }) async {
    return <V2SyncResult>[
      await syncCustomers(context),
      await syncOrders(
        context,
        query: <String, dynamic>{'limit': orderLimit, 'page': 1},
        pullDetails: false,
        detailLimit: 12,
      ),
      await syncPayments(
        context,
        query: <String, dynamic>{'limit': paymentLimit, 'page': 1},
      ),
    ];
  }

  Future<List<V2SyncResult>> syncItemsPaged(
    V2SyncContext context, {
    Map<String, dynamic>? baseQuery,
    int itemPerPage = 200,
    int startPage = 1,
    int maxPages = 25,
    Duration delayBetweenPages = Duration.zero,
  }) async {
    final results = <V2SyncResult>[];
    final endPage = startPage + maxPages - 1;
    for (var page = startPage; page <= endPage; page++) {
      final query = <String, dynamic>{
        ...?baseQuery,
        'item_per_page': itemPerPage,
        'page': page,
      };

      try {
        final result = await syncItems(context, query: query);
        results.add(result);
        if (result.fetchedCount < itemPerPage) {
          break;
        }
        if (delayBetweenPages > Duration.zero && page < endPage) {
          await Future<void>.delayed(delayBetweenPages);
        }
      } catch (_) {
        if (page == 1) {
          rethrow;
        }
        break;
      }
    }
    return results;
  }
}
