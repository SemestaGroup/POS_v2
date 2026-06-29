# API V2 Response Map

Scope: `back_end_web_office/config/routes.php`, `back_end_web_office/controllers/v2/*`, related v2 models, and the existing notes under `back_end_web_office/`.

## Baseline Envelope

Most normalized v2 endpoints use:

```json
{
  "status": true,
  "message": "Success",
  "data": {}
}
```

Validation and business errors usually use:

```json
{
  "status": false,
  "message": "Validation failed",
  "errors": {
    "field": ["..."]
  }
}
```

`meta` is optional and only appears on some list/report endpoints.

## Cross-Cutting Caveats

- `status` at the top level is transport/result status, not the domain status of an order, payment, shift, device session, or approval request.
- Several `api/v2/*` routes are still legacy wrappers or return legacy top-level keys instead of the normalized `data` envelope.
- Some controllers decode legacy JSON or PHP serialized fields before returning them; some return the raw legacy field as-is.
- Some list endpoints paginate in controller memory after loading the full dataset, not in SQL.
- `GET by id` is inconsistent: some endpoints return a single object in `data`, some still return a one-element array under a legacy key.

## Auth And Bootstrap

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `POST /api/v2/pos-auth/discover` | `data.email`, `data.tenants[]` | `tenant_id`, `tenant_code`, `tenant_name`, `location_id`, `base_url`, `user_type`, `role_code`, `can_pos_login`, `is_default` | Staff and contact flows differ. `tenant_id` is currently `null`. |
| `POST /api/v2/pos-auth/login` | `data` object | `location_id`, `tenant_name`, `base_url`, `auth_token`, `staff{staff_id,full_name,email,role_code,role_id,active}`, `device_session`, `policies{approval,device_session}` | Staff login creates or updates device session. Contact login proxies legacy `/api/pos_auth/data` and does not return `device_session`. |
| `POST /api/v2/pos-auth/pin-login` | `data` object | Same core fields as password login, but `policies` only includes `device_session` | `location_id` is returned as `null` in the current controller. |
| `GET /api/v2/pos-auth/session` | `data` object | Sanitized device session | Looks up by `session_code`, `staff_id + device_id`, or `session_id`. |
| `POST /api/v2/pos-auth/logout` | `data` object | Sanitized device session after status change | Status becomes `logged_out`. |
| `POST /api/v2/pos-auth/session-touch` | `data` object | Sanitized device session after heartbeat | Updates `last_seen_at` and optional `app_version`. |
| `POST /api/v2/pos-auth/force-logout` | `data` object | Sanitized device session after forced close | Requires managerial `acting_staff_id`. Returns `409` on active-device policy conflicts during login flow. |
| `GET /api/v2/pos-bootstrap` | `data` object | `tenant`, `options`, `payment_modes[]`, `order_types[]`, `staff_profile`, `active_device_session` | Good bootstrap endpoint for session + policy + POS runtime state. `tenant.location_id` is currently `null`. |

## Options And Policies

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-options` | `data` is a flat option map | Option key to raw string value map | `meta.count` only. Values may still be raw strings even when they contain JSON. Supports `name` and `names` filters. |
| `PUT /api/v2/pos-options` | `data` is the updated option subset | Same option key map | Arrays are stored server-side as JSON strings. New keys prefixed with `pos_` are auto-created with `autoload = 1`. |
| `GET /api/v2/pos-policies` | `data` object | `role_matrix`, `approval_policy`, `discount_policy`, `refund_policy` | This endpoint returns parsed JSON policy bundles, unlike `pos-options`, which returns raw option strings. |

## Reference And Master Data

### Brands

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-brands` | `{status, brands:[...]}` | Rows from `tblitems_groups`; typically `id`, `name`, `commodity_group_code`, `display` | Legacy envelope, not normalized `data`. No `meta`. |
| `GET /api/v2/pos-brands/{id}` | Same as list | Same as list | Still returns `brands:[...]`, not a single object. |
| `GET /api/v2/pos-brands/search/{keyword}` | Same as list | Same as list | Legacy envelope. |
| `POST /api/v2/pos-brands` | `{status, message, id}` | Bulk payload accepted as array or object | Current implementation deletes all existing brands then recreates them. Treat as full replace sync, not row-level upsert. |

