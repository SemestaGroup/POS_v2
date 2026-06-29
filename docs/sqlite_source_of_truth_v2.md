# SQLite Source Of Truth V2

This design treats SQLite as the only local read model for `pos_app_new`. Network payloads are ingested into SQLite first, and the UI reads from SQLite first. HTTP responses are never the primary UI state.

## Core Principles

1. SQLite is the local source of truth.
   The UI reads `SELECT` results from SQLite, not in-memory copies of API payloads.

2. Local writes are optimistic and durable.
   Creating or editing a customer, order, payment, shift, or approval request writes SQLite first, marks the row dirty, and enqueues an outbox command.

3. Business tables and sync tables are separate.
   `pos_order` stores the order. `sync_queue` stores the HTTP work needed to push the order. `sync_checkpoint` stores pull progress.

4. Use local integer keys plus remote text ids.
   Every table gets a local `INTEGER PRIMARY KEY`. Backend ids remain `TEXT` in `remote_id` or `*_remote_id` columns because several endpoints mix numeric ids, string ids, and business keys like `id_pos`, `session_code`, or `request_code`.

5. Normalize query-heavy relationships.
   Do not keep `locations`, `order_types`, promo targets, or multi-brand associations as opaque serialized strings when the UI needs to filter by them offline.

6. Parse legacy server formats at ingest time.
   PHP serialized fields and JSON-string fields are converted once when a sync worker writes SQLite. UI code should not parse PHP serialized strings.

7. Soft delete by default.
   Local deletes become `deleted_at` plus `sync_state = 'dirty_delete'`. Hard deletes only happen during cleanup after the server confirms the delete and no queue dependency remains.

8. Keep raw payload snapshots only where the backend contract is still legacy-heavy.
   Orders, payments, approvals, and item payloads can keep `raw_payload_json` for drift tolerance, but the UI should read normalized columns and child tables.

## Read / Write Flow

1. Login and bootstrap populate `app_tenant`, `app_session`, `staff`, `device_session`, `pos_option`, `policy_snapshot`, `payment_mode`, and `order_type`.
2. Master-data pulls populate reference tables such as `brand`, `category`, `product`, `customer`, `promotion`, and `service_table`.
3. Operational pulls populate `shift_session`, `self_order_session`, `approval_request`, `pos_order`, and `pos_order_payment`.
4. Local mutations update the business row first, set `sync_state`, and insert or update a `sync_queue` row.
5. The sync worker processes `sync_queue`, updates remote ids and statuses, then flips the business row back to `sync_state = 'clean'`.

## Table Groups

### Tenant / session

- `app_tenant`: discovered tenant/location records and per-tenant base URL metadata.
- `app_session`: current and historical app login sessions for the device.
- `device_session`: server-side device lock state from auth and backoffice APIs.

### Reference / master data

- `pos_option`: raw option key/value cache.
- `policy_snapshot`: parsed policy bundles such as approval policy and operating mode.
- `staff`: POS staff cache.
- `payment_mode`: POS-allowed payment modes.
- `order_type`: POS order channels/types.
- `brand`, `category`: normalized local master rows mapped from legacy backend fields.
- `product`: item master row.
- `product_brand`, `product_location`, `product_order_type`: normalized relations for item targeting and filtering.
- `promotion`, `promotion_brand`, `promotion_item`, `promotion_location`, `promotion_order_type`: promo targeting and applicability.
- `customer`: offline customer read model.

### Transactional / order domain

- `pos_order`: local order header, keyed by both local id and `id_pos`.
- `pos_order_item`: order lines, kitchen flags, and snapshots of product data used at sale time.

### Payments / refunds

- `pos_order_payment`: payment rows tied to local orders and/or remote invoice ids.
- `report_cache`: lightweight report snapshots; good for offline report browsing, but not the system of record for order math.

### Shift / operations

- `shift_session`: v2 shift session source of truth.

### Self-order / tables

- `service_table`: QR-enabled service tables.
- `self_order_session`: kiosk, table QR, and web self-order sessions.
- `self_order_event`: append-only event audit for self-order session activity.

