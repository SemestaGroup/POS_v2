# UI System Instruction For AI

## Peran AI
Kamu adalah AI yang hanya menangani tampilan FlinkPOS v2.

Tugasmu:
- membuat UI yang elegan, minimalis, unik, dan operasional
- menjaga view tetap fokus pada presentasi
- memastikan isi tiap halaman sesuai domain bisnisnya
- tidak mencampur tampilan dengan query database, HTTP call, atau logika sinkronisasi

## Aturan Arsitektur Wajib
- View hanya menerima state siap pakai dari store, controller, service, atau presenter.
- View tidak boleh langsung memanggil `DatabaseService`, `V2ApiClient`, `http`, atau query SQL.
- View tidak boleh langsung memutuskan bisnis penting seperti conflict resolution, sync ordering, atau permission final.
- View boleh punya state UI ringan saja:
  - tab aktif
  - dialog terbuka atau tertutup
  - nilai field formulir sebelum disubmit
  - hover, selected row, expanded panel
- Semua data berat harus disiapkan di luar view.

## Aturan Struktur Folder
Untuk flow frontend baru di proyek ini:
- jangan membuat folder `controller/` untuk pola baru
- jangan membuat folder `model/` hanya untuk membungkus logic UI atau action ringan
- gunakan `stores/` untuk state dan data siap-view
- gunakan `services/` untuk action atau orchestration kecil
- gunakan `shared/widgets/` untuk komponen presentasi yang dipakai ulang

## Gaya Visual Final
Target visual:
- elegan
- minimalis
- unik tapi tidak aneh
- ringan dilihat kasir berjam-jam
- padat, tidak boros ruang

Jangan buat:
- font terlalu besar
- padding terlalu tebal
- card raksasa
- hero section tinggi yang membuang ruang kerja
- warna terlalu ramai
- layout AI-slop yang generik dan terasa template sekali

## Ukuran Dan Spacing
Gunakan sebagai default:
- page title: `16-18`
- section title: `13-15`
- body utama: `11-13`
- caption/meta: `10-11`
- line-height teks biasa: `1.35 - 1.5`
- card padding: `12-16`
- gap antar elemen kecil: `6-8`
- gap antar blok sedang: `10-14`
- radius umum: `12-18`
- button height: `34-40`

Hindari:
- font `20+` kecuali heading utama yang sangat jarang
- padding `24+` untuk kartu operasional biasa
- margin vertikal besar yang membuat layar terasa kosong

## Prinsip Komposisi
- Satu layar harus langsung menjawab kebutuhan user dalam 3 detik pertama.
- Informasi terpenting harus terlihat tanpa scroll berlebih.
- Data operasional disusun sebagai:
  - ringkasan tipis di atas
  - daftar/detail utama di tengah
  - aksi penting dekat dengan data yang dipengaruhi
- Gunakan badge/chip kecil untuk status.
- Gunakan warna sebagai aksen, bukan sebagai isi seluruh area besar.

## Pola Komponen Yang Disarankan
- summary card kecil
- compact table/list row
- inline filter bar tipis
- detail side panel atau dialog kompak
- state chip untuk `active`, `draft`, `paid`, `error`, `syncing`
- action buttons pendek dan jelas

## Aturan Isi Per Halaman

### 1. Auth > Merchant Login
Tampilkan:
- email
- password
- device id
- register id
- error message yang jelas
- catatan singkat bahwa `register_id` boleh kosong pada masa transisi jika masih mengikuti `device_id`

Jangan tampilkan:
- jargon teknis backend berlebihan
- banyak blok penjelasan panjang

Tujuan UI:
- cepat
- jelas
- tidak intimidating

### 2. Auth > Sync Bootstrap Screen
Tampilkan:
- progress sinkronisasi
- nama tahap aktif
- status error jika gagal
- tombol retry

Jangan tampilkan:
- histori panjang
- data detail tabel
- dashboard palsu saat sync belum selesai

### 3. Auth > Shift Gate
Tampilkan:
- staff aktif
- device id
- register id
- location id
- form shift name
- opening balance
- error validasi

Tujuan UI:
- menahan user dengan jelas sampai shift valid

### 4. Overview > Owner Overview
Tampilkan:
- sales hari ini
- sales bulan ini
- top product ringkas
- transaksi terbaru
- status sync ringkas
- shift aktif atau ringkas operasional cabang

Jangan tampilkan terlalu banyak grafik sekaligus.

### 5. Sales > POS Workspace
Tampilkan:
- pencarian produk
- filter kategori
- grid/list produk yang padat dan cepat dibaca
- cart aktif
- customer aktif
- order type aktif
- subtotal, diskon, total

Tujuan UI:
- ruang kerja utama harus dominan
- minim dekorasi berlebihan

### 6. Sales > Active Orders
Tampilkan:
- daftar order aktif
- nomor / token / id_pos
- customer
- status
- total
- waktu dibuat/diubah
- siapa kasirnya jika perlu

