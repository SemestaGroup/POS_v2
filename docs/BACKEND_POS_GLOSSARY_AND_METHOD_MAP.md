# Backend POS Glossary And Method Map

## Scope
Dokumen ini fokus pada modul POS yang benar-benar relevan untuk FlinkPOS v2:
- route POS di `back_end_web_office/config/routes.php`
- controller `controllers/v2/Pos_*`
- controller `controllers/v2/backoffice/Pos_*`
- model `models/Pos*.php`

Dokumen ini tidak membedah semua modul non-POS seperti proyek, kontrak, tiket, dan lain-lain.

## Peta Relasi Sederhana
| Entitas | Tabel backend utama | Penjelasan sangat sederhana |
| --- | --- | --- |
| Tenant POS | gabungan opsi tenant + base URL | Ini identitas toko/cabang yang dipakai app untuk tahu harus bicara ke server mana. |
| Staff | `tblstaff` | Orang yang login ke POS. |
| Customer | `tblclients` dan poin di `tblcustom_pos_points` | Pelanggan yang bisa dipilih saat transaksi. |
| Item produk | `tblcustom_pos_products` | Barang yang dijual kasir. |
| Brand | `tblitems_groups` | Kelompok merek produk. |
| Category | `tblcustom_pos_categories` | Kelompok kategori produk. |
| Order POS | `tblinvoices` | Kepala transaksi penjualan. |
| Item order | `tblitemable` | Daftar barang di dalam order. |
| Payment POS | `tblinvoicepaymentrecords` | Catatan uang yang dibayar untuk order. |
| Shift session | `tblcustom_pos_shift_sessions` | Sesi siapa yang sedang jaga kasir. |
| Device session | `tblcustom_pos_device_sessions` | Catatan siapa login di device mana. |
| Service table | `tblcustom_pos_service_tables` | Data meja dan QR untuk dine in atau self-order. |
| Self-order session | `tblcustom_pos_self_order_sessions` | Sesi pelanggan yang pesan sendiri. |
| Approval request | `tblcustom_pos_approval_requests` | Permintaan izin untuk tindakan sensitif. |
| POS options | `tblcustom_pos_options` | Tempat setting global POS. |

## Arti Field Yang Paling Sering Membingungkan
| Field | Arti sederhana | Harus diisi dari mana |
| --- | --- | --- |
| `location_id` | ID lokasi/cabang toko. | Dari discovery tenant, bootstrap, QR table, atau session aktif. Jangan hardcode `1` kecuali data demo. |
| `outlet_id` | Nama lain yang sering dipakai orang untuk cabang. | Di flow v2 yang dibaca, field ini bukan standar utama. Sebaiknya satukan ke `location_id`. |
| `tenant_id` | ID tenant di level SaaS pusat. | Dari central discovery. Bukan dari input kasir. |
| `staff_id` | ID pegawai yang sedang login. | Dari hasil login atau session aktif. Bukan diketik manual oleh user. |
| `user_id` | Nama umum yang terlalu kabur. | Sebaiknya dihindari di flow POS. Pakai `staff_id` untuk pegawai atau `customer_id` untuk pelanggan. |
| `device_id` | Identitas unik device atau terminal. | Dibuat sekali per instalasi/device. Jangan ganti setiap login. |
| `register_id` | ID register kasir yang sedang dipakai. | Idealnya dari provisioning register. Dalam fase transisi sekarang boleh disamakan dulu dengan `device_id` jika stabil. |
| `session_code` | Kode sesi aktif. | Dibuat sistem saat session dibuat. |
| `shift_session_id` | ID shift yang sedang berlangsung. | Dibuat saat open shift. |
| `id_pos` | ID order versi POS. | Dibuat app sejak order lahir. Ini sangat penting untuk offline sync. |
| `request_code` | Kode permintaan approval. | Dibuat backend saat approval request dibuat. |
| `source_channel` | Asal order. | Dari mode order, misalnya `pos`, `table_qr`, `kiosk`, `web`. Bukan teks bebas. |
| `sale_agent` | Staff yang menangani penjualan. | Harus diambil dari staff aktif yang sedang bekerja. |
| `queue_number` | Nomor antrean. | Dibuat sistem menurut aturan lokasi dan tanggal bisnis. |
| `status` | Keadaan suatu data. | Dikelola sistem sesuai alur. User memicu aksi, bukan menulis status mentah. |

