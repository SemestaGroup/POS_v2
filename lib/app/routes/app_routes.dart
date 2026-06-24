abstract final class AppRoutes {
  static const merchantLogin = '/auth/merchant-login';
  static const staffSelector = '/auth/staff-selector';
  static const lockscreen = '/auth/lockscreen';

  static const ownerShell = '/shell/owner';
  static const supervisorShell = '/shell/supervisor';
  static const cashierShell = '/shell/cashier';
  static const kitchenShell = '/shell/kitchen';

  static const ownerOverview = '/overview/owner';
  static const supervisorOverview = '/overview/supervisor';

  static const posWorkspace = '/sales/pos/workspace';
  static const checkout = '/sales/pos/checkout';
  static const paymentSuccess = '/sales/pos/payment-success';
  static const activeOrders = '/sales/orders/active';
  static const parkedOrders = '/sales/orders/parked';
  static const salesHistoryLite = '/sales/orders/history-lite';

  static const shiftOpen = '/operations/shift/open';
  static const shiftClose = '/operations/shift/close';
  static const shiftHistory = '/operations/shift/history';
  static const recapSummary = '/operations/recap/summary';
  static const paymentAudit = '/operations/recap/payment-audit';
  static const cashFlowReview = '/operations/recap/cash-flow-review';
  static const kitchenBoard = '/operations/kitchen/board';
  static const kitchenTicketDetail = '/operations/kitchen/ticket-detail';

  static const reportSummary = '/reports/summary';
  static const salesReport = '/reports/sales';
  static const productReport = '/reports/products';
  static const staffReport = '/reports/staff';
  static const cashierReportLite = '/reports/cashier-lite';

  static const products = '/master-data/catalog/products';
  static const categories = '/master-data/catalog/categories';
  static const brands = '/master-data/catalog/brands';
  static const promos = '/master-data/catalog/promos';
  static const customerList = '/master-data/customers/list';
  static const customerDetail = '/master-data/customers/detail';
  static const staffList = '/master-data/staff/list';
  static const staffRoles = '/master-data/staff/roles';

  static const generalSettings = '/settings/general';
  static const profileSettings = '/settings/profile';
  static const storeProfile = '/settings/store/profile';
  static const shiftConfig = '/settings/store/shift-config';
  static const printerList = '/settings/printers/list';
  static const printerMapping = '/settings/printers/mapping';
  static const printerTest = '/settings/printers/test';
  static const syncCenter = '/settings/sync/center';
  static const syncHistory = '/settings/sync/history';
  static const appUpdate = '/settings/device/update';
  static const deviceStatus = '/settings/device/status';

  static const developerHub = '/programmer/hub';
  static const databaseInspector = '/programmer/database-inspector';
  static const syncQueueInspector = '/programmer/sync-queue-inspector';
  static const apiLogViewer = '/programmer/api-log-viewer';
  static const printerDiagnostics = '/programmer/printer-diagnostics';
  static const featureFlags = '/programmer/feature-flags';
}