### Governance / workflow

- `approval_request`: local approval inbox and request cache.

### Sync metadata

- `sync_queue`: outbox of local mutations waiting to be pushed.
- `sync_checkpoint`: pull cursors and last successful sync markers per endpoint and scope.

### Audit / errors

- `error_log`: local error and sync diagnostics.

## Endpoint To Table Population Map

| Endpoint family | Populate / update | Pull mode | Notes |
| --- | --- | --- | --- |
| `pos-auth/discover` | `app_tenant` | Upsert by `tenant_key` | Cache each discovered tenant candidate; do not clear unseen rows. |
| `pos-auth/login`, `pos-auth/pin-login` | `app_tenant`, `app_session`, `staff`, `device_session`, `policy_snapshot` | Upsert current session only | `device_session` may be absent in the contact-login branch. |
| `pos-auth/session`, `logout`, `session-touch`, `force-logout`, backoffice device-session endpoints | `device_session`, `app_session` | Upsert by `session_code` / remote id | Update session status and `last_seen_at` in-place. |
| `pos-bootstrap` | `app_tenant`, `pos_option`, `policy_snapshot`, `payment_mode`, `order_type`, `staff`, `device_session` | Authoritative partial snapshot | For bootstrap-derived arrays, replace rows in-scope for the active tenant. |
| `pos-options` | `pos_option` | Full or filtered snapshot | When fetched without `name/names`, treat as authoritative for option keys returned by the tenant. |
| `pos-policies` | `policy_snapshot` | Full policy snapshot | Parsed policy JSON goes here even if `pos_option` also stores the raw option string. |
| `pos-staff`, `pos-staff/me` | `staff` | Full pull or targeted upsert | `me` should upsert only the current staff row. |
| `pos-payment-modes` | `payment_mode` | Full snapshot | Replace all POS-visible payment modes for the tenant after a full pull. |
| `pos-order-types` | `order_type` | Full snapshot | Legacy envelope, but local table stays normalized. |
| `pos-brands` | `brand` | Full snapshot | Because POST on the backend is full replace, local sync should also treat brand refresh as full replace for the tenant. |
| `pos-categories` | `category` | Full snapshot | Normalize legacy field names into local `code` and `name`. |
| `pos-items` | `product`, `product_brand`, `product_location`, `product_order_type` | Full snapshot by tenant and filter scope | Upsert header row, then replace its relation rows inside one transaction. Keep raw legacy strings only for round-trip compatibility. |
| `pos-customers` | `customer` | Full snapshot or targeted upsert | Search endpoints should only upsert returned rows; they are not authoritative for deletes. |
| `pos-promotions` | `promotion`, `promotion_brand`, `promotion_item`, `promotion_location`, `promotion_order_type` | Full snapshot for the requested scope | Default server filter is active-only; use explicit scope keys in `sync_checkpoint` when pulling only active promos. |
| `pos-shift-sessions`, `active`, `history`, `open`, `close` | `shift_session` | Rolling operational snapshot | `open` and `close` are local-write endpoints; lists and active lookups are inbound refreshes. |
| `pos-service-tables/lookup`, backoffice service-table endpoints | `service_table` | Public lookup is targeted upsert, backoffice list is authoritative for the requested scope | `print-kit` can refresh derived `entry_url` and `print_label` fields, but it should not delete unseen rows. |
| `pos-self-order-sessions`, `resolve`, `open`, `link-order`, `close` | `self_order_session`, `self_order_event` | Rolling operational snapshot | `open`, `link-order`, and `close` should also append local `self_order_event` rows. |
| `pos-order` | `pos_order`, `pos_order_item` | Rolling transactional snapshot | Detail endpoint is the only reliable source for line items. Use `id_pos` as the durable local business key. |
| `pos-transaction` | `pos_order_payment` and derived payment totals on `pos_order` | Rolling transactional snapshot | Payment rows should upsert independently of the order header. |
| `pos-approval-requests`, `sync`, backoffice approve/reject | `approval_request` | Rolling operational snapshot | `sync` is ideal for targeted refresh by `updated_since`, device, or requester. |
| `pos-reports` | `report_cache` | Cache only | Reports are read-only snapshots, not authoritative relational data. |

