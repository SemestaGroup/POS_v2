# FlinkPOS V2 Textual ERD

## Tujuan
Dokumen ini menjelaskan bentuk relasi data FlinkPOS v2 tanpa gambar, supaya tetap mudah dibaca dan dijadikan dasar backend, SQLite lokal, dan sync engine.

## Aturan Dasar ERD
- Semua tabel lokal berada di dalam scope `tenant_id`.
- `remote_id` adalah identitas dari server tenant.
- `id_pos` adalah identitas order dari sisi POS lokal.
- `location_id` adalah identitas cabang.
- `register_id` atau `terminal_id` harus ditambahkan jika satu cabang ingin banyak kasir aktif bersamaan.
- `device_session`, `app_session`, dan `shift_session` adalah entitas berbeda. Jangan digabung.
- Dalam implementasi transisi saat ini, `register_id` boleh mengikuti `device_id` dulu, tetapi target akhirnya tetap register provisioning terpisah.

## Lapisan 1: Tenant Dan Session

### `app_tenant`
Fungsi: menyimpan tenant yang pernah ditemukan oleh device.

Field penting:
- `id`
- `tenant_key`
- `tenant_remote_id`
- `tenant_code`
- `tenant_name`
- `location_id`
- `base_url`
- `role_code`
- `last_bootstrap_at`

Relasi:
- `app_tenant 1 -> n staff`
- `app_tenant 1 -> n app_session`
- `app_tenant 1 -> n device_session`
- `app_tenant 1 -> n shift_session`
- `app_tenant 1 -> n product`
- `app_tenant 1 -> n customer`
- `app_tenant 1 -> n pos_order`
- `app_tenant 1 -> n sync_queue`

### `staff`
Fungsi: menyimpan staff POS yang boleh dipakai di tenant itu.

Field penting:
- `id`
- `tenant_id`
- `remote_id`
- `role_code`
- `full_name`
- `email`
- `pin_hash`
- `is_active`

Relasi:
- `staff 1 -> n device_session`
- `staff 1 -> n shift_session`
- `staff 1 -> n pos_order` sebagai `sale_staff_id`
- `staff 1 -> n approval_request` sebagai requester
- `staff 1 -> n approval_request` sebagai approver
- `staff 1 -> n self_order_session` sebagai creator/updater

### `device_session`
Fungsi: menyimpan siapa login di device mana.

Field penting:
- `id`
- `tenant_id`
- `staff_id`
- `session_code`
- `device_id`
- `device_name`
- `platform`
- `login_method`
- `status`
- `last_seen_at`

Relasi:
- `device_session n -> 1 staff`
- `device_session 1 -> n app_session`
- `device_session 1 -> n pos_order`
- `device_session 1 -> n shift_session` jika dipakai sebagai device pembuka shift

Catatan desain:
- Satu staff boleh dibatasi hanya punya satu `device_session` aktif.
- `device_id` wajib stabil.

### `app_session`
Fungsi: menyimpan sesi aplikasi yang aktif di device sekarang.

Field penting:
- `id`
- `tenant_id`
- `staff_id`
- `device_session_id`
- `current_shift_session_id`
- `location_id`
- `auth_token`
- `status`
- `logged_in_at`

Relasi:
- `app_session n -> 1 tenant`
- `app_session n -> 1 staff`
- `app_session n -> 1 device_session`
- `app_session n -> 1 shift_session`

Catatan desain:
- `app_session` adalah state aplikasi.
- `device_session` adalah state otorisasi device di backend.
- Jangan tukar arti keduanya.

## Lapisan 2: Konfigurasi Dan Master Data

### `pos_option`
Fungsi: cache raw setting POS.

Field penting:
- `option_name`
- `option_value_text`
- `option_value_json`
- `value_kind`

### `policy_snapshot`
Fungsi: menyimpan hasil parse policy agar UI dan engine tidak perlu membaca JSON mentah terus.