## Kapan Nilai Diambil Dari User, Session, Atau Sistem
| Data | Dari user | Dari session | Dari sistem |
| --- | --- | --- | --- |
| Email login | Ya | Tidak | Tidak |
| Password / PIN | Ya | Tidak | Tidak |
| `location_id` saat login | Tidak | Ya, hasil discovery/login | Bisa terisi dari QR/self-order flow |
| `staff_id` saat order | Tidak | Ya | Tidak |
| `device_id` | Tidak | Ya | Dibuat saat instalasi |
| `register_id` | Tidak idealnya | Ya | Dari session/provisioning register. Untuk transisi sementara boleh ikut `device_id`. |
| `id_pos` | Tidak | Tidak | Ya, generator lokal app |
| `shift_session_id` | Tidak | Ya | Dibuat saat open shift |
| Harga item | Tidak sebaiknya | Ya, dari katalog aktif | Bisa terpengaruh promo/policy |
| Diskon manual | Ya, jika role/policy mengizinkan | Ya | Bisa butuh approval |
| Payment method | Ya, dipilih user | Tidak | Harus valid terhadap master payment mode |
| Approval code | Tidak | Tidak | Ya, dibuat backend |

## Route POS V2 Yang Paling Penting
| Route | Tujuan sederhana |
| --- | --- |
| `POST /api/v2/pos-auth/discover` | Mencari tenant dari email. |
| `POST /api/v2/pos-auth/login` | Login utama ke tenant. |
| `POST /api/v2/pos-auth/pin-login` | Login cepat dengan PIN. |
| `GET /api/v2/pos-bootstrap` | Mengambil data awal POS. |
| `GET /api/v2/pos-policies` | Mengambil policy role dan approval. |
| `GET /api/v2/pos-items` | Mengambil data item produk. |
| `GET /api/v2/pos-customers` | Mengambil data customer. |
| `GET/POST/PUT/DELETE /api/v2/pos-order` | Melihat, membuat, mengubah, menghapus order POS. |
| `GET/POST/PUT/DELETE /api/v2/pos-transaction` | Melihat dan mengubah pembayaran POS. |
| `GET/POST /api/v2/pos-shift-sessions/*` | Membaca, membuka, menutup shift. |
| `GET/POST /api/v2/pos-self-order-sessions/*` | Mengelola self-order session. |
| `GET/POST /api/v2/pos-approval-requests*` | Membuat dan sinkron approval request. |
| `GET/POST /api/v2/backoffice/pos-approval-requests*` | Menyetujui atau menolak approval. |

## Controller Map

### `controllers/v2/Pos_auth_v2.php`
Fungsi file ini: mengurus pintu masuk user ke POS.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `discover_post` | Mencari tenant mana yang cocok dengan email user. | `email` |
| `login_post` | Login dengan email dan password, lalu membuat session device. | `email`, `password`, `device_id`, `register_id`, `platform`, `app_version` |
| `pin_login_post` | Login cepat dengan PIN setelah tenant sudah diketahui. | `email`, `pin`, `device_id`, `register_id` |
| `session_get` | Mengecek session device yang masih aktif. | `session_code` atau `staff_id + device_id` |
| `logout_post` | Menutup session device saat user logout. | `session_code` atau `staff_id + device_id` |
| `session_touch_post` | Memberi tanda ke server bahwa app ini masih hidup. | `session_code` atau `staff_id + device_id` |
| `force_logout_post` | Supervisor atau owner memaksa device lain logout. | `acting_staff_id`, target session |
| `register_device_session` | Helper yang memutuskan apakah staff boleh aktif di device ini. | `staff`, `device_id`, `register_id`, policy |
| `resolve_session_target` | Helper untuk mencari session yang dimaksud. | `session_code`, `session_id`, `staff_id`, `device_id` |
| `sanitize_device_session` | Helper untuk membersihkan bentuk data session sebelum dikirim ke app. | data session |

Catatan:
- Ini controller inti.
- Di branch non-staff, `login_post` masih menjembatani endpoint lama.
- `pin_login_post` masih membandingkan PIN langsung di database. Ini risiko keamanan yang harus diperbaiki.

### `controllers/v2/Pos_bootstrap_v2.php`
Fungsi file ini: memberi bekal awal agar app bisa bekerja.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengirim options, policy, payment modes, order types, profil staff, dan active device session. | `staff_id`, `device_id`, `location_id`, `register_id` |

