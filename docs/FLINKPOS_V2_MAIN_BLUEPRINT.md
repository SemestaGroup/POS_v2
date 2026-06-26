# FlinkPOS V2 Main Blueprint

## Tujuan
Dokumen ini merangkum alur utama FlinkPOS v2 dari nol berdasarkan pembelajaran dari:
- backend lama `back_end_web_office`
- aplikasi POS v1 `pos_app_new`
- dokumen arah v2 yang sudah ada

Dokumen ini sengaja memprioritaskan alur bisnis dan aturan sistem terlebih dahulu, bukan mengikuti implementasi v2 yang sudah terlanjur ada.

## Prinsip Wajib
- POS harus `offline-first`.
- SQLite lokal adalah sumber baca dan tulis operasional utama di device.
- Server tenant tetap menjadi sumber konsolidasi lintas device, audit, refund resmi, dan laporan pusat setelah sinkronisasi berhasil.
- User tidak boleh langsung masuk ke kasir sebelum data minimum selesai masuk ke SQLite.
- Login, device session, shift session, order, payment, dan approval harus menjadi entitas yang jelas, bukan hanya status tempelan.
- Jika `omni sales` tidak aktif, perubahan order utama berasal dari POS, bukan dari polling server terus-menerus.
- Jika `omni sales` aktif, POS hanya menarik perubahan yang memang perlu, bukan semua order aktif setiap beberapa detik.
- Tidak boleh ada celah yang membuat user tanpa shift aktif bisa membuat atau mengubah order.

## Keputusan Yang Sudah Dikunci
- `classic_pos` adalah mode default.
- `location_id` wajib ada pada session aktif.
- `register_id` atau `terminal_id` harus disiapkan untuk menghindari konflik multi-device di satu cabang.
- Dalam fase transisi, `register_id` boleh disamakan dulu dengan `device_id` selama tiap terminal punya nilai yang stabil dan unik.
- `device_session`, `app_session`, dan `shift_session` tidak boleh digabung.
- Startup sync harus dibagi dua: `blocking essential` dan `deferred sync`.
- `paid invoice refund` berbeda dari `void unpaid invoice`.
- Dukungan web dianggap final hanya jika local source of truth untuk web benar-benar aktif.

## Koreksi Penting Dari Implementasi Saat Ini
- Implementasi v2 sekarang belum benar-benar siap web karena database lokal web belum aktif.
- Flow login staff dan PIN sekarang sudah dibuat fail-fast jika `location_id` tidak bisa diselesaikan, tetapi sumber data lokasi staff di backend tetap harus dikonfigurasi dengan benar.
- Open shift tidak lagi memakai fallback `location_id = 0`.
- Blocking sync tidak seharusnya menarik histori/order berat sebagai syarat masuk ke POS.
- Token session final tidak boleh bergantung pada token hardcoded tetap.

## Aktor Utama
| Aktor | Peran sederhana | Boleh membuat order | Boleh menerima pembayaran | Boleh approval |
| --- | --- | --- | --- | --- |
| Owner | Pemilik toko | Ya | Ya | Ya |
| Supervisor | Pengawas toko | Ya | Ya | Ya |
| Cashier | Kasir utama | Ya, jika shift aktif | Ya, jika shift aktif | Tidak langsung |
| Kitchen | Bagian dapur | Tidak | Tidak | Tidak |
| Customer self-order | Pelanggan pesan sendiri | Ya, hanya lewat flow self-order | Tergantung mode | Tidak |
| Sync worker | Proses sistem | Tidak | Tidak | Tidak |
| Back office web | Panel kontrol | Tidak untuk kasir harian | Tidak untuk kasir harian | Ya |

## Komponen Sistem
| Komponen | Fungsi |
| --- | --- |
| Central discovery API | Mencari tenant dari email user. |
| Tenant operational API | Menangani login tenant, bootstrap, sync master, order, payment, shift, approval, self-order. |
| SQLite di app | Menyimpan semua data kerja POS agar tetap jalan offline. |
| Sync engine | Mengirim perubahan lokal ke server dan menarik pembaruan server ke SQLite. |
| Device session | Mencatat siapa login di device mana. |
| Shift session | Mencatat siapa membuka laci kas dan siapa yang bertanggung jawab. |
| Printer service | Mencetak struk, QR, dan dokumen lain sesuai platform. |

