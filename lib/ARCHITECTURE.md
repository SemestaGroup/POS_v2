# FlinkPOS V2 Architecture

## Core Principles
- One shared app shell with role-aware entry points.
- Sidebar navigation is grouped by domain, not by every individual page.
- Business concerns stay split across domains even when they appear in the same shell.
- Every page keeps three view layouts:
  - `web_landscape`
  - `mobile_portrait`
  - `tablet_landscape`

## Role Entry Points
- `owner`: starts from overview and can access all standard domains.
- `supervisor`: starts from overview with limited settings access.
- `cashier`: starts directly in sales.
- `kitchen`: starts directly in kitchen operations.
- `programmer`: hidden role for internal tools only.

## Domain Boundaries
- `overview`: role-specific high-level summaries.
- `sales`: POS, checkout, active orders, parked orders, sales history lite.
- `operations`: shift session, recap, cash flow review, kitchen board.
- `reports`: structured reporting and managerial insights.
- `master_data`: catalog, customers, staff, promos, categories, brands.
- `settings`: general, store, printer, sync, device.
- `programmer`: diagnostics, queue inspection, flags, logs.

## Intentional Splits
- POS and orders are related, but remain separate concerns inside `sales`.
- recap is not merged into orders; it belongs to `operations`.
- kitchen stays separate from POS workflow even if it shares transaction context.
- reports stay separate from shift recap.

## Visual Direction
- Cheerful, friendlier UI than the old app.
- Stronger empty states, imagery, motion, and role-based color identity.
- Mobile portrait remains operationally efficient; web and tablet can be richer.