### `controllers/v2/Pos_policies_v2.php`
Fungsi file ini: memberi aturan main role dan approval.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengirim role matrix, approval policy, discount policy, dan refund policy. | tidak ada |

### `controllers/v2/Pos_order_v2.php`
Fungsi file ini: mengurus order POS.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil satu order atau daftar order. | `id`, filter query |
| `search_get` | Mencari order dari kata kunci. | `keyword` |
| `index_post` | Membuat order baru, atau memperbarui order lama jika `id_pos` sama. | `id_pos`, item, total, customer, staff data |
| `index_put` | Mengubah order yang sudah ada. | `id`, perubahan order |
| `index_delete` | Menghapus order. | `id` |
| `prepare_order_payload` | Menata payload agar cocok dengan model invoice backend. | payload order |
| `validate_order_payload` | Memeriksa field wajib order. | payload order |
| `find_existing_order_id_by_pos_id` | Mencari apakah `id_pos` ini sudah pernah masuk server. | `id_pos` |
| `extract_order_id` | Mengambil ID order dari hasil model. | hasil model |
| `sync_self_order_session_link` | Menghubungkan order dengan self-order session. | `self_order_session_id`, `self_order_session_code`, `id_pos` |

Catatan:
- `id_pos` adalah kunci bisnis paling penting untuk order POS.
- Method create dan update sama-sama sensitif karena menyentuh invoice asli.

### `controllers/v2/Pos_transaction_v2.php`
Fungsi file ini: mengurus pembayaran order.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil satu payment atau daftar payment POS. | `id`, filter query |
| `search_get` | Mencari payment. | `keyword` |
| `index_post` | Menambah payment baru. | `id_pos`, `invoiceid`, `amount`, `paymentmode` |
| `index_put` | Mengubah payment, termasuk convert atau split payment. | `id`, `convert` |
| `index_delete` | Menghapus payment. | `id` |
| `validate_transaction_payload` | Memeriksa field wajib payment. | payload payment |
| `update_converted_payments` | Memecah satu payment menjadi beberapa baris baru. | payment lama + payload baru |
| `sync_points_for_invoice` | Menyegarkan poin customer setelah payment berubah. | `invoiceId` |

### `controllers/v2/Pos_shift_sessions_v2.php`
Fungsi file ini: mengurus buka dan tutup shift.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil satu shift atau daftar shift. | `id`, `location_id`, `register_id`, `pos_staff_id`, `status` |
| `active_get` | Mengambil shift yang sedang aktif. | `pos_staff_id`, `device_id`, `register_id`, `location_id` |
| `history_get` | Mengambil riwayat shift. | `location_id`, `register_id`, `pos_staff_id` |
| `open_post` | Membuka shift baru. | `location_id`, `staff_id`, `staff_name`, `shift_name`, `opening_balance`, `device_id`, `register_id` |
| `close_post` | Menutup shift dan menyimpan hasil rekonsiliasi. | `id`, `closing_balance`, `expected_cash`, `actual_cash`, `reconciliation_json` |

### `controllers/v2/Pos_items_v2.php`
Fungsi file ini: mengurus produk POS.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil item produk. | `id`, filter query |
| `search_get` | Mencari item. | `keyword` |
| `index_post` | Menambah item baru. | data item |
| `index_put` | Mengubah item. | `id`, data item |
| `index_delete` | Menghapus item. | `id` |

### `controllers/v2/Pos_customers_v2.php`
Fungsi file ini: mengurus customer POS.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil customer. | `id` |
| `search_get` | Mencari customer. | `keyword` |
| `index_post` | Menambah customer. | `company/nama`, `phonenumber/no_hp`, `address/alamat` |
| `index_put` | Mengubah customer. | `id`, data customer |
| `index_delete` | Menghapus customer. | `id` |

Catatan:
- Bentuk field response customer masih banyak alias Indonesia seperti `nama`, `no_hp`, `alamat`.

### `controllers/v2/Pos_promotions_v2.php`
Fungsi file ini: memberi promo yang aktif.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil promo dan biasanya memfilter per lokasi atau status. | `id`, `id_location`, `status` |

### `controllers/v2/Pos_options_v2.php`
Fungsi file ini: menyimpan setting global POS.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil option POS. | `name`, `names` |
| `index_put` | Mengubah option POS. | pasangan `option_name => value` |

Catatan:
- Hati-hati, karena file ini bisa mengubah policy global seluruh POS.