## Sumber Kebenaran Data
| Domain | Sumber kebenaran saat dipakai kasir | Sumber kebenaran lintas device | Catatan |
| --- | --- | --- | --- |
| Session aktif di device | SQLite lokal | Tenant API | UI selalu membaca session dari lokal dulu. |
| Master data produk, kategori, brand, customer, promo | SQLite lokal | Tenant API | Update server masuk dulu ke SQLite, baru UI berubah. |
| Cart dan order yang belum tersinkron | SQLite lokal | Belum ada | Selama `sync_state` masih kotor, lokal menang. |
| Order yang sudah tersinkron | SQLite lokal untuk UI device itu | Tenant API untuk konsolidasi | Setelah ack server, lokal dan server harus sama. |
| Payment | SQLite lokal dulu | Tenant API sesudah ack | Payment tidak boleh menunggu internet. |
| Shift aktif | SQLite lokal | Tenant API | Device lain hanya boleh lihat, bukan mengambil alih diam-diam. |
| Approval | SQLite lokal cache | Tenant API / back office | Keputusan final approval datang dari server. |
| Refund resmi | Bukan lokal | Tenant API / back office | Refund paid invoice harus jadi dokumen resmi di server. |

## DFD Tekstual Level 0
1. User membuka aplikasi.
2. Aplikasi meminta tenant ke `central discovery API` berdasarkan email.
3. Aplikasi login ke `tenant API`.
4. `tenant API` mengirim session, policy, dan data bootstrap.
5. App memasukkan data itu ke `SQLite`.
6. Semua layar POS membaca dari `SQLite`.
7. Saat user membuat order atau payment, app menulis ke `SQLite` dulu.
8. `sync engine` membaca antrean lokal lalu mengirim ke `tenant API`.
9. `tenant API` membalas hasil sinkron dan app memperbarui `SQLite`.

## DFD Tekstual Level 1

### 1. Discovery Dan Login
`Aplikasi dibuka > user isi email > central discovery mencari tenant > app menampilkan tenant yang cocok > user pilih tenant > user isi password > tenant API verifikasi > backend membuat atau memperbarui device session > hasil login disimpan ke SQLite > app lanjut ke bootstrap`

Aturan penting:
- `device_id` harus stabil per instalasi/device, bukan berubah setiap login.
- Jika policy `single device per staff` aktif, staff yang masih aktif di device lain harus ditolak atau dipaksa logout oleh owner/supervisor.
- PIN hanya dipakai untuk unlock layar atau pindah akun cepat setelah tenant dan akun itu sudah diketahui device.

### 2. Bootstrap Dan Blocking Sync Screen
`Login berhasil > app masuk ke layar sinkronisasi wajib > app memanggil pos-bootstrap, pos-policies, dan master data minimum > semua data masuk ke SQLite > validasi tabel minimum selesai > layar blokir hilang > user boleh masuk ke aplikasi`

Data minimum yang wajib ada sebelum POS bisa dipakai:
- tenant aktif
- session aktif
- policy snapshot
- staff profile aktif
- payment modes
- order types
- halaman awal products aktif
- categories
- minimal customer cache
- POS options penting

Data yang tidak wajib ada untuk membuka layar kasir pertama kali:
- histori order panjang
- histori payment panjang
- report cache
- semua halaman item sampai habis jika katalog sangat besar
- semua self-order session lama

Halaman blokir ini memang sengaja menahan klik user ke menu lain. Tujuannya supaya tidak ada order dibuat saat data dasar belum siap.

### 3. Shift Gate
`User sudah login > app cek apakah ada shift aktif untuk device/register ini > jika tidak ada maka app paksa ke layar open shift > user isi opening cash > shift session dibuat di SQLite dan dikirim ke queue > sales baru dibuka`

Aturan penting:
- Tanpa shift aktif, halaman penjualan hanya boleh menjadi read-only.
- User yang membuka shift menjadi penanggung jawab utama register itu.
- Jika ada device lain login dengan akun lain, device itu tidak boleh membuat atau mengubah order pada register yang sama.

