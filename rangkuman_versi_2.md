ada beberapa fondasi lama yang menurut saya wajib tetap hidup di V2 walaupun tampilannya berubah total:
- offline-first
- sync queue background
- multi-role
- shift open/close
- hold order
- multi-payment
- reprint
- report dasar
- printer integration

Jadi V2 bukan sekadar “lebih ceria”, tapi:
- lebih rapi domain-nya
- lebih singkat navigasinya
- lebih beda per role
- tapi tidak kehilangan kemampuan operasional inti

**Prinsip V2**
- 1 shell utama yang role-aware
- domain besar di sidebar, bukan banyak menu kecil
- halaman turunan ditaruh di dalam domain
- controller dipisah berdasarkan tanggung jawab bisnis
- view dipisah 3 mode di setiap page
- visual system disiapkan dari awal untuk animasi, ilustrasi, dan state yang tidak polos

**Standar Penamaan**
Saya sarankan kita konsisten dari awal:
- pakai `snake_case` untuk folder
- pakai `bindings/` plural, jangan campur dengan `binding/`
- pakai `utils/`, jangan campur `util/`
- view mode selalu:
  - `web_landscape`
  - `mobile_portrait`
  - `tablet_landscape`

**Struktur Final `lib/`**
```text
lib/
├─ app/
│  ├─ bindings/
│  ├─ navigation/
│  ├─ role_access/
│  ├─ routes/
│  └─ shell/
│     ├─ controllers/
│     ├─ models/
│     ├─ views/
│     │  ├─ owner_shell/
│     │  │  ├─ web_landscape/
│     │  │  ├─ mobile_portrait/
│     │  │  └─ tablet_landscape/
│     │  ├─ supervisor_shell/
│     │  │  ├─ web_landscape/
│     │  │  ├─ mobile_portrait/
│     │  │  └─ tablet_landscape/
│     │  ├─ cashier_shell/
│     │  │  ├─ web_landscape/
│     │  │  ├─ mobile_portrait/
│     │  │  └─ tablet_landscape/
│     │  └─ kitchen_shell/
│     │     ├─ web_landscape/
│     │     ├─ mobile_portrait/
│     │     └─ tablet_landscape/
│     └─ widgets/
├─ core/
│  ├─ animations/
│  ├─ constants/
│  ├─ extensions/
│  ├─ models/
│  ├─ services/
│  ├─ theme/
│  ├─ utils/
│  └─ widgets/
├─ modules/
│  ├─ auth/
│  │  ├─ bindings/
│  │  ├─ controllers/
│  │  ├─ models/
│  │  ├─ views/
│  │  │  ├─ merchant_login/
│  │  │  │  ├─ web_landscape/
│  │  │  │  ├─ mobile_portrait/
│  │  │  │  └─ tablet_landscape/
│  │  │  ├─ staff_selector/
│  │  │  │  ├─ web_landscape/
│  │  │  │  ├─ mobile_portrait/
│  │  │  │  └─ tablet_landscape/
│  │  │  └─ lockscreen/
│  │  │     ├─ web_landscape/
│  │  │     ├─ mobile_portrait/
│  │  │     └─ tablet_landscape/
│  │  └─ widgets/
│  ├─ overview/
│  │  ├─ bindings/
│  │  ├─ controllers/
│  │  ├─ models/
│  │  ├─ views/
│  │  │  ├─ owner_overview/
│  │  │  │  ├─ web_landscape/
│  │  │  │  ├─ mobile_portrait/
│  │  │  │  └─ tablet_landscape/
│  │  │  └─ supervisor_overview/
│  │  │     ├─ web_landscape/
│  │  │     ├─ mobile_portrait/
│  │  │     └─ tablet_landscape/
│  │  └─ widgets/
│  ├─ sales/
│  │  ├─ pos/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ pos_workspace/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  ├─ checkout/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ payment_success/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  ├─ orders/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ active_orders/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  ├─ parked_orders/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ sales_history_lite/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  └─ shared/
│  │     ├─ models/
│  │     └─ widgets/
│  ├─ operations/
│  │  ├─ shift/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ shift_open/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  ├─ shift_close/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ shift_history/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  ├─ recap/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ recap_summary/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  ├─ payment_audit/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ cash_flow_review/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  ├─ kitchen_board/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ kitchen_board/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ kitchen_ticket_detail/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  └─ shared/
│  │     ├─ models/
│  │     └─ widgets/
│  ├─ reports/
│  │  ├─ bindings/
│  │  ├─ controllers/
│  │  ├─ models/
│  │  ├─ views/
│  │  │  ├─ report_summary/
│  │  │  │  ├─ web_landscape/
│  │  │  │  ├─ mobile_portrait/
│  │  │  │  └─ tablet_landscape/
│  │  │  ├─ sales_report/
│  │  │  │  ├─ web_landscape/
│  │  │  │  ├─ mobile_portrait/
│  │  │  │  └─ tablet_landscape/
│  │  │  ├─ product_report/
│  │  │  │  ├─ web_landscape/
│  │  │  │  ├─ mobile_portrait/
│  │  │  │  └─ tablet_landscape/
│  │  │  ├─ staff_report/
│  │  │  │  ├─ web_landscape/
│  │  │  │  ├─ mobile_portrait/
│  │  │  │  └─ tablet_landscape/
│  │  │  └─ cashier_report_lite/
│  │  │     ├─ web_landscape/
│  │  │     ├─ mobile_portrait/
│  │  │     └─ tablet_landscape/
│  │  └─ widgets/
│  ├─ master_data/
│  │  ├─ catalog/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ products/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  ├─ categories/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  ├─ brands/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ promos/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  ├─ customers/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ customer_list/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ customer_detail/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  ├─ staff/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ staff_list/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ staff_roles/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  └─ shared/
│  │     ├─ models/
│  │     └─ widgets/
│  ├─ settings/
│  │  ├─ general/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ general_settings/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ profile_settings/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  ├─ store/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ store_profile/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ shift_config/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  ├─ printers/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ printer_list/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  ├─ printer_mapping/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ printer_test/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  ├─ sync/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ sync_center/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ sync_history/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  ├─ device/
│  │  │  ├─ bindings/
│  │  │  ├─ controllers/
│  │  │  ├─ models/
│  │  │  ├─ views/
│  │  │  │  ├─ app_update/
│  │  │  │  │  ├─ web_landscape/
│  │  │  │  │  ├─ mobile_portrait/
│  │  │  │  │  └─ tablet_landscape/
│  │  │  │  └─ device_status/
│  │  │  │     ├─ web_landscape/
│  │  │  │     ├─ mobile_portrait/
│  │  │  │     └─ tablet_landscape/
│  │  │  └─ widgets/
│  │  └─ shared/
│  │     ├─ models/
│  │     └─ widgets/
│  └─ programmer/
│     ├─ bindings/
│     ├─ controllers/
│     ├─ models/
│     ├─ views/
│     │  ├─ developer_hub/
│     │  │  ├─ web_landscape/
│     │  │  ├─ mobile_portrait/
│     │  │  └─ tablet_landscape/
│     │  ├─ database_inspector/
│     │  │  ├─ web_landscape/
│     │  │  ├─ mobile_portrait/
│     │  │  └─ tablet_landscape/
│     │  ├─ sync_queue_inspector/
│     │  │  ├─ web_landscape/
│     │  │  ├─ mobile_portrait/
│     │  │  └─ tablet_landscape/
│     │  ├─ api_log_viewer/
│     │  │  ├─ web_landscape/
│     │  │  ├─ mobile_portrait/
│     │  │  └─ tablet_landscape/
│     │  ├─ printer_diagnostics/
│     │  │  ├─ web_landscape/
│     │  │  ├─ mobile_portrait/
│     │  │  └─ tablet_landscape/
│     │  └─ feature_flags/
│     │     ├─ web_landscape/
│     │     ├─ mobile_portrait/
│     │     └─ tablet_landscape/
│     └─ widgets/
└─ main.dart
```

