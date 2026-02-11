# PoultryPro Frontend Implementation Plan (6 Phases)

**Goal**: A mobile-first, high-utility PWA for Ghanaian poultry farmers with **< 2 minutes/day** data entry.

**Source of Truth**: PostgreSQL schema + RLS + views/functions in `supabase-schema-v2.sql`.

**Core rule**: **Read from views**, **write to base tables**, keep client logic lean.

---

## 1) Architecture & Design System

### UX principles (farm reality)
- **One-handed** operation: bottom nav, primary actions in thumb zone.
- **Low cognitive load**: “Today” first, analytics second.
- **Fast entry**: sensible defaults, numeric keypad, steppers, “save” always visible.
- **Resilient**: handles low-signal/offline with queued writes.

### Color palette (Tailwind tokens)
Set semantic colors via CSS variables and map them in Tailwind.

- **Primary — Egg Yolk Gold**: `#F6C445` (primary buttons, highlights)
- **Success — Farm Green**: `#2E7D32` (healthy, positive)
- **Danger — Alert Red**: `#D32F2F` (money leaks, critical)
- **Warning — Orange**: `#F57C00` (stock-out risk)
- **Info — Blue**: `#1976D2` (context)
- **Neutrals**
  - Charcoal: `#111827`
  - Dust Gray: `#6B7280`
  - Field White: `#FAFAFA`

### Typography
- Font: **Inter**
- Numbers: use **tabular numerals** for aligned dashboards.
- Mobile sizes:
  - Body: `text-base`
  - Section headers: `text-lg`
  - Key metrics: `text-2xl` / `text-3xl`

### Tech stack
- **React + Next.js (App Router) + TypeScript**
- **Tailwind CSS**
- **Lucide Icons**
- **Supabase Auth + Supabase JS client**
- **TanStack Query** for caching + optimistic updates

### Folder structure
```
src/
  app/
    (auth)/login/
    (auth)/signup/
    onboarding/
    dashboard/
    daily/
    inventory/
    analytics/
    team/
    settings/
  components/
    ui/
    layout/
    cards/
    forms/
  hooks/
    useAuth.ts
    useOrg.ts
    useOfflineQueue.ts
  services/
    supabase/
      client.ts
      auth.ts
      queries.ts
      mutations.ts
    format/
      currency.ts
      dates.ts
  types/
    database.ts
    domain.ts
  lib/
    constants.ts
```

### Supabase client setup (typed)
- Generate types:
  - `supabase gen types typescript --project-id <id> --schema public > src/types/database.ts`
- Create client:
  - `createClient<Database>(url, anonKey)`

### Data access rulebook
- **Prefer views for reads**:
  - `v_batch_dashboard`, `v_recording_completeness`, `v_feed_inventory`, `v_feed_stockout_risk`,
  - `v_supplier_balances`, `v_cash_pinch`, `v_egg_summary`, `v_farm_pnl`, `v_org_summary_30d`, `v_price_context`,
  - `v_mortality_by_supplier`, `v_mortality_by_season`
- **Write to tables**:
  - `daily_logs`, `egg_inventory`, `feed_deliveries`, `supplier_ledger`, `market_prices`, `batches`, `batch_outcomes`, `members`
- **Use Postgres functions for flows**:
  - `fn_onboard_organization`, `fn_invite_member`, `fn_deactivate_member`

### TanStack Query conventions
- Query keys:
  - `['org', orgId, 'summary']` → `v_org_summary_30d`
  - `['farm', farmId, 'dashboard']` → farm dashboard queries
  - `['batch', batchId, 'dashboard']` → `v_batch_dashboard`
  - `['farm', farmId, 'eggSummary']` → `v_egg_summary`
- Mutations:
  - optimistic updates for `daily_logs` and `egg_inventory` entry forms

---

## 2) The 6-Phase Roadmap (each phase deployable)

### Phase 1: Authentication & Onboarding
**Goal**: sign up/login + create organization in one flow.

**Schema touchpoints**
- Tables: `profiles`, `organizations`, `farms`, `houses`, `members`, `org_subscriptions`
- Function: `fn_onboard_organization(p_org_name, p_farm_name, p_house_name, p_location)`

**Pages**
- `/login`, `/signup`
- `/onboarding` (single screen or 2-step max)

**UX**
- Single onboarding form:
  - Org name (required)
  - Farm name (default “My Farm”)
  - House name (default “House A”)
  - Location (optional)
- Submit → call `fn_onboard_organization` → route to `/dashboard`.

**Acceptance criteria**
- New user can sign up, create org, and reach dashboard.
- RLS enforced automatically.

---

### Phase 2: The Command Center (Dashboard)
**Goal**: show “what matters today” using views.

**Schema touchpoints (reads)**
- `v_batch_dashboard` (active batches)
- `v_org_summary_30d` (org rollup)
- `v_feed_stockout_risk`
- `v_cash_pinch`
- `v_recording_completeness`

**Pages**
- `/dashboard`

**Dashboard layout (mobile)**
- Top: “Today” header + farm selector (if multi-farm)
- Cards:
  - **Active batches** (from `v_batch_dashboard`)
  - **Feed stock-out** (from `v_feed_stockout_risk`)
  - **Cash pinch** (from `v_cash_pinch`)
  - **Recording completeness** (from `v_recording_completeness`)