Catatan desain penting:
- Jika bisnis benar-benar hanya ingin satu kasir aktif per cabang, cukup kunci `1 open shift per location_id`.
- Jika nanti ingin banyak kasir bersamaan dalam satu cabang, tambahkan `register_id` atau `terminal_id`, lalu kuncinya menjadi `1 open shift per location_id + register_id`.

### 4. Alur Jualan POS Normal
`Kasir pilih produk > app membaca produk dari SQLite > cart disimpan lokal > kasir pilih customer atau walk-in > kasir simpan hold atau lanjut bayar > app membuat order header + order item di SQLite > app menaruh perintah sync ke outbox`

Aturan penting:
- `id_pos` dibuat oleh app sejak order pertama kali lahir. Ini identitas tetap order dari sisi POS.
- Order tidak boleh bergantung pada `remote invoice id` untuk bisa dipakai offline.
- Harga, diskon, promo, dan pajak dihitung dari snapshot lokal yang sudah tersinkron terakhir.

### 5. Hold, Resume, Dan Edit Order
`Kasir simpan order hold > order status lokal menjadi hold > user lain membuka daftar parked orders > hanya user/register yang berhak yang boleh resume > order dibuka lagi dari SQLite > user ubah item > app menandai order dirty_update`

Aturan penting:
- Saat order masih punya perubahan lokal yang belum terkirim, refresh server tidak boleh menimpa isi order itu.
- Jika order sudah punya payment pending, order juga tidak boleh diam-diam dioverwrite oleh pull dari server.

### 6. Checkout Dan Multi-Payment
`Kasir tekan bayar > app membuat payment record di SQLite > order total dan status lokal ikut diperbarui > print lokal boleh jalan langsung > queue mengirim order dulu lalu payment > server mengembalikan ack > SQLite diperbarui menjadi clean`

Aturan penting:
- Payment tidak boleh menunggu internet.
- Jika satu order dibayar dengan beberapa metode, semua payment disimpan sebagai baris terpisah.
- Poin member yang final sebaiknya dianggap resmi setelah ack server, tetapi app boleh menampilkan estimasi lokal.

### 7. Background Sync
`App hidup > network tersedia > sync worker membaca sync_queue > kirim command satu per satu sesuai dependency > jika berhasil maka row bisnis jadi clean > jika gagal maka retry dengan backoff > jika konflik maka tandai conflict dan minta tindakan user`

Dependency minimal:
- customer create lebih dulu dari order yang memakai customer baru
- order create lebih dulu dari payment yang mengarah ke order itu
- self-order session create lebih dulu dari link-order

Pull dari server harus dipisahkan dari push lokal:
- push keluar memakai `sync_queue`
- pull masuk memakai `sync_checkpoint`

### 8. Approval Flow
`Kasir butuh void, refund, atau diskon khusus > app membuat approval request di SQLite > queue mengirim request ke server > supervisor/owner menyetujui dari POS atau web sesuai policy > hasil approval disinkronkan balik ke device > app baru menjalankan perubahan final pada order atau payment`

Aturan penting:
- `void unpaid invoice` boleh lewat approval sesuai policy.
- `paid invoice` jangan diperlakukan sebagai void biasa. Jalur benarnya adalah refund resmi.
- Kasir tidak boleh override diskon di luar batas policy tanpa approval.

### 9. Self-Order Dan Table QR
`Customer scan QR meja > app/web resolve meja dan buka self-order session > customer pilih item > session tersimpan > saat cashier mengambil alih atau customer submit > session ditautkan ke order POS melalui id_pos/invoice > status session bergerak sampai close`

Aturan penting:
- `queue_number` harus konsisten per `location_id + business_date`.
- Jika offline penuh, self-order web tidak bisa menjadi fitur utama. Ia tetap butuh jalur online minimal.
- Self-order tidak boleh menabrak aturan shift. Order yang akhirnya masuk ke POS tetap harus terkait ke shift aktif cashier yang memprosesnya.