### Categories

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-categories` | `{status, categories:[...]}` | Legacy fields from `tblcustom_pos_categories`: `commodity_type_id`, `commondity_code`, `commondity_name`, `brand`, `note` | Legacy envelope and legacy field spellings are preserved. No `meta`. |
| `GET /api/v2/pos-categories/{id}` | Same as list | Same as list | Returns an array under `categories`, not a single object. |
| `POST/PUT /api/v2/pos-categories` | `{status, message, data}` | Same legacy fields | `data` may still be an array result from `get_pos_categories($id)`. |

### Items

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-items` | `data:[...]` | Raw `tblcustom_pos_products.*` plus decoded `locations`, `units`, `order_types`, and derived `group_names` | `meta.page`, `meta.item_per_page`, `meta.count`. `brand_id` may still contain comma-separated legacy group ids. |
| `GET /api/v2/pos-items/{id}` | `data:{...}` | Same as list | Good single-object response. |
| `GET /api/v2/pos-items/search/{keyword}` | `data:[...]` | Same as list | `meta.keyword`, `meta.count`. |
| `POST/PUT /api/v2/pos-items` | `data:{...}` | Same as list | Incoming `locations` and `units` arrays are stored as PHP serialized strings. Incoming `order_types` and `children` arrays are stored as JSON strings. |

### Customers

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-customers` | `data:[...]` | Legacy customer projection: `id`, `nama`, `no_hp`, `alamat`, `datecreated`, `value_pts` | `meta.count` only. Response field names are still legacy Indonesian aliases. |
| `GET /api/v2/pos-customers/{id}` | `data:{...}` | Same as list | Single object. |
| `GET /api/v2/pos-customers/search/{keyword}` | `data:[...]` | Search result from `Api_model->search('pos_customers', ...)` | Search shape can drift from `Pos_customers_model->get()` projection. |
| `POST/PUT /api/v2/pos-customers` | `data:{...}` | Same customer projection | Input aliases supported: `company` or `nama`, `phonenumber` or `no_hp`, `address` or `alamat`. |

### Payment Modes, Order Types, Staff

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-payment-modes` | `data:[...]` | Rows from `tblpayment_modes` filtered by `allow_pos = 1` | `meta.count` only. GET by id returns a single object. |
| `POST/PUT/DELETE /api/v2/pos-payment-modes` | `data:{...}` or delete acknowledgement | Standard payment mode fields | `POST` defaults `allow_pos = 1` when omitted. |
| `GET /api/v2/pos-order-types` | `{status, data, message?}` | Legacy `pos_order_types` rows | Inherited V1 controller. Validation errors can appear in `error`, not `errors`. Not fully normalized. |
| `GET /api/v2/pos-staff` | `data:[...]` | `staff_id`, `firstname`, `lastname`, `full_name`, `email`, `phonenumber`, `role`, `role_id`, `role_code`, `active` | `meta.count` only. Response is now normalized. |
| `GET /api/v2/pos-staff/{id}` | `data:{...}` | Same as list row | Returns a single normalized object. |
| `POST /api/v2/pos-staff` | `data:{...}` | Created staff row | Accepts `role`, `role_id`, or `role_code`. Password is hashed server-side. |
| `PUT /api/v2/pos-staff/{id}` | `data:{...}` | Updated staff row | Partial update is supported. Empty password does not overwrite the current password. |
| `DELETE /api/v2/pos-staff/{id}` | `data:{staff_id,active}` | Delete acknowledgement | Staff is deactivated (`active = 0`) instead of hard deleted to preserve relational integrity. Active POS device sessions are force-closed. |
| `GET /api/v2/pos-staff/me` | `{status, data}` | `staffid`, `firstname`, `lastname`, `email`, `phonenumber`, `role`, `last_login`, `last_activity`, `last_password_change` | `staff_id` or `email` is required. Response now follows the same normalized staff row shape. |
| `PUT /api/v2/pos-staff/me` | `data:{...}` | Updated normalized staff row | Only basic profile fields are updated. Current implementation resolves target from `staff_id` or `email` in the request body. |
| `POST /api/v2/pos-staff/change-password` | `{status, message, data}` | `staff_id`, `changed_at` | Returns the standard V2 envelope. |

## Orders, Payments, Reports, Promotions