**Yang Sengaja Dipertahankan dari Sistem Lama**
Supaya migrasi nanti tidak bikin fitur inti hilang:
- auth merchant + staff selector
- role-based access
- offline-first sync
- hold order / active orders
- shift session
- reconciliation
- kitchen board
- printer / reprint
- report
- customer/member
- catalog master data

**Yang Dirombak di V2**
- dashboard admin dan employee diganti shell role-aware
- `order`, `report`, `recap` dibersihkan batas tanggung jawabnya
- `settings` dipecah jadi `general`, `store`, `printers`, `sync`, `device`
- `member` dipindah jadi bagian `master_data/customers`
- menu sidebar diringkas per role
- kasir tidak dibebani dashboard

**Usulan Visual System**
Agar “ceria” dari awal, nanti struktur ini akan enak kalau dibangun dengan:
- warna role-based
- ilustrasi pada empty state
- motion ringan di success, loading, sync, dan perpindahan status
- card/card group yang lebih playful
- icon dan gambar produk lebih dominan
- kitchen board dengan status color timing
- report lite untuk kasir agar tidak terasa berat

**Tahap Implementasi Nanti Saat Edit Diizinkan**
1. buat root `lib/`
2. buat `app/`, `core/`, `modules/`
3. buat domain besar
4. buat sub-feature leaf folders
5. buat 3 view-mode folder di setiap page
6. tambahkan placeholder minimal agar folder tidak hilang di version control

