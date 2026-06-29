# FlinkPOS V2 API Documentation

## Overview
Dokumen ini adalah rancangan API V2 untuk FlinkPOS dengan model SaaS:
- ada `central discovery/auth layer`
- ada `tenant operational API`
- transaksi keuangan tetap dicatat di database tenant
- approval supervisor dipusatkan di back office tenant

Dokumen ini tidak menggantikan seluruh endpoint lama, tetapi menjadi arah baru untuk endpoint yang perlu dipertahankan, diperbaiki, atau ditambahkan.

## Base URLs

### Central API
Dipakai untuk menemukan tenant berdasarkan email dan, bila diinginkan nanti, mengelola sesi lintas tenant.

Example:
`https://core.flinkaja.com/api`

### Tenant API
Dipakai untuk operasi POS setelah tenant ditemukan.

Example:
`https://tenant-domain.example.com/api`

`base_url` tenant didapat dari endpoint central discovery.

## Standard Response Envelope

### Success
```json
{
  "status": true,
  "message": "Success",
  "data": {}
}
```

### Error
```json
{
  "status": false,
  "message": "Validation failed",
  "errors": {
    "email": [
      "Email is required"
    ]
  }
}
```

## Authentication Strategy

### Recommended Flow
1. user memasukkan email
2. central API mencari tenant yang memiliki akses untuk email tersebut
3. central API mengembalikan `base_url`, `location_id`, dan opsi tenant bila ada lebih dari satu
4. aplikasi melakukan login ke tenant API menggunakan `email + password` atau `email + pin`
5. tenant API mengembalikan session POS, role, policy, dan bootstrap awal

### Why This Flow
- tidak perlu hardcode tenant di aplikasi
- tetap cocok dengan model SaaS
- bisa mendukung owner, supervisor, cashier, kitchen, dan programmer login dengan email masing-masing
- lebih aman dibanding membebankan semua validasi login ke central database

## Existing V1 Endpoints To Keep
Endpoint lama yang masih layak dipakai dan cukup dipertahankan dengan perbaikan kecil:
- `pos_brands`
- `pos_categories`
- `pos_items`
- `pos_customers`
- `pos_order`
- `pos_transaction`
- `pos_options`
- `pos_payment_modes`
- `pos_staff`
- `pos_shift_logs`
- `credit_notes`
- `pos_promotions`
- `pos_expenses`

## New And Revised Endpoints

## 1. Central Discovery

### `POST /pos-auth/discover`
Mencari tenant yang bisa diakses oleh email tersebut.

### Request
```json
{
  "email": "cashier1@brand.com",
  "app_id": "flinkpos_v2",
  "device_id": "POS-ANDROID-01"
}
```

### Success Response
```json
{
  "status": true,
  "message": "Tenant discovered",
  "data": {
    "email": "cashier1@brand.com",
    "tenants": [
      {
        "tenant_id": 18,
        "tenant_code": "xieininebatam",
        "tenant_name": "Xie Xie Ice Cream X Nine Chicken Batam",
        "location_id": 1073,
        "base_url": "https://batam.example.com/",
        "user_type": "staff",
        "role_code": "cashier",
        "can_pos_login": true,
        "is_default": true
      }
    ]
  }
}
```

### Function
- mencocokkan email ke central user-tenant registry
- mengembalikan tenant mana saja yang bisa diakses user
- menjadi langkah awal sebelum password/pin diverifikasi di tenant

## 2. Tenant Login

### `POST /pos-auth/login`
Login user di tenant yang sudah ditemukan.

### Request
```json
{
  "email": "cashier1@brand.com",
  "password": "secret123",
  "device_id": "POS-ANDROID-01",
  "app_version": "2.0.0",
  "platform": "android"
}
```

### Success Response
```json
{
  "status": true,
  "message": "Login successful",
  "data": {
    "location_id": 1073,
    "tenant_name": "Xie Xie Ice Cream X Nine Chicken Batam",
    "base_url": "https://batam.example.com/",
    "auth_token": "tenant-session-token",
    "staff": {
      "staff_id": 7,
      "full_name": "Alfan -",
      "email": "alfan.notreal@email.com",
      "role_code": "cashier",
      "role_id": 2,
      "active": true
    },
    "policies": {
      "approval": {
        "discount_override": "supervisor",
        "refund_paid_invoice": "web_backoffice",
        "void_unpaid_invoice": "supervisor"
      }
    }
  }
}
```

