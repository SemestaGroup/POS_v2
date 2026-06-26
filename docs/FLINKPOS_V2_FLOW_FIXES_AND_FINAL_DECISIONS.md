# FlinkPOS V2 Flow Fixes And Final Decisions

## Tujuan
Dokumen ini bukan sekadar catatan ide. Dokumen ini mengunci keputusan yang perlu dipakai agar FlinkPOS v2 tidak membingungkan, tidak berat dipelihara, dan tidak melahirkan error dari desain yang kabur.

## Temuan Pengganjal Dari Source Dan Status Sekarang
| Temuan | Status sekarang | Referensi |
| --- | --- | --- |
| SQLite lokal belum aktif untuk web, malah melempar error. | Masih belum selesai. Web source of truth belum final. | `flinkpos_v2/lib/core/services/local/database_service.dart` |
| Runtime session store di web langsung mengembalikan `null`. | Masih belum selesai. Web session persistence belum final. | `flinkpos_v2/lib/core/services/sync/pos_v2_runtime_session_store.dart` |
| Token auth masih berupa konstanta hardcoded. | Masih sebagian. Login sekarang memakai `auth_token` dari respons bila ada, tetapi fallback konstanta masih tersisa. | `flinkpos_v2/lib/core/network/v2_api_fixed_auth.dart`, `pos_v2_auth_service.dart` |
| Login dan PIN login belum konsisten soal `location_id`. | Sudah diperbaiki sebagian. Login, PIN login, dan bootstrap sekarang mencoba resolusi `location_id` yang lebih tegas, dan frontend fail-fast jika tetap kosong. Namun kualitas akhirnya tetap bergantung pada konfigurasi lokasi staff/tenant di backend. | `back_end_web_office/controllers/v2/Pos_auth_v2.php`, `back_end_web_office/models/Pos_auth_model.php`, `flinkpos_v2/lib/core/services/sync/pos_v2_auth_service.dart` |
| Bootstrap tenant juga masih mengirim `location_id = null`. | Sudah diperbaiki sebagian. Bootstrap sekarang menerima dan mengembalikan `location_id` dari context, lalu frontend menyimpannya ulang secara lebih konsisten. | `back_end_web_office/controllers/v2/Pos_bootstrap_v2.php`, `flinkpos_v2/lib/core/services/sync/bootstrap_sync_adapter.dart` |
| Flow open shift memakai `int.tryParse(session.locationId) ?? 0`. | Sudah diperbaiki. Sekarang open shift berhenti dengan error jelas jika `location_id` tidak valid. | `flinkpos_v2/lib/modules/operations/shift/models/active_shift_store.dart` |
| Blocking sync saat startup masih ikut menarik order aktif. | Belum saya ubah penuh. Secara keputusan arsitektur sudah dikunci, tetapi implementasi layar bootstrap masih bisa diringankan lagi. | `flinkpos_v2/lib/modules/auth/views/sync_bootstrap_screen.dart` |
| App mengaku Android dan web, tetapi fondasi database masih mobile-only. | Masih belum selesai. Arsitektur lintas platform belum final. | `flinkpos_v2/pubspec.yaml`, `database_service.dart` |

## Prinsip Keputusan
- Jika satu hal bisa membingungkan developer baru, maka penamaannya salah atau entitasnya belum dipisah.
- Jika satu flow bisa jalan dengan `null`, `0`, atau fallback diam-diam, maka itu rawan menjadi bug diam-diam.
- Jika satu fitur inti tidak didukung di web sekarang, jangan dianggap “sudah support web”. Harus ditulis apa adanya.

## Keputusan Final

### D-01. Satu Jalur Login Final
Keputusan:
- Jalur utama login adalah `discover tenant -> pilih tenant -> password login tenant -> bootstrap -> essential sync -> shift gate -> masuk aplikasi`.
- PIN bukan jalur discovery tenant.
- PIN hanya boleh dipakai untuk:
  - unlock layar
  - switch user di tenant yang sama
  - re-entry cepat jika akun itu sudah pernah bootstrap di device tersebut