**Hal Yang Sudah Fixed**
- supervisor dibatasi dari settings sensitif dan programmer
- customer bukan menu sidebar utama
- order dan recap dipisah
- cashier masuk langsung ke sales
- kitchen punya alur terpisah
- V2 tetap membawa offline-first dan sync

================================================================

**Yang Dirombak di V2**
- dashboard admin dan employee diganti shell role-aware
- `order`, `report`, `recap` dibersihkan batas tanggung jawabnya
- `settings` dipecah jadi `general`, `store`, `printers`, `sync`, `device`
- `member` dipindah jadi bagian `master_data/customers`
- menu sidebar diringkas per role
- kasir tidak dibebani dashboard

**Usulan Visual System**
Agar “ceria” dari awal, nanti struktur ini akan enak kalau dibangun dengan:
- warna role-based
- ilustrasi pada empty state
- motion ringan di success, loading, sync, dan perpindahan status
- card/card group yang lebih playful
- icon dan gambar produk lebih dominan
- kitchen board dengan status color timing
- report lite untuk kasir agar tidak terasa berat

**Arah V2**
- Pakai 1 `shell` utama yang role-aware, bukan dashboard admin dan employee terpisah.
- Sidebar dipersingkat jadi menu domain besar, bukan menu per layar kecil.
- Detail halaman dipindah ke tab/subpage di dalam domain itu.
- View tetap 3 mode per halaman: `web_landscape`, `mobile_portrait`, `tablet_landscape`.
Berarti arsitektur V2 yang saya anggap final untuk kerangka `flinkpos_v2/lib` adalah ini.

**Dasar**
- `home_controller.dart`, `report_controller.dart`, dan `setting_controller.dart` di versi sekarang terlalu besar.
- `dashboard_admin.dart` dan `dashboard_employee.dart` terlalu mirip, jadi lebih baik diganti 1 shell utama yang role-aware.
- Sidebar perlu dipendekkan dengan domain besar, bukan terlalu banyak halaman kecil.

**Keputusan Final**
- `Order` dan `Recap` tidak dijadikan 1 controller.
- `Order` tetap dekat dengan `POS` di domain `Sales`.
- `Recap` dipindah ke domain `Operations` bersama shift dan cash flow review.
- `Kitchen` tetap dipisah dari POS, tapi saya taruh di domain `Operations` supaya menu owner/supervisor tetap ringkas.
- `Product`, `Category`, `Brand`, dan `Promo` digabung ke `Master Data > Catalog`.
- `Customer/Member` tidak jadi menu sidebar utama, tapi masuk ke `Master Data > Customers`.
- `Programmer` jadi modul rahasia terpisah dan tidak muncul di sidebar normal.

**Role Menu**
- `Owner/Admin`: `Overview`, `Sales`, `Operations`, `Reports`, `Master Data`, `Settings`
- `Supervisor`: `Overview`, `Sales`, `Operations`, `Reports`, `Master Data`
- `Cashier`: langsung masuk `Sales`, tanpa dashboard
- `Kitchen`: langsung masuk `Operations > Kitchen Board`
- `Programmer`: akses khusus, bukan menu biasa

**Batas Akses**
- `Owner/Admin`: semua kecuali `Programmer`
- `Supervisor`: hampir semua, tapi tanpa `Settings` sensitif, `Sync` destruktif, `Device`, dan `Programmer`
- `Cashier`: `Sales`, `Shift`, `Report Lite`
- `Kitchen`: hanya `Kitchen Board` dan identitas kerja dasar

**Controller Yang Dipisah**
- `shell_controller`: navigasi utama, role access, state sidebar
- `sales_pos_controller`: cart, checkout, payment flow
- `sales_orders_controller`: active order, hold order, reopen order
- `operations_shift_controller`: open/close shift, active session
- `operations_recap_controller`: recap, payment audit, cash flow review
- `operations_kitchen_controller`: kitchen queue, item status
- `reports_controller`: filter dan laporan sesuai role
- `master_catalog_controller`: products, categories, brands, promos
- `customers_controller`: data customer/member
- `settings_controller`: general/store/printer
- `programmer_tools_controller`: inspector, logs, diagnostics

