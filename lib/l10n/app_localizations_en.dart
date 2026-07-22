// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get authForcedOutTitle => 'Session Ended';

  @override
  String get authForcedOutMessage =>
      'Your account has been forcefully logged out by another user. Please log in again.';

  @override
  String get authForcedOutUnderstand => 'Understood';

  @override
  String get activeSessionTitle => 'Active Session Detected';

  @override
  String get activeSessionMessage =>
      'Your account is still active on another device. Do you want to force log out from that device and log in here?';

  @override
  String get activeSessionForceLogout => 'Force Log Out';

  @override
  String get appName => 'FlinkPOS V2';

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
  String get paymentScreenTitle => 'Payment';

  @override
  String get selectPaymentMethod =>
      'Select a payment method before continuing.';

  @override
  String get paymentMethodLabel => 'Payment Method';

  @override
  String get orderTypeLabel => 'Order Type';

  @override
  String get itemsLabel => 'Items';

  @override
  String get reviewOrderTitle => 'Review Order';

  @override
  String get changeLabel => 'Change';

  @override
  String get totalAmountLabel => 'Total Amount';

  @override
  String get exactPaymentHint =>
      'This method will be recorded as an exact payment for the current total.';

  @override
  String get insertManually => 'Insert Manually';

  @override
  String get confirmPayment => 'Confirm Payment';

  @override
  String get paymentConfirmationTitle => 'Confirm Payment';

  @override
  String get paymentConfirmationSubtitle =>
      'Make sure the order type, payment method, and total are correct.';

  @override
  String get paymentSuccessTitle => 'Payment Successful';

  @override
  String paymentSuccessMessage(String paymentModeName) {
    return 'Payment has been saved with $paymentModeName and the order is now marked as completed.';
  }

  @override
  String get paymentModeUnavailableMessage =>
      'No payment method is available for this order type yet.';

  @override
  String get paymentProcessingFailedMessage =>
      'Payment could not be processed. Please try again.';

  @override
  String get orderProcessingFailedMessage =>
      'Order could not be processed. Please try again.';

  @override
  String get paymentSummaryTitle => 'Payment Summary';

  @override
  String get paymentAutoMatchedHint =>
      'This payment method was matched automatically with the current order type.';

  @override
  String get continueAction => 'Continue';

  @override
  String get backAction => 'Back';

  @override
  String get done => 'Done';

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
  String get syncDataStartedMessage => 'Data synchronization started.';

  @override
  String get syncDataSuccessMessage =>
      'Catalog, promotions, and customers have been refreshed.';

  @override
  String syncDataFailedMessage(String message) {
    return 'Data synchronization failed: $message';
  }

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
  String get loginHeroTagline =>
      'Manage your business more efficiently\nwith a modern POS system.';

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
  String get loginFormIncomplete => 'Complete email and password first.';

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
  String get switchStaffTitle => 'Switch Staff';

  @override
  String get switchStaffSubtitle =>
      'Please select your account and enter your PIN to continue.';

  @override
  String get switchStaffLockAppAction => 'Lock App';

  @override
  String get switchStaffLockedMessage => 'App locked.';

  @override
  String get switchStaffSyncAction => 'Sync Staff';

  @override
  String get switchStaffSyncedMessage => 'Staff synced.';

  @override
  String get switchStaffLogoutLocationAction => 'Logout Location';

  @override
  String get switchStaffLoggedOutLocationMessage => 'Logged out of location.';

  @override
  String get switchStaffNoCurrentSession => 'No staff selected';

  @override
  String get switchStaffCurrentSessionTitle => 'Current Session';

  @override
  String get switchStaffSelectAccountPrompt => 'Select an account to continue';

  @override
  String get switchStaffSecureTitle => 'Secure Switch';

  @override
  String get switchStaffSecureSubtitle =>
      'Your session is protected\nwith PIN verification';

  @override
  String get switchStaffRoleAccessTitle => 'Role Based Access';

  @override
  String get switchStaffRoleAccessSubtitle =>
      'Access is limited based\non user role';

  @override
  String get switchStaffAuditTitle => 'Audit Logged';

  @override
  String get switchStaffAuditSubtitle =>
      'All staff switches are\nlogged for audit';

  @override
  String get switchStaffPoweredBy => 'POWERED BY FLINK POS';

  @override
  String get switchStaffAddStaffAction => 'Add Staff';

  @override
  String get switchStaffAddStaffSoon => 'Add Staff coming soon!';

  @override
  String get switchStaffOwnerOnly => 'OWNER ONLY';

  @override
  String get switchStaffPinRequired => 'PIN is required';

  @override
  String switchStaffEnterPinFor(String name) {
    return 'Enter PIN for $name';
  }

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
  String get shiftCloseAddPaymentMethodAction => 'Add Payment Method';

  @override
  String get shiftCloseAddPaymentMethodTitle => 'Choose Payment Method';

  @override
  String get shiftCloseNoAdditionalPaymentModes =>
      'No additional payment methods are available to add.';

  @override
  String get shiftCloseNoPaymentMethodRecap =>
      'No non-cash payment recap has been added yet.';

  @override
  String get shiftCloseNonCashSummaryLabel => 'Total Non-Cash';

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

  @override
  String get settingsGeneralTitle => 'General';

  @override
  String get settingsGeneralSubtitle => 'General settings and tenant profile';

  @override
  String get settingsStoreTitle => 'Store';

  @override
  String get settingsStoreSubtitle =>
      'Store profile and operations configuration';

  @override
  String get settingsPrinterTitle => 'Printer';

  @override
  String get settingsPrinterSubtitle =>
      'Cashier and kitchen printer management';

  @override
  String get settingsSyncTitle => 'Sync';

  @override
  String get settingsSyncSubtitle => 'Sync and offline data management';

  @override
  String get settingsDeviceTitle => 'Device';

  @override
  String get settingsDeviceSubtitle => 'Device status and system updates';

  @override
  String get settingsCompanyNameLabel => 'Company Name';

  @override
  String get settingsLocationIdLabel => 'Location ID';

  @override
  String get settingsServerUrlLabel => 'Server URL';

  @override
  String get settingsDeviceIdLabel => 'Device ID';

  @override
  String get settingsAppInfoTitle => 'App Info';

  @override
  String get settingsAppInfoSubtitle => 'Version and developer information';

  @override
  String get settingsCheckUpdatesTitle => 'Check for Updates';

  @override
  String get settingsCheckUpdatesSubtitle =>
      'Check if a newer version is available';

  @override
  String get settingsAllowSellOutOfStockTitle => 'Allow Selling Out of Stock';

  @override
  String get settingsAllowSellOutOfStockSubtitle =>
      'Enable adding products to cart even when system stock is 0';

  @override
  String get settingsSuccessSave => 'Settings saved successfully';

  @override
  String get settingsFailSave => 'Failed to save settings';

  @override
  String get settingsAppConfig => 'App Configuration';

  @override
  String get settingsActiveRole => 'Active Role';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsSyncMasterData => 'Sync Master Data';

  @override
  String get settingsSyncing => 'Syncing Master Data...';

  @override
  String get settingsSyncError => 'Sync Error';

  @override
  String get settingsPartialSynced => 'Partial Synced - Tap to Full Sync';

  @override
  String get settingsSynced => 'Synced';

  @override
  String get settingsStoreApi => 'Store & API Settings';

  @override
  String get settingsOperatingMode => 'Operating Mode';

  @override
  String get settingsOnlineStoreUrl => 'Online Store Base URL';

  @override
  String get settingsWebhookUrl => 'Webhook URL (Transaction)';

  @override
  String get settingsDisplayConfig => 'Display Configuration';

  @override
  String get settingsShowImage => 'Show Product Image';

  @override
  String get settingsShowImageDesc => 'Always display product image on grid';

  @override
  String get settingsShowName => 'Show Product Name';

  @override
  String get settingsShowNameDesc => 'Display product name on grid';

  @override
  String get settingsShowStock => 'Show Product Stock';

  @override
  String get settingsShowStockDesc => 'Display available stock on grid';

  @override
  String get settingsShowPrice => 'Show Product Price';

  @override
  String get settingsShowPriceDesc => 'Display product price on grid';

  @override
  String get settingsMinDisplayOptions =>
      'Minimum 2 display options must be active.';

  @override
  String get settingsSelfOrder => 'Self Order Settings';

  @override
  String get settingsEnableSelfOrder => 'Enable Self Order';

  @override
  String get settingsEnableSelfOrderDesc => 'Activate hybrid self order mode';

  @override
  String get settingsRequireTableNumber => 'Require Table Number';

  @override
  String get settingsRequireTableNumberDesc =>
      'Customer must provide table number';

  @override
  String get settingsAllowGuestCheckout => 'Allow Guest Checkout';

  @override
  String get settingsAllowGuestCheckoutDesc =>
      'Customer can checkout without registration';

  @override
  String settingsEditTitle(String title) {
    return 'Edit $title';
  }

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsClose => 'Close';

  @override
  String get settingsEmpty => '(Empty)';

  @override
  String get settingsApp => 'App';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsTenant => 'Tenant';

  @override
  String get settingsTenantCode => 'Tenant Code';

  @override
  String get settingsStaff => 'Staff';

  @override
  String get settingsRole => 'Role';

  @override
  String get settingsLastBootstrap => 'Last Bootstrap';

  @override
  String get settingsNever => 'Never';

  @override
  String get enterWithoutShift => 'Enter Without Opening Shift';

  @override
  String get enterWithoutShiftHint =>
      'You will enter in read-only mode. Transactions are disabled.';

  @override
  String get readOnlyWarning =>
      'View-Only Mode: You cannot process transactions.';

  @override
  String get readOnlyWarningActiveShift =>
      'An active shift exists, but you cannot add, remove or edit orders in view-only mode.';

  @override
  String get printToKitchen => 'Print to Kitchen';

  @override
  String get delete => 'Delete';

  @override
  String get printerPairedBluetoothDevices => 'Paired Bluetooth Devices';

  @override
  String get printerAddProfile => 'Add Profile';

  @override
  String get printerDeleteTitle => 'Delete Profile';

  @override
  String get printerTypeSystem => 'System';

  @override
  String get printerTypeNetwork => 'Network';

  @override
  String get printerTypeBluetooth => 'Bluetooth';

  @override
  String get printerTypeUsb => 'USB';

  @override
  String get printerSupportsAutoCut => 'Supports Auto-Cut';

  @override
  String get printerActive => 'Active';

  @override
  String get printerMappingTitle => 'Printer Mapping';

  @override
  String get printerTestTitle => 'Printer Test';

  @override
  String get printerTestNoActiveProfile =>
      'No active printer profile available. Add one first.';

  @override
  String get printerTestPreviewPrint => 'Preview / Print';

  @override
  String get storeProfileTitle => 'Store Profile';

  @override
  String get storeProfileDesc =>
      'Current tenant identity and public POS/store links';

  @override
  String get refresh => 'Refresh';

  @override
  String get storeProfileInventorySettings => 'Inventory Settings';

  @override
  String get syncCenterTitle => 'Sync Center';

  @override
  String get syncCenterDesc =>
      'Observe queue health and trigger lightweight recovery actions.';

  @override
  String get syncCurrentStatus => 'Current Sync Status';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get syncFlushQueue => 'Flush Queue';

  @override
  String get syncRefreshBootstrap => 'Refresh Bootstrap';

  @override
  String get syncHistoryTitle => 'Sync History';

  @override
  String get syncHistoryDesc => 'Recent queue activity and local error logs.';

  @override
  String get syncHistoryNoQueue => 'No recent queue entries.';

  @override
  String get syncHistoryNoErrors => 'No recent error logs.';

  @override
  String get logoutConfirmTitle => 'Confirm Logout';

  @override
  String get logoutConfirmMessage =>
      'Are you sure you want to log out of this account?';

  @override
  String get logoutSession => 'Log Out Session';

  @override
  String get profileInfoTitle => 'Profile Information';

  @override
  String get profileInfoEmail => 'Registered Email';

  @override
  String get profileInfoActiveDevice => 'Active Device';

  @override
  String get profileInfoDeviceId => 'Device ID';

  @override
  String get profileInfoRegisterId => 'Register ID';

  @override
  String get syncStart => 'Start Sync';

  @override
  String get syncDownloadLog => 'Download Log';

  @override
  String get printerDeleteConfirmMessage =>
      'Are you sure you want to delete this printer profile?';

  @override
  String printerBrandFilter(String role) {
    return '$role Brand Filter';
  }

  @override
  String syncStage(String stage) {
    return 'Stage: $stage';
  }

  @override
  String syncBlocking(String status) {
    return 'Blocking: $status';
  }

  @override
  String syncProgress(int progress) {
    return 'Progress: $progress%';
  }

  @override
  String get cashOut => 'Cash Out';

  @override
  String get addCashOut => 'Add Cash Out';

  @override
  String get amount => 'Amount';

  @override
  String get startDate => 'Start Date';

  @override
  String get endDate => 'End Date';

  @override
  String get promoNotStackable =>
      'This promo cannot be stacked with other promos.';

  @override
  String get unstackablePromoAlreadySelected =>
      'An unstackable promo is already selected.';
}