**Acceptance criteria**
- Dashboard loads fast using views.
- No client-side calculations beyond formatting.

---

### Phase 3: The 45-Second Daily Log
**Goal**: ultra-fast input for `daily_logs` + `egg_inventory`.

**Schema touchpoints (writes)**
- `daily_logs` (per batch per day): `feed_bags`, `deaths`, `issue`, `notes`
- `egg_inventory` (per farm per day): `opening_stock` (auto), `collected`, `broken`, `sold`, `sale_amount`, `home_use`

**Pages**
- `/daily` (primary daily entry)

**UX**
- Default to **today**.
- Show **1 card per active batch**:
  - Feed bags: stepper (+ / -) + quick buttons (0.5, 1, 2)
  - Deaths: stepper
  - Optional issue tag chips: water/feed/heat/unknown
  - Save button pinned
- Egg inventory (farm-level) appears only if farm has layers (or always but collapsible).

**Acceptance criteria**
- Staff can enter daily numbers in under 2 minutes.
- Optimistic UI: after save, dashboard updates.

---

### Phase 4: Inventory & Supplier Ledger
**Goal**: track feed deliveries and supplier credit with minimal friction.

**Schema touchpoints**
- Write: `feed_deliveries`, `supplier_ledger`, `inventory_checks`
- Read: `v_feed_inventory`, `v_supplier_balances`

**Pages**
- `/inventory/feed`
- `/inventory/suppliers`

**UX**
- Feed:
  - “Add delivery” (bags received + optional cost)
  - “Count stock” (inventory check)
  - Theft gap card: show gap bags + estimated GH₵
- Suppliers:
  - Add purchase (credit) and payments
  - Show supplier balances + overdue

**Acceptance criteria**
- Farmer can see feed gap and supplier owed amounts without spreadsheets.

---

### Phase 5: Money Signals & Analytics
**Goal**: justify subscription with clear weekly/monthly insights.

**Schema touchpoints (reads)**
- `v_farm_pnl`, `v_org_summary_30d`
- `v_mortality_by_supplier`, `v_mortality_by_season`
- `v_egg_summary`
- `v_price_context`

**Pages**
- `/analytics`

**UX**
- P&L card: revenue vs costs vs gross margin
- Mortality insights: “Supplier A vs Supplier B”
- Price trend: last 14 days min/max/avg

**Acceptance criteria**
- Analytics uses views and remains readable on small screens.

---

### Phase 6: Team Management & PWA
**Goal**: manage roles + PWA offline support.

**Schema touchpoints**
- Functions: `fn_invite_member`, `fn_deactivate_member`
- Table: `members`

**Pages**
- `/team`
- `/settings/pwa`

**PWA**
- Add manifest + icons
- Installable home-screen app
- Offline-first daily entry with queued writes

**Acceptance criteria**
- Admin can invite/deactivate.
- Offline entries sync automatically when online.

---

## 3) Component Deep Dive

### A) Daily Log form (ultra-fast)
**Design**
- One screen: “Today”
- Batch cards stacked vertically
- Each card has 2 primary inputs: **Feed bags** + **Deaths**
- Optional chips: issue tag

**Speed patterns**
- Numeric steppers with large tap areas
- Quick-add buttons (e.g. `+0.5`, `+1`, `+2`)
- Default values = yesterday’s values (optional) but require explicit confirmation

**Data strategy**
- Preload from `v_batch_dashboard` to show current stats
- On save:
  - Upsert into `daily_logs` keyed by `(batch_id, log_date)`
  - Use optimistic update then invalidate queries:
    - `['batch', batchId, 'dashboard']`
    - `['farm', farmId, 'feedInventory']`

### B) Theft Alert card (feed gap visualization)
**Inputs**: `v_feed_inventory.gap_bags`, `gap_value_ghs`, `bags_expected`, last check date.

**UI**
- Header: “Possible feed loss”
- Big number: `gap_bags` (bags)
- Subtext: `~ GH₵ gap_value_ghs`
- Context bar:
  - Expected vs counted as a simple horizontal bar

**Behavior**
- If `gap_bags <= 0`: show “No gap detected” (muted)
- If `gap_bags > threshold`: show danger styling

---

## 4) Critical Edge Cases

### Offline in low-signal areas
**Requirement**: daily entry must still work.

**Approach**
- Maintain an **offline mutation queue** in IndexedDB (or localStorage for v1).
- Each queued item contains:
  - table/function name
  - payload
  - client timestamp
  - idempotency key
- When connection returns:
  - flush queue sequentially
  - revalidate relevant queries

**UI**
- Offline banner: “Offline — saving locally”
- Sync indicator: “3 entries pending”

### Currency + locale formatting (GHS)
- Use `Intl.NumberFormat('en-GH', { style: 'currency', currency: 'GHS' })`
- Dates:
  - store in DB as `DATE`/`TIMESTAMPTZ`
  - display with consistent format, e.g. `dd MMM` on mobile
- Avoid timezone confusion:
  - For daily logs use `log_date` (DATE) derived from local day selection

---

## Notes on batch completion
- Batches end with `batches.status = 'completed'`.
- How birds exited (sold live, sold as meat, culled, etc.) is recorded in `batch_outcomes.exit_type`.

---
