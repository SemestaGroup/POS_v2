-- SQLite source-of-truth schema for POS API v2.
--
-- Notes:
-- - Use INTEGER local primary keys for sqflite joins.
-- - Keep backend ids and business keys in TEXT columns (`remote_id`, `id_pos`,
--   `session_code`, `request_code`, etc.) because backend responses mix numeric
--   ids, strings, and legacy keys.
-- - Monetary columns below are stored as INTEGER minor units. If the tenant
--   currency has no decimals (for example IDR), the API adapter can map server
--   totals directly into these fields.

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- Tenant and session
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS app_tenant (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_key TEXT NOT NULL UNIQUE,
  tenant_remote_id TEXT,
  tenant_code TEXT,
  tenant_name TEXT,
  location_id TEXT NOT NULL DEFAULT '',
  base_url TEXT NOT NULL,
  user_type TEXT,
  role_code TEXT,
  can_pos_login INTEGER NOT NULL DEFAULT 1,
  is_default INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  catalog_owner TEXT,
  created_at TEXT,
  updated_at TEXT,
  last_bootstrap_at TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_app_tenant_base_url_location
  ON app_tenant(base_url, location_id);

CREATE TABLE IF NOT EXISTS staff (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  role_remote_id TEXT,
  role_code TEXT,
  role_name TEXT,
  first_name TEXT,
  last_name TEXT,
  full_name TEXT,
  email TEXT,
  phone_number TEXT,
  pin_hash TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  last_login_at TEXT,
  last_activity_at TEXT,
  last_password_change_at TEXT,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_staff_email
  ON staff(tenant_id, email);

CREATE INDEX IF NOT EXISTS idx_staff_role_active
  ON staff(tenant_id, role_code, is_active);

CREATE TABLE IF NOT EXISTS device_session (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  staff_id INTEGER,
  forced_out_by_staff_id INTEGER,
  remote_id TEXT,
  session_code TEXT,
  staff_remote_id TEXT,
  staff_role_code TEXT,
  device_id TEXT,
  device_name TEXT,
  platform TEXT,
  app_version TEXT,
  login_method TEXT,
  status TEXT,
  auth_token_snapshot TEXT,
  forced_out_by_staff_remote_id TEXT,
  force_reason TEXT,
  metadata_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  last_seen_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  UNIQUE(tenant_id, session_code),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE SET NULL,
  FOREIGN KEY (forced_out_by_staff_id) REFERENCES staff(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_device_session_staff_status
  ON device_session(tenant_id, staff_remote_id, status);

CREATE INDEX IF NOT EXISTS idx_device_session_device_status
  ON device_session(tenant_id, device_id, status);

CREATE TABLE IF NOT EXISTS shift_session (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  location_id TEXT,
  pos_staff_id INTEGER,
  pos_staff_remote_id TEXT,
  pos_staff_name_snapshot TEXT,
  shift_name TEXT,
  source_device_session_id INTEGER,
  source_device_id TEXT,
  business_date TEXT,
  opened_at TEXT,
  closed_at TEXT,
  opening_balance INTEGER NOT NULL DEFAULT 0,
  closing_balance INTEGER NOT NULL DEFAULT 0,
  expected_cash INTEGER NOT NULL DEFAULT 0,
  actual_cash INTEGER NOT NULL DEFAULT 0,
  total_non_cash INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'open',
  note TEXT,
  reconciliation_json TEXT,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  dirty_fields_json TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (pos_staff_id) REFERENCES staff(id) ON DELETE SET NULL,
  FOREIGN KEY (source_device_session_id) REFERENCES device_session(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_shift_session_status_opened
  ON shift_session(tenant_id, status, opened_at);

CREATE INDEX IF NOT EXISTS idx_shift_session_staff_status
  ON shift_session(tenant_id, pos_staff_remote_id, status);

CREATE INDEX IF NOT EXISTS idx_shift_session_device
  ON shift_session(tenant_id, source_device_id, status);

CREATE TABLE IF NOT EXISTS service_table (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  location_id TEXT NOT NULL,
  area_name TEXT,
  table_code TEXT NOT NULL,
  table_name TEXT NOT NULL,
  capacity INTEGER NOT NULL DEFAULT 0,
  qr_token TEXT,
  default_source_channel TEXT,
  self_order_enabled INTEGER NOT NULL DEFAULT 1,
  is_active INTEGER NOT NULL DEFAULT 1,
  entry_url TEXT,
  notes TEXT,
  metadata_json TEXT,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  UNIQUE(tenant_id, location_id, table_code),
  UNIQUE(tenant_id, qr_token),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_service_table_location_active
  ON service_table(tenant_id, location_id, is_active);

CREATE INDEX IF NOT EXISTS idx_service_table_code
  ON service_table(tenant_id, table_code);

CREATE TABLE IF NOT EXISTS app_session (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  staff_id INTEGER,
  device_session_id INTEGER,
  current_shift_session_id INTEGER,
  location_id TEXT,
  staff_remote_id TEXT,
  staff_email TEXT,
  staff_full_name TEXT,
  staff_role_code TEXT,
  base_url TEXT,
  auth_token TEXT,
  refresh_token TEXT,
  device_id TEXT,
  device_name TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  logged_in_at TEXT,
  last_seen_at TEXT,
  logged_out_at TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  created_at TEXT,
  updated_at TEXT,
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE SET NULL,
  FOREIGN KEY (device_session_id) REFERENCES device_session(id) ON DELETE SET NULL,
  FOREIGN KEY (current_shift_session_id) REFERENCES shift_session(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_app_session_status
  ON app_session(tenant_id, status, logged_in_at);

-- ---------------------------------------------------------------------------
-- Options and policies
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pos_option (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  option_name TEXT NOT NULL,
  option_value_text TEXT NOT NULL DEFAULT '',
  option_value_json TEXT,
  value_kind TEXT NOT NULL DEFAULT 'text',
  autoload INTEGER NOT NULL DEFAULT 1,
  source_endpoint TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, option_name),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_pos_option_name
  ON pos_option(tenant_id, option_name);

CREATE TABLE IF NOT EXISTS policy_snapshot (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  policy_name TEXT NOT NULL,
  source_option_name TEXT,
  source_endpoint TEXT,
  policy_json TEXT NOT NULL,
  policy_version TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, policy_name),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_policy_snapshot_name
  ON policy_snapshot(tenant_id, policy_name);

-- ---------------------------------------------------------------------------
-- Reference and master data
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS payment_mode (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  name TEXT,
  description TEXT,
  allow_pos INTEGER NOT NULL DEFAULT 1,
  is_active INTEGER NOT NULL DEFAULT 1,
  selected_by_default INTEGER NOT NULL DEFAULT 0,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_payment_mode_active
  ON payment_mode(tenant_id, is_active, selected_by_default);

CREATE TABLE IF NOT EXISTS order_type (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  code TEXT,
  name TEXT,
  description TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  UNIQUE(tenant_id, code),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_order_type_active
  ON order_type(tenant_id, is_active, code);

CREATE TABLE IF NOT EXISTS brand (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  code TEXT,
  name TEXT,
  display_flag INTEGER NOT NULL DEFAULT 1,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_brand_name
  ON brand(tenant_id, name);

CREATE TABLE IF NOT EXISTS category (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  code TEXT,
  name TEXT,
  brand_name TEXT,
  note TEXT,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_category_name
  ON category(tenant_id, name);

CREATE TABLE IF NOT EXISTS product (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  category_id INTEGER,
  category_remote_id TEXT,
  primary_brand_id INTEGER,
  primary_brand_remote_id TEXT,
  parent_product_id INTEGER,
  parent_remote_id TEXT,
  name TEXT NOT NULL,
  sku TEXT,
  barcode TEXT,
  description TEXT,
  image_url TEXT,
  cost_amount INTEGER NOT NULL DEFAULT 0,
  price_amount INTEGER NOT NULL DEFAULT 0,
  stock_quantity REAL NOT NULL DEFAULT 0,
  min_stock_level REAL NOT NULL DEFAULT 0,
  discount_total_amount INTEGER NOT NULL DEFAULT 0,
  discount_type TEXT,
  tax_rate REAL,
  is_available INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'active',
  children_json TEXT,
  units_json TEXT,
  legacy_locations_raw TEXT,
  legacy_brand_ids_raw TEXT,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES category(id) ON DELETE SET NULL,
  FOREIGN KEY (primary_brand_id) REFERENCES brand(id) ON DELETE SET NULL,
  FOREIGN KEY (parent_product_id) REFERENCES product(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_product_name_status
  ON product(tenant_id, name, status);

CREATE INDEX IF NOT EXISTS idx_product_sku
  ON product(tenant_id, sku);

CREATE INDEX IF NOT EXISTS idx_product_barcode
  ON product(tenant_id, barcode);

CREATE INDEX IF NOT EXISTS idx_product_category
  ON product(tenant_id, category_remote_id, status);

CREATE TABLE IF NOT EXISTS product_brand (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  brand_id INTEGER,
  product_remote_id TEXT,
  brand_remote_id TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  raw_json TEXT,
  UNIQUE(tenant_id, product_remote_id, brand_remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE CASCADE,
  FOREIGN KEY (brand_id) REFERENCES brand(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_product_brand_brand
  ON product_brand(tenant_id, brand_remote_id);

CREATE TABLE IF NOT EXISTS product_location (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  product_remote_id TEXT,
  location_id TEXT NOT NULL,
  location_name TEXT,
  raw_json TEXT,
  UNIQUE(tenant_id, product_remote_id, location_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_product_location_lookup
  ON product_location(tenant_id, location_id);

CREATE TABLE IF NOT EXISTS product_order_type (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  order_type_id INTEGER,
  product_remote_id TEXT,
  order_type_remote_id TEXT,
  order_type_code TEXT NOT NULL,
  raw_json TEXT,
  UNIQUE(tenant_id, product_remote_id, order_type_code),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE CASCADE,
  FOREIGN KEY (order_type_id) REFERENCES order_type(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_product_order_type_lookup
  ON product_order_type(tenant_id, order_type_code);

CREATE TABLE IF NOT EXISTS promotion (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  name TEXT,
  promo_type TEXT,
  description TEXT,
  terms_conditions TEXT,
  start_at TEXT,
  end_at TEXT,
  is_multiplied INTEGER NOT NULL DEFAULT 0,
  is_stackable INTEGER NOT NULL DEFAULT 0,
  status TEXT,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_promotion_status_window
  ON promotion(tenant_id, status, start_at, end_at);

CREATE TABLE IF NOT EXISTS promotion_brand (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  promotion_id INTEGER NOT NULL,
  brand_id INTEGER,
  promotion_remote_id TEXT,
  brand_remote_id TEXT NOT NULL,
  UNIQUE(tenant_id, promotion_remote_id, brand_remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (promotion_id) REFERENCES promotion(id) ON DELETE CASCADE,
  FOREIGN KEY (brand_id) REFERENCES brand(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_promotion_brand_lookup
  ON promotion_brand(tenant_id, brand_remote_id);

CREATE TABLE IF NOT EXISTS promotion_item (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  promotion_id INTEGER NOT NULL,
  product_id INTEGER,
  promotion_remote_id TEXT,
  product_remote_id TEXT NOT NULL,
  UNIQUE(tenant_id, promotion_remote_id, product_remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (promotion_id) REFERENCES promotion(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_promotion_item_lookup
  ON promotion_item(tenant_id, product_remote_id);

CREATE TABLE IF NOT EXISTS promotion_location (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  promotion_id INTEGER NOT NULL,
  promotion_remote_id TEXT,
  location_id TEXT NOT NULL,
  UNIQUE(tenant_id, promotion_remote_id, location_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (promotion_id) REFERENCES promotion(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_promotion_location_lookup
  ON promotion_location(tenant_id, location_id);

CREATE TABLE IF NOT EXISTS promotion_order_type (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  promotion_id INTEGER NOT NULL,
  order_type_id INTEGER,
  promotion_remote_id TEXT,
  order_type_code TEXT NOT NULL,
  order_type_remote_id TEXT,
  UNIQUE(tenant_id, promotion_remote_id, order_type_code),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (promotion_id) REFERENCES promotion(id) ON DELETE CASCADE,
  FOREIGN KEY (order_type_id) REFERENCES order_type(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_promotion_order_type_lookup
  ON promotion_order_type(tenant_id, order_type_code);

CREATE TABLE IF NOT EXISTS customer (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  display_name TEXT,
  company_name TEXT,
  phone_number TEXT,
  email TEXT,
  address_line1 TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  country_id TEXT,
  billing_street TEXT,
  billing_city TEXT,
  billing_state TEXT,
  billing_postal_code TEXT,
  billing_country TEXT,
  shipping_street TEXT,
  shipping_city TEXT,
  shipping_state TEXT,
  shipping_postal_code TEXT,
  shipping_country TEXT,
  group_ids_json TEXT,
  points_balance INTEGER NOT NULL DEFAULT 0,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  dirty_fields_json TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_customer_name
  ON customer(tenant_id, display_name);

CREATE INDEX IF NOT EXISTS idx_customer_phone
  ON customer(tenant_id, phone_number);

CREATE INDEX IF NOT EXISTS idx_customer_email
  ON customer(tenant_id, email);

-- ---------------------------------------------------------------------------
-- Self-order and tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS self_order_session (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  remote_id TEXT,
  service_table_id INTEGER,
  created_by_staff_id INTEGER,
  updated_by_staff_id INTEGER,
  current_order_id INTEGER,
  service_table_remote_id TEXT,
  session_code TEXT,
  public_code TEXT,
  access_token TEXT,
  location_id TEXT,
  business_date TEXT,
  table_code TEXT,
  queue_number INTEGER,
  customer_name TEXT,
  source_channel TEXT,
  flow_mode TEXT,
  payment_stage TEXT,
  status TEXT,
  order_type_code TEXT,
  current_order_remote_id TEXT,
  current_id_pos TEXT,
  feedback_url TEXT,
  resume_url TEXT,
  metadata_json TEXT,
  created_by_staff_remote_id TEXT,
  updated_by_staff_remote_id TEXT,
  last_activity_at TEXT,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  dirty_fields_json TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  UNIQUE(tenant_id, session_code),
  UNIQUE(tenant_id, public_code),
  UNIQUE(tenant_id, access_token),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (service_table_id) REFERENCES service_table(id) ON DELETE SET NULL,
  FOREIGN KEY (created_by_staff_id) REFERENCES staff(id) ON DELETE SET NULL,
  FOREIGN KEY (updated_by_staff_id) REFERENCES staff(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_self_order_status_activity
  ON self_order_session(tenant_id, status, last_activity_at);

CREATE INDEX IF NOT EXISTS idx_self_order_queue_lookup
  ON self_order_session(tenant_id, location_id, business_date, queue_number);

CREATE INDEX IF NOT EXISTS idx_self_order_table_code
  ON self_order_session(tenant_id, table_code);

CREATE INDEX IF NOT EXISTS idx_self_order_current_id_pos
  ON self_order_session(tenant_id, current_id_pos);

CREATE TABLE IF NOT EXISTS self_order_event (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  self_order_session_id INTEGER NOT NULL,
  actor_staff_id INTEGER,
  remote_id TEXT,
  self_order_session_remote_id TEXT,
  actor_staff_remote_id TEXT,
  event_type TEXT NOT NULL,
  actor_source TEXT,
  note TEXT,
  payload_json TEXT,
  occurred_at TEXT NOT NULL,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (self_order_session_id) REFERENCES self_order_session(id) ON DELETE CASCADE,
  FOREIGN KEY (actor_staff_id) REFERENCES staff(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_self_order_event_session_time
  ON self_order_event(tenant_id, self_order_session_id, occurred_at);

CREATE INDEX IF NOT EXISTS idx_self_order_event_type
  ON self_order_event(tenant_id, event_type, occurred_at);

-- ---------------------------------------------------------------------------
-- Orders and payments
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS pos_order (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  customer_id INTEGER,
  sale_staff_id INTEGER,
  shift_session_id INTEGER,
  device_session_id INTEGER,
  service_table_id INTEGER,
  self_order_session_id INTEGER,
  remote_id TEXT,
  id_pos TEXT,
  customer_remote_id TEXT,
  sale_staff_remote_id TEXT,
  shift_session_remote_id TEXT,
  device_session_remote_id TEXT,
  service_table_remote_id TEXT,
  self_order_session_remote_id TEXT,
  invoice_number TEXT,
  formatted_number TEXT,
  prefix TEXT,
  order_date TEXT,
  due_date TEXT,
  business_date TEXT,
  currency_remote_id TEXT,
  currency_code TEXT,
  billing_street TEXT,
  billing_city TEXT,
  billing_state TEXT,
  billing_postal_code TEXT,
  billing_country TEXT,
  shipping_street TEXT,
  shipping_city TEXT,
  shipping_state TEXT,
  shipping_postal_code TEXT,
  shipping_country TEXT,
  include_shipping INTEGER NOT NULL DEFAULT 0,
  show_shipping_on_invoice INTEGER NOT NULL DEFAULT 1,
  allowed_payment_modes_json TEXT,
  source_channel TEXT,
  order_type_code TEXT,
  queue_number INTEGER,
  table_code TEXT,
  status_code TEXT,
  status_text TEXT,
  subtotal_amount INTEGER NOT NULL DEFAULT 0,
  discount_total_amount INTEGER NOT NULL DEFAULT 0,
  discount_percent REAL NOT NULL DEFAULT 0,
  discount_type TEXT,
  manual_discount_value INTEGER NOT NULL DEFAULT 0,
  adjustment_amount INTEGER NOT NULL DEFAULT 0,
  total_amount INTEGER NOT NULL DEFAULT 0,
  amount_received INTEGER NOT NULL DEFAULT 0,
  change_amount INTEGER NOT NULL DEFAULT 0,
  total_left_to_pay_amount INTEGER NOT NULL DEFAULT 0,
  awarded_points INTEGER NOT NULL DEFAULT 0,
  customer_deposit_amount INTEGER NOT NULL DEFAULT 0,
  weight_estimate REAL NOT NULL DEFAULT 0,
  label TEXT,
  admin_note TEXT,
  client_note TEXT,
  terms TEXT,
  order_note TEXT,
  custom_fields_json TEXT,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  dirty_fields_json TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  UNIQUE(tenant_id, id_pos),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (customer_id) REFERENCES customer(id) ON DELETE SET NULL,
  FOREIGN KEY (sale_staff_id) REFERENCES staff(id) ON DELETE SET NULL,
  FOREIGN KEY (shift_session_id) REFERENCES shift_session(id) ON DELETE SET NULL,
  FOREIGN KEY (device_session_id) REFERENCES device_session(id) ON DELETE SET NULL,
  FOREIGN KEY (service_table_id) REFERENCES service_table(id) ON DELETE SET NULL,
  FOREIGN KEY (self_order_session_id) REFERENCES self_order_session(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_pos_order_status_date
  ON pos_order(tenant_id, status_code, order_date);

CREATE INDEX IF NOT EXISTS idx_pos_order_invoice_number
  ON pos_order(tenant_id, formatted_number);

CREATE INDEX IF NOT EXISTS idx_pos_order_id_pos
  ON pos_order(tenant_id, id_pos);

CREATE INDEX IF NOT EXISTS idx_pos_order_customer
  ON pos_order(tenant_id, customer_remote_id, order_date);

CREATE INDEX IF NOT EXISTS idx_pos_order_session
  ON pos_order(tenant_id, self_order_session_id, table_code);

CREATE TABLE IF NOT EXISTS approval_request (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  requester_staff_id INTEGER,
  approved_by_staff_id INTEGER,
  shift_session_id INTEGER,
  remote_id TEXT,
  request_code TEXT,
  request_type TEXT,
  reference_type TEXT,
  reference_remote_id TEXT,
  reference_number TEXT,
  draft_id_pos TEXT,
  location_id TEXT,
  requester_staff_remote_id TEXT,
  requester_name_snapshot TEXT,
  requester_role TEXT,
  requester_device_id TEXT,
  shift_session_remote_id TEXT,
  reason TEXT,
  requested_payload_json TEXT,
  status TEXT,
  approved_by_staff_remote_id TEXT,
  approver_name_snapshot TEXT,
  approved_at TEXT,
  approval_note TEXT,
  rejection_note TEXT,
  expires_at TEXT,
  applied_at TEXT,
  resolved_reference_type TEXT,
  resolved_reference_remote_id TEXT,
  resolved_reference_number TEXT,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  dirty_fields_json TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  UNIQUE(tenant_id, request_code),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (requester_staff_id) REFERENCES staff(id) ON DELETE SET NULL,
  FOREIGN KEY (approved_by_staff_id) REFERENCES staff(id) ON DELETE SET NULL,
  FOREIGN KEY (shift_session_id) REFERENCES shift_session(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_approval_request_status_type
  ON approval_request(tenant_id, status, request_type);

CREATE INDEX IF NOT EXISTS idx_approval_request_reference
  ON approval_request(tenant_id, reference_type, reference_remote_id);

CREATE INDEX IF NOT EXISTS idx_approval_request_location_status
  ON approval_request(tenant_id, location_id, status);

CREATE INDEX IF NOT EXISTS idx_approval_request_requester_device
  ON approval_request(tenant_id, requester_device_id, updated_at);

CREATE TABLE IF NOT EXISTS pos_order_item (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  order_id INTEGER NOT NULL,
  product_id INTEGER,
  remote_id TEXT,
  order_remote_id TEXT,
  order_id_pos TEXT,
  product_remote_id TEXT,
  brand_remote_id_snapshot TEXT,
  category_remote_id_snapshot TEXT,
  product_name_snapshot TEXT,
  description TEXT,
  long_description TEXT,
  unit_name TEXT,
  qty REAL NOT NULL DEFAULT 0,
  price_amount INTEGER NOT NULL DEFAULT 0,
  base_price_amount INTEGER NOT NULL DEFAULT 0,
  line_subtotal_amount INTEGER NOT NULL DEFAULT 0,
  discount_amount INTEGER NOT NULL DEFAULT 0,
  discount_type TEXT,
  order_type_code TEXT,
  note TEXT,
  tax_names_json TEXT,
  kitchen_status TEXT,
  is_refund INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  dirty_fields_json TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES pos_order(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES product(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_pos_order_item_order
  ON pos_order_item(tenant_id, order_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_pos_order_item_product
  ON pos_order_item(tenant_id, product_remote_id);

CREATE INDEX IF NOT EXISTS idx_pos_order_item_kitchen
  ON pos_order_item(tenant_id, kitchen_status, order_id);

CREATE TABLE IF NOT EXISTS pos_order_payment (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  order_id INTEGER,
  payment_mode_id INTEGER,
  approval_request_id INTEGER,
  remote_id TEXT,
  invoice_remote_id TEXT,
  id_pos TEXT,
  payment_mode_remote_id TEXT,
  payment_mode_name_snapshot TEXT,
  amount INTEGER NOT NULL DEFAULT 0,
  payment_method TEXT,
  payment_date TEXT,
  recorded_at TEXT,
  note TEXT,
  transaction_reference TEXT,
  custom_fields_json TEXT,
  is_refund INTEGER NOT NULL DEFAULT 0,
  raw_payload_json TEXT,
  sync_state TEXT NOT NULL DEFAULT 'clean',
  dirty_fields_json TEXT,
  last_synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  UNIQUE(tenant_id, remote_id),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES pos_order(id) ON DELETE SET NULL,
  FOREIGN KEY (payment_mode_id) REFERENCES payment_mode(id) ON DELETE SET NULL,
  FOREIGN KEY (approval_request_id) REFERENCES approval_request(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_pos_order_payment_invoice
  ON pos_order_payment(tenant_id, invoice_remote_id);

CREATE INDEX IF NOT EXISTS idx_pos_order_payment_id_pos
  ON pos_order_payment(tenant_id, id_pos);

CREATE INDEX IF NOT EXISTS idx_pos_order_payment_mode_date
  ON pos_order_payment(tenant_id, payment_mode_remote_id, payment_date);

CREATE TABLE IF NOT EXISTS report_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  report_type TEXT NOT NULL,
  cache_key TEXT NOT NULL,
  params_json TEXT,
  meta_json TEXT,
  snapshot_json TEXT NOT NULL,
  row_count INTEGER NOT NULL DEFAULT 0,
  generated_at TEXT NOT NULL,
  expires_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  UNIQUE(tenant_id, report_type, cache_key),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_report_cache_type_expiry
  ON report_cache(tenant_id, report_type, expires_at);

-- ---------------------------------------------------------------------------
-- Sync metadata and diagnostics
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sync_checkpoint (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  endpoint_name TEXT NOT NULL,
  scope_key TEXT NOT NULL,
  cursor_value TEXT,
  cursor_type TEXT,
  http_etag TEXT,
  http_last_modified TEXT,
  last_success_at TEXT,
  last_attempt_at TEXT,
  full_refresh_required INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  UNIQUE(tenant_id, endpoint_name, scope_key),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sync_checkpoint_endpoint
  ON sync_checkpoint(tenant_id, endpoint_name, scope_key);

CREATE TABLE IF NOT EXISTS sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER,
  entity_type TEXT,
  entity_local_id INTEGER,
  entity_remote_id TEXT,
  dependency_entity_type TEXT,
  dependency_local_id INTEGER,
  operation TEXT NOT NULL,
  method TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  base_url TEXT,
  request_headers_json TEXT,
  request_body_json TEXT,
  response_code INTEGER,
  response_body_json TEXT,
  dedupe_key TEXT,
  priority INTEGER NOT NULL DEFAULT 100,
  status TEXT NOT NULL DEFAULT 'pending',
  retry_count INTEGER NOT NULL DEFAULT 0,
  next_retry_at TEXT,
  locked_at TEXT,
  locked_by TEXT,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  processed_at TEXT,
  UNIQUE(tenant_id, dedupe_key),
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_status
  ON sync_queue(status, next_retry_at, priority, created_at);

CREATE INDEX IF NOT EXISTS idx_sync_queue_entity
  ON sync_queue(tenant_id, entity_type, entity_local_id, status);

CREATE INDEX IF NOT EXISTS idx_sync_queue_endpoint
  ON sync_queue(tenant_id, endpoint, status);

CREATE TABLE IF NOT EXISTS error_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER,
  queue_id INTEGER,
  entity_type TEXT,
  entity_local_id INTEGER,
  severity TEXT NOT NULL DEFAULT 'error',
  category TEXT,
  error_code TEXT,
  message TEXT NOT NULL,
  details_json TEXT,
  stack_trace TEXT,
  endpoint TEXT,
  status TEXT NOT NULL DEFAULT 'new',
  created_at TEXT NOT NULL,
  uploaded_at TEXT,
  resolved_at TEXT,
  FOREIGN KEY (tenant_id) REFERENCES app_tenant(id) ON DELETE SET NULL,
  FOREIGN KEY (queue_id) REFERENCES sync_queue(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_error_log_status_created
  ON error_log(status, created_at);

CREATE INDEX IF NOT EXISTS idx_error_log_entity
  ON error_log(entity_type, entity_local_id, created_at);
