// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get posTitle => 'POS';

  @override
  String get activeOrdersTitle => 'Active Orders';

  @override
  String get resumeOrderTitle => 'Resume Order';

  @override
  String get historyTitle => 'History';

  @override
  String get searchPlaceholder => 'Search by ID or Customer...';

  @override
  String get newOrder => 'New Order';

  @override
  String ordersFound(int count) {
    return '$count orders found';
  }

  @override
  String get overview => 'Overview';

  @override
  String get sales => 'Sales';

  @override
  String get operations => 'Operations';

  @override
  String get reports => 'Reports';

  @override
  String get masterData => 'Master Data';

  @override
  String get settings => 'Settings';

  @override
  String comingSoon(String title) {
    return '$title Coming Soon';
  }

  @override
  String get all => 'All';

  @override
  String get promo => 'Promo';

  @override
  String get chooseTable => 'Choose Table';

  @override
  String ordersWithCount(int count) {
    return 'Orders $count';
  }

  @override
  String get orders => 'Orders';

  @override
  String get customer => 'Customer';

  @override
  String get walkInCustomer => 'Walk-In Customer';

  @override
  String get dineIn => 'Dine In';

  @override
  String get orderNote => 'Order Note';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get tax => 'Tax';

  @override
  String get discount => 'Discount';

  @override
  String get totalPay => 'Total Pay';

  @override
  String get sendToKitchen => 'Send to Kitchen';

  @override
  String get save => 'Save';

  @override
  String get payNow => 'Pay Now';

  @override
  String get searchProduct => 'Search Product...';

  @override
  String get cancel => 'Cancel';

  @override
  String get enterNotes => 'Enter notes here...';

  @override
  String get searchCustomer => 'Search by name or phone...';

  @override
  String get selectOrderType => 'Select Order Type';

  @override
  String get takeAway => 'Take Away';

  @override
  String get enterNotesHere => 'Enter notes here...';

  @override
  String get searchAddCustomer => 'Search / Add Customer';

  @override
  String get searchByNameOrPhone => 'Search by name or phone...';

  @override
  String get addNewCustomer => 'Add New Customer';

  @override
  String get noCustomerSearchResults => 'No customer results yet';

  @override
  String get customerNameLabel => 'Customer Name';

  @override
  String get customerPhoneLabel => 'Phone Number';

  @override
  String get customerAddressLabel => 'Address';

  @override
  String get customerNameRequiredMessage => 'Customer name is required.';

  @override
  String get customerSelectionRequiredMessage =>
      'Choose or create a customer before saving the order.';

  @override
  String get shiftRequiredBeforeOrderMessage =>
      'Open an active shift before saving or sending the order.';

  @override
  String get quantity => 'Quantity';

  @override
  String get orderType => 'Order Type';

  @override
  String get note => 'Note';

  @override
  String get anySpecialRequests => 'Any special requests?';

  @override
  String get splitItem => 'Split Item';

  @override
  String get saveDetails => 'Save Details';

  @override
  String get totalSales => 'Total Sales';

  @override
  String get avgSalesPerTransaction => 'Avg. Sales/Transaction';

  @override
  String get transactions => 'Transactions';

  @override
  String get totalDiscount => 'Total Discount';

  @override
  String get applyFilter => 'Apply Filter';

  @override
  String get dailySales => 'Daily Sales >';

  @override
  String lastModified(String date, String time) {
    return 'Last modified on $date at $time';
  }

  @override
  String transactionsWithCount(String count) {
    return '$count Transactions';
  }

  @override
  String get operationsHeader => 'Operations';

  @override
  String get operationsSubtitle =>
      'Choose an operations workspace from this panel.';

  @override
  String get operationsUnavailableMessage =>
      'No operations available for this role.';

  @override
  String get shiftMenu => 'Shift';

  @override
  String get recapMenu => 'Recap';

  @override
  String get cashFlowMenu => 'Cash Flow';

  @override
  String get kitchenMonitorMenu => 'Kitchen Monitor';

  @override
  String get masterDataSubtitle => 'Choose master data to manage.';

  @override
  String get masterDataUnavailableMessage =>
      'No master data available for this role.';

  @override
  String get productsMenu => 'Products';

  @override
  String get categoriesMenu => 'Categories';

  @override
  String get brandsMenu => 'Brands';

  @override
  String get promosMenu => 'Promos';

  @override
  String get customerListMenu => 'Customer List';

  @override
  String get customerDetailMenu => 'Customer Detail';

  @override
  String get staffListMenu => 'Staff List';

  @override
  String get staffRolesMenu => 'Staff Roles';

  @override
  String get settingsSubtitle => 'Choose a settings area to review.';

  @override
  String get settingsUnavailableMessage =>
      'No settings available for this role.';

  @override
  String get generalSettingsMenu => 'General Settings';

  @override
  String get profileSettingsMenu => 'Profile Settings';

  @override
  String get storeProfileMenu => 'Store Profile';

  @override
  String get shiftConfigMenu => 'Shift Config';

  @override
  String get printerListMenu => 'Printer List';

  @override
  String get printerMappingMenu => 'Printer Mapping';

  @override
  String get printerTestMenu => 'Printer Test';

  @override
  String get syncCenterMenu => 'Sync Center';

  @override
  String get syncHistoryMenu => 'Sync History';

  @override
  String get appUpdateMenu => 'App Update';

  @override
  String get deviceStatusMenu => 'Device Status';

  @override
  String placeholderPage(String title) {
    return '$title Placeholder Page';
  }

  @override
  String get orderNoteSubtitle =>
      'Add short instructions for cashier or kitchen.';

  @override
  String get noteAdded => 'Note Added';

  @override
  String get orderStatusActive => 'Active';

  @override
  String get orderStatusClosed => 'Closed';

  @override
  String get orderStatusPartially => 'Partially Paid';

  @override
  String get orderStatusOverdue => 'Overdue';

  @override
  String get orderStatusVoid => 'Void';

  @override
  String get orderStatusParked => 'Parked';

  @override
  String get applyPromoAction => 'Apply Promo';

  @override
  String get clearOrderAction => 'Clear Order';

  @override
  String get cancelOrderAction => 'Cancel Order';

  @override
  String get syncDataAction => 'Sync Data';

  @override
  String get closeOutletAction => 'Close Outlet';

  @override
  String get deleteAction => 'Delete';

  @override
  String get resumeAction => 'Resume';

  @override
  String get applyPromoTitle => 'Apply Promo';

  @override
  String get applyPromoSubtitle => 'This promo applies to the whole order.';

  @override
  String get removePromoAction => 'Remove Promo';

  @override
  String get addProductFirstMessage => 'Add products first.';

  @override
  String get activeOrderCreatedMessage => 'Active order created.';

  @override
  String get closedOrderCreatedMessage => 'Order closed successfully.';

  @override
  String get voidOrderCreatedMessage =>
      'Order cancelled and moved to void history.';

  @override
  String get parkedOrderCreatedMessage => 'Order saved as parked.';

  @override
  String get splitItemMinQuantityMessage =>
      'Item quantity must be at least 2 to split.';

  @override
  String get productDiscountEnabled => 'Product discount enabled';

  @override
  String get productDiscountDisabled => 'Product discount disabled';

  @override
  String get splitQuantityLabel => 'Split Quantity';

  @override
  String splitPreview(int left, int right) {
    return 'Result: $left and $right';
  }

  @override
  String get emptyActiveOrdersMessage =>
      'No active orders from the cashier workspace.';

  @override
  String get emptyParkedOrdersMessage =>
      'No parked orders saved from the cashier.';

  @override
  String get emptyHistoryMessage => 'No completed, overdue, or void orders.';

  @override
  String get table => 'Table';

  @override
  String get online => 'Online';

  @override
  String orderSummary(int count, String type) {
    return '$count items • $type';
  }

  @override
  String itemsCount(int count) {
    return '$count items';
  }

  @override
  String get choosePromo => 'Choose Promo';

  @override
  String get choosePromoSubtitle => 'Choose one of the available promos';

  @override
  String get noApplicablePromotionsMessage =>
      'No applicable promotions for the current cart yet.';

  @override
  String get manualDiscount => 'Manual Discount';

  @override
  String get manualDiscountSubtitle => 'Enter discount amount';

  @override
  String get discountTypeRp => 'Amount';

  @override
  String get discountTypePercent => 'Percent (%)';

  @override
  String get applyDiscount => 'Apply Discount';

  @override
  String get emptyCartTitle => 'No Orders Yet!';

  @override
  String get emptyCartSubtitle => 'Add items from the menu to start';

  @override
  String get noAdditionalOptions => 'No additional\noptions available.';

  @override
  String get reportsSubtitle => 'Choose a report to review.';

  @override
  String get reportsUnavailableMessage => 'No reports available for this role.';

  @override
  String get reportSummaryMenu => 'Report Summary';

  @override
  String get salesReportMenu => 'Sales Report';

  @override
  String get productReportMenu => 'Product Report';

  @override
  String get staffReportMenu => 'Staff Report';

  @override
  String get cashierReportLiteMenu => 'Cashier Report';

  @override
  String get optionOne => 'Option 1';

  @override
  String get optionTwo => 'Option 2';

  @override
  String get stock => 'Stock';

  @override
  String get code => 'Code';

  @override
  String get date => 'Date';

  @override
  String get status => 'Status';

  @override
  String get editAction => 'Edit';

  @override
  String get copyUrlAction => 'Copy URL';

  @override
  String get ownerRoleLabel => 'Owner';

  @override
  String get supervisorRoleLabel => 'Supervisor';

  @override
  String get cashierRoleLabel => 'Cashier';

  @override
  String get kitchenRoleLabel => 'Kitchen';

  @override
  String get programmerRoleLabel => 'Programmer';

  @override
  String get loginTitle => 'Sign In';

  @override
  String get loginSubtitle =>
      'Enter the fields required for the central login request. After success, tenant data will be synchronized automatically.';

  @override
  String get centralLoginBaseUrl => 'Central Login Base URL';

  @override
  String get authTokenLabel => 'Auth Token';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get deviceIdLabel => 'Device ID';

  @override
  String get loginButton => 'Login';

  @override
  String get loginFormIncomplete =>
      'Complete email, password, and device ID first.';

  @override
  String get loginRequiredMessage =>
      'Login is required before switching account.';

  @override
  String get switchAccountTitle => 'Switch Account';

  @override
  String get switchAccountAction => 'Switch Account';

  @override
  String get switchAccountUserLabel => 'User';

  @override
  String get switchAccountPinLabel => 'PIN';

  @override
  String get switchAccountNoCachedStaff =>
      'No cached staff accounts are available yet. Sync staff data first.';

  @override
  String get switchAccountSuccess => 'Account switched successfully.';

  @override
  String get switchAccountIncomplete =>
      'Choose a user and enter the PIN first.';

  @override
  String get shiftGateTitle => 'Open Shift First';

  @override
  String get shiftGateSubtitle =>
      'A cashier session needs an active shift before POS transactions can start.';

  @override
  String get shiftGateIncomplete =>
      'Complete the shift name and opening balance first.';

  @override
  String get locationLabel => 'Location';

  @override
  String get shiftNameLabel => 'Shift Name';

  @override
  String get openingBalanceLabel => 'Opening Balance';

  @override
  String get openShiftAction => 'Open Shift And Continue';

  @override
  String get chooseBrandTitle => 'Choose Brand';

  @override
  String get syncPreparingTitle => 'Preparing Your Store';

  @override
  String get syncPreparingSettings => 'Downloading store settings...';

  @override
  String get syncPreparingShift => 'Checking active shift...';

  @override
  String get syncPreparingCategoriesBrands =>
      'Downloading categories and brands...';

  @override
  String get syncPreparingCatalog => 'Downloading product catalog...';

  @override
  String get syncPreparingLocalCache => 'Loading local cache...';

  @override
  String get syncPreparingError => 'Failed to download data:';

  @override
  String get retryAction => 'Try Again';

  @override
  String get syncStatusIdle => 'Sync Idle';

  @override
  String get syncStatusPreparing => 'Preparing POS';

  @override
  String get syncStatusSyncing => 'Syncing Data';

  @override
  String get syncStatusUpToDate => 'Up To Date';

  @override
  String get syncStatusFailed => 'Sync Failed';

  @override
  String featureNotWiredMessage(String feature) {
    return '$feature is not wired yet.';
  }

  @override
  String get selectOrderTypeSubtitle =>
      'Choose the most appropriate sales channel for this transaction.';

  @override
  String get thousandShort => 'K';

  @override
  String get millionShort => 'M';

  @override
  String get overviewMultiBrandSales => 'Multi Brand Sales';

  @override
  String get overviewSalesTrendChart => 'Sales Trend Chart';

  @override
  String get overviewPeakHours => 'Peak Hours';

  @override
  String get overviewMonthlySalesTrend => 'Monthly Sales Trend';

  @override
  String get overviewTopFiveBestSelling => 'Top 5 Best Selling';

  @override
  String get overviewLowStockAlert => 'Low Stock Alert';

  @override
  String get overviewLowStatus => 'Low';

  @override
  String get overviewSystemIntegrationLogStatus =>
      'System Integration Log & Status';

  @override
  String get overviewMekariJurnalSync => 'Mekari Jurnal Sync';

  @override
  String get overviewSuccess200Ok => 'Success (200 OK)';

  @override
  String get overviewSupabaseConnectivity => 'Supabase Connectivity';

  @override
  String get overviewLiveTransactionFeed => 'Live Transaction Feed';

  @override
  String get overviewCredit => 'Credit';

  @override
  String get overviewCash => 'Cash';

  @override
  String get developerHubGuestWalkIn => 'Guest Walk-in';

  @override
  String get developerHubRefreshSuccess =>
      'Deck refreshed. The latest V2 foundation has been reloaded.';

  @override
  String get developerHubSavePolicySuccess =>
      'Operating mode and self-order settings updated successfully.';

  @override
  String get developerHubSelectTableFirst =>
      'Choose a table before generating a QR session.';

  @override
  String get developerHubSessionPreviewSuccess =>
      'Customer QR session created successfully. Use it for receipts or preview.';

  @override
  String get developerHubForceCloseSessionSuccess =>
      'The old device session was closed successfully.';

  @override
  String developerHubTableDeleted(String tableName) {
    return 'Table $tableName deleted successfully.';
  }

  @override
  String get developerHubTableCreatedSuccess =>
      'New table created successfully.';

  @override
  String get developerHubTableUpdatedSuccess =>
      'Table details updated successfully.';

  @override
  String get developerHubNoActiveTablesToPrint =>
      'There are no active tables to print yet.';

  @override
  String get developerHubTableQrKit => 'Table QR Kit';

  @override
  String get developerHubPrintReadySuccess =>
      'Table QR is ready to print or save as PDF.';

  @override
  String get developerHubAddQrTableTitle => 'Add QR Table';

  @override
  String get developerHubEditQrTableTitle => 'Edit QR Table';

  @override
  String get developerHubAreaZone => 'Area / Zone';

  @override
  String get developerHubTableCode => 'Table Code';

  @override
  String get developerHubTableName => 'Table Name';

  @override
  String get developerHubCapacity => 'Capacity';

  @override
  String get developerHubActiveForService => 'Active for service';

  @override
  String get developerHubSelfOrderEnabled => 'Self-order enabled';

  @override
  String get developerHubLaunchpad => 'Launchpad';

  @override
  String get developerHubPolicyCenter => 'Policy Center';

  @override
  String get developerHubTableQrStudio => 'Table QR Studio';

  @override
  String get developerHubSessionLab => 'Session Lab';

  @override
  String get developerHubDeviceLock => 'Device Lock';

  @override
  String get developerHubApiLogs => 'API Logs';

  @override
  String get developerHubApiLogsSubtitle =>
      'Every request to central and tenant endpoints is captured here with method, endpoint, body, response, error, and duration.';

  @override
  String get developerHubEmptyApiLogs =>
      'No API calls have been captured yet. Trigger login, refresh, or SQLite sync first.';

  @override
  String get developerHubHeroSubtitle =>
      'A cleaner new chapter for self-order, table QR, and device lock.';

  @override
  String get developerHubConnectionDeck => 'Connection Deck';

  @override
  String get developerHubCentralLoginBaseUrl => 'Central Login Base URL';

  @override
  String get developerHubTenantBaseUrl => 'Tenant Base URL';

  @override
  String get developerHubAuthToken => 'Auth Token';

  @override
  String get developerHubLoginEmail => 'Login Email';

  @override
  String get developerHubLoginPassword => 'Login Password';

  @override
  String get developerHubLoginAction => 'Login And Load Bootstrap';

  @override
  String get developerHubSyncSqliteAction => 'Sync SQLite Snapshot';

  @override
  String get developerHubLoginIncomplete =>
      'Complete tenant base URL, email, password, and device ID first.';

  @override
  String get developerHubLoginRequired =>
      'Login first so the tenant session and location are known.';

  @override
  String get developerHubLoginSuccess =>
      'Login succeeded and bootstrap was stored locally.';

  @override
  String get developerHubSqliteSyncSuccess =>
      'SQLite snapshot refreshed from the V2 endpoints.';

  @override
  String get catalogEmptyTitle => 'Catalog is empty';

  @override
  String get catalogEmptySubtitle =>
      'Sync items, categories, and brands from the API into SQLite first so POS can read the local source of truth.';

  @override
  String get developerHubActingStaffId => 'Acting Staff ID';

  @override
  String get developerHubDeviceId => 'Device ID';

  @override
  String get developerHubRefreshing => 'Refreshing...';

  @override
  String get developerHubRefreshBackendState => 'Refresh Backend State';

  @override
  String get developerHubLaunchpadSubtitle =>
      'The backend foundation is ready. Review the active mode, prepare table QR, and inspect device lock from here without touching the legacy POS.';

  @override
  String get developerHubOperatingMode => 'Operating Mode';

  @override
  String get developerHubOperatingModeHint => 'Classic or self_order_hybrid';

  @override
  String get developerHubSelfOrderMetric => 'Self-Order';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get developerHubSelfOrderHint => 'Kiosk, table, and resume order';

  @override
  String get developerHubStrict => 'Strict';

  @override
  String get developerHubFlexible => 'Flexible';

  @override
  String get developerHubDeviceLockHint => '1 staff = 1 active device';

  @override
  String get developerHubTableQr => 'Table QR';

  @override
  String developerHubTableCount(int count) {
    return '$count tables';
  }

  @override
  String get developerHubTableQrHint => 'Static, printable, and ready to stick';

  @override
  String get developerHubActiveDevices => 'Active Devices';

  @override
  String developerHubActiveSessionCount(int count) {
    return '$count sessions';
  }

  @override
  String get developerHubActiveDevicesHint =>
      'Can be force-closed by supervisor/owner';

  @override
  String get developerHubPriorityQuestion => 'What matters most right now?';

  @override
  String get developerHubPriorityAnswer =>
      'Static table QR is generated from the backend as the canonical payload, and `flinkpos_v2` renders, downloads, and prints it. The link stays consistent while the printed look stays flexible inside the app.';

  @override
  String get developerHubPolicySubtitle =>
      'Owners and supervisors can choose a strict classic flow or a self-order hybrid. Core settings are stored in the backend and broadcast again through bootstrap.';

  @override
  String get developerHubClassicPosFlow => 'Classic POS Flow';

  @override
  String get developerHubSelfOrderHybrid => 'Self-Order Hybrid';

  @override
  String get developerHubEnableSelfOrderFoundation =>
      'Enable self-order foundation';

  @override
  String get developerHubEnableSelfOrderFoundationSubtitle =>
      'Enable QR sessions, resume order, and table QR';

  @override
  String get developerHubAllowPayLater => 'Allow pay later';

  @override
  String get developerHubAllowPayLaterSubtitle =>
      'Customers can add items and pay later at the cashier';

  @override
  String get developerHubAllowAddAfterSubmit => 'Allow add after submit';

  @override
  String get developerHubAllowAddAfterSubmitSubtitle =>
      'The same session can still add items before final checkout';

  @override
  String get developerHubFeedbackUrl => 'Feedback URL';

  @override
  String get developerHubOnlineStoreBaseUrl => 'Online Store Base URL';

  @override
  String get developerHubSavePolicyToBackend => 'Save Policy to Backend';

  @override
  String get developerHubPrintQrKit => 'Print QR Kit';

  @override
  String get developerHubAddTable => 'Add Table';

  @override
  String get developerHubTableQrStudioSubtitle =>
      'This generates the table QR that will be placed on site. The backend stores the token and canonical URL, while `flinkpos_v2` renders the QR on screen and exports PDF for printing.';

  @override
  String get developerHubEmptyTablesTitle => 'No table QR yet';

  @override
  String get developerHubEmptyTablesSubtitle =>
      'Create the table registry first so each static table QR can be downloaded and printed.';

  @override
  String get developerHubSessionLabSubtitle =>
      'Simulate a customer session: choose a table, open a session, and the backend will return two QR payloads for feedback and resume order.';

  @override
  String get developerHubServiceTable => 'Service Table';

  @override
  String get developerHubPreviewCustomerName => 'Preview Customer Name';

  @override
  String get developerHubGenerateSessionQrPreview =>
      'Generate Session QR Preview';

  @override
  String get developerHubFeedbackQr => 'Feedback QR';

  @override
  String get developerHubFeedbackQrSubtitle =>
      'For feedback, suggestions, and confirmation that the customer holds a digital receipt.';

  @override
  String developerHubQueueBadge(String queueNumber) {
    return 'Queue $queueNumber';
  }

  @override
  String get developerHubResumeOrderQr => 'Resume Order QR';

  @override
  String get developerHubResumeOrderQrSubtitle =>
      'Scan again on the customer\'s phone or the cashier tablet to add items or continue payment.';

  @override
  String get developerHubSelfOrderBadge => 'Self Order';

  @override
  String get developerHubEmptySessionPreviewTitle => 'No session preview yet';

  @override
  String get developerHubEmptySessionPreviewSubtitle =>
      'Generate one session first to see the customer receipt QR format.';

  @override
  String get developerHubDeviceLockSubtitle =>
      'If the same account is stuck on an old device, the owner or supervisor can remove it here without waiting for that device to be touched first.';

  @override
  String get developerHubEmptyActiveSessionsTitle => 'No active sessions';

  @override
  String get developerHubEmptyActiveSessionsSubtitle =>
      'When staff sign in from another device, the active list will appear here.';

  @override
  String get developerHubZoneFallback => 'Zone';

  @override
  String developerHubSeatCount(String count) {
    return 'Seat $count';
  }

  @override
  String developerHubStaffSessionSummary(
    String staffId,
    String role,
    String platform,
  ) {
    return 'Staff #$staffId • $role • $platform';
  }

  @override
  String developerHubLastSeen(String value) {
    return 'Last seen: $value';
  }

  @override
  String get developerHubForceCloseAction => 'Force Close';

  @override
  String get totalCustomers => 'Total Customers';

  @override
  String newCustomersToday(int count) {
    return '$count new customers today';
  }

  @override
  String get activeCustomers => 'Active Customers';

  @override
  String get inLast30Days => 'In the last 30 days';

  @override
  String get averageVisits => 'Average Visits';

  @override
  String get visitsPerMonth => 'Visits per month';

  @override
  String get customerChartNotAvailable => 'Customer Chart Not Available';

  @override
  String get waitingForDesignData =>
      'Waiting for specific design data for this chart.';

  @override
  String get filterToday => 'Today';

  @override
  String get filterYesterday => 'Yesterday';

  @override
  String get filterLast7Days => 'Last 7 Days';

  @override
  String get filterLast30Days => 'Last 30 Days';

  @override
  String get filterThisMonth => 'This Month';

  @override
  String get selectDate => 'Select Date';

  @override
  String get promoNotApplicable => 'Promo requirements not met';
}