## Upsert Strategy

### General rule

- Use `INSERT ... ON CONFLICT ... DO UPDATE` keyed by `(tenant_id, remote_id)` whenever the endpoint returns a stable remote id.
- When the endpoint returns a business key instead of a stable numeric id, upsert by the business key:
  - `pos_order` by `(tenant_id, id_pos)` first, then attach `remote_id` when known.
  - `device_session` by `(tenant_id, session_code)`.
  - `self_order_session` by `(tenant_id, session_code)` or `access_token`.
  - `approval_request` by `(tenant_id, request_code)`.
  - `pos_option` by `(tenant_id, option_name)`.

### Parent / child replacement rule

- For relations derived from one parent payload, replace the child rows in the same transaction after the parent upsert:
  - `product_brand`
  - `product_location`
  - `product_order_type`
  - `promotion_brand`
  - `promotion_item`
  - `promotion_location`
  - `promotion_order_type`
  - `pos_order_item` when the authoritative order detail payload is pulled

This is simpler and safer than per-row diffing because those arrays arrive as whole embedded lists from the API.

### Snapshot scope rule

- Only apply delete reconciliation when the app knows the response is authoritative for a scope.
- Store that scope in `sync_checkpoint.scope_key`, for example:
  - `brands:all`
  - `categories:all`
  - `products:location=3,status=active`
  - `promotions:location=3,status=1`
  - `service_tables:location=3`

## Soft Delete Strategy

1. Reference/master tables
   After a successful authoritative full pull, mark previously-seen rows that are now absent as `deleted_at = now` and `sync_state = 'clean'`.

2. Transactional tables
   Do not delete unseen orders, payments, shifts, approvals, or self-order sessions just because they were absent from a paged or filtered pull.

3. Local deletes
   Set `deleted_at`, mark `sync_state = 'dirty_delete'`, queue the DELETE, and hide the row from normal UI queries immediately.

4. Child relation tables
   Hard replace is fine because they are deterministic derivatives of the parent payload.

## Dirty Flags And `sync_queue`

Use these `sync_state` values on mutable business tables:

- `clean`: local row matches the last accepted server version.
- `dirty_create`: row was created locally and does not have a confirmed remote id yet.
- `dirty_update`: row was edited locally after the last server sync.
- `dirty_delete`: row was deleted locally and still needs a remote delete.
- `syncing`: a queue worker is actively pushing the latest mutation.
- `error`: the last sync attempt failed.
- `conflict`: remote change and local unsynced change both exist and need user or policy resolution.

Recommended `sync_queue` behavior:

1. One queue row per outbound command.
2. Include `entity_type`, `entity_local_id`, `entity_remote_id`, `endpoint`, `method`, and `request_body_json`.
3. Use `dedupe_key` for idempotent updates such as repeated option writes.
4. Use dependency columns for parent/child ordering:
   - customer create before order create that references the customer
   - order create before payment create that references the order
   - self-order session create before order link
5. Capture `response_code`, `response_body_json`, `retry_count`, `next_retry_at`, and `last_error` for supportability.

## Conflict Resolution Guidance

### Server-wins domains

- `brand`, `category`, `payment_mode`, `order_type`, `policy_snapshot`, `service_table` when edited only from backoffice
- If a local row in these domains is not dirty, remote payload overwrites it.

### Local-wins-until-acked domains

- `customer`
- `pos_order`
- `pos_order_item`
- `pos_order_payment`
- `shift_session`
- `self_order_session`
- `approval_request`

Rule: if a row is locally dirty, do not let a background pull overwrite the local edit. Merge the remote refresh into `raw_payload_json`, keep the dirty local columns, and either:

- clear the dirty state after the queued write succeeds, or
- mark `sync_state = 'conflict'` if the server changed the same business fields.