### Orders

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-order` | `data:[...]` | Legacy invoice rows from `tblinvoices` | `meta.page`, `meta.limit`, `meta.count`, `meta.total`. Filtering and pagination happen in controller memory after loading the full list. |
| `GET /api/v2/pos-order/{id}` | `data:{...}` | Full `Pos_order_model->get()` object | Detail payload is still very legacy: raw invoice fields, nested `items[]`, nested `payments[]`, nested `client`, and serialized strings such as `allowed_payment_modes` / `expedition_id` may still leak through. |
| `GET /api/v2/pos-order/search/{keyword}` | `data:[...]` | Search results | Current controller calls `Api_model->search('pos_transaction', ...)`, so search semantics are inconsistent with order detail/list semantics. |
| `POST /api/v2/pos-order` | `data:{...}` | Saved order object | `id_pos` is the practical remote matching key for offline sync. If `id_pos` already exists server-side, the controller dedupes and updates instead of creating a new invoice. |
| `PUT /api/v2/pos-order/{id}` | `data:{...}` | Saved order object | Partial update merges with existing invoice data so that `allowed_payment_modes`, `items`, and address fields are not dropped. |
| `DELETE /api/v2/pos-order/{id}` | `data:{id,id_pos}` | Delete acknowledgement | Hard delete from the endpoint perspective. Local SQLite should soft-delete first. |

### Transactions / Payments

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-transaction` | `data:[...]` | Rows from `tblinvoicepaymentrecords` filtered to POS payments (`id_pos IS NOT NULL AND id_pos != ''`) | `meta.page`, `meta.limit`, `meta.count`, `meta.total`. Filtering and pagination happen in controller memory after loading all POS payments. |
| `GET /api/v2/pos-transaction/{id}` | `data:{...}` | Payment object with joined payment mode name | Good single-object envelope. |
| `GET /api/v2/pos-transaction/search/{keyword}` | `data:[...]` | Search results | Search shape can differ from `payment_get()` detail/list objects. |
| `POST /api/v2/pos-transaction` | `data:{...}` | Saved payment object | `id_pos` is required for create. Customer point recalculation is a side effect on create/update/delete/convert. |
| `PUT /api/v2/pos-transaction/{id}` | `data:{...}` or `data:[...]` when `?convert=1` | Updated payment or converted payment rows | `convert=1` splits one payment into multiple rows and returns an array plus `meta.convert = true`. |
| `DELETE /api/v2/pos-transaction/{id}` | `data:{id,invoiceid}` | Delete acknowledgement | Also recalculates customer points. |

### Reports

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-reports?type=...` | `data:[...]` | Report-specific legacy rows | `meta.type`, `meta.date_from`, `meta.date_to`, `meta.count`. `data` is not normalized across report types. Treat as cache/snapshot data, not relational source data. |

Supported `type` values:

- `invoices_report`
- `items_report`
- `payments_report`
- `customers_report`

### Promotions

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-promotions` | `data:[...]` | Promotion rows with decoded `brands[]`, `locations[]`, `items[]`, `order_types[]` | `meta.count`, `meta.status`, `meta.id_location`. Default filter is active-only (`status = 1`). |
| `GET /api/v2/pos-promotions/{id}` | `data:{...}` | Same as list | Good single-object response. |

## Shifts, Self-Order, Tables, Devices, Approvals

### Shift Sessions

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-shift-sessions` | `data:[...]` | `id`, `location_id`, `pos_staff_id`, `pos_staff_name_snapshot`, `shift_name`, `opened_at`, `closed_at`, balances, `status`, `source_device_id`, `reconciliation_json` | `meta.page`, `meta.limit`, `meta.count`. `reconciliation_json` is stored as JSON text in the model and is returned raw. |
| `GET /api/v2/pos-shift-sessions/active` | `data:{...}` | Active shift session | Looks up by `pos_staff_id` and optional `device_id`. |
| `GET /api/v2/pos-shift-sessions/history` | `data:[...]` | Recent shift sessions | No `meta`. |
| `POST /api/v2/pos-shift-sessions/open` | `data:{...}` | Opened shift session | Returns `409` when an active shift already exists for the staff/device. |
| `POST /api/v2/pos-shift-sessions/{id}/close` | `data:{...}` | Closed shift session | Incoming `reconciliation_json` array is encoded server-side and returned as raw text. |

### Self-Order Sessions

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-self-order-sessions` | `data:[...]` | Presented session object | `meta.page`, `meta.limit`, `meta.count`. Good normalized response. |
| `GET /api/v2/pos-self-order-sessions/{id}` | `data:{...}` | Presented session object | Uses parsed `metadata_json`. |
| `GET /api/v2/pos-self-order-sessions/resolve` | `data:{...}` | Presented session object | Resolves by `access_token`, `session_code`, `public_code`, or `queue_number + business_date (+ table_code)`. |
| `POST /api/v2/pos-self-order-sessions/open` | `data:{session,qr_payloads}` | Session plus `feedback_url`, `resume_url`, `query` | Returns `409` when self-order mode is disabled by policy. |
| `POST /api/v2/pos-self-order-sessions/{id}/link-order` | `data:{...}` | Presented session object | Links `current_invoice_id`, `current_id_pos`, `queue_number`, `payment_stage`, `status`. |
| `POST /api/v2/pos-self-order-sessions/{id}/close` | `data:{...}` | Presented session object | Appends an event in `tblcustom_pos_self_order_events` as a side effect. |