Kenapa:
- Ini menghapus kebingungan antara `merchant login`, `staff selector`, dan `email-per-staff login`.

Yang harus dihindari:
- flow campuran `merchant login` lalu `staff selector` untuk semua role
- PIN login tanpa tenant context yang jelas

### D-02. `location_id` Wajib Ada Di Sesi Aktif
Keputusan:
- Setelah login berhasil, `app_session.location_id` tidak boleh kosong.
- `pin_login` harus mengembalikan `location_id` yang valid, atau app harus mengambilnya dari tenant aktif yang sudah dipilih sebelumnya tanpa ambigu.
- `pos-bootstrap` juga harus mengirim `tenant.location_id` yang valid.
- Jika backend tetap tidak bisa menyelesaikan `location_id`, frontend harus berhenti saat login atau PIN login dengan pesan error yang jelas. Jangan lanjut diam-diam ke shift gate.

Kenapa:
- Shift, promo lokasi, meja layanan, dan sync scoped location semuanya bergantung pada ini.

Efek desain:
- Jangan gunakan `0`, string kosong, atau `null` sebagai fallback sunyi.
- Jika `location_id` tidak ada, app harus berhenti di layar error setup, bukan lanjut ke kasir.

### D-03. Tambahkan `register_id` atau `terminal_id`
Keputusan:
- `location_id` tidak cukup untuk membedakan banyak kasir aktif di cabang yang sama.
- Tambahkan `register_id` atau `terminal_id` sebagai identitas register operasional.
- Untuk fase transisi implementasi sekarang, `register_id` boleh diset sama dengan `device_id` terlebih dahulu selama nilainya stabil per terminal. Target akhirnya tetap register provisioning yang eksplisit.

Harus dipakai minimal pada:
- `device_session`
- `app_session`
- `shift_session`
- `pos_order`
- `approval_request`

Kenapa:
- Tanpa ini, aturan “siapa yang membuka shift dia yang bertanggung jawab” akan bentrok saat ada beberapa device aktif di lokasi yang sama.

### D-04. Bedakan Tiga Entitas Session
Keputusan:
- `device_session` = siapa login di device mana.
- `app_session` = sesi aplikasi yang sedang aktif secara lokal.
- `shift_session` = siapa yang bertanggung jawab pada register penjualan.

Kenapa:
- Tiga hal ini kelihatannya mirip, tapi fungsi bisnisnya berbeda.

Larangan:
- Jangan menyimpan semua hal itu ke satu tabel status session tunggal.

### D-05. Startup Sync Harus Dipecah Dua Tahap
Keputusan:
- Tahap blocking hanya memuat data minimum.
- Tahap deferred memuat data berat setelah user sudah bisa masuk.

Blocking minimum:
- tenant aktif
- app session
- policy snapshot
- payment modes
- order types
- categories
- brands
- halaman pertama item aktif
- promo aktif untuk lokasi itu
- active shift untuk context itu

Deferred sync:
- halaman item berikutnya
- staff list penuh
- self-order session
- history shift
- customer lebih luas
- history order dan payment
- report cache

Kenapa:
- Ini mempercepat startup dan mengurangi potensi “app terasa macet saat baru login”.

Perbaikan terhadap implementasi sekarang:
- jangan tarik `50 order + detail` di blocking screen default
- history order bukan syarat minimum membuka kasir

### D-06. `classic_pos` Harus Jadi Default Mode
Keputusan:
- Mode default operasi adalah `classic_pos`.
- Dalam mode ini, POS adalah pemilik utama order.
- Pull order aktif berkala tidak wajib.

Mode lain:
- `self_order_hybrid`
- `omni_sales_hybrid`

Kenapa:
- Mayoritas toko POS butuh performa dan kestabilan, bukan sinkronisasi order aktif tanpa henti.

### D-07. Conflict Rule Untuk Order Dan Payment
Keputusan:
- Jika order lokal masih `dirty`, server pull tidak boleh menimpa field bisnis lokal.
- Jika payment lokal belum ack server, order itu dianggap masih milik lokal untuk status pembayaran.
- Jika server juga berubah pada field yang sama, status menjadi `conflict`.

