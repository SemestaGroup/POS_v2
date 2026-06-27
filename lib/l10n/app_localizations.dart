import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @posTitle.
  ///
  /// In en, this message translates to:
  /// **'POS'**
  String get posTitle;

  /// No description provided for @activeOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Orders'**
  String get activeOrdersTitle;

  /// No description provided for @resumeOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Resume Order'**
  String get resumeOrderTitle;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by ID or Customer...'**
  String get searchPlaceholder;

  /// No description provided for @newOrder.
  ///
  /// In en, this message translates to:
  /// **'New Order'**
  String get newOrder;

  /// No description provided for @ordersFound.
  ///
  /// In en, this message translates to:
  /// **'{count} orders found'**
  String ordersFound(int count);

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @operations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get operations;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @masterData.
  ///
  /// In en, this message translates to:
  /// **'Master Data'**
  String get masterData;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{title} Coming Soon'**
  String comingSoon(String title);

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @promo.
  ///
  /// In en, this message translates to:
  /// **'Promo'**
  String get promo;

  /// No description provided for @chooseTable.
  ///
  /// In en, this message translates to:
  /// **'Choose Table'**
  String get chooseTable;

  /// No description provided for @ordersWithCount.
  ///
  /// In en, this message translates to:
  /// **'Orders {count}'**
  String ordersWithCount(int count);

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @walkInCustomer.
  ///
  /// In en, this message translates to:
  /// **'Walk-In Customer'**
  String get walkInCustomer;

  /// No description provided for @dineIn.
  ///
  /// In en, this message translates to:
  /// **'Dine In'**
  String get dineIn;

  /// No description provided for @orderNote.
  ///
  /// In en, this message translates to:
  /// **'Order Note'**
  String get orderNote;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get tax;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @totalPay.
  ///
  /// In en, this message translates to:
  /// **'Total Pay'**
  String get totalPay;

  /// No description provided for @sendToKitchen.
  ///
  /// In en, this message translates to:
  /// **'Send to Kitchen'**
  String get sendToKitchen;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @searchProduct.
  ///
  /// In en, this message translates to:
  /// **'Search Product...'**
  String get searchProduct;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @enterNotes.
  ///
  /// In en, this message translates to:
  /// **'Enter notes here...'**
  String get enterNotes;

  /// No description provided for @searchCustomer.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone...'**
  String get searchCustomer;

  /// No description provided for @selectOrderType.
  ///
  /// In en, this message translates to:
  /// **'Select Order Type'**
  String get selectOrderType;

  /// No description provided for @takeAway.
  ///
  /// In en, this message translates to:
  /// **'Take Away'**
  String get takeAway;

  /// No description provided for @enterNotesHere.
  ///
  /// In en, this message translates to:
  /// **'Enter notes here...'**
  String get enterNotesHere;

  /// No description provided for @searchAddCustomer.
  ///
  /// In en, this message translates to:
  /// **'Search / Add Customer'**
  String get searchAddCustomer;

  /// No description provided for @searchByNameOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone...'**
  String get searchByNameOrPhone;

  /// No description provided for @addNewCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add New Customer'**
  String get addNewCustomer;

  /// No description provided for @noCustomerSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No customer results yet'**
  String get noCustomerSearchResults;

  /// No description provided for @customerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerNameLabel;

  /// No description provided for @customerPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get customerPhoneLabel;

  /// No description provided for @customerAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get customerAddressLabel;

  /// No description provided for @customerNameRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Customer name is required.'**
  String get customerNameRequiredMessage;

  /// No description provided for @customerSelectionRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose or create a customer before saving the order.'**
  String get customerSelectionRequiredMessage;

  /// No description provided for @shiftRequiredBeforeOrderMessage.
  ///
  /// In en, this message translates to:
  /// **'Open an active shift before saving or sending the order.'**
  String get shiftRequiredBeforeOrderMessage;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @orderType.
  ///
  /// In en, this message translates to:
  /// **'Order Type'**
  String get orderType;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @anySpecialRequests.
  ///
  /// In en, this message translates to:
  /// **'Any special requests?'**
  String get anySpecialRequests;

  /// No description provided for @splitItem.
  ///
  /// In en, this message translates to:
  /// **'Split Item'**
  String get splitItem;

  /// No description provided for @saveDetails.
  ///
  /// In en, this message translates to:
  /// **'Save Details'**
  String get saveDetails;

  /// No description provided for @totalSales.
  ///
  /// In en, this message translates to:
  /// **'Total Sales'**
  String get totalSales;

  /// No description provided for @avgSalesPerTransaction.
  ///
  /// In en, this message translates to:
  /// **'Avg. Sales/Transaction'**
  String get avgSalesPerTransaction;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @totalDiscount.
  ///
  /// In en, this message translates to:
  /// **'Total Discount'**
  String get totalDiscount;

  /// No description provided for @applyFilter.
  ///
  /// In en, this message translates to:
  /// **'Apply Filter'**
  String get applyFilter;

  /// No description provided for @dailySales.
  ///
  /// In en, this message translates to:
  /// **'Daily Sales >'**
  String get dailySales;

  /// No description provided for @lastModified.
  ///
  /// In en, this message translates to:
  /// **'Last modified on {date} at {time}'**
  String lastModified(String date, String time);

  /// No description provided for @transactionsWithCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Transactions'**
  String transactionsWithCount(String count);

  /// No description provided for @operationsHeader.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get operationsHeader;

  /// No description provided for @operationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an operations workspace from this panel.'**
  String get operationsSubtitle;

  /// No description provided for @operationsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'No operations available for this role.'**
  String get operationsUnavailableMessage;

  /// No description provided for @shiftMenu.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get shiftMenu;

  /// No description provided for @recapMenu.
  ///
  /// In en, this message translates to:
  /// **'Recap'**
  String get recapMenu;

  /// No description provided for @cashFlowMenu.
  ///
  /// In en, this message translates to:
  /// **'Cash Flow'**
  String get cashFlowMenu;

  /// No description provided for @kitchenMonitorMenu.
  ///
  /// In en, this message translates to:
  /// **'Kitchen Monitor'**
  String get kitchenMonitorMenu;

  /// No description provided for @masterDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose master data to manage.'**
  String get masterDataSubtitle;

  /// No description provided for @masterDataUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'No master data available for this role.'**
  String get masterDataUnavailableMessage;

  /// No description provided for @productsMenu.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsMenu;

  /// No description provided for @categoriesMenu.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesMenu;

  /// No description provided for @brandsMenu.
  ///
  /// In en, this message translates to:
  /// **'Brands'**
  String get brandsMenu;

  /// No description provided for @promosMenu.
  ///
  /// In en, this message translates to:
  /// **'Promos'**
  String get promosMenu;

  /// No description provided for @customerListMenu.
  ///
  /// In en, this message translates to:
  /// **'Customer List'**
  String get customerListMenu;

  /// No description provided for @customerDetailMenu.
  ///
  /// In en, this message translates to:
  /// **'Customer Detail'**
  String get customerDetailMenu;

  /// No description provided for @staffListMenu.
  ///
  /// In en, this message translates to:
  /// **'Staff List'**
  String get staffListMenu;

  /// No description provided for @staffRolesMenu.
  ///
  /// In en, this message translates to:
  /// **'Staff Roles'**
  String get staffRolesMenu;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a settings area to review.'**
  String get settingsSubtitle;

  /// No description provided for @settingsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'No settings available for this role.'**
  String get settingsUnavailableMessage;

  /// No description provided for @generalSettingsMenu.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get generalSettingsMenu;

  /// No description provided for @profileSettingsMenu.
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get profileSettingsMenu;

  /// No description provided for @storeProfileMenu.
  ///
  /// In en, this message translates to:
  /// **'Store Profile'**
  String get storeProfileMenu;

  /// No description provided for @shiftConfigMenu.
  ///
  /// In en, this message translates to:
  /// **'Shift Config'**
  String get shiftConfigMenu;

  /// No description provided for @printerListMenu.
  ///
  /// In en, this message translates to:
  /// **'Printer List'**
  String get printerListMenu;

  /// No description provided for @printerMappingMenu.
  ///
  /// In en, this message translates to:
  /// **'Printer Mapping'**
  String get printerMappingMenu;

  /// No description provided for @printerTestMenu.
  ///
  /// In en, this message translates to:
  /// **'Printer Test'**
  String get printerTestMenu;

  /// No description provided for @syncCenterMenu.
  ///
  /// In en, this message translates to:
  /// **'Sync Center'**
  String get syncCenterMenu;

  /// No description provided for @syncHistoryMenu.
  ///
  /// In en, this message translates to:
  /// **'Sync History'**
  String get syncHistoryMenu;

  /// No description provided for @appUpdateMenu.
  ///
  /// In en, this message translates to:
  /// **'App Update'**
  String get appUpdateMenu;

  /// No description provided for @deviceStatusMenu.
  ///
  /// In en, this message translates to:
  /// **'Device Status'**
  String get deviceStatusMenu;

  /// No description provided for @placeholderPage.
  ///
  /// In en, this message translates to:
  /// **'{title} Placeholder Page'**
  String placeholderPage(String title);

  /// No description provided for @orderNoteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add short instructions for cashier or kitchen.'**
  String get orderNoteSubtitle;

  /// No description provided for @noteAdded.
  ///
  /// In en, this message translates to:
  /// **'Note Added'**
  String get noteAdded;

  /// No description provided for @orderStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get orderStatusActive;

  /// No description provided for @orderStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get orderStatusClosed;

  /// No description provided for @orderStatusPartially.
  ///
  /// In en, this message translates to:
  /// **'Partially Paid'**
  String get orderStatusPartially;

  /// No description provided for @orderStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get orderStatusOverdue;

  /// No description provided for @orderStatusVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get orderStatusVoid;

  /// No description provided for @orderStatusParked.
  ///
  /// In en, this message translates to:
  /// **'Parked'**
  String get orderStatusParked;

  /// No description provided for @applyPromoAction.
  ///
  /// In en, this message translates to:
  /// **'Apply Promo'**
  String get applyPromoAction;

  /// No description provided for @clearOrderAction.
  ///
  /// In en, this message translates to:
  /// **'Clear Order'**
  String get clearOrderAction;

  /// No description provided for @cancelOrderAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrderAction;

  /// No description provided for @syncDataAction.
  ///
  /// In en, this message translates to:
  /// **'Sync Data'**
  String get syncDataAction;

  /// No description provided for @closeOutletAction.
  ///
  /// In en, this message translates to:
  /// **'Close Outlet'**
  String get closeOutletAction;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @resumeAction.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeAction;

  /// No description provided for @applyPromoTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply Promo'**
  String get applyPromoTitle;

  /// No description provided for @applyPromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This promo applies to the whole order.'**
  String get applyPromoSubtitle;

  /// No description provided for @removePromoAction.
  ///
  /// In en, this message translates to:
  /// **'Remove Promo'**
  String get removePromoAction;

  /// No description provided for @addProductFirstMessage.
  ///
  /// In en, this message translates to:
  /// **'Add products first.'**
  String get addProductFirstMessage;

  /// No description provided for @activeOrderCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Active order created.'**
  String get activeOrderCreatedMessage;

  /// No description provided for @closedOrderCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Order closed successfully.'**
  String get closedOrderCreatedMessage;

  /// No description provided for @voidOrderCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled and moved to void history.'**
  String get voidOrderCreatedMessage;

  /// No description provided for @parkedOrderCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Order saved as parked.'**
  String get parkedOrderCreatedMessage;

  /// No description provided for @splitItemMinQuantityMessage.
  ///
  /// In en, this message translates to:
  /// **'Item quantity must be at least 2 to split.'**
  String get splitItemMinQuantityMessage;

  /// No description provided for @productDiscountEnabled.
  ///
  /// In en, this message translates to:
  /// **'Product discount enabled'**
  String get productDiscountEnabled;

  /// No description provided for @productDiscountDisabled.
  ///
  /// In en, this message translates to:
  /// **'Product discount disabled'**
  String get productDiscountDisabled;

  /// No description provided for @splitQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Split Quantity'**
  String get splitQuantityLabel;

  /// No description provided for @splitPreview.
  ///
  /// In en, this message translates to:
  /// **'Result: {left} and {right}'**
  String splitPreview(int left, int right);

  /// No description provided for @emptyActiveOrdersMessage.
  ///
  /// In en, this message translates to:
  /// **'No active orders from the cashier workspace.'**
  String get emptyActiveOrdersMessage;

  /// No description provided for @emptyParkedOrdersMessage.
  ///
  /// In en, this message translates to:
  /// **'No parked orders saved from the cashier.'**
  String get emptyParkedOrdersMessage;

  /// No description provided for @emptyHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'No completed, overdue, or void orders.'**
  String get emptyHistoryMessage;

  /// No description provided for @table.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get table;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} items • {type}'**
  String orderSummary(int count, String type);

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(int count);

  /// No description provided for @choosePromo.
  ///
  /// In en, this message translates to:
  /// **'Choose Promo'**
  String get choosePromo;

  /// No description provided for @choosePromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose one of the available promos'**
  String get choosePromoSubtitle;

  /// No description provided for @noApplicablePromotionsMessage.
  ///
  /// In en, this message translates to:
  /// **'No applicable promotions for the current cart yet.'**
  String get noApplicablePromotionsMessage;

  /// No description provided for @manualDiscount.
  ///
  /// In en, this message translates to:
  /// **'Manual Discount'**
  String get manualDiscount;

  /// No description provided for @manualDiscountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter discount amount'**
  String get manualDiscountSubtitle;

  /// No description provided for @discountTypeRp.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get discountTypeRp;

  /// No description provided for @discountTypePercent.
  ///
  /// In en, this message translates to:
  /// **'Percent (%)'**
  String get discountTypePercent;

  /// No description provided for @applyDiscount.
  ///
  /// In en, this message translates to:
  /// **'Apply Discount'**
  String get applyDiscount;

  /// No description provided for @emptyCartTitle.
  ///
  /// In en, this message translates to:
  /// **'No Orders Yet!'**
  String get emptyCartTitle;

  /// No description provided for @emptyCartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add items from the menu to start'**
  String get emptyCartSubtitle;

  /// No description provided for @noAdditionalOptions.
  ///
  /// In en, this message translates to:
  /// **'No additional\noptions available.'**
  String get noAdditionalOptions;

  /// No description provided for @reportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a report to review.'**
  String get reportsSubtitle;

  /// No description provided for @reportsUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'No reports available for this role.'**
  String get reportsUnavailableMessage;

  /// No description provided for @reportSummaryMenu.
  ///
  /// In en, this message translates to:
  /// **'Report Summary'**
  String get reportSummaryMenu;

  /// No description provided for @salesReportMenu.
  ///
  /// In en, this message translates to:
  /// **'Sales Report'**
  String get salesReportMenu;

  /// No description provided for @productReportMenu.
  ///
  /// In en, this message translates to:
  /// **'Product Report'**
  String get productReportMenu;

  /// No description provided for @staffReportMenu.
  ///
  /// In en, this message translates to:
  /// **'Staff Report'**
  String get staffReportMenu;

  /// No description provided for @cashierReportLiteMenu.
  ///
  /// In en, this message translates to:
  /// **'Cashier Report'**
  String get cashierReportLiteMenu;

  /// No description provided for @optionOne.
  ///
  /// In en, this message translates to:
  /// **'Option 1'**
  String get optionOne;

  /// No description provided for @optionTwo.
  ///
  /// In en, this message translates to:
  /// **'Option 2'**
  String get optionTwo;

  /// No description provided for @stock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @editAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editAction;

  /// No description provided for @copyUrlAction.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get copyUrlAction;

  /// No description provided for @ownerRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get ownerRoleLabel;

  /// No description provided for @supervisorRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Supervisor'**
  String get supervisorRoleLabel;

  /// No description provided for @cashierRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashierRoleLabel;

  /// No description provided for @kitchenRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get kitchenRoleLabel;

  /// No description provided for @programmerRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Programmer'**
  String get programmerRoleLabel;

  /// No description provided for @loginHeroTagline.
  ///
  /// In en, this message translates to:
  /// **'Manage your business more efficiently\nwith a modern POS system.'**
  String get loginHeroTagline;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the fields required for the central login request. After success, tenant data will be synchronized automatically.'**
  String get loginSubtitle;

  /// No description provided for @centralLoginBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Central Login Base URL'**
  String get centralLoginBaseUrl;

  /// No description provided for @authTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Auth Token'**
  String get authTokenLabel;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @deviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceIdLabel;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @loginFormIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Complete email, password, and device ID first.'**
  String get loginFormIncomplete;

  /// No description provided for @loginRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Login is required before switching account.'**
  String get loginRequiredMessage;

  /// No description provided for @switchAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Account'**
  String get switchAccountTitle;

  /// No description provided for @switchAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Switch Account'**
  String get switchAccountAction;

  /// No description provided for @switchAccountUserLabel.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get switchAccountUserLabel;

  /// No description provided for @switchAccountPinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get switchAccountPinLabel;

  /// No description provided for @switchAccountNoCachedStaff.
  ///
  /// In en, this message translates to:
  /// **'No cached staff accounts are available yet. Sync staff data first.'**
  String get switchAccountNoCachedStaff;

  /// No description provided for @switchAccountSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account switched successfully.'**
  String get switchAccountSuccess;

  /// No description provided for @switchAccountIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Choose a user and enter the PIN first.'**
  String get switchAccountIncomplete;

  /// No description provided for @shiftGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Shift First'**
  String get shiftGateTitle;

  /// No description provided for @shiftGateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A cashier session needs an active shift before POS transactions can start.'**
  String get shiftGateSubtitle;

  /// No description provided for @shiftGateIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Complete the shift name and opening balance first.'**
  String get shiftGateIncomplete;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @shiftNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift Name'**
  String get shiftNameLabel;

  /// No description provided for @openingBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening Balance'**
  String get openingBalanceLabel;

  /// No description provided for @openShiftAction.
  ///
  /// In en, this message translates to:
  /// **'Open Shift And Continue'**
  String get openShiftAction;

  /// No description provided for @chooseBrandTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Brand'**
  String get chooseBrandTitle;

  /// No description provided for @syncPreparingTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing Your Store'**
  String get syncPreparingTitle;

  /// No description provided for @syncPreparingSettings.
  ///
  /// In en, this message translates to:
  /// **'Downloading store settings...'**
  String get syncPreparingSettings;

  /// No description provided for @syncPreparingShift.
  ///
  /// In en, this message translates to:
  /// **'Checking active shift...'**
  String get syncPreparingShift;

  /// No description provided for @syncPreparingCategoriesBrands.
  ///
  /// In en, this message translates to:
  /// **'Downloading categories and brands...'**
  String get syncPreparingCategoriesBrands;

  /// No description provided for @syncPreparingCatalog.
  ///
  /// In en, this message translates to:
  /// **'Downloading product catalog...'**
  String get syncPreparingCatalog;

  /// No description provided for @syncPreparingLocalCache.
  ///
  /// In en, this message translates to:
  /// **'Loading local cache...'**
  String get syncPreparingLocalCache;

  /// No description provided for @syncPreparingError.
  ///
  /// In en, this message translates to:
  /// **'Failed to download data:'**
  String get syncPreparingError;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get retryAction;

  /// No description provided for @syncStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Sync Idle'**
  String get syncStatusIdle;

  /// No description provided for @syncStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing POS'**
  String get syncStatusPreparing;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing Data'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up To Date'**
  String get syncStatusUpToDate;

  /// No description provided for @syncStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync Failed'**
  String get syncStatusFailed;

  /// No description provided for @featureNotWiredMessage.
  ///
  /// In en, this message translates to:
  /// **'{feature} is not wired yet.'**
  String featureNotWiredMessage(String feature);

  /// No description provided for @selectOrderTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the most appropriate sales channel for this transaction.'**
  String get selectOrderTypeSubtitle;

  /// No description provided for @thousandShort.
  ///
  /// In en, this message translates to:
  /// **'K'**
  String get thousandShort;

  /// No description provided for @millionShort.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get millionShort;

  /// No description provided for @overviewMultiBrandSales.
  ///
  /// In en, this message translates to:
  /// **'Multi Brand Sales'**
  String get overviewMultiBrandSales;

  /// No description provided for @overviewSalesTrendChart.
  ///
  /// In en, this message translates to:
  /// **'Sales Trend Chart'**
  String get overviewSalesTrendChart;

  /// No description provided for @overviewPeakHours.
  ///
  /// In en, this message translates to:
  /// **'Peak Hours'**
  String get overviewPeakHours;

  /// No description provided for @overviewMonthlySalesTrend.
  ///
  /// In en, this message translates to:
  /// **'Monthly Sales Trend'**
  String get overviewMonthlySalesTrend;

  /// No description provided for @overviewTopFiveBestSelling.
  ///
  /// In en, this message translates to:
  /// **'Top 5 Best Selling'**
  String get overviewTopFiveBestSelling;

  /// No description provided for @overviewLowStockAlert.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Alert'**
  String get overviewLowStockAlert;

  /// No description provided for @overviewLowStatus.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get overviewLowStatus;

  /// No description provided for @overviewSystemIntegrationLogStatus.
  ///
  /// In en, this message translates to:
  /// **'System Integration Log & Status'**
  String get overviewSystemIntegrationLogStatus;

  /// No description provided for @overviewMekariJurnalSync.
  ///
  /// In en, this message translates to:
  /// **'Mekari Jurnal Sync'**
  String get overviewMekariJurnalSync;

  /// No description provided for @overviewSuccess200Ok.
  ///
  /// In en, this message translates to:
  /// **'Success (200 OK)'**
  String get overviewSuccess200Ok;

  /// No description provided for @overviewSupabaseConnectivity.
  ///
  /// In en, this message translates to:
  /// **'Supabase Connectivity'**
  String get overviewSupabaseConnectivity;

  /// No description provided for @overviewLiveTransactionFeed.
  ///
  /// In en, this message translates to:
  /// **'Live Transaction Feed'**
  String get overviewLiveTransactionFeed;

  /// No description provided for @overviewCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get overviewCredit;

  /// No description provided for @overviewCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get overviewCash;

  /// No description provided for @developerHubGuestWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Guest Walk-in'**
  String get developerHubGuestWalkIn;

  /// No description provided for @developerHubRefreshSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deck refreshed. The latest V2 foundation has been reloaded.'**
  String get developerHubRefreshSuccess;

  /// No description provided for @developerHubSavePolicySuccess.
  ///
  /// In en, this message translates to:
  /// **'Operating mode and self-order settings updated successfully.'**
  String get developerHubSavePolicySuccess;

  /// No description provided for @developerHubSelectTableFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a table before generating a QR session.'**
  String get developerHubSelectTableFirst;

  /// No description provided for @developerHubSessionPreviewSuccess.
  ///
  /// In en, this message translates to:
  /// **'Customer QR session created successfully. Use it for receipts or preview.'**
  String get developerHubSessionPreviewSuccess;

  /// No description provided for @developerHubForceCloseSessionSuccess.
  ///
  /// In en, this message translates to:
  /// **'The old device session was closed successfully.'**
  String get developerHubForceCloseSessionSuccess;

  /// No description provided for @developerHubTableDeleted.
  ///
  /// In en, this message translates to:
  /// **'Table {tableName} deleted successfully.'**
  String developerHubTableDeleted(String tableName);

  /// No description provided for @developerHubTableCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'New table created successfully.'**
  String get developerHubTableCreatedSuccess;

  /// No description provided for @developerHubTableUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Table details updated successfully.'**
  String get developerHubTableUpdatedSuccess;

  /// No description provided for @developerHubNoActiveTablesToPrint.
  ///
  /// In en, this message translates to:
  /// **'There are no active tables to print yet.'**
  String get developerHubNoActiveTablesToPrint;

  /// No description provided for @developerHubTableQrKit.
  ///
  /// In en, this message translates to:
  /// **'Table QR Kit'**
  String get developerHubTableQrKit;

  /// No description provided for @developerHubPrintReadySuccess.
  ///
  /// In en, this message translates to:
  /// **'Table QR is ready to print or save as PDF.'**
  String get developerHubPrintReadySuccess;

  /// No description provided for @developerHubAddQrTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Add QR Table'**
  String get developerHubAddQrTableTitle;

  /// No description provided for @developerHubEditQrTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit QR Table'**
  String get developerHubEditQrTableTitle;

  /// No description provided for @developerHubAreaZone.
  ///
  /// In en, this message translates to:
  /// **'Area / Zone'**
  String get developerHubAreaZone;

  /// No description provided for @developerHubTableCode.
  ///
  /// In en, this message translates to:
  /// **'Table Code'**
  String get developerHubTableCode;

  /// No description provided for @developerHubTableName.
  ///
  /// In en, this message translates to:
  /// **'Table Name'**
  String get developerHubTableName;

  /// No description provided for @developerHubCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get developerHubCapacity;

  /// No description provided for @developerHubActiveForService.
  ///
  /// In en, this message translates to:
  /// **'Active for service'**
  String get developerHubActiveForService;

  /// No description provided for @developerHubSelfOrderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Self-order enabled'**
  String get developerHubSelfOrderEnabled;

  /// No description provided for @developerHubLaunchpad.
  ///
  /// In en, this message translates to:
  /// **'Launchpad'**
  String get developerHubLaunchpad;

  /// No description provided for @developerHubPolicyCenter.
  ///
  /// In en, this message translates to:
  /// **'Policy Center'**
  String get developerHubPolicyCenter;

  /// No description provided for @developerHubTableQrStudio.
  ///
  /// In en, this message translates to:
  /// **'Table QR Studio'**
  String get developerHubTableQrStudio;

  /// No description provided for @developerHubSessionLab.
  ///
  /// In en, this message translates to:
  /// **'Session Lab'**
  String get developerHubSessionLab;

  /// No description provided for @developerHubDeviceLock.
  ///
  /// In en, this message translates to:
  /// **'Device Lock'**
  String get developerHubDeviceLock;

  /// No description provided for @developerHubApiLogs.
  ///
  /// In en, this message translates to:
  /// **'API Logs'**
  String get developerHubApiLogs;

  /// No description provided for @developerHubApiLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every request to central and tenant endpoints is captured here with method, endpoint, body, response, error, and duration.'**
  String get developerHubApiLogsSubtitle;

  /// No description provided for @developerHubEmptyApiLogs.
  ///
  /// In en, this message translates to:
  /// **'No API calls have been captured yet. Trigger login, refresh, or SQLite sync first.'**
  String get developerHubEmptyApiLogs;

  /// No description provided for @developerHubHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A cleaner new chapter for self-order, table QR, and device lock.'**
  String get developerHubHeroSubtitle;

  /// No description provided for @developerHubConnectionDeck.
  ///
  /// In en, this message translates to:
  /// **'Connection Deck'**
  String get developerHubConnectionDeck;

  /// No description provided for @developerHubCentralLoginBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Central Login Base URL'**
  String get developerHubCentralLoginBaseUrl;

  /// No description provided for @developerHubTenantBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Tenant Base URL'**
  String get developerHubTenantBaseUrl;

  /// No description provided for @developerHubAuthToken.
  ///
  /// In en, this message translates to:
  /// **'Auth Token'**
  String get developerHubAuthToken;

  /// No description provided for @developerHubLoginEmail.
  ///
  /// In en, this message translates to:
  /// **'Login Email'**
  String get developerHubLoginEmail;

  /// No description provided for @developerHubLoginPassword.
  ///
  /// In en, this message translates to:
  /// **'Login Password'**
  String get developerHubLoginPassword;

  /// No description provided for @developerHubLoginAction.
  ///
  /// In en, this message translates to:
  /// **'Login And Load Bootstrap'**
  String get developerHubLoginAction;

  /// No description provided for @developerHubSyncSqliteAction.
  ///
  /// In en, this message translates to:
  /// **'Sync SQLite Snapshot'**
  String get developerHubSyncSqliteAction;

  /// No description provided for @developerHubLoginIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Complete tenant base URL, email, password, and device ID first.'**
  String get developerHubLoginIncomplete;

  /// No description provided for @developerHubLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login first so the tenant session and location are known.'**
  String get developerHubLoginRequired;

  /// No description provided for @developerHubLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login succeeded and bootstrap was stored locally.'**
  String get developerHubLoginSuccess;

  /// No description provided for @developerHubSqliteSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'SQLite snapshot refreshed from the V2 endpoints.'**
  String get developerHubSqliteSyncSuccess;

  /// No description provided for @catalogEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog is empty'**
  String get catalogEmptyTitle;

  /// No description provided for @catalogEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync items, categories, and brands from the API into SQLite first so POS can read the local source of truth.'**
  String get catalogEmptySubtitle;

  /// No description provided for @developerHubActingStaffId.
  ///
  /// In en, this message translates to:
  /// **'Acting Staff ID'**
  String get developerHubActingStaffId;

  /// No description provided for @developerHubDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get developerHubDeviceId;

  /// No description provided for @developerHubRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get developerHubRefreshing;

  /// No description provided for @developerHubRefreshBackendState.
  ///
  /// In en, this message translates to:
  /// **'Refresh Backend State'**
  String get developerHubRefreshBackendState;

  /// No description provided for @developerHubLaunchpadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The backend foundation is ready. Review the active mode, prepare table QR, and inspect device lock from here without touching the legacy POS.'**
  String get developerHubLaunchpadSubtitle;

  /// No description provided for @developerHubOperatingMode.
  ///
  /// In en, this message translates to:
  /// **'Operating Mode'**
  String get developerHubOperatingMode;

  /// No description provided for @developerHubOperatingModeHint.
  ///
  /// In en, this message translates to:
  /// **'Classic or self_order_hybrid'**
  String get developerHubOperatingModeHint;

  /// No description provided for @developerHubSelfOrderMetric.
  ///
  /// In en, this message translates to:
  /// **'Self-Order'**
  String get developerHubSelfOrderMetric;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @developerHubSelfOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Kiosk, table, and resume order'**
  String get developerHubSelfOrderHint;

  /// No description provided for @developerHubStrict.
  ///
  /// In en, this message translates to:
  /// **'Strict'**
  String get developerHubStrict;

  /// No description provided for @developerHubFlexible.
  ///
  /// In en, this message translates to:
  /// **'Flexible'**
  String get developerHubFlexible;

  /// No description provided for @developerHubDeviceLockHint.
  ///
  /// In en, this message translates to:
  /// **'1 staff = 1 active device'**
  String get developerHubDeviceLockHint;

  /// No description provided for @developerHubTableQr.
  ///
  /// In en, this message translates to:
  /// **'Table QR'**
  String get developerHubTableQr;

  /// No description provided for @developerHubTableCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tables'**
  String developerHubTableCount(int count);

  /// No description provided for @developerHubTableQrHint.
  ///
  /// In en, this message translates to:
  /// **'Static, printable, and ready to stick'**
  String get developerHubTableQrHint;

  /// No description provided for @developerHubActiveDevices.
  ///
  /// In en, this message translates to:
  /// **'Active Devices'**
  String get developerHubActiveDevices;

  /// No description provided for @developerHubActiveSessionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String developerHubActiveSessionCount(int count);

  /// No description provided for @developerHubActiveDevicesHint.
  ///
  /// In en, this message translates to:
  /// **'Can be force-closed by supervisor/owner'**
  String get developerHubActiveDevicesHint;

  /// No description provided for @developerHubPriorityQuestion.
  ///
  /// In en, this message translates to:
  /// **'What matters most right now?'**
  String get developerHubPriorityQuestion;

  /// No description provided for @developerHubPriorityAnswer.
  ///
  /// In en, this message translates to:
  /// **'Static table QR is generated from the backend as the canonical payload, and `flinkpos_v2` renders, downloads, and prints it. The link stays consistent while the printed look stays flexible inside the app.'**
  String get developerHubPriorityAnswer;

  /// No description provided for @developerHubPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Owners and supervisors can choose a strict classic flow or a self-order hybrid. Core settings are stored in the backend and broadcast again through bootstrap.'**
  String get developerHubPolicySubtitle;

  /// No description provided for @developerHubClassicPosFlow.
  ///
  /// In en, this message translates to:
  /// **'Classic POS Flow'**
  String get developerHubClassicPosFlow;

  /// No description provided for @developerHubSelfOrderHybrid.
  ///
  /// In en, this message translates to:
  /// **'Self-Order Hybrid'**
  String get developerHubSelfOrderHybrid;

  /// No description provided for @developerHubEnableSelfOrderFoundation.
  ///
  /// In en, this message translates to:
  /// **'Enable self-order foundation'**
  String get developerHubEnableSelfOrderFoundation;

  /// No description provided for @developerHubEnableSelfOrderFoundationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable QR sessions, resume order, and table QR'**
  String get developerHubEnableSelfOrderFoundationSubtitle;

  /// No description provided for @developerHubAllowPayLater.
  ///
  /// In en, this message translates to:
  /// **'Allow pay later'**
  String get developerHubAllowPayLater;

  /// No description provided for @developerHubAllowPayLaterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customers can add items and pay later at the cashier'**
  String get developerHubAllowPayLaterSubtitle;

  /// No description provided for @developerHubAllowAddAfterSubmit.
  ///
  /// In en, this message translates to:
  /// **'Allow add after submit'**
  String get developerHubAllowAddAfterSubmit;

  /// No description provided for @developerHubAllowAddAfterSubmitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The same session can still add items before final checkout'**
  String get developerHubAllowAddAfterSubmitSubtitle;

  /// No description provided for @developerHubFeedbackUrl.
  ///
  /// In en, this message translates to:
  /// **'Feedback URL'**
  String get developerHubFeedbackUrl;

  /// No description provided for @developerHubOnlineStoreBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Online Store Base URL'**
  String get developerHubOnlineStoreBaseUrl;

  /// No description provided for @developerHubSavePolicyToBackend.
  ///
  /// In en, this message translates to:
  /// **'Save Policy to Backend'**
  String get developerHubSavePolicyToBackend;

  /// No description provided for @developerHubPrintQrKit.
  ///
  /// In en, this message translates to:
  /// **'Print QR Kit'**
  String get developerHubPrintQrKit;

  /// No description provided for @developerHubAddTable.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get developerHubAddTable;

  /// No description provided for @developerHubTableQrStudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This generates the table QR that will be placed on site. The backend stores the token and canonical URL, while `flinkpos_v2` renders the QR on screen and exports PDF for printing.'**
  String get developerHubTableQrStudioSubtitle;

  /// No description provided for @developerHubEmptyTablesTitle.
  ///
  /// In en, this message translates to:
  /// **'No table QR yet'**
  String get developerHubEmptyTablesTitle;

  /// No description provided for @developerHubEmptyTablesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create the table registry first so each static table QR can be downloaded and printed.'**
  String get developerHubEmptyTablesSubtitle;

  /// No description provided for @developerHubSessionLabSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Simulate a customer session: choose a table, open a session, and the backend will return two QR payloads for feedback and resume order.'**
  String get developerHubSessionLabSubtitle;

  /// No description provided for @developerHubServiceTable.
  ///
  /// In en, this message translates to:
  /// **'Service Table'**
  String get developerHubServiceTable;

  /// No description provided for @developerHubPreviewCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Preview Customer Name'**
  String get developerHubPreviewCustomerName;

  /// No description provided for @developerHubGenerateSessionQrPreview.
  ///
  /// In en, this message translates to:
  /// **'Generate Session QR Preview'**
  String get developerHubGenerateSessionQrPreview;

  /// No description provided for @developerHubFeedbackQr.
  ///
  /// In en, this message translates to:
  /// **'Feedback QR'**
  String get developerHubFeedbackQr;

  /// No description provided for @developerHubFeedbackQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For feedback, suggestions, and confirmation that the customer holds a digital receipt.'**
  String get developerHubFeedbackQrSubtitle;

  /// No description provided for @developerHubQueueBadge.
  ///
  /// In en, this message translates to:
  /// **'Queue {queueNumber}'**
  String developerHubQueueBadge(String queueNumber);

  /// No description provided for @developerHubResumeOrderQr.
  ///
  /// In en, this message translates to:
  /// **'Resume Order QR'**
  String get developerHubResumeOrderQr;

  /// No description provided for @developerHubResumeOrderQrSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan again on the customer\'s phone or the cashier tablet to add items or continue payment.'**
  String get developerHubResumeOrderQrSubtitle;

  /// No description provided for @developerHubSelfOrderBadge.
  ///
  /// In en, this message translates to:
  /// **'Self Order'**
  String get developerHubSelfOrderBadge;

  /// No description provided for @developerHubEmptySessionPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'No session preview yet'**
  String get developerHubEmptySessionPreviewTitle;

  /// No description provided for @developerHubEmptySessionPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate one session first to see the customer receipt QR format.'**
  String get developerHubEmptySessionPreviewSubtitle;

  /// No description provided for @developerHubDeviceLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If the same account is stuck on an old device, the owner or supervisor can remove it here without waiting for that device to be touched first.'**
  String get developerHubDeviceLockSubtitle;

  /// No description provided for @developerHubEmptyActiveSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No active sessions'**
  String get developerHubEmptyActiveSessionsTitle;

  /// No description provided for @developerHubEmptyActiveSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When staff sign in from another device, the active list will appear here.'**
  String get developerHubEmptyActiveSessionsSubtitle;

  /// No description provided for @developerHubZoneFallback.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get developerHubZoneFallback;

  /// No description provided for @developerHubSeatCount.
  ///
  /// In en, this message translates to:
  /// **'Seat {count}'**
  String developerHubSeatCount(String count);

  /// No description provided for @developerHubStaffSessionSummary.
  ///
  /// In en, this message translates to:
  /// **'Staff #{staffId} • {role} • {platform}'**
  String developerHubStaffSessionSummary(
    String staffId,
    String role,
    String platform,
  );

  /// No description provided for @developerHubLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen: {value}'**
  String developerHubLastSeen(String value);

  /// No description provided for @developerHubForceCloseAction.
  ///
  /// In en, this message translates to:
  /// **'Force Close'**
  String get developerHubForceCloseAction;

  /// No description provided for @totalCustomers.
  ///
  /// In en, this message translates to:
  /// **'Total Customers'**
  String get totalCustomers;

  /// No description provided for @newCustomersToday.
  ///
  /// In en, this message translates to:
  /// **'{count} new customers today'**
  String newCustomersToday(int count);

  /// No description provided for @activeCustomers.
  ///
  /// In en, this message translates to:
  /// **'Active Customers'**
  String get activeCustomers;

  /// No description provided for @inLast30Days.
  ///
  /// In en, this message translates to:
  /// **'In the last 30 days'**
  String get inLast30Days;

  /// No description provided for @averageVisits.
  ///
  /// In en, this message translates to:
  /// **'Average Visits'**
  String get averageVisits;

  /// No description provided for @visitsPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Visits per month'**
  String get visitsPerMonth;

  /// No description provided for @customerChartNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Customer Chart Not Available'**
  String get customerChartNotAvailable;

  /// No description provided for @waitingForDesignData.
  ///
  /// In en, this message translates to:
  /// **'Waiting for specific design data for this chart.'**
  String get waitingForDesignData;

  /// No description provided for @filterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get filterToday;

  /// No description provided for @filterYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get filterYesterday;

  /// No description provided for @filterLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get filterLast7Days;

  /// No description provided for @filterLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get filterLast30Days;

  /// No description provided for @filterThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get filterThisMonth;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @promoNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Promo requirements not met'**
  String get promoNotApplicable;

  /// No description provided for @settingsGeneralTitle.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneralTitle;

  /// No description provided for @settingsGeneralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'General settings and tenant profile'**
  String get settingsGeneralSubtitle;

  /// No description provided for @settingsStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get settingsStoreTitle;

  /// No description provided for @settingsStoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Store profile and operations configuration'**
  String get settingsStoreSubtitle;

  /// No description provided for @settingsPrinterTitle.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get settingsPrinterTitle;

  /// No description provided for @settingsPrinterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cashier and kitchen printer management'**
  String get settingsPrinterSubtitle;

  /// No description provided for @settingsSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get settingsSyncTitle;

  /// No description provided for @settingsSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync and offline data management'**
  String get settingsSyncSubtitle;

  /// No description provided for @settingsDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get settingsDeviceTitle;

  /// No description provided for @settingsDeviceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Device status and system updates'**
  String get settingsDeviceSubtitle;

  /// No description provided for @settingsCompanyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get settingsCompanyNameLabel;

  /// No description provided for @settingsLocationIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Location ID'**
  String get settingsLocationIdLabel;

  /// No description provided for @settingsServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get settingsServerUrlLabel;

  /// No description provided for @settingsDeviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get settingsDeviceIdLabel;

  /// No description provided for @settingsAppInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'App Info'**
  String get settingsAppInfoTitle;

  /// No description provided for @settingsAppInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version and developer information'**
  String get settingsAppInfoSubtitle;

  /// No description provided for @settingsCheckUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get settingsCheckUpdatesTitle;

  /// No description provided for @settingsCheckUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check if a newer version is available'**
  String get settingsCheckUpdatesSubtitle;

  /// No description provided for @settingsAllowSellOutOfStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow Selling Out of Stock'**
  String get settingsAllowSellOutOfStockTitle;

  /// No description provided for @settingsAllowSellOutOfStockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable adding products to cart even when system stock is 0'**
  String get settingsAllowSellOutOfStockSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