### Function
- memverifikasi password terhadap tenant user
- mengembalikan identitas staff aktif
- mengembalikan policy inti agar aplikasi bisa bekerja offline-first

## 3. Tenant PIN Unlock / Switch User

### `POST /pos-auth/pin-login`
Masuk cepat dengan PIN setelah tenant sudah diketahui.

### Request
```json
{
  "email": "cashier1@brand.com",
  "pin": "7777",
  "device_id": "POS-ANDROID-01"
}
```

### Success Response
```json
{
  "status": true,
  "message": "PIN login successful",
  "data": {
    "staff_id": 7,
    "full_name": "Alfan -",
    "role_code": "cashier",
    "auth_token": "tenant-session-token"
  }
}
```

## 4. POS Bootstrap

### `GET /pos-bootstrap`
Mengambil bootstrap awal setelah login.

### Success Response
```json
{
  "status": true,
  "message": "Bootstrap loaded",
  "data": {
    "tenant": {
      "location_id": 1073,
      "tenant_name": "Xie Xie Ice Cream X Nine Chicken Batam"
    },
    "options": {
      "version": "2.0.0",
      "pos_app_settings": {},
      "approval_policy": {},
      "discount_policy": {}
    },
    "payment_modes": [],
    "order_types": [],
    "staff_profile": {}
  }
}
```

## 5. POS Policies

### `GET /pos-policies`
Mengambil role matrix, approval policy, dan batas operasional.

### Success Response
```json
{
  "status": true,
  "message": "Policies loaded",
  "data": {
    "role_matrix": {
      "cashier": ["sales.pos", "sales.orders", "operations.shift"],
      "supervisor": ["overview", "sales", "operations", "reports", "master_data"],
      "owner": ["overview", "sales", "operations", "reports", "master_data", "settings"]
    },
    "approval_policy": {
      "discount_override": {
        "required_role": "supervisor",
        "channel": "pos_preferred"
      },
      "refund_paid_invoice": {
        "required_role": "supervisor",
        "channel": "web_backoffice"
      },
      "void_unpaid_invoice": {
        "required_role": "supervisor",
        "channel": "pos_or_web"
      }
    }
  }
}
```

## 6. Shift Sessions

### `POST /pos-shift-sessions/open`
Membuka shift aktif.

### Request
```json
{
  "staff_id": 7,
  "shift_name": "Shift 1",
  "opening_balance": 1000000,
  "device_id": "POS-ANDROID-01",
  "opened_at": "2026-06-06 09:46:33"
}
```

### Response
```json
{
  "status": true,
  "message": "Shift opened",
  "data": {
    "shift_session_id": 88,
    "status": "open"
  }
}
```

### `POST /pos-shift-sessions/{id}/close`
Menutup shift dan menyimpan recap final.

### Request
```json
{
  "closed_at": "2026-06-06 15:02:11",
  "actual_cash": 1345000,
  "reconciliation_json": {
    "payment_modes": [],
    "order_types": [],
    "products_sold": []
  }
}
```

## 7. Approval Requests

### `POST /pos-approval-requests`
Membuat request approval dari POS.

### Request
```json
{
  "request_type": "refund_paid_invoice",
  "reference_type": "invoice",
  "reference_id": 455,
  "reference_number": "POS-000455",
  "location_id": 1073,
  "requester_staff_id": 7,
  "requester_role": "cashier",
  "requester_device_id": "POS-ANDROID-01",
  "shift_session_id": 88,
  "reason": "Customer received wrong item",
  "requested_payload": {
    "refund_mode": "partial",
    "refund_amount": 10000,
    "items": [
      {
        "invoice_item_id": 912,
        "product_name": "Smookey Blaze",
        "qty": 1,
        "amount": 10000
      }
    ]
  }
}
```

### Response
```json
{
  "status": true,
  "message": "Approval request created",
  "data": {
    "approval_request_id": 9001,
    "request_code": "APR-20260606-0001",
    "approval_status": "pending"
  }
}
```

### `GET /pos-approval-requests/sync?device_id=POS-ANDROID-01&updated_since=2026-06-06%2010:00:00`
Sinkron status approval ke aplikasi POS.

### Response
```json
{
  "status": true,
  "message": "Approval sync loaded",
  "data": [
    {
      "approval_request_id": 9001,
      "status": "approved",
      "resolved_reference_type": "credit_note",
      "resolved_reference_id": 12,
      "resolved_reference_number": "CN-000012",
      "updated_at": "2026-06-06 10:18:40"
    }
  ]
}
```