Kenapa:
- Ini mencegah order berubah sendiri, total melompat, atau payment hilang saat koneksi putus-sambung.

### D-08. Ownership Order Wajib Jelas
Keputusan:
Setiap order harus bisa ditelusuri ke:
- `tenant_id`
- `location_id`
- `register_id` nanti
- `sale_staff_id`
- `device_session_id`
- `shift_session_id`
- `source_channel`

Kenapa:
- Tanpa atribut ini, audit dan penyelesaian masalah akan kabur.

### D-09. Shift Menentukan Hak Tulis, Bukan Sekadar Login
Keputusan:
- Login saja tidak cukup untuk membuat order.
- Hak tulis order ditentukan oleh shift aktif pada register tersebut.

Aturan:
- device lain boleh login sebagai user lain untuk monitoring jika dibutuhkan
- tetapi tanpa shift yang relevan, device itu tidak boleh mengubah atau membuat order pada register yang sedang dikuasai orang lain

### D-10. Switch User Harus Melewati Handoff Rule
Keputusan:
- Jika ada cart aktif, switch user harus memaksa salah satu:
  - selesaikan order
  - hold order
  - batalkan order
- Jika shift masih aktif, user baru tidak otomatis menjadi penanggung jawab shift.

Pilihan handoff yang disarankan:
- `switch identity only` untuk layar terkunci tanpa mengganti shift owner
- `handoff register` hanya untuk supervisor/owner atau flow khusus end-shift/open-shift baru

### D-11. Refund Dan Void Tidak Boleh Dicampur
Keputusan:
- `void unpaid invoice` adalah pembatalan order yang belum selesai dibayar.
- `refund paid invoice` adalah pengembalian resmi yang membuat jejak credit note atau dokumen resmi server.

Kenapa:
- Ini mencegah laporan keuangan bercampur dan audit menjadi rusak.

### D-12. Approval Adalah Entitas, Bukan Status Tempelan
Keputusan:
- Approval request harus tetap menjadi tabel sendiri.
- Hasil approval boleh mengubah order/payment/expense, tetapi request-nya tetap punya identitas sendiri.

Kenapa:
- History approval harus tetap terbaca walau order sudah berubah.

### D-13. Self-Order Tidak Boleh Mem-bypass Shift
Keputusan:
- Self-order session boleh lahir sebelum kasir sentuh order.
- Tetapi saat order itu diambil alih POS, ia harus terikat ke `shift_session` kasir yang memprosesnya.

Kenapa:
- Kalau tidak, akan ada order masuk tanpa penanggung jawab register.

### D-14. Queue Number Harus Punya Scope Jelas
Keputusan:
- `queue_number` minimal scoped ke `tenant + location + business_date`.
- Jika tipe bisnis butuh pemisahan antrean per register atau per order type, scope diperluas dengan `register_id` atau `order_type_code`.

### D-15. Web Support Harus Jujur Dan Benar
Keputusan:
- Sampai database source of truth web benar-benar aktif, jangan klaim v2 sudah siap web penuh.
- Target final web tetap dipertahankan, tetapi implementasinya harus memakai database lintas platform seperti `drift + sqlite3/wasm` atau alternatif yang setara.

Kenapa:
- Kode saat ini memang belum benar-benar mendukung web source-of-truth.

### D-16. Token Dan Secret Tidak Boleh Hardcoded
Keputusan:
- `auth_token` sesi tidak boleh memakai konstanta tetap untuk seluruh device.
- Token hasil login tenant harus dipakai sebagai token sesi aktual.
- Secret sensitif harus masuk secure storage atau session layer yang aman.

Kenapa:
- Token tetap hardcoded adalah hutang keamanan besar.

### D-17. Naming Harus Dinormalisasi
Keputusan:
- pakai `location_id`, bukan campur `id_location`
- pakai `staff_id`, bukan campur `user_id` untuk pegawai
- pakai `customer_id` untuk pelanggan
- pakai `register_id`, bukan campur terus dengan `terminal_id` di semua layer internal
- pakai `status_code` untuk nilai status baku
- pakai `source_channel` untuk asal order

