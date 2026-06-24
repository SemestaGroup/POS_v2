# FlinkPOS V2 Backend And SaaS Direction

## Purpose
Dokumen ini menjadi arahan backend untuk FlinkPOS V2, meliputi:
- strategi login SaaS
- pembagian tanggung jawab central database vs tenant database
- perubahan schema tenant yang direkomendasikan
- tabel baru untuk approval, shift, dan attribution POS
- arahan implementasi refund, void, dan discount override

## Current Database Findings

## Core Back Office Tables Already Usable
- `tblinvoices` menyimpan invoice POS dan sudah punya `id_pos`, `sale_agent`, `discount_total`, `discount_type`.
- `tblinvoicepaymentrecords` menyimpan pembayaran invoice.
- `tblcreditnotes` dan `tblcreditnote_refunds` sudah bisa dipakai sebagai basis refund resmi.
- `tblexpenses` sudah punya pola `approved`, `voided`, dan `reason_for_void`.
- `tblstaff` sudah bisa menjadi sumber identitas user POS tenant.

## Current POS-Specific Tables
- `tblcustom_pos_options` cocok untuk policy JSON dan setting POS.
- `tblcustom_pos_shift_logs` sekarang masih berbentuk snapshot JSON recap, bukan session table relasional.
- `tblcustom_pos_products`, `tblcustom_pos_categories`, `tblcustom_pos_customers`, dan lain-lain tetap relevan sebagai lapisan POS.

## Weak Points In Current Model
1. `tblinvoices.sale_agent` ada, tetapi perlu dipastikan benar-benar menyimpan `tblstaff.staffid` tenant.
2. `tblinvoices.id_pos` dan `tblinvoicepaymentrecords.id_pos` masih `TEXT`, sehingga kurang ideal untuk indexing dan sync matching.
3. `tblcustom_pos_shift_logs` belum cukup relasional untuk analytics, policy, dan approval tracing.
4. belum ada tabel request approval POS.

## Recommended SaaS Login Architecture

## Recommended Final Model
Gunakan pola `central discovery -> tenant authentication`.

### Flow
1. user input email
2. central API mencari tenant yang bisa diakses email tersebut
3. central API mengembalikan `tenant_id`, `location_id`, `base_url`, `role`, dan metadata login
4. aplikasi login ke tenant API menggunakan `email + password` atau `email + pin`
5. tenant mengembalikan sesi kerja POS

## Why This Is Better Than Current Model
Model sekarang cukup untuk login merchant/contact awal, tetapi kurang ideal bila semua staff ingin login dengan email masing-masing.

Kalau hanya pakai tabel `contact` sebagai discovery:
- owner/contact bisa ditemukan
- cashier/supervisor/kitchen belum tentu ada di central contact
- mapping user ke banyak tenant akan cepat berantakan

## Recommended Central Database Changes

### A. New Central Tenant Directory
Tabel ini menjadi sumber tenant discovery.

```sql
CREATE TABLE tblcustom_saas_tenants (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  client_id INT NOT NULL,
  tenant_code VARCHAR(100) NOT NULL,
  tenant_name VARCHAR(191) NOT NULL,
  location_id INT NOT NULL,
  base_url VARCHAR(255) NOT NULL,
  db_name VARCHAR(100) NOT NULL,
  db_host VARCHAR(191) NULL,
  db_port INT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tenant_code (tenant_code),
  UNIQUE KEY uq_location_id (location_id),
  KEY idx_client_id (client_id)
);
```

### B. New Central User-To-Tenant Registry
Tabel ini menjadi jembatan agar semua user dengan email sendiri bisa login.

```sql
CREATE TABLE tblcustom_saas_user_tenants (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(191) NOT NULL,
  normalized_email VARCHAR(191) NOT NULL,
  tenant_id BIGINT NOT NULL,
  tenant_staff_id INT NULL,
  tenant_contact_id INT NULL,
  user_source ENUM('staff','contact') NOT NULL,
  role_code ENUM('owner','supervisor','cashier','kitchen','programmer') NOT NULL,
  can_pos_login TINYINT(1) NOT NULL DEFAULT 1,
  is_default TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  last_synced_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_normalized_email (normalized_email),
  KEY idx_tenant_id (tenant_id),
  KEY idx_staff_id (tenant_staff_id)
);
```

## If You Want Minimal Change First
Kalau belum mau tabel central baru penuh, minimal:
- tambahkan `base_url` dan `location_id` ke table pusat yang memetakan tenant
- tetap buat `tblcustom_saas_user_tenants`