Field penting:
- `policy_name`
- `policy_json`
- `policy_version`

### `payment_mode`
Fungsi: metode pembayaran yang boleh dipakai POS.

Relasi:
- `payment_mode 1 -> n pos_order_payment`

### `order_type`
Fungsi: tipe order seperti dine in, takeaway, delivery.

Relasi:
- dipakai oleh `product_order_type`
- dipakai oleh `promotion_order_type`
- dipakai oleh `pos_order.order_type_code`

### `brand`
Fungsi: master brand atau group produk.

### `category`
Fungsi: master kategori produk.

### `product`
Fungsi: master item yang dijual.

Field penting:
- `remote_id`
- `category_id`
- `primary_brand_id`
- `parent_product_id`
- `name`
- `sku`
- `barcode`
- `price_amount`
- `stock_quantity`
- `status`
- `is_available`

Relasi:
- `product n -> 1 category`
- `product n -> 1 brand` sebagai brand utama
- `product 1 -> n product_brand`
- `product 1 -> n product_location`
- `product 1 -> n product_order_type`
- `product 1 -> n pos_order_item`

### `product_brand`
Fungsi: relasi banyak brand untuk satu produk jika backend lama masih menyimpan multi-brand.

### `product_location`
Fungsi: menentukan produk tersedia di lokasi mana.

### `product_order_type`
Fungsi: menentukan produk boleh dijual untuk tipe order apa dan harga spesifiknya.

### `promotion`
Fungsi: master promo.

Relasi:
- `promotion 1 -> n promotion_brand`
- `promotion 1 -> n promotion_item`
- `promotion 1 -> n promotion_location`
- `promotion 1 -> n promotion_order_type`

### `customer`
Fungsi: cache pelanggan yang bisa dipakai offline.

Field penting:
- `remote_id`
- `display_name`
- `company_name`
- `phone_number`
- `email`
- `points_balance`

Relasi:
- `customer 1 -> n pos_order`

## Lapisan 3: Operasional Shift Dan Table Service

### `shift_session`
Fungsi: sesi tanggung jawab kasir.

Field penting:
- `remote_id`
- `location_id`
- `pos_staff_id`
- `source_device_session_id`
- `source_device_id`
- `business_date`
- `opened_at`
- `closed_at`
- `opening_balance`
- `expected_cash`
- `actual_cash`
- `status`

Relasi:
- `shift_session n -> 1 staff`
- `shift_session n -> 1 device_session`
- `shift_session 1 -> n pos_order`
- `shift_session 1 -> n approval_request`
- `shift_session 1 -> n app_session`

Aturan relasi:
- minimal `1 open shift` per penanggung jawab register
- kalau belum ada `register_id`, maka sistem saat ini rawan ambigu bila ada banyak kasir di lokasi sama

### `service_table`
Fungsi: data meja, area, dan QR.

Field penting:
- `location_id`
- `table_code`
- `table_name`
- `qr_token`
- `default_source_channel`
- `self_order_enabled`

Relasi:
- `service_table 1 -> n self_order_session`
- `service_table 1 -> n pos_order`

### `self_order_session`
Fungsi: sesi pemesanan mandiri.

Field penting:
- `service_table_id`
- `session_code`
- `public_code`
- `access_token`
- `location_id`
- `business_date`
- `table_code`
- `queue_number`
- `source_channel`
- `flow_mode`
- `payment_stage`
- `status`
- `current_order_id`
- `current_id_pos`

Relasi:
- `self_order_session n -> 1 service_table`
- `self_order_session 1 -> n self_order_event`
- `self_order_session 1 -> n pos_order` secara bisnis, tetapi current live link utamanya ada di `current_order_id`

Catatan desain:
- `queue_number` harus unik minimal per `tenant_id + location_id + business_date`
- `current_id_pos` menghubungkan self-order dengan order POS lokal

### `self_order_event`
Fungsi: audit log sesi self-order.