Kenapa:
- Nama yang tidak konsisten akan membuat adapter, query, dan dokumentasi berantakan.

## Alur Final Yang Sudah Dibersihkan

### Flow A. First Login
`app dibuka > user isi email > discover tenant > user pilih tenant > user isi password > tenant login > app simpan tenant + staff + device session + app session > blocking essential sync > jika data minimum valid maka lanjut ke shift gate atau home sesuai shift`

### Flow B. Reopen App
`app dibuka lagi > runtime session dipulihkan dari lokal > validasi token/session ringan > bootstrap delta > cek active shift > masuk home jika aman`

### Flow C. Switch User
`user tekan ganti akun > app lock screen > app cek ada cart aktif atau tidak > jika ada maka minta selesaikan/hold/batal > user baru isi PIN > app ganti app session aktif > shift tetap milik owner lama kecuali flow handoff resmi dipakai`

### Flow D. Open Shift
`session aktif valid > location_id valid > register_id valid jika ada > user isi opening balance > open shift ke SQLite dulu > queue push ke backend > shift gate terbuka`

### Flow E. Create Order
`kasir pilih item dari SQLite > app buat id_pos > order header dan item masuk SQLite > sync_state dirty_create > queue dibuat > UI tetap jalan tanpa tunggu server`

### Flow F. Payment
`kasir pilih metode bayar > payment row masuk SQLite > total order lokal diperbarui > struk boleh dicetak > queue mengirim order lalu payment > setelah ack, order dan payment menjadi clean`

### Flow G. Approval
`kasir minta approval > approval_request lokal dibuat > queue push request > supervisor/owner setujui atau tolak > hasil ditarik balik > app menerapkan hasil final`

### Flow H. Close Shift
`kasir minta tutup shift > sistem hitung expected cash dari SQLite > user isi actual cash > shift close row dibuat/update lokal > queue push close shift > setelah ack, shift selesai`

## Yang Harus Dianggap Error, Bukan Fallback Diam-Diam
- `location_id` kosong setelah login
- `staff_id` kosong untuk akun yang harusnya kasir/supervisor/owner POS
- `device_id` kosong saat policy mewajibkan device lock
- buka shift dengan `location_id = 0`
- order POS lahir tanpa `id_pos`
- payment lahir tanpa relasi ke order atau `id_pos`
- approval request lahir tanpa `request_type` dan `reason`

## Prioritas Fix Yang Disarankan

### P0
- pastikan `location_id` selalu ada pada login, pin-login, dan bootstrap
- hentikan fallback `0` pada open shift
- ganti token hardcoded
- putuskan arsitektur database web final

### P1
- tambahkan `register_id` atau `terminal_id`
- pisahkan startup blocking vs deferred sync secara tegas
- normalisasi nama field `location_id` dan `id_location`
- tetapkan enum final `status_code`, `source_channel`, `request_type`

### P2
- rapikan flow self-order hybrid
- rapikan report cache
- tambah handoff register flow resmi

## Checklist Keputusan Yang Harus Dipatuhi Tim
- [ ] Tidak ada flow login yang berakhir dengan `location_id` kosong
- [ ] Tidak ada write order tanpa shift aktif
- [ ] Tidak ada write payment tanpa `id_pos` atau order link
- [ ] Tidak ada token tetap hardcoded untuk sesi user
- [ ] Tidak ada klaim web-ready sebelum local DB web aktif
- [ ] Tidak ada polling order aktif berat pada mode `classic_pos`
- [ ] Tidak ada kebingungan antara device session, app session, dan shift session

## Rekomendasi Perubahan Pada Blueprint Utama
Setelah dokumen ini, anggap keputusan berikut sudah terkunci:
- `classic_pos` sebagai default mode
- `location_id` wajib dan tidak boleh fallback sunyi
- `register_id` adalah kebutuhan desain, bukan tambahan kosmetik
- startup sync harus dibagi `blocking essential` dan `deferred`
- dukungan web butuh fondasi DB baru atau adapter yang benar-benar setara