### `controllers/v2/Pos_payment_modes_v2.php`
Fungsi file ini: mengurus metode pembayaran.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil metode pembayaran yang boleh dipakai POS. | `id` |
| `index_post` | Menambah metode pembayaran. | data mode |
| `index_put` | Mengubah metode pembayaran. | `id`, data mode |
| `index_delete` | Menghapus metode pembayaran. | `id` |

### `controllers/v2/Pos_service_tables_v2.php`
Fungsi file ini: membaca meja dari QR atau kode meja.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `lookup_get` | Mencari meja publik dari `qr_token` atau `table_code`. | `qr_token` atau `table_code` |

### `controllers/v2/backoffice/Pos_service_tables_v2.php`
Fungsi file ini: mengurus daftar meja dan kit cetaknya.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil satu meja atau daftar meja. | `id`, `location_id` |
| `index_post` | Membuat meja baru. | `location_id`, `table_code`, `table_name` |
| `index_put` | Mengubah meja atau regenerate QR. | `id`, data meja |
| `index_delete` | Menghapus meja. | `id` |
| `print_kit_get` | Mengambil data siap cetak untuk QR meja. | `location_id` |

### `controllers/v2/Pos_self_order_sessions_v2.php`
Fungsi file ini: mengurus sesi self-order.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil session self-order. | `id`, filter query |
| `resolve_get` | Mencari session dari token, kode, atau antrean. | `access_token`, `session_code`, `public_code`, `queue_number` |
| `open_post` | Membuka self-order session baru. | `location_id`, `table_qr_token`, `business_date`, `source_channel` |
| `link_order_post` | Menautkan self-order session ke order POS atau invoice. | `id_pos`, `invoice_id`, `queue_number` |
| `close_post` | Menutup self-order session. | `id`, `status`, `payment_stage` |
| `next_queue_number` | Menentukan nomor antrean berikutnya. | `location_id`, `business_date` |
| `build_qr_payloads` | Membuat URL resume dan feedback. | data session + runtime |

### `controllers/v2/Pos_approval_requests_v2.php`
Fungsi file ini: tempat kasir meminta izin.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil approval request. | `id`, filter query termasuk `location_id` dan `register_id` |
| `index_post` | Membuat approval request baru. | `request_type`, `reason`, `location_id`, `register_id`, `requester_staff_id`, `draft_id_pos` |
| `sync_get` | Mengambil perubahan approval yang relevan untuk device atau staff. | `updated_since`, `device_id`, `register_id`, `requester_staff_id` |

### `controllers/v2/backoffice/Pos_approval_requests_v2.php`
Fungsi file ini: tempat supervisor atau owner memutuskan approval.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil inbox approval. | `status`, `location_id`, dll |
| `approve_post` | Menyetujui request dan menjalankan efek akhirnya. | `id`, `approver_staff_id`, `approval_note` |
| `reject_post` | Menolak request. | `id`, `approver_staff_id`, `rejection_note` |

### `controllers/v2/backoffice/Pos_device_sessions_v2.php`
Fungsi file ini: memonitor device yang sedang login.

| Method | Arti sangat sederhana | Input penting |
| --- | --- | --- |
| `index_get` | Mengambil daftar atau detail device session. | `id`, filter query termasuk `device_id` dan `register_id` |
| `force_close_post` | Mematikan paksa session device. | `id`, `acting_staff_id`, `reason` |

## Model Map

### `models/Pos_auth_model.php`
| Method | Arti sangat sederhana |
| --- | --- |
| `get_Staff` | Mengecek apakah email ini milik staff internal. |
| `get_staff_name` | Mengambil nama user dari staff atau contact. |
| `get_user_base_url` | Menentukan tenant base URL dari email. |
| `get_location` | Mengambil lokasi milik email itu. |

Catatan:
- Untuk staff, `get_location` saat ini mengembalikan `null`. Ini salah satu alasan `location_id` masih belum konsisten.

### `models/Pos_items_model.php`
| Method | Arti sangat sederhana |
| --- | --- |
| `get_pos_items` | Mengambil produk POS dan membongkar field serialisasi seperti `locations` dan `units`. |
| `add_pos_item` | Menambah produk baru dan membuat barcode. |
| `get_group_names` | Mengubah daftar ID brand menjadi nama group yang lebih mudah dibaca. |

Catatan:
- `locations` dan `units` masih disimpan sebagai serialized string lama.
- `brand_id` bisa berisi daftar ID yang dipisah koma.