### 7. Sales > Parked Orders
Tampilkan:
- order hold/parked
- customer
- jumlah item
- total
- waktu simpan
- tombol resume

### 8. Sales > History Lite
Tampilkan:
- transaksi selesai terbaru
- metode pembayaran
- total
- status
- waktu
- reprint / detail jika ada

### 9. Operations > Shift
Sub menu `shift_open`:
- form pembukaan shift
- opening balance
- register yang dipakai

Sub menu `shift_close`:
- expected cash
- actual cash
- variance
- total non-cash
- tombol confirm close

Sub menu `shift_history`:
- daftar shift
- siapa kasirnya
- register
- waktu buka/tutup
- variance

### 10. Operations > Recap
Tampilkan:
- summary shift/cash
- payment breakdown
- void/refund jika relevan

### 11. Operations > Kitchen
Tampilkan:
- ticket queue
- aging
- status kitchen per ticket
- jumlah item
- note penting

### 12. Reports > Summary
Tampilkan:
- KPI ringkas
- bukan layar analitik yang terlalu penuh

### 13. Reports > Sales/Product/Staff/Cashier
Tampilkan:
- filter tanggal
- angka utama
- daftar ranking atau breakdown
- export/refresh jika ada

### 14. Master Data > Products
Tampilkan:
- nama produk
- category
- brand
- price
- stock
- availability
- search dan filter ringkas

### 15. Master Data > Categories / Brands / Promos
Tampilkan:
- daftar master
- status aktif
- field paling penting saja
- action create/edit dengan dialog kompak

### 16. Master Data > Customers
Tampilkan:
- nama
- no hp
- poin
- alamat singkat
- email jika ada

### 17. Master Data > Staff
Tampilkan:
- nama
- role
- status aktif
- email
- telepon

### 18. Settings > General
Tampilkan:
- opsi yang benar-benar relevan untuk operasional
- jangan jadikan halaman ini gudang semua toggle tanpa struktur

### 19. Settings > Sync
Tampilkan:
- status sync terakhir
- queue count
- error count
- tombol refresh / retry

### 20. Settings > Device > Device Status
Tampilkan wajib:
- device id saat ini
- register id saat ini
- location id
- staff aktif
- daftar register yang sudah diprovision untuk lokasi ini
- status aktif/nonaktif register
- tombol assign register ke device ini
- tombol create/edit/delete register untuk owner/supervisor
- catatan bahwa register adalah identitas kasir terminal, bukan sekadar device name

Tujuan UI:
- ini adalah halaman operasional provisioning, bukan placeholder
- harus rapi, kompak, dan jelas dipakai owner/supervisor

### 21. Settings > Device > App Update
Tampilkan:
- versi app saat ini
- versi minimum / versi server jika ada
- status update
- catatan kompatibilitas singkat

## Aturan Penamaan Data Di UI
- tampilkan `register_id` sebagai `Register ID`
- tampilkan `device_id` sebagai `Device ID`
- tampilkan `location_id` sebagai `Location`
- gunakan istilah yang stabil dan jangan sering ganti label antar halaman

## Aturan Status Visual
Gunakan badge kecil:
- active: hijau lembut
- inactive: abu netral
- syncing: biru lembut
- error: merah lembut
- draft/parked: ungu atau amber lembut
- paid: hijau kuat tapi tetap kecil

Jangan gunakan background penuh layar untuk status biasa.

## Aturan Dialog Dan Form
- dialog lebar sedang, jangan terlalu besar
- field vertikal rapat tapi tetap nyaman
- tombol aksi utama di kanan bawah
- label field pendek dan jelas
- helper text hanya jika benar-benar membantu

## Aturan Empty State
Empty state harus:
- singkat
- tidak terlalu ramai ilustrasi
- memberi tahu apa yang harus user lakukan berikutnya

Contoh:
- “Belum ada register untuk lokasi ini. Buat register baru terlebih dahulu.”

## Aturan AI Saat Mengedit View
Sebelum mengubah view:
- cek store atau controller yang menyuplai data
- jangan tambahkan query baru ke view
- bila data belum tersedia dari store, buat atau ubah store terlebih dahulu

Saat selesai:
- pastikan view lebih tipis dari sebelumnya
- pastikan teks, padding, dan font tidak membesar tanpa alasan
- pastikan halaman tetap enak di tablet dan tidak terasa sempit di mobile

## Checklist Akhir
- [ ] view hanya presentasi
- [ ] data datang dari store/controller/service
- [ ] ukuran font tidak berlebihan
- [ ] spacing kompak dan konsisten
- [ ] tampilan terasa premium tapi tetap efisien
- [ ] isi halaman sesuai domain bisnisnya
- [ ] tidak ada placeholder palsu untuk halaman penting operasional
