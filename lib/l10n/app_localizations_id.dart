// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get posTitle => 'Kasir';

  @override
  String get activeOrdersTitle => 'Pesanan Aktif';

  @override
  String get resumeOrderTitle => 'Lanjutkan Pesanan';

  @override
  String get historyTitle => 'Riwayat';

  @override
  String get searchPlaceholder => 'Cari ID atau Pelanggan...';

  @override
  String get newOrder => 'Pesanan Baru';

  @override
  String ordersFound(int count) {
    return '$count pesanan ditemukan';
  }

  @override
  String get overview => 'Ringkasan';

  @override
  String get sales => 'Penjualan';

  @override
  String get operations => 'Operasional';

  @override
  String get reports => 'Laporan';

  @override
  String get masterData => 'Data Master';

  @override
  String get settings => 'Pengaturan';

  @override
  String comingSoon(String title) {
    return '$title Segera Hadir';
  }

  @override
  String get all => 'Semua';

  @override
  String get promo => 'Promo';

  @override
  String get chooseTable => 'Pilih Meja';

  @override
  String ordersWithCount(int count) {
    return 'Pesanan $count';
  }

  @override
  String get orders => 'Pesanan';

  @override
  String get customer => 'Pelanggan';

  @override
  String get walkInCustomer => 'Pelanggan Biasa';

  @override
  String get dineIn => 'Dine In';

  @override
  String get orderNote => 'Catatan';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get tax => 'Pajak';

  @override
  String get discount => 'Diskon';

  @override
  String get totalPay => 'Total Bayar';

  @override
  String get sendToKitchen => 'Kirim ke Dapur';

  @override
  String get save => 'Simpan';

  @override
  String get payNow => 'Bayar';

  @override
  String get searchProduct => 'Cari Produk...';

  @override
  String get cancel => 'Batal';

  @override
  String get enterNotes => 'Masukkan catatan di sini...';

  @override
  String get searchCustomer => 'Cari berdasarkan nama atau telepon...';

  @override
  String get selectOrderType => 'Pilih Tipe Pesanan';

  @override
  String get takeAway => 'Bungkus';

  @override
  String get enterNotesHere => 'Masukkan catatan di sini...';

  @override
  String get searchAddCustomer => 'Cari / Tambah Pelanggan';

  @override
  String get searchByNameOrPhone => 'Cari berdasarkan nama atau telepon...';

  @override
  String get addNewCustomer => 'Tambah Pelanggan Baru';

  @override
  String get noCustomerSearchResults => 'Belum ada hasil pelanggan';

  @override
  String get customerNameLabel => 'Nama Pelanggan';

  @override
  String get customerPhoneLabel => 'Nomor Telepon';

  @override
  String get customerAddressLabel => 'Alamat';

  @override
  String get customerNameRequiredMessage => 'Nama pelanggan wajib diisi.';

  @override
  String get customerSelectionRequiredMessage =>
      'Pilih atau tambahkan pelanggan sebelum menyimpan pesanan.';

  @override
  String get shiftRequiredBeforeOrderMessage =>
      'Buka shift aktif terlebih dahulu sebelum menyimpan atau mengirim pesanan.';

  @override
  String get quantity => 'Kuantitas';

  @override
  String get orderType => 'Tipe Pesanan';

  @override
  String get note => 'Catatan';

  @override
  String get anySpecialRequests => 'Ada permintaan khusus?';

  @override
  String get splitItem => 'Pisah Item';

  @override
  String get saveDetails => 'Simpan Detail';

  @override
  String get totalSales => 'Total Penjualan';

  @override
  String get avgSalesPerTransaction => 'Rata-Rata Penjualan/Transaksi';

  @override
  String get transactions => 'Transaksi';

  @override
  String get totalDiscount => 'Total Diskon';

  @override
  String get applyFilter => 'Terapkan Filter';

  @override
  String get dailySales => 'Penjualan Harian >';

  @override
  String lastModified(String date, String time) {
    return 'Terakhir diubah pada $date pukul $time';
  }

  @override
  String transactionsWithCount(String count) {
    return '$count Transaksi';
  }

  @override
  String get operationsHeader => 'Operasional';

  @override
  String get operationsSubtitle => 'Pilih area kerja operasional di panel ini.';

  @override
  String get operationsUnavailableMessage =>
      'Tidak ada menu operasional untuk peran ini.';

  @override
  String get shiftMenu => 'Shift';

  @override
  String get recapMenu => 'Rekap';

  @override
  String get cashFlowMenu => 'Arus Kas';

  @override
  String get kitchenMonitorMenu => 'Monitor Dapur';

  @override
  String get masterDataSubtitle => 'Pilih data master yang ingin dikelola.';

  @override
  String get masterDataUnavailableMessage =>
      'Tidak ada data master untuk peran ini.';

  @override
  String get productsMenu => 'Produk';

  @override
  String get categoriesMenu => 'Kategori';

  @override
  String get brandsMenu => 'Merek';

  @override
  String get promosMenu => 'Promo';

  @override
  String get customerListMenu => 'Daftar Pelanggan';

  @override
  String get customerDetailMenu => 'Detail Pelanggan';

  @override
  String get staffListMenu => 'Daftar Staf';

  @override
  String get staffRolesMenu => 'Peran Staf';

  @override
  String get settingsSubtitle => 'Pilih area pengaturan yang ingin ditinjau.';

  @override
  String get settingsUnavailableMessage =>
      'Tidak ada pengaturan untuk peran ini.';

  @override
  String get generalSettingsMenu => 'Pengaturan Umum';

  @override
  String get profileSettingsMenu => 'Pengaturan Profil';

  @override
  String get storeProfileMenu => 'Profil Toko';

  @override
  String get shiftConfigMenu => 'Konfigurasi Shift';

  @override
  String get printerListMenu => 'Daftar Printer';

  @override
  String get printerMappingMenu => 'Pemetaan Printer';

  @override
  String get printerTestMenu => 'Tes Printer';

  @override
  String get syncCenterMenu => 'Pusat Sinkronisasi';

  @override
  String get syncHistoryMenu => 'Riwayat Sinkronisasi';

  @override
  String get appUpdateMenu => 'Pembaruan Aplikasi';

  @override
  String get deviceStatusMenu => 'Status Perangkat';

  @override
  String placeholderPage(String title) {
    return 'Halaman Sementara $title';
  }

  @override
  String get orderNoteSubtitle =>
      'Tambahkan arahan singkat untuk kasir atau dapur.';

  @override
  String get noteAdded => 'Catatan Ditambahkan';

  @override
  String get orderStatusActive => 'Aktif';

  @override
  String get orderStatusClosed => 'Selesai';

  @override
  String get orderStatusPartially => 'Parsial';

  @override
  String get orderStatusOverdue => 'Jatuh Tempo';

  @override
  String get orderStatusVoid => 'Void';

  @override
  String get orderStatusParked => 'Parkir';

  @override
  String get applyPromoAction => 'Terapkan Promo';

  @override
  String get clearOrderAction => 'Kosongkan Pesanan';

  @override
  String get cancelOrderAction => 'Batalkan Pesanan';

  @override
  String get syncDataAction => 'Sinkronkan Data';

  @override
  String get closeOutletAction => 'Tutup Outlet';

  @override
  String get deleteAction => 'Hapus';

  @override
  String get resumeAction => 'Lanjutkan';

  @override
  String get applyPromoTitle => 'Terapkan Promo';

  @override
  String get applyPromoSubtitle =>
      'Promo ini berlaku untuk keseluruhan pesanan.';

  @override
  String get removePromoAction => 'Hapus Promo';

  @override
  String get addProductFirstMessage => 'Tambahkan produk terlebih dahulu.';

  @override
  String get activeOrderCreatedMessage => 'Pesanan aktif berhasil dibuat.';

  @override
  String get closedOrderCreatedMessage => 'Pesanan ditutup sebagai selesai.';

  @override
  String get voidOrderCreatedMessage =>
      'Pesanan dibatalkan dan masuk riwayat void.';

  @override
  String get parkedOrderCreatedMessage => 'Pesanan disimpan sebagai parkir.';

  @override
  String get splitItemMinQuantityMessage =>
      'Item harus minimal qty 2 untuk dipisah.';

  @override
  String get productDiscountEnabled => 'Diskon produk aktif';

  @override
  String get productDiscountDisabled => 'Diskon produk dimatikan';

  @override
  String get splitQuantityLabel => 'Jumlah Dipisah';

  @override
  String splitPreview(int left, int right) {
    return 'Hasil: $left dan $right';
  }

  @override
  String get emptyActiveOrdersMessage =>
      'Belum ada pesanan aktif dari workspace kasir.';

  @override
  String get emptyParkedOrdersMessage =>
      'Belum ada pesanan parked yang disimpan dari kasir.';

  @override
  String get emptyHistoryMessage =>
      'Belum ada order selesai, overdue, atau void.';

  @override
  String get table => 'Meja';

  @override
  String get online => 'Online';

  @override
  String orderSummary(int count, String type) {
    return '$count item • $type';
  }

  @override
  String itemsCount(int count) {
    return '$count item';
  }

  @override
  String get choosePromo => 'Pilih Promo';

  @override
  String get choosePromoSubtitle => 'Pilih salah satu promo yang tersedia';

  @override
  String get noApplicablePromotionsMessage =>
      'Belum ada promo yang cocok untuk isi keranjang saat ini.';

  @override
  String get manualDiscount => 'Diskon Manual';

  @override
  String get manualDiscountSubtitle => 'Masukkan nominal diskon (Rp)';

  @override
  String get discountTypeRp => 'Rupiah (Rp)';

  @override
  String get discountTypePercent => 'Persen (%)';

  @override
  String get applyDiscount => 'Terapkan Diskon';

  @override
  String get emptyCartTitle => 'Belum Ada Pesanan!';

  @override
  String get emptyCartSubtitle => 'Tambahkan item dari menu untuk memulai';

  @override
  String get noAdditionalOptions => 'Tidak ada opsi\ntambahan tersedia.';

  @override
  String get reportsSubtitle => 'Pilih laporan yang ingin Anda tinjau.';

  @override
  String get reportsUnavailableMessage => 'Tidak ada laporan untuk peran ini.';

  @override
  String get reportSummaryMenu => 'Ringkasan Laporan';

  @override
  String get salesReportMenu => 'Laporan Penjualan';

  @override
  String get productReportMenu => 'Laporan Produk';

  @override
  String get staffReportMenu => 'Laporan Staf';

  @override
  String get cashierReportLiteMenu => 'Laporan Kasir';

  @override
  String get optionOne => 'Opsi 1';

  @override
  String get optionTwo => 'Opsi 2';

  @override
  String get stock => 'Stok';

  @override
  String get code => 'Kode';

  @override
  String get date => 'Tanggal';

  @override
  String get status => 'Status';

  @override
  String get editAction => 'Edit';

  @override
  String get copyUrlAction => 'Salin URL';

  @override
  String get ownerRoleLabel => 'Pemilik';

  @override
  String get supervisorRoleLabel => 'Supervisor';

  @override
  String get cashierRoleLabel => 'Kasir';

  @override
  String get kitchenRoleLabel => 'Dapur';

  @override
  String get programmerRoleLabel => 'Programmer';

  @override
  String get loginHeroTagline =>
      'Kelola bisnis Anda lebih efisien\ndengan sistem kasir modern.';

  @override
  String get loginTitle => 'Masuk';

  @override
  String get loginSubtitle =>
      'Masukkan field yang dibutuhkan untuk request login ke pusat. Setelah berhasil, data tenant akan disinkronkan otomatis.';

  @override
  String get centralLoginBaseUrl => 'Central Login Base URL';

  @override
  String get authTokenLabel => 'Auth Token';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get deviceIdLabel => 'ID Perangkat';

  @override
  String get loginButton => 'Login';

  @override
  String get loginFormIncomplete =>
      'Lengkapi email, password, dan ID perangkat terlebih dahulu.';

  @override
  String get loginRequiredMessage => 'Login diperlukan sebelum ganti akun.';

  @override
  String get switchAccountTitle => 'Ganti Akun';

  @override
  String get switchAccountAction => 'Ganti Akun';

  @override
  String get switchAccountUserLabel => 'Pengguna';

  @override
  String get switchAccountPinLabel => 'PIN';

  @override
  String get switchAccountNoCachedStaff =>
      'Belum ada akun staf yang tersimpan lokal. Sinkronkan data staf terlebih dahulu.';

  @override
  String get switchAccountSuccess => 'Akun berhasil diganti.';

  @override
  String get switchAccountIncomplete =>
      'Pilih pengguna dan isi PIN terlebih dahulu.';

  @override
  String get shiftGateTitle => 'Buka Shift Dulu';

  @override
  String get shiftGateSubtitle =>
      'Sesi kasir membutuhkan shift aktif sebelum transaksi POS bisa dimulai.';

  @override
  String get shiftGateIncomplete =>
      'Lengkapi nama shift dan saldo awal terlebih dahulu.';

  @override
  String get locationLabel => 'Lokasi';

  @override
  String get shiftNameLabel => 'Nama Shift';

  @override
  String get openingBalanceLabel => 'Saldo Awal';

  @override
  String get openShiftAction => 'Buka Shift Dan Lanjutkan';

  @override
  String get chooseBrandTitle => 'Pilih Brand';

  @override
  String get syncPreparingTitle => 'Menyiapkan Toko Anda';

  @override
  String get syncPreparingSettings => 'Mengunduh pengaturan toko...';

  @override
  String get syncPreparingShift => 'Memeriksa shift aktif...';

  @override
  String get syncPreparingCategoriesBrands => 'Mengunduh kategori dan brand...';

  @override
  String get syncPreparingCatalog => 'Mengunduh katalog produk...';

  @override
  String get syncPreparingLocalCache => 'Memuat cache lokal...';

  @override
  String get syncPreparingError => 'Gagal mengunduh data:';

  @override
  String get retryAction => 'Coba Lagi';

  @override
  String get syncStatusIdle => 'Sync Idle';

  @override
  String get syncStatusPreparing => 'Menyiapkan POS';

  @override
  String get syncStatusSyncing => 'Sinkronisasi Data';

  @override
  String get syncStatusUpToDate => 'Sudah Terbaru';

  @override
  String get syncStatusFailed => 'Sync Gagal';

  @override
  String featureNotWiredMessage(String feature) {
    return '$feature belum dihubungkan.';
  }

  @override
  String get selectOrderTypeSubtitle =>
      'Pilih channel penjualan yang paling sesuai untuk transaksi ini.';

  @override
  String get thousandShort => 'Rb';

  @override
  String get millionShort => 'Jt';

  @override
  String get overviewMultiBrandSales => 'Penjualan Multi Brand';

  @override
  String get overviewSalesTrendChart => 'Grafik Tren Penjualan';

  @override
  String get overviewPeakHours => 'Jam Ramai';

  @override
  String get overviewMonthlySalesTrend => 'Tren Penjualan Bulanan';

  @override
  String get overviewTopFiveBestSelling => '5 Produk Terlaris';

  @override
  String get overviewLowStockAlert => 'Peringatan Stok Menipis';

  @override
  String get overviewLowStatus => 'Rendah';

  @override
  String get overviewSystemIntegrationLogStatus =>
      'Log & Status Integrasi Sistem';

  @override
  String get overviewMekariJurnalSync => 'Sinkronisasi Mekari Jurnal';

  @override
  String get overviewSuccess200Ok => 'Berhasil (200 OK)';

  @override
  String get overviewSupabaseConnectivity => 'Konektivitas Supabase';

  @override
  String get overviewLiveTransactionFeed => 'Feed Transaksi Langsung';

  @override
  String get overviewCredit => 'Kredit';

  @override
  String get overviewCash => 'Tunai';

  @override
  String get developerHubGuestWalkIn => 'Tamu Walk-in';

  @override
  String get developerHubRefreshSuccess =>
      'Deck diperbarui. Fondasi V2 terbaru sudah dimuat ulang.';

  @override
  String get developerHubSavePolicySuccess =>
      'Mode operasi dan pengaturan self-order berhasil diperbarui.';

  @override
  String get developerHubSelectTableFirst =>
      'Pilih meja dulu sebelum membuat sesi QR.';

  @override
  String get developerHubSessionPreviewSuccess =>
      'Sesi QR pelanggan berhasil dibuat. Gunakan untuk nota atau pratinjau.';

  @override
  String get developerHubForceCloseSessionSuccess =>
      'Sesi perangkat lama berhasil ditutup.';

  @override
  String developerHubTableDeleted(String tableName) {
    return 'Meja $tableName berhasil dihapus.';
  }

  @override
  String get developerHubTableCreatedSuccess => 'Meja baru berhasil dibuat.';

  @override
  String get developerHubTableUpdatedSuccess =>
      'Data meja berhasil diperbarui.';

  @override
  String get developerHubNoActiveTablesToPrint =>
      'Belum ada meja aktif untuk dicetak.';

  @override
  String get developerHubTableQrKit => 'Paket QR Meja';

  @override
  String get developerHubPrintReadySuccess =>
      'QR meja siap dicetak atau disimpan sebagai PDF.';

  @override
  String get developerHubAddQrTableTitle => 'Tambah Meja QR';

  @override
  String get developerHubEditQrTableTitle => 'Edit Meja QR';

  @override
  String get developerHubAreaZone => 'Area / Zona';

  @override
  String get developerHubTableCode => 'Kode Meja';

  @override
  String get developerHubTableName => 'Nama Meja';

  @override
  String get developerHubCapacity => 'Kapasitas';

  @override
  String get developerHubActiveForService => 'Aktif untuk layanan';

  @override
  String get developerHubSelfOrderEnabled => 'Self-order aktif';

  @override
  String get developerHubLaunchpad => 'Pusat Kendali';

  @override
  String get developerHubPolicyCenter => 'Pusat Kebijakan';

  @override
  String get developerHubTableQrStudio => 'Studio QR Meja';

  @override
  String get developerHubSessionLab => 'Lab Sesi';

  @override
  String get developerHubDeviceLock => 'Kunci Perangkat';

  @override
  String get developerHubApiLogs => 'Log API';

  @override
  String get developerHubApiLogsSubtitle =>
      'Setiap request ke endpoint central dan tenant dicatat di sini lengkap dengan method, endpoint, body, response, error, dan durasi.';

  @override
  String get developerHubEmptyApiLogs =>
      'Belum ada panggilan API yang terekam. Jalankan login, refresh, atau sinkronisasi SQLite terlebih dahulu.';

  @override
  String get developerHubHeroSubtitle =>
      'Bab baru yang lebih rapi untuk self-order, QR meja, dan kunci perangkat.';

  @override
  String get developerHubConnectionDeck => 'Panel Koneksi';

  @override
  String get developerHubCentralLoginBaseUrl => 'Central Login Base URL';

  @override
  String get developerHubTenantBaseUrl => 'Tenant Base URL';

  @override
  String get developerHubAuthToken => 'Auth Token';

  @override
  String get developerHubLoginEmail => 'Email Login';

  @override
  String get developerHubLoginPassword => 'Password Login';

  @override
  String get developerHubLoginAction => 'Login Dan Muat Bootstrap';

  @override
  String get developerHubSyncSqliteAction => 'Sinkronkan Snapshot SQLite';

  @override
  String get developerHubLoginIncomplete =>
      'Lengkapi tenant base URL, email, password, dan ID perangkat terlebih dahulu.';

  @override
  String get developerHubLoginRequired =>
      'Login dulu supaya session tenant dan location sudah diketahui.';

  @override
  String get developerHubLoginSuccess =>
      'Login berhasil dan bootstrap sudah disimpan lokal.';

  @override
  String get developerHubSqliteSyncSuccess =>
      'Snapshot SQLite berhasil diperbarui dari endpoint V2.';

  @override
  String get catalogEmptyTitle => 'Katalog masih kosong';

  @override
  String get catalogEmptySubtitle =>
      'Sinkronkan items, kategori, dan brands dari API ke SQLite terlebih dahulu agar POS membaca source of truth lokal.';

  @override
  String get developerHubActingStaffId => 'ID Staf Pelaksana';

  @override
  String get developerHubDeviceId => 'ID Perangkat';

  @override
  String get developerHubRefreshing => 'Memuat ulang...';

  @override
  String get developerHubRefreshBackendState => 'Muat Ulang State Backend';

  @override
  String get developerHubLaunchpadSubtitle =>
      'Fondasi backend sudah siap. Dari sini kamu bisa melihat mode aktif, menyiapkan QR meja, dan meninjau kunci perangkat tanpa menyentuh POS lama.';

  @override
  String get developerHubOperatingMode => 'Mode Operasi';

  @override
  String get developerHubOperatingModeHint => 'Classic atau self_order_hybrid';

  @override
  String get developerHubSelfOrderMetric => 'Self-Order';

  @override
  String get enabled => 'Aktif';

  @override
  String get disabled => 'Nonaktif';

  @override
  String get developerHubSelfOrderHint => 'Kiosk, meja, dan lanjutkan pesanan';

  @override
  String get developerHubStrict => 'Ketat';

  @override
  String get developerHubFlexible => 'Fleksibel';

  @override
  String get developerHubDeviceLockHint => '1 staf = 1 perangkat aktif';

  @override
  String get developerHubTableQr => 'QR Meja';

  @override
  String developerHubTableCount(int count) {
    return '$count meja';
  }

  @override
  String get developerHubTableQrHint =>
      'Statis, mudah dicetak, dan siap ditempel';

  @override
  String get developerHubActiveDevices => 'Perangkat Aktif';

  @override
  String developerHubActiveSessionCount(int count) {
    return '$count sesi';
  }

  @override
  String get developerHubActiveDevicesHint =>
      'Bisa dipaksa keluar oleh supervisor/owner';

  @override
  String get developerHubPriorityQuestion =>
      'Apa yang paling penting sekarang?';

  @override
  String get developerHubPriorityAnswer =>
      'QR meja statis akan dihasilkan dari backend sebagai payload canonical, lalu `flinkpos_v2` yang merender, mengunduh, dan mencetaknya. Jadi link tetap konsisten, sementara tampilan cetaknya tetap fleksibel di aplikasi.';

  @override
  String get developerHubPolicySubtitle =>
      'Owner dan supervisor bisa memilih alur classic yang ketat atau self-order hybrid. Semua pengaturan inti disimpan di backend dan disiarkan lagi lewat bootstrap.';

  @override
  String get developerHubClassicPosFlow => 'Alur POS Classic';

  @override
  String get developerHubSelfOrderHybrid => 'Self-Order Hybrid';

  @override
  String get developerHubEnableSelfOrderFoundation =>
      'Aktifkan fondasi self-order';

  @override
  String get developerHubEnableSelfOrderFoundationSubtitle =>
      'Aktifkan sesi QR, lanjutkan pesanan, dan QR meja';

  @override
  String get developerHubAllowPayLater => 'Izinkan bayar nanti';

  @override
  String get developerHubAllowPayLaterSubtitle =>
      'Pelanggan boleh tambah pesanan lalu bayar belakangan di kasir';

  @override
  String get developerHubAllowAddAfterSubmit => 'Izinkan tambah setelah kirim';

  @override
  String get developerHubAllowAddAfterSubmitSubtitle =>
      'Sesi yang sama masih bisa menambah item sebelum checkout final';

  @override
  String get developerHubFeedbackUrl => 'URL Feedback';

  @override
  String get developerHubOnlineStoreBaseUrl => 'Base URL Toko Online';

  @override
  String get developerHubSavePolicyToBackend => 'Simpan Kebijakan ke Backend';

  @override
  String get developerHubPrintQrKit => 'Cetak Paket QR';

  @override
  String get developerHubAddTable => 'Tambah Meja';

  @override
  String get developerHubTableQrStudioSubtitle =>
      'Di sini QR meja yang akan ditempel dibuat. Backend menyimpan token dan URL canonical, sedangkan `flinkpos_v2` merender QR di layar dan mengekspor PDF untuk dicetak.';

  @override
  String get developerHubEmptyTablesTitle => 'Belum ada QR meja';

  @override
  String get developerHubEmptyTablesSubtitle =>
      'Buat registry meja dulu supaya QR statis per meja bisa diunduh dan dicetak.';

  @override
  String get developerHubSessionLabSubtitle =>
      'Simulasikan sesi pelanggan: pilih meja, buka sesi, lalu backend akan memberi dua payload QR untuk feedback dan lanjutkan pesanan.';

  @override
  String get developerHubServiceTable => 'Meja Layanan';

  @override
  String get developerHubPreviewCustomerName => 'Nama Pelanggan Pratinjau';

  @override
  String get developerHubGenerateSessionQrPreview => 'Buat Pratinjau QR Sesi';

  @override
  String get developerHubFeedbackQr => 'QR Feedback';

  @override
  String get developerHubFeedbackQrSubtitle =>
      'Untuk kritik, saran, dan memastikan pelanggan memegang nota digital.';

  @override
  String developerHubQueueBadge(String queueNumber) {
    return 'Antrean $queueNumber';
  }

  @override
  String get developerHubResumeOrderQr => 'QR Lanjutkan Pesanan';

  @override
  String get developerHubResumeOrderQrSubtitle =>
      'Pindai lagi di HP pelanggan atau tablet kasir untuk menambah item atau lanjut bayar.';

  @override
  String get developerHubSelfOrderBadge => 'Self Order';

  @override
  String get developerHubEmptySessionPreviewTitle => 'Belum ada pratinjau sesi';

  @override
  String get developerHubEmptySessionPreviewSubtitle =>
      'Buat satu sesi dulu untuk melihat bentuk QR nota pelanggan.';

  @override
  String get developerHubDeviceLockSubtitle =>
      'Kalau akun yang sama nyangkut di perangkat lama, owner atau supervisor bisa mengeluarkannya dari sini tanpa menunggu perangkat itu disentuh dulu.';

  @override
  String get developerHubEmptyActiveSessionsTitle => 'Tidak ada sesi aktif';

  @override
  String get developerHubEmptyActiveSessionsSubtitle =>
      'Saat staf login dari perangkat lain, daftar aktif akan muncul di sini.';

  @override
  String get developerHubZoneFallback => 'Zona';

  @override
  String developerHubSeatCount(String count) {
    return 'Kursi $count';
  }

  @override
  String developerHubStaffSessionSummary(
    String staffId,
    String role,
    String platform,
  ) {
    return 'Staf #$staffId • $role • $platform';
  }

  @override
  String developerHubLastSeen(String value) {
    return 'Terakhir terlihat: $value';
  }

  @override
  String get developerHubForceCloseAction => 'Tutup Paksa';

  @override
  String get totalCustomers => 'Total Pelanggan';

  @override
  String newCustomersToday(int count) {
    return '$count pelanggan baru hari ini';
  }

  @override
  String get activeCustomers => 'Pelanggan Aktif';

  @override
  String get inLast30Days => 'Dalam 30 hari terakhir';

  @override
  String get averageVisits => 'Rata-rata Kunjungan';

  @override
  String get visitsPerMonth => 'Kunjungan per bulan';

  @override
  String get customerChartNotAvailable => 'Grafik Pelanggan Belum Tersedia';

  @override
  String get waitingForDesignData =>
      'Menunggu data desain spesifik untuk grafik ini.';

  @override
  String get filterToday => 'Hari Ini';

  @override
  String get filterYesterday => 'Kemarin';

  @override
  String get filterLast7Days => '7 Hari Terakhir';

  @override
  String get filterLast30Days => '30 Hari Terakhir';

  @override
  String get filterThisMonth => 'Bulan Ini';

  @override
  String get selectDate => 'Pilih Tanggal';

  @override
  String get promoNotApplicable => 'Belum memenuhi syarat promo';

  @override
  String get settingsGeneralTitle => 'General';

  @override
  String get settingsGeneralSubtitle => 'Pengaturan umum dan profil tenant';

  @override
  String get settingsStoreTitle => 'Store';

  @override
  String get settingsStoreSubtitle => 'Konfigurasi profil toko dan operasional';

  @override
  String get settingsPrinterTitle => 'Printer';

  @override
  String get settingsPrinterSubtitle => 'Manajemen printer kasir dan dapur';

  @override
  String get settingsSyncTitle => 'Sync';

  @override
  String get settingsSyncSubtitle => 'Manajemen sinkronisasi dan data offline';

  @override
  String get settingsDeviceTitle => 'Device';

  @override
  String get settingsDeviceSubtitle => 'Status perangkat dan pembaruan sistem';

  @override
  String get settingsCompanyNameLabel => 'Nama Perusahaan';

  @override
  String get settingsLocationIdLabel => 'ID Lokasi';

  @override
  String get settingsServerUrlLabel => 'URL Server';

  @override
  String get settingsDeviceIdLabel => 'ID Perangkat';

  @override
  String get settingsAppInfoTitle => 'Info Aplikasi';

  @override
  String get settingsAppInfoSubtitle => 'Versi dan informasi pengembang';

  @override
  String get settingsCheckUpdatesTitle => 'Periksa Pembaruan';

  @override
  String get settingsCheckUpdatesSubtitle =>
      'Periksa apakah versi terbaru tersedia';

  @override
  String get settingsAllowSellOutOfStockTitle => 'Izinkan Jual Barang Kosong';

  @override
  String get settingsAllowSellOutOfStockSubtitle =>
      'Izinkan menambahkan produk ke keranjang meski stok sistem 0';

  @override
  String get settingsSuccessSave => 'Pengaturan berhasil disimpan';

  @override
  String get settingsFailSave => 'Gagal menyimpan pengaturan';

  @override
  String get settingsAppConfig => 'Konfigurasi Aplikasi';

  @override
  String get settingsActiveRole => 'Peran Aktif';

  @override
  String get settingsLanguage => 'Bahasa';

  @override
  String get settingsSyncMasterData => 'Sinkronisasi Data Master';

  @override
  String get settingsSyncing => 'Sedang menyinkronkan Data Master...';

  @override
  String get settingsSyncError => 'Kesalahan Sinkronisasi';

  @override
  String get settingsPartialSynced =>
      'Tersinkron Sebagian - Ketuk untuk Sinkronisasi Penuh';

  @override
  String get settingsSynced => 'Tersinkron';

  @override
  String get settingsStoreApi => 'Pengaturan Toko & API';

  @override
  String get settingsOperatingMode => 'Mode Operasi';

  @override
  String get settingsOnlineStoreUrl => 'URL Dasar Toko Online';

  @override
  String get settingsWebhookUrl => 'URL Webhook (Transaksi)';

  @override
  String get settingsDisplayConfig => 'Konfigurasi Tampilan';

  @override
  String get settingsShowImage => 'Tampilkan Gambar Produk';

  @override
  String get settingsShowImageDesc => 'Selalu tampilkan gambar produk di kisi';

  @override
  String get settingsShowName => 'Tampilkan Nama Produk';

  @override
  String get settingsShowNameDesc => 'Tampilkan nama produk di kisi';

  @override
  String get settingsShowStock => 'Tampilkan Stok Produk';

  @override
  String get settingsShowStockDesc => 'Tampilkan stok yang tersedia di kisi';

  @override
  String get settingsShowPrice => 'Tampilkan Harga Produk';

  @override
  String get settingsShowPriceDesc => 'Tampilkan harga produk di kisi';

  @override
  String get settingsMinDisplayOptions =>
      'Minimal 2 opsi tampilan harus aktif.';

  @override
  String get settingsSelfOrder => 'Pengaturan Pesanan Mandiri';

  @override
  String get settingsEnableSelfOrder => 'Aktifkan Pesanan Mandiri';

  @override
  String get settingsEnableSelfOrderDesc =>
      'Aktifkan mode pesanan mandiri hibrida';

  @override
  String get settingsRequireTableNumber => 'Wajibkan Nomor Meja';

  @override
  String get settingsRequireTableNumberDesc =>
      'Pelanggan harus memberikan nomor meja';

  @override
  String get settingsAllowGuestCheckout => 'Izinkan Checkout Tamu';

  @override
  String get settingsAllowGuestCheckoutDesc =>
      'Pelanggan dapat melakukan checkout tanpa registrasi';

  @override
  String settingsEditTitle(String title) {
    return 'Ubah $title';
  }

  @override
  String get settingsCancel => 'Batal';

  @override
  String get settingsSave => 'Simpan';

  @override
  String get settingsClose => 'Tutup';

  @override
  String get settingsEmpty => '(Kosong)';

  @override
  String get settingsApp => 'Aplikasi';

  @override
  String get settingsVersion => 'Versi';

  @override
  String get settingsTenant => 'Tenant';

  @override
  String get settingsTenantCode => 'Kode Tenant';

  @override
  String get settingsStaff => 'Staf';

  @override
  String get settingsRole => 'Peran';

  @override
  String get settingsLastBootstrap => 'Bootstrap Terakhir';

  @override
  String get settingsNever => 'Tidak Pernah';
}