### `models/Pos_customers_model.php`
| Method | Arti sangat sederhana |
| --- | --- |
| `get` | Mengambil customer dan menjumlahkan poinnya. |
| `add` | Menambah customer ke tabel customer POS lama. |
| `delete` | Menghapus customer dari tabel customer POS lama. |
| `update` | Mengubah customer di tabel customer POS lama. |

Catatan:
- `get()` membaca `tblclients`, tetapi `add/update/delete()` menulis ke `tblcustom_pos_customers`. Ini tidak seragam dan harus dirapikan.

### `models/Pos_order_model.php`
| Method | Arti sangat sederhana |
| --- | --- |
| `get` | Mengambil order POS beserta item dan data terkait. |
| `get_attachments` | Mengambil lampiran order atau invoice. |
| `add` | Membuat order baru, atau menimpa order lama jika `id_pos` sudah ada. |
| `convert_export` | Mengubah item order menjadi pergerakan stok atau goods delivery. |
| `save_formatted_number` | Menyimpan nomor invoice yang sudah diformat cantik. |
| `delete` | Menghapus order dan data ikutannya. |
| `update` | Mengubah invoice, item, dan efek samping terkait. |
| `log_invoice_activity` | Menyimpan jejak aktivitas invoice. |
| `get_invoice_item` | Mengambil satu item invoice. |
| `normalize_invoice_items_payload` | Memilah item mana yang lama, baru, atau harus dihapus. |
| `remove_items` | Menghapus item dari invoice. |
| `save_items` | Menyimpan perubahan item yang sudah ada. |
| `add_new_items` | Menambahkan item baru ke invoice lama. |

Catatan:
- Ini salah satu model paling penting sekaligus paling sensitif.
- Order POS v2 masih berdiri di atas konsep invoice backend lama.

### `models/Pos_transaction_model.php`
| Method | Arti sangat sederhana |
| --- | --- |
| `payment_get` | Mengambil payment yang terkait dengan POS. |
| `delete` | Menghapus payment dan efek poin terkait. |
| `update` | Mengubah payment, termasuk split atau convert jika diminta. |
| `add_points` | Menambah poin customer. |
| `update_points` | Menyegarkan total poin customer setelah payment berubah. |

### `models/Pos_shift_session_v2_model.php`
| Method | Arti sangat sederhana |
| --- | --- |
| `get_by_id` | Mengambil shift dari ID-nya. |
| `get_list` | Mengambil daftar shift. |
| `get_active` | Mengambil shift yang masih aktif. |
| `create` | Membuat shift baru. |
| `close` | Menutup shift. |

### `models/Pos_device_session_v2_model.php`
| Method | Arti sangat sederhana |
| --- | --- |
| `get_by_id` | Mengambil device session dari ID. |
| `get_by_session_code` | Mengambil device session dari kode session. |
| `get_active_by_staff` | Mengecek apakah staff ini sedang aktif di device lain. |
| `get_active_by_staff_device` | Mengecek apakah staff ini aktif di device tertentu. |
| `get_list` | Mengambil daftar session device. |
| `create` | Membuat device session baru. |
| `update` | Mengubah data device session. |
| `close_session` | Menutup atau memaksa keluar session device. |
| `touch` | Memperbarui `last_seen_at`. |

### `models/Pos_approval_request_v2_model.php`
| Method | Arti sangat sederhana |
| --- | --- |
| `generate_request_code` | Membuat kode approval yang unik. |
| `create` | Menyimpan permintaan approval baru. |
| `get_by_id` | Mengambil satu request. |
| `get_list` | Mengambil daftar request. |
| `add_log` | Menulis riwayat aksi request. |
| `approve_request` | Menyetujui request. |
| `reject_request` | Menolak request. |
| `apply_request_resolution` | Memilih aksi bisnis yang harus dijalankan saat request disetujui. |
| `apply_refund_paid_invoice` | Menjalankan refund resmi untuk invoice yang sudah dibayar. |
| `apply_void_unpaid_invoice` | Menjalankan void untuk invoice yang belum dibayar. |
| `apply_expense_void` | Membatalkan expense. |
| `apply_expense_approval` | Menyetujui expense. |
| `decode_json_field` | Membaca field JSON agar lebih mudah dipakai. |