### 10. Omni Sales Mode
Mode yang disarankan:
- `classic_pos`: POS adalah pemilik utama order. Tidak perlu polling detail order aktif terus-menerus.
- `self_order_hybrid`: order bisa lahir dari POS dan self-order.
- `omni_sales_hybrid`: order bisa masuk dari channel lain juga.

Aturan saat `omni sales` tidak aktif:
- sumber perubahan order utama adalah POS
- POS tidak perlu sync detail order aktif setiap beberapa detik
- cukup sync saat login, resume app, manual sync, checkout, close shift, atau interval aman

Aturan saat `omni sales` aktif:
- POS hanya menarik delta order yang memang relevan untuk lokasi/device itu
- jangan menarik seluruh histori berulang-ulang
- bila memungkinkan, pakai incremental API atau event channel, bukan polling berat

### 11. Switch User Dan Lock Screen
`User sedang login > user ingin ganti akun > app kunci layar > akun baru harus isi PIN atau login ulang > jika masih ada cart aktif maka app minta selesaikan, hold, atau batalkan dulu > setelah aman baru session aktif berganti`

Aturan penting:
- Switch user bukan logout tenant penuh.
- Akun baru tidak boleh mengambil order aktif tanpa jejak audit.
- Jika shift masih aktif milik user lama, perpindahan user harus mengikuti policy handoff yang jelas.

## UCD Tekstual

### Cashier
- login ke tenant
- masuk dengan PIN
- melihat layar sinkronisasi awal
- membuka shift
- membuat order
- hold order
- resume order
- menerima multi-payment
- mencetak struk
- meminta approval
- menutup shift
- ganti akun dengan PIN

### Supervisor
- semua use case cashier
- force logout device lain
- menyetujui discount override
- menyetujui void unpaid order
- memonitor device sessions
- melihat shift history

### Owner
- semua use case supervisor
- mengubah policy POS
- memonitor laporan
- menyetujui refund sesuai jalur bisnis

### Kitchen
- melihat tiket kitchen
- mengubah status kesiapan pesanan jika diizinkan
- tidak boleh mengubah payment

### Customer Self-Order
- scan QR
- buka session order
- pilih item
- submit order
- lihat nomor antrian atau status

### System Sync Worker
- push perubahan lokal
- pull perubahan server
- retry gagal sinkron
- menandai conflict

## Aturan Anti-Celah Yang Wajib
- Tidak ada penjualan tanpa `device session` aktif.
- Tidak ada penjualan tanpa `shift session` aktif.
- Session aktif harus terikat ke `device_id` yang jelas.
- User lain yang login di device lain tidak otomatis boleh mengubah order milik shift aktif orang lain.
- `id_pos` harus unik global, misalnya UUID atau ULID.
- Order yang masih `dirty` tidak boleh ditimpa pull server.
- Payment yang sudah dibuat lokal tidak boleh hilang walau internet putus.
- PIN tidak boleh disimpan polos di lokal atau diverifikasi polos selamanya. Target akhirnya harus hash + secure storage untuk rahasia penting.
- Token login jangan disimpan di tempat yang mudah dibaca mentah.
- Approval, refund, dan force logout harus punya audit log.
- Queue harus menyimpan error terakhir, retry count, dan response server.

## Status Yang Disarankan
| Domain | Status utama |
| --- | --- |
| Device session | `active`, `logged_out`, `forced_out` |
| Shift | `open`, `closed`, `reconciled`, `cancelled` |
| Order | `draft`, `hold`, `unpaid`, `paid`, `void`, `refund_requested`, `refunded` |
| Payment | `pending_push`, `posted`, `voided`, `failed` |
| Approval request | `pending`, `approved`, `rejected`, `applied`, `expired`, `cancelled` |
| Sync row | `clean`, `dirty_create`, `dirty_update`, `dirty_delete`, `syncing`, `error`, `conflict` |

## Platform Dan Library Recommendation
Karena v2 harus jalan di Android tablet, iOS tablet, Android phone, iOS phone, dan web, maka pilihan library harus mengikuti batas platform, bukan hanya nyaman di Android.