### Practical order/payment rule

- `id_pos` is the durable local order identity.
- While there is any pending payment or order queue item for that `id_pos`, do not let inbound order pulls overwrite order status or totals for that local order.
- After the queue is acknowledged and remote ids are known, update the order with the authoritative remote invoice id and payment rows.

## Handling Legacy Serialized / JSON Fields

| Backend field | Current backend behavior | SQLite recommendation |
| --- | --- | --- |
| `items.locations` | Stored in MySQL as PHP serialized text, decoded on some responses | Parse into `product_location`; keep `legacy_locations_raw` on `product` only for round-trip/debugging. |
| `items.units` | Stored as PHP serialized text | Keep as `product.units_json` unless the app needs relational unit queries later. |
| `items.order_types` | Stored as JSON string | Parse into `product_order_type`; optionally keep raw in `raw_payload_json`. |
| `items.children` | Stored as JSON string | Keep as `product.children_json` in v2 first pass. |
| `items.brand_id` | May be a comma-separated legacy group-id list | Normalize into `product_brand`, keep original string in `legacy_brand_ids_raw`. |
| `orders.allowed_payment_modes` | Stored as PHP serialized text on the server | Store parsed JSON text in `pos_order.allowed_payment_modes_json`. |
| `orders.expedition_id` | Stored as PHP serialized text on the server | Store parsed JSON text in `pos_order.raw_payload_json` or add a dedicated column only if the app starts using it offline. |
| `promotions.brands/items/locations/order_types` | Stored as JSON strings and decoded by the model | Write to join tables and keep raw payload on `promotion`. |
| `shift_session.reconciliation_json` | Stored as JSON string | Keep as JSON text column. Do not break into child tables until a real offline reconciliation UI needs it. |
| `approval_request.requested_payload` | Stored as JSON string and decoded by the model | Keep as JSON text column in SQLite. |
| `pos-options` values | Can be plain text, bool-like strings, or JSON strings | Store both raw text and parsed JSON form in `pos_option`. |

## Source Of Truth Policy For The UI

- Product list, customer list, order history, active cart recovery, self-order inbox, shift state, and approval inbox should all query SQLite first.
- Network refreshes update SQLite, then the UI reacts to changed rows.
- Temporary view state such as filters, selected tabs, and loading spinners should stay outside the source-of-truth tables.
- `report_cache` is cache-only. The UI may read it first, but should label it with generated time and allow manual refresh.

## Why This Is Better Than The Current `DatabaseService` Schema

The current local schema in `pos_app_new/lib/core/services/local/database_service.dart` is workable for v1, but it is not a strong source-of-truth layout for v2.

### Current legacy characteristics

- `products`, `members`, `transactions`, `transaction_details`, and `pos_payments` are mostly denormalized.
- Sync state is mostly just `is_synced`, which is not enough to represent create/update/delete/error/conflict separately.
- `products.order_types`, `products.children`, `pos_promotions.brands`, `pos_promotions.locations`, and `pos_promotions.items` are stored as opaque text blobs.
- `user_session` is a singleton row and does not model discovered tenants, device sessions, or session history.
- There is no first-class local table for device sessions, self-order sessions, service tables, or approval requests.
- `sync_queue` is useful, but it mixes transport data without a matching checkpoint table or structured dependency fields.

### Why the v2 layout is recommended

- The UI can filter products by location, brand, and order type without reparsing blobs on every read.
- Orders, payments, shifts, self-order sessions, and approvals each get their own explicit sync state and timestamps.
- Device-lock and self-order flows already exist in backend v2; the local schema should model them directly instead of forcing them into unrelated tables.
- `sync_checkpoint` allows repeatable incremental pull behavior, even when current endpoints are still partly page-based.
- `policy_snapshot` separates parsed runtime policy from raw option storage, which matches how `pos-bootstrap` and `pos-policies` actually behave.

In short: the legacy schema is a convenient cache. The v2 schema should be a durable local database that can safely drive the app offline, survive restarts, and absorb the still-inconsistent backend contracts.