### `models/Pos_service_table_v2_model.php`
| Method | Arti sangat sederhana |
| --- | --- |
| `get_by_id` | Mengambil satu meja. |
| `get_by_lookup` | Mengambil meja dari token atau kode. |
| `get_list` | Mengambil daftar meja. |
| `create` | Membuat meja baru. |
| `update` | Mengubah data meja. |
| `delete` | Menghapus meja. |
| `normalize_row` | Merapikan format data meja. |

### `models/Pos_self_order_session_v2_model.php`
| Method | Arti sangat sederhana |
| --- | --- |
| `get_by_id` | Mengambil satu session self-order. |
| `get_by_lookup` | Mencari session dari token atau kode. |
| `get_list` | Mengambil daftar session. |
| `create` | Membuat session baru. |
| `update` | Mengubah session yang ada. |
| `log_event` | Menyimpan jejak kejadian pada session. |
| `normalize_row` | Merapikan bentuk data session. |

### Model pendukung lain
| File | Fungsi sederhana |
| --- | --- |
| `Pos_promotions_model.php` | Mengambil promo dan membongkar field JSON promo. |
| `Pos_payment_mode_model.php` | Mengambil dan mengubah metode pembayaran POS. |
| `Pos_category_model.php` | Mengambil dan mengubah kategori POS. |
| `Pos_reports_model.php` | Membuat report invoice, item, payment, dan customer. |
| `Pos_options_model.php` | Mengambil dan mengubah option POS. |
| `Pos_staff_model.php` | Mengambil data staff. |
| `Pos_shift_logs_model.php` | Mengurus shift log lama. |
| `Pos_order_type_model.php` | Mengurus tipe order. |
| `Pos_brands_model.php` | Mengambil brand dan memiliki flow sync brand yang destruktif. |
| `Pos_error_logs_model.php` | Menyimpan log error POS. |

## Field Yang Sebaiknya Jangan Lagi Diisi Manual
- `location_id`
- `staff_id`
- `sale_agent`
- `device_id`
- `shift_session_id`
- `id_pos`
- `request_code`
- `status`
- `queue_number`

Alasannya sederhana: data ini seharusnya lahir dari session, shift, atau generator sistem, bukan dari isian bebas user. Jika user bebas menulisnya, celah audit dan bentrok data akan mudah terjadi.

## Inkonsistensi Penting Yang Terlihat Dari Kode
- `location_id` masih belum konsisten, terutama saat login staff.
- `Pos_customers_model` membaca dan menulis ke tabel yang berbeda.
- `Pos_brands_model` melakukan full delete lalu insert ulang.
- `pos-order` dan `pos-transaction` masih kuat bergantung pada model invoice lama.
- `PIN` staff masih terlihat dibandingkan langsung, belum melalui mekanisme yang lebih aman.
- `id_location` dan `location_id` belum seragam di semua endpoint.
- `register_id` sekarang mulai masuk ke flow baru, tetapi provisioning register terpisah dari `device_id` belum final.

## Rekomendasi Penamaan Dan Aturan Data
- Pakai `location_id` sebagai standar tunggal untuk cabang.
- Tambahkan `register_id` atau `terminal_id` untuk membedakan satu kasir dengan kasir lain di cabang yang sama.
- Pakai `staff_id` untuk pegawai, `customer_id` untuk pelanggan, jangan campur dengan `user_id` yang terlalu umum.
- Pakai `id_pos` sebagai kunci bisnis order di sisi POS.
- Pakai `session_code` untuk identitas sesi yang dibagikan antar komponen.
- Pakai enum yang jelas untuk `status`, `source_channel`, dan `request_type`.

## File Rujukan Paling Penting
- `back_end_web_office/config/routes.php`
- `back_end_web_office/controllers/v2/Pos_auth_v2.php`
- `back_end_web_office/controllers/v2/Pos_bootstrap_v2.php`
- `back_end_web_office/controllers/v2/Pos_order_v2.php`
- `back_end_web_office/controllers/v2/Pos_transaction_v2.php`
- `back_end_web_office/controllers/v2/Pos_shift_sessions_v2.php`
- `back_end_web_office/controllers/v2/Pos_self_order_sessions_v2.php`
- `back_end_web_office/controllers/v2/Pos_approval_requests_v2.php`
- `back_end_web_office/controllers/v2/backoffice/Pos_approval_requests_v2.php`
- `back_end_web_office/models/Pos_order_model.php`
- `back_end_web_office/models/Pos_transaction_model.php`
- `back_end_web_office/models/Pos_items_model.php`
- `back_end_web_office/models/Pos_customers_model.php`