Field penting:
- `self_order_session_id`
- `event_type`
- `actor_source`
- `occurred_at`

## Lapisan 4: Order Dan Payment

### `pos_order`
Fungsi: header order/transaksi POS.

Field penting:
- `customer_id`
- `sale_staff_id`
- `shift_session_id`
- `device_session_id`
- `service_table_id`
- `self_order_session_id`
- `remote_id`
- `id_pos`
- `invoice_number`
- `business_date`
- `source_channel`
- `order_type_code`
- `queue_number`
- `table_code`
- `status_code`
- `subtotal_amount`
- `discount_total_amount`
- `total_amount`
- `amount_received`
- `change_amount`
- `total_left_to_pay_amount`
- `order_note`
- `sync_state`

Relasi:
- `pos_order n -> 1 customer`
- `pos_order n -> 1 staff`
- `pos_order n -> 1 shift_session`
- `pos_order n -> 1 device_session`
- `pos_order n -> 1 service_table`
- `pos_order n -> 1 self_order_session`
- `pos_order 1 -> n pos_order_item`
- `pos_order 1 -> n pos_order_payment`

Aturan penting:
- `id_pos` adalah unique business key dari sisi POS
- `remote_id` boleh belum ada saat order baru lahir offline
- `status_code` harus punya enum baku

### `pos_order_item`
Fungsi: detail barang di dalam order.

Field penting:
- `order_id`
- `product_id`
- `product_remote_id`
- `product_name_snapshot`
- `qty`
- `price_amount`
- `base_price_amount`
- `discount_amount`
- `note`
- `kitchen_status`
- `is_refund`

Relasi:
- `pos_order_item n -> 1 pos_order`
- `pos_order_item n -> 1 product`

Catatan desain:
- snapshot nama, brand, kategori disimpan agar histori tidak berubah saat master item berubah

### `pos_order_payment`
Fungsi: pembayaran untuk order.

Field penting:
- `order_id`
- `payment_mode_id`
- `approval_request_id`
- `remote_id`
- `invoice_remote_id`
- `id_pos`
- `payment_mode_remote_id`
- `amount`
- `payment_method`
- `payment_date`
- `transaction_reference`
- `is_refund`
- `sync_state`

Relasi:
- `pos_order_payment n -> 1 pos_order`
- `pos_order_payment n -> 1 payment_mode`
- `pos_order_payment n -> 1 approval_request`

Aturan penting:
- satu order boleh punya banyak payment
- payment harus boleh lahir sebelum `remote invoice id` ada, selama `id_pos` sudah ada

## Lapisan 5: Governance Dan Approval

### `approval_request`
Fungsi: permintaan izin untuk aksi sensitif.

Field penting:
- `request_code`
- `request_type`
- `reference_type`
- `reference_remote_id`
- `reference_number`
- `draft_id_pos`
- `location_id`
- `requester_staff_id`
- `requester_role`
- `requester_device_id`
- `shift_session_id`
- `reason`
- `status`
- `approved_by_staff_id`
- `approved_at`
- `applied_at`
- `resolved_reference_type`
- `resolved_reference_remote_id`

Relasi:
- `approval_request n -> 1 staff` sebagai requester
- `approval_request n -> 1 staff` sebagai approver
- `approval_request n -> 1 shift_session`
- `approval_request 1 -> n pos_order_payment` bila payment tertentu memerlukan jejak approval

## Lapisan 6: Reporting Cache Dan Infrastruktur Sync

### `report_cache`
Fungsi: cache laporan siap baca. Bukan sumber data transaksi utama.

### `sync_checkpoint`
Fungsi: menyimpan posisi terakhir pull data.

Field penting:
- `endpoint_name`
- `scope_key`
- `cursor_value`
- `http_etag`
- `last_success_at`
- `full_refresh_required`

### `sync_queue`
Fungsi: antrean perubahan lokal yang menunggu dikirim ke server.