Karena discovery berdasarkan email tanpa registry khusus akan cepat mentok saat user POS bertambah banyak.

## Recommended Tenant Database Changes

## 1. Normalize POS Invoice Attribution

### Recommended Changes
```sql
ALTER TABLE tblinvoices
  MODIFY COLUMN id_pos VARCHAR(191) NULL,
  ADD KEY idx_id_pos (id_pos);

ALTER TABLE tblinvoicepaymentrecords
  MODIFY COLUMN id_pos VARCHAR(191) NULL,
  ADD KEY idx_id_pos (id_pos);
```

### Operational Rule
- `tblinvoices.sale_agent` wajib menyimpan `tblstaff.staffid` tenant untuk transaksi POS.
- `tblinvoices.addedfrom` boleh tetap dipakai sesuai aturan back office, tetapi jangan dipakai sebagai sumber analytics kasir.

## 2. Add Invoice Meta Companion Table
Supaya relasi invoice POS tidak bergantung hanya pada `sale_agent`.

```sql
CREATE TABLE tblcustom_pos_invoice_meta (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  invoice_id INT NOT NULL,
  id_pos VARCHAR(191) NOT NULL,
  location_id INT NOT NULL,
  pos_staff_id INT NULL,
  pos_staff_name_snapshot VARCHAR(191) NULL,
  shift_session_id BIGINT NULL,
  device_id VARCHAR(191) NULL,
  source_channel ENUM('pos','web','api') NOT NULL DEFAULT 'pos',
  approval_request_id BIGINT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_invoice_id (invoice_id),
  KEY idx_id_pos (id_pos),
  KEY idx_pos_staff_id (pos_staff_id),
  KEY idx_shift_session_id (shift_session_id)
);
```

## 3. Replace Summary-Only Shift Storage With Relational Sessions

```sql
CREATE TABLE tblcustom_pos_shift_sessions (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  location_id INT NOT NULL,
  pos_staff_id INT NOT NULL,
  pos_staff_name_snapshot VARCHAR(191) NOT NULL,
  shift_name VARCHAR(100) NOT NULL,
  opened_at DATETIME NOT NULL,
  closed_at DATETIME NULL,
  opening_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
  closing_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
  expected_cash DECIMAL(15,2) NOT NULL DEFAULT 0,
  actual_cash DECIMAL(15,2) NOT NULL DEFAULT 0,
  total_non_cash DECIMAL(15,2) NOT NULL DEFAULT 0,
  status ENUM('open','closed','reconciled','cancelled') NOT NULL DEFAULT 'open',
  source_device_id VARCHAR(191) NULL,
  reconciliation_json JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_staff_opened_at (pos_staff_id, opened_at),
  KEY idx_status (status)
);
```

### Note
`tblcustom_pos_shift_logs` jangan langsung dibuang.
- simpan sebagai snapshot history / legacy import
- gunakan `tblcustom_pos_shift_sessions` sebagai sumber utama V2

## 4. Add Approval Queue For POS Governance

```sql
CREATE TABLE tblcustom_pos_approval_requests (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  request_code VARCHAR(50) NOT NULL,
  request_type ENUM(
    'void_unpaid_invoice',
    'refund_paid_invoice',
    'discount_override',
    'expense_void',
    'expense_approval'
  ) NOT NULL,
  reference_type ENUM('invoice','draft','expense','credit_note') NOT NULL,
  reference_id INT NULL,
  reference_number VARCHAR(100) NULL,
  draft_id_pos VARCHAR(191) NULL,
  location_id INT NOT NULL,
  requester_staff_id INT NOT NULL,
  requester_role INT NOT NULL,
  requester_device_id VARCHAR(191) NULL,
  shift_session_id BIGINT NULL,
  reason TEXT NOT NULL,
  requested_payload JSON NULL,
  status ENUM('pending','approved','rejected','expired','applied','cancelled') NOT NULL DEFAULT 'pending',
  approved_by_staff_id INT NULL,
  approved_at DATETIME NULL,
  approval_note TEXT NULL,
  rejection_note TEXT NULL,
  expires_at DATETIME NULL,
  applied_at DATETIME NULL,
  resolved_reference_type ENUM('invoice','credit_note','expense','draft') NULL,
  resolved_reference_id INT NULL,
  resolved_reference_number VARCHAR(100) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_request_code (request_code),
  KEY idx_status_type (status, request_type),
  KEY idx_reference (reference_type, reference_id),
  KEY idx_location_status (location_id, status),
  KEY idx_requester (requester_staff_id)
);
```