### Service Tables

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-service-tables/lookup` | `data:{...}` | `id`, `location_id`, `area_name`, `table_code`, `table_name`, `capacity`, `qr_token`, `default_source_channel`, `self_order_enabled`, `entry_url` | Public lookup. Requires `qr_token` or `table_code`. |
| `GET /api/v2/backoffice/pos-service-tables` | `data:[...]` | Same plus `active`, `qr_value`, `print_label`, `notes`, `metadata_json`, timestamps | `meta.page`, `meta.limit`, `meta.count`. Manager-only. |
| `GET /api/v2/backoffice/pos-service-tables/print-kit` | `data:[...]` | Printable table rows | `meta.count` only. Useful for QR print packs. |
| `POST/PUT/DELETE /api/v2/backoffice/pos-service-tables` | `data:{...}` or delete acknowledgement | Same as backoffice read shape | `table_code` is unique per `location_id`. `PUT` can regenerate `qr_token`. |

### Device Sessions

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/backoffice/pos-device-sessions` | `data:[...]` | `id`, `session_code`, `staff_id`, `staff_role_code`, `device_id`, `device_name`, `platform`, `app_version`, `login_method`, `status`, `forced_out_by_staff_id`, `force_reason`, `metadata_json`, timestamps | `meta.page`, `meta.limit`, `meta.count`. Manager-only. |
| `GET /api/v2/backoffice/pos-device-sessions/{id}` | `data:{...}` | Same as list row | Good normalized response. |
| `POST /api/v2/backoffice/pos-device-sessions/{id}/force-close` | `data:{...}` | Same as list row | Manager-only status change. |

### Approval Requests

| Endpoint | Success shape | Key fields | Meta / caveats |
| --- | --- | --- | --- |
| `GET /api/v2/pos-approval-requests` | `data:[...]` | Request rows plus `requester_name`, `approver_name`, decoded `requested_payload` | `meta.page`, `meta.limit`, `meta.count`. Good list envelope. |
| `GET /api/v2/pos-approval-requests/{id}` | `data:{...}` | Same as list row | Good single-object envelope. |
| `POST /api/v2/pos-approval-requests` | `data:{approval_request_id,request_code,approval_status,request}` | New pending request | Supported `request_type`: `void_unpaid_invoice`, `refund_paid_invoice`, `discount_override`, `expense_void`, `expense_approval`. |
| `GET /api/v2/pos-approval-requests/sync` | `data:[...]` | Same request rows | Requires at least one of `updated_since`, `device_id`, or `requester_staff_id`. No `meta`. |
| `GET /api/v2/backoffice/pos-approval-requests` | `data:[...]` | Same request rows | `meta.page`, `meta.limit`, `meta.count`. Manager inbox. |
| `POST /api/v2/backoffice/pos-approval-requests/{id}/approve` | `data:{approval_request_id,approval_status,resolved_reference_type,resolved_reference_id,resolved_reference_number,request}` | Approved request plus resolution info | Approval can apply side effects immediately, for example void invoice or create refund credit note. |
| `POST /api/v2/backoffice/pos-approval-requests/{id}/reject` | `data:{approval_request_id,approval_status,request}` | Rejected request | Manager-only. |

## Practical Parsing Guidance For SQLite

- Treat `brands`, `categories`, `order_types`, and inherited `staff` endpoints as compatibility endpoints, not clean v2 contracts.
- Persist raw option values from `pos-options`, but persist parsed policy bundles from `pos-policies` and `pos-bootstrap` separately.
- Parse legacy arrays once on ingest:
  - `items.locations` -> relation rows
  - `items.order_types` -> relation rows
  - `promotions.brands/items/locations/order_types` -> relation rows or JSON snapshots
- Keep raw payload snapshots for `pos-order`, `pos-transaction`, and other legacy-heavy objects because their detail responses are not fully normalized yet.