| Kebutuhan | Rekomendasi utama | Alasan |
| --- | --- | --- |
| Database lokal offline-first | `drift` + SQLite native di mobile + SQLite WASM di web | `sqflite` bagus di mobile, tetapi tidak cukup untuk web. `drift` memberi satu layer query yang lebih konsisten untuk semua platform. |
| Penyimpanan rahasia | `flutter_secure_storage` di mobile, penyimpanan web dengan TTL pendek + token minim | Token dan PIN hash tidak boleh ditaruh polos. |
| Network client | `dio` atau `http` + wrapper retry/logging sendiri | Perlu timeout, interceptor, dan logging sync. |
| Deteksi koneksi | `connectivity_plus` + health check ke tenant API | Status wifi saja tidak cukup. |
| Background sync | Foreground sync engine sebagai inti, `workmanager` hanya tambahan di Android/iOS | Web dan iOS tidak bisa dijadikan bergantung penuh pada background worker. |
| Printing universal | `printing` untuk baseline semua platform | Aman untuk web, iOS, Android karena pakai dialog print/share sistem. |
| Thermal ESC/POS | Network printer lebih diutamakan; Bluetooth hanya sebagai fitur tambahan per platform | Bluetooth thermal lintas Android, iOS, dan web tidak benar-benar seragam. |
| Barcode scan | `mobile_scanner` | Mendukung mobile dan web lebih baik daripada solusi yang terlalu native. |
| Device info | `device_info_plus` + installation UUID sendiri | `device_id` harus stabil dan tidak berubah-ubah. |

Catatan printer penting:
- Jika targetnya benar-benar lintas platform, prioritaskan `LAN/WiFi printer` sebagai standar utama.
- Bluetooth printer boleh tetap ada, tetapi jangan dijadikan fondasi satu-satunya karena iOS dan web lebih rumit.

## Domain Lokal SQLite Yang Disarankan
Minimal tabel lokal v2:
- `app_tenant`
- `app_session`
- `staff`
- `device_session`
- `shift_session`
- `pos_option`
- `policy_snapshot`
- `payment_mode`
- `order_type`
- `brand`
- `category`
- `product`
- `product_brand`
- `product_location`
- `product_order_type`
- `customer`
- `promotion`
- `pos_order`
- `pos_order_item`
- `pos_order_payment`
- `service_table`
- `self_order_session`
- `self_order_event`
- `approval_request`
- `sync_queue`
- `sync_checkpoint`
- `error_log`

## Urutan Pengerjaan Yang Paling Aman
1. Discovery tenant, login, bootstrap, policy snapshot.
2. Local database final dan sync engine final.
3. Shift gate dan device session gate.
4. POS cart, order, hold, resume, payment, print.
5. Approval request dasar.
6. Self-order dan service table.
7. Omni sales hybrid.
8. Report, diagnostics, dan optimasi platform.

## Keputusan Desain Yang Sebaiknya Dipegang
- POS v2 tetap Flutter, tetapi layer database lokal sebaiknya diubah agar benar-benar lintas platform.
- Offline-first bukan sekadar cache. Ia harus menjadi pola tulis utama.
- SQLite lokal menjadi sumber kerja utama device, tetapi hasil final lintas device tetap dikonsolidasikan ke tenant backend.
- `location_id` saja belum cukup untuk masa depan. Siapkan ruang untuk `register_id` atau `terminal_id`.
- `omni sales` harus menjadi mode operasional, bukan perilaku default diam-diam.

## Referensi Yang Paling Mempengaruhi Dokumen Ini
- `pos_app_new/docs/sqlite_source_of_truth_v2.md`
- `pos_app_new/lib/core/services/sync_service.dart`
- `back_end_web_office/controllers/v2/Pos_auth_v2.php`
- `back_end_web_office/controllers/v2/Pos_bootstrap_v2.php`
- `back_end_web_office/controllers/v2/Pos_shift_sessions_v2.php`
- `back_end_web_office/controllers/v2/Pos_order_v2.php`
- `back_end_web_office/controllers/v2/Pos_transaction_v2.php`
- `back_end_web_office/config/routes.php`
- `flinkpos_v2/API_DOCS.md`
- `flinkpos_v2/BACKEND_SAAS_DIRECTION.md`