```sql
CREATE TABLE tblcustom_pos_approval_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  approval_request_id BIGINT NOT NULL,
  action ENUM('created','approved','rejected','applied','expired','cancelled','sync_failed') NOT NULL,
  actor_staff_id INT NULL,
  actor_source ENUM('pos','web','system') NOT NULL,
  note TEXT NULL,
  payload JSON NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_request_id (approval_request_id)
);
```

## 5. Keep POS Policy In Options Table
Tidak perlu tabel policy baru dulu. Simpan dalam `tblcustom_pos_options`.

### New Option Keys
- `pos_role_matrix`
- `pos_approval_policy`
- `pos_discount_policy`
- `pos_refund_policy`

### Example `pos_approval_policy`
```json
{
  "void_unpaid_invoice": {
    "required_role": 4,
    "channel": "pos_or_web",
    "require_reason": true
  },
  "refund_paid_invoice": {
    "required_role": 4,
    "channel": "web_backoffice",
    "require_reason": true
  },
  "discount_override": {
    "required_role": 4,
    "channel": "pos_preferred",
    "cashier_max_manual_discount_percent": 0,
    "approval_ttl_minutes": 5
  }
}
```

## Recommended Operational Rules

## 1. Refund
- `paid invoice refund` sebaiknya diproses melalui web back office supervisor
- hasil akhirnya membuat `tblcreditnotes` dan `tblcreditnote_refunds`
- POS hanya membuat request dan sinkron keputusan

## 2. Void
- `paid invoice` jangan diperlakukan sebagai void biasa
- perlakukan sebagai refund / credit note
- `unpaid invoice` masih bisa diberi jalur supervisor approval

## 3. Discount Override
- kasir tidak boleh override langsung
- supervisor menjadi approval layer
- jalur paling baik secara operasional adalah `POS approval atau web fallback`

## SaaS Login Recommendation

## Option A: Current-Style Discovery
Flow:
- user input email
- central cek email ke contact pusat
- jika ketemu, ambil `location_id` dan `base_url`
- tenant login jalan setelah itu

### Pros
- paling dekat dengan sistem sekarang
- cepat dibuat

### Cons
- tidak cocok untuk semua staff POS
- cashier/supervisor tenant belum tentu terdaftar sebagai central contact
- sulit dipakai jika satu email punya banyak tenant/role

## Option B: Recommended Discovery Registry
Flow:
- central lookup ke `tblcustom_saas_user_tenants`
- dapatkan tenant list by email
- pilih tenant bila lebih dari satu
- tenant login pakai password/pin

### Pros
- cocok untuk seluruh role POS
- lebih scalable untuk SaaS
- lebih rapi untuk audit dan provisioning

### Recommendation
Pakai `Option B` sebagai target akhir.
Kalau perlu cepat, boleh mulai dari `Option A`, tapi desain endpoint discovery tetap disiapkan seperti `Option B` supaya migrasi halus.

## Backend Flow Recommendation

## Login Flow
1. app hit central `POST /pos-auth/discover`
2. central balas tenant list
3. app hit tenant `POST /pos-auth/login`
4. tenant balas session + policy + role
5. app pull `GET /pos-bootstrap`

## Approval Flow
1. cashier membuat request approval dari POS
2. request masuk ke `tblcustom_pos_approval_requests`
3. web back office SPV membaca inbox pending
4. SPV approve atau reject
5. bila approve refund, backend membuat `tblcreditnotes` dan `tblcreditnote_refunds`
6. POS sync dan menampilkan hasil keputusan

## Suggested Migration Order

### Phase 1
- buat central discovery registry
- normalisasi `id_pos`
- pastikan `sale_agent` terisi `tblstaff.staffid`

### Phase 2
- buat `tblcustom_pos_invoice_meta`
- buat `tblcustom_pos_shift_sessions`
- buat `tblcustom_pos_approval_requests`
- buat `tblcustom_pos_approval_logs`

### Phase 3
- web inbox approval supervisor
- POS sync approval status
- policy JSON di `tblcustom_pos_options`

### Phase 4
- analytics per kasir
- activity logs
- attendance / session extension

## Final Recommendation
- jangan bongkar total tabel core back office yang sudah ada
- tambahkan lapisan `tblcustom_pos_*` untuk governance dan attribution
- gunakan central discovery registry agar semua user bisa login dengan email masing-masing
- refund final tetap diproses di back office tenant
- approval jadi first-class feature, bukan hanya side effect dari update invoice