Field penting:
- `entity_type`
- `entity_local_id`
- `entity_remote_id`
- `dependency_entity_type`
- `dependency_local_id`
- `operation`
- `method`
- `endpoint`
- `request_body_json`
- `response_code`
- `dedupe_key`
- `priority`
- `status`
- `retry_count`
- `next_retry_at`
- `last_error`

Relasi:
- `sync_queue n -> 1 tenant`
- `sync_queue` secara logis menunjuk ke entitas bisnis, walau tidak memakai FK langsung ke semua tabel

### `error_log`
Fungsi: menyimpan error penting, terutama error sync.

Relasi:
- `error_log n -> 1 sync_queue`

## Rantai Relasi Paling Penting

### Rantai sesi dan tanggung jawab
`app_tenant -> staff -> device_session -> app_session -> shift_session`

Arti sederhananya:
- tenant menentukan toko mana
- staff menentukan siapa orangnya
- device session menentukan dia login dari device mana
- app session menentukan sesi aktif aplikasi
- shift session menentukan siapa yang bertanggung jawab atas penjualan

### Rantai penjualan
`shift_session -> pos_order -> pos_order_item`

Arti sederhananya:
- order harus punya jejak shift
- item order menempel ke order itu

### Rantai pembayaran
`pos_order -> pos_order_payment -> approval_request`

Arti sederhananya:
- payment menempel ke order
- beberapa payment atau aksi setelah payment bisa butuh approval

### Rantai self-order
`service_table -> self_order_session -> pos_order`

Arti sederhananya:
- pelanggan scan meja
- sistem membuat session self-order
- session itu nanti berubah menjadi order POS yang diproses kasir atau sistem

## Unique Rule Yang Harus Dijaga
- `app_tenant.tenant_key` harus unik.
- `device_session.session_code` unik per tenant.
- `service_table.location_id + table_code` unik per tenant.
- `self_order_session.session_code`, `public_code`, dan `access_token` unik per tenant.
- `pos_order.id_pos` unik per tenant.
- `approval_request.request_code` unik per tenant.
- `sync_checkpoint.endpoint_name + scope_key` unik per tenant.
- `sync_queue.dedupe_key` unik per tenant jika command memang idempoten.

## Nullability Rule Yang Disarankan
- `location_id` jangan boleh null di session aktif.
- `staff_id` jangan boleh null untuk shift normal.
- `device_id` jangan boleh null untuk device session normal.
- `id_pos` jangan boleh null untuk order yang lahir dari POS.
- `order_id` di `pos_order_payment` boleh null sementara hanya jika payment baru lahir lebih dulu, tetapi targetnya tetap harus cepat direlasikan.

## Hal Yang Jangan Digabung Karena Akan Bikin Bingung
- `device_session` jangan digabung dengan `shift_session`.
- `app_session` jangan digabung dengan `device_session`.
- `approval_request` jangan digabung ke status order biasa.
- `self_order_session` jangan dipaksa jadi `pos_order` langsung sebelum benar-benar submit.
- `report_cache` jangan dijadikan sumber transaksi utama.

## Keputusan Future-Proof Yang Disarankan
- Tambahkan `register_id` atau `terminal_id` pada:
  - `device_session`
  - `app_session`
  - `shift_session`
  - `pos_order`
  - `approval_request`
- Tambahkan `business_date` secara konsisten pada semua domain operasional yang butuh rekap harian.
- Bedakan `status_code` dan `status_label`, jangan hanya satu field status bebas.

## Kesimpulan ERD
Kalau diringkas paling singkat, inti FlinkPOS v2 adalah:

`tenant -> staff -> device session -> shift -> order -> item/payment -> sync/approval`

dan bila ada self-order:

`service table -> self-order session -> order -> payment`

Kalau dua rantai itu dijaga rapi, maka login, shift, offline-first, multi-device, dan audit akan tetap jelas walau sistem bertambah besar.