**Pola Folder**
Semua leaf feature nanti pakai pola ini:

```text
<feature>/
├─ bindings/
├─ controllers/
├─ models/
├─ views/
│  └─ <page>/
│     ├─ web_landscape/
│     ├─ mobile_portrait/
│     └─ tablet_landscape/
└─ widgets/
```

**Rencana `lib/`**
```text
lib/
├─ app/
│  ├─ bindings/
│  ├─ navigation/
│  ├─ role_access/
│  ├─ routes/
│  └─ shell/
├─ core/
│  ├─ animations/
│  ├─ models/
│  ├─ services/
│  ├─ theme/
│  ├─ utils/
│  └─ widgets/
├─ modules/
│  ├─ auth/
│  ├─ overview/
│  ├─ sales/
│  ├─ operations/
│  ├─ reports/
│  ├─ master_data/
│  ├─ settings/
│  └─ programmer/
└─ main.dart
```

**Leaf Feature Yang Akan Di-scaffold**
- `app/shell`: `owner_shell`, `supervisor_shell`, `cashier_shell`, `kitchen_shell`
- `auth`: `merchant_login`, `staff_selector`, `lockscreen`
- `overview`: `owner_overview`, `supervisor_overview`
- `sales/pos`: `pos_workspace`, `checkout`, `payment_success`
- `sales/orders`: `active_orders`, `parked_orders`, `sales_history_lite`
- `operations/shift`: `shift_open`, `shift_close`, `shift_history`
- `operations/recap`: `recap_summary`, `payment_audit`, `cash_flow_review`
- `operations/kitchen_board`: `kitchen_board`, `kitchen_ticket_detail`
- `reports`: `report_summary`, `sales_report`, `product_report`, `staff_report`, `cashier_report_lite`
- `master_data/catalog`: `products`, `categories`, `brands`, `promos`
- `master_data/customers`: `customer_list`, `customer_detail`
- `master_data/staff`: `staff_list`, `staff_roles`
- `settings/general`: `general_settings`, `profile_settings`
- `settings/store`: `store_profile`, `shift_config`
- `settings/printers`: `printer_list`, `printer_mapping`, `printer_test`
- `settings/sync`: `sync_center`, `sync_history`
- `settings/device`: `app_update`, `device_status`
- `programmer`: `developer_hub`, `database_inspector`, `sync_queue_inspector`, `api_log_viewer`, `printer_diagnostics`, `feature_flags`

**Fitur V2 Yang Saya Usulkan**
- `park/hold order` yang lebih jelas dan mudah dilanjutkan
- `quick resume order` dari daftar order aktif
- `report lite` khusus kasir
- `shift closing wizard` yang lebih ramah
- `kitchen aging indicator` untuk order yang mulai lama
- `promo dan upsell visual` supaya POS terasa lebih hidup
- `sync center` yang mudah dibaca user non-teknis
- `role-based empty states` dengan ilustrasi, animasi ringan, dan warna per role
- `programmer hub` untuk debugging rahasia tanpa mengganggu user biasa

**Catatan UX**
- Karena kamu ingin POS yang lebih ceria, saya sengaja memasukkan `core/animations/` dan `core/theme/`.
- Ini akan memudahkan nanti kalau kita bikin micro-interaction, ilustrasi empty state, success animation, dan identitas warna berbeda per role.

**Update Implementasi Saat Ini**
- Domain shell entry view yang sudah dipakai sekarang ada di `modules/operations/views/tablet_landscape/view.dart`, `modules/reports/views/tablet_landscape/view.dart`, `modules/master_data/views/tablet_landscape/view.dart`, `modules/settings/views/tablet_landscape/view.dart`, dan `modules/sales/orders/views/tablet_landscape/view.dart`.
- `operations` saat ini memakai sibling feature `shift/`, `recap/`, `cash_flow/`, dan `kitchen/` yang di-mount dari shell operasional, jadi implementasinya lebih ringkas dari rencana leaf yang lebih dalam.
- Folder riwayat order yang benar saat ini adalah `modules/sales/orders/views/history_lite/`, bukan `sales_history_lite/`.
- Folder kitchen yang benar saat ini adalah `modules/operations/kitchen/`, bukan `kitchen_board/`.
- Infrastruktur tambahan yang sudah ada di project ini mencakup `lib/l10n/`, `core/localization/`, `core/network/`, dan `core/widgets/motion/` di luar daftar awal.
- Folder kosong `lib/modules/sales/views/` sudah dihapus karena tidak dipakai dan tidak punya referensi aktif.