## 8. Back Office Approval Inbox

### `GET /backoffice/pos-approval-requests`
Daftar request approval untuk supervisor/owner di web back office.

### Query Example
`?status=pending&request_type=refund_paid_invoice&location_id=1073`

### Response
```json
{
  "status": true,
  "message": "Success",
  "data": [
    {
      "approval_request_id": 9001,
      "request_code": "APR-20260606-0001",
      "request_type": "refund_paid_invoice",
      "reference_number": "POS-000455",
      "requester_staff_id": 7,
      "requester_name": "Alfan -",
      "reason": "Customer received wrong item",
      "status": "pending",
      "created_at": "2026-06-06 10:15:00"
    }
  ]
}
```

### `POST /backoffice/pos-approval-requests/{id}/approve`

### Request
```json
{
  "approver_staff_id": 4,
  "approval_note": "Approved after verification"
}
```

### Response
```json
{
  "status": true,
  "message": "Approval approved",
  "data": {
    "approval_request_id": 9001,
    "approval_status": "applied",
    "resolved_reference_type": "credit_note",
    "resolved_reference_id": 12,
    "resolved_reference_number": "CN-000012"
  }
}
```

### `POST /backoffice/pos-approval-requests/{id}/reject`

### Request
```json
{
  "approver_staff_id": 4,
  "rejection_note": "Reason is not valid"
}
```

### Response
```json
{
  "status": true,
  "message": "Approval rejected",
  "data": {
    "approval_request_id": 9001,
    "approval_status": "rejected"
  }
}
```

## 9. Staff

### `GET /pos-staff`
Mengambil daftar staff POS dengan envelope V2 konsisten.

### `POST /pos-staff`
Membuat staff POS baru.

### Request
```json
{
  "firstname": "Alfan",
  "lastname": "Rahman",
  "email": "alfan@example.com",
  "password": "secret-123",
  "pin": "1234",
  "phonenumber": "6281234567890",
  "role_code": "cashier",
  "active": true
}
```

### `PUT /pos-staff/{id}`
Mengupdate data staff POS. `password` opsional; jika tidak dikirim, password lama tetap dipakai.

### `DELETE /pos-staff/{id}`
Menonaktifkan staff POS secara aman. Endpoint ini melakukan deactivation, bukan hard delete.

## 10. Staff Profile

### `GET /pos-staff/me`
Mengambil profil user aktif.

### Response
```json
{
  "status": true,
  "message": "Success",
  "data": {
    "staff_id": 7,
    "firstname": "Alfan",
    "lastname": "-",
    "email": "alfan.notreal@email.com",
    "phonenumber": "",
    "role_code": "cashier",
    "last_login": "2026-06-06 09:46:00",
    "last_password_change": null
  }
}
```

### `PUT /pos-staff/me`
Update profil dasar user aktif. Karena tenant API saat ini belum memakai auth identity resolver per-user untuk endpoint ini, kirim `staff_id` atau `email` di body sebagai target update.

### Request
```json
{
  "staff_id": 7,
  "firstname": "Alfan",
  "lastname": "Rahman",
  "phonenumber": "6281234567890"
}
```

## 11. Password Change

### `POST /pos-staff/change-password`
Endpoint ini opsional, tetapi direkomendasikan bila nanti POS user ingin mandiri mengganti password.

### Request
```json
{
  "staff_id": 7,
  "old_password": "old-secret",
  "new_password": "new-secret-123",
  "confirm_password": "new-secret-123"
}
```

### Response
```json
{
  "status": true,
  "message": "Password changed successfully",
  "data": {
    "staff_id": 7,
    "changed_at": "2026-06-06 10:30:00"
  }
}
```

## 12. Future Optional Endpoints
Belum wajib di fase awal, tetapi disiapkan arahnya:
- `GET /pos-staff/{id}/performance`
- `POST /pos-activity-logs/bulk`
- `POST /pos-orders/split-payment`
- `GET /pos-table-layout`
- `POST /pos-table-sessions`

## Operational Policy Notes
- `refund_paid_invoice`: sebaiknya approval dan aplikasi final dilakukan dari web back office supervisor.
- `void_paid_invoice`: jangan diperlakukan sebagai void biasa; lebih aman diproses sebagai refund atau credit note.
- `discount_override`: idealnya supervisor approval; implementasi bisa web atau PIN-based approval tergantung kebijakan akhir.
- `void_unpaid_invoice`: masih bisa dibiarkan sebagai approval supervisor dengan jalur POS atau web.
