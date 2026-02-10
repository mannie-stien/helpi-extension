# Phase 3: Batch & Worker Management
## PoultryPro Frontend Development Guide

---

## 📋 PHASE OVERVIEW

**What You'll Build**:
- Batches list page with filters and search
- Create/edit batch forms
- Batch details page with 6 tabs
- Workers list page
- Add/edit worker forms
- Worker details page
- Batch-worker assignment system

**Database Tables**: `batches`, `workers`, `batch_workers`, `batch_statistics` (view), `batch_financials` (view)

**Estimated Time**: 4-5 days

---

## 3.1 BATCHES LIST PAGE

**Route**: `/batches`

**Purpose**: View and manage all batches

**Key Features**:
- Filter by status (All, Active, Completed, Sold)
- Filter by bird type (All, Layers, Broilers)
- Sort options (Newest, Oldest, Name, Bird Count)
- Search by batch name
- Toggle between grid and table view
- "Create Batch" button

**Data Source**: 
- Table: `batches` joined with `batch_statistics` and `batch_financials` views
- Filter: `farmer_id = auth.uid()`

**Display Info Per Batch**:
- Name, bird type, status
- Current count / Initial count
- Age in days
- Mortality rate
- Health score (use `get_batch_health_score()` function)
- Last record date
- Quick actions: View | Edit | Archive

---

## 3.2 CREATE/EDIT BATCH

**Route**: `/batches/new` or `/batches/[id]/edit`

**Form Fields**:
- Batch name (required)
- Bird type: Layer or Broiler (required)
- Initial count (required, positive integer)
- Start date (required)
- Expected end date (auto-calculate: broiler = 42 days, layer = 540 days)
- Cost per chick (optional)
- Notes (optional)

**Auto-calculations**:
- Total chick cost = cost per chick × initial count
- Current count = initial count (on create)
- Expected end date based on bird type

**Database Operations**:
- Insert into `batches` table
- Set `farmer_id = auth.uid()`
- Set `status = 'active'`

**Post-Creation Options**:
- View batch details
- Assign workers
- Add first record

---

## 3.3 BATCH DETAILS PAGE

**Route**: `/batches/[id]`

**Layout**: Header with batch info + 6 tabs

### TAB 1: OVERVIEW

**Key Metrics** (4 cards):
1. Population (current/initial, survival rate)
2. Mortality Rate (percentage, total deaths)
3. Production (total eggs, avg per day) - layers only
4. Feed Consumption (total kg, per bird ratio)

**Data Source**: `batch_statistics` view

**Charts**:
1. Mortality trend (last 30 days) - from `daily_records`
2. Production trend (last 30 days) - from `daily_records`
3. Feed efficiency by week - from `daily_records`

**Health Score Widget**:
- Use `get_batch_health_score()` function
- Display as circular progress (0-100)
- Color-coded: Green (80+), Yellow (60-79), Orange (40-59), Red (<40)
- Show factors: mortality rate, recent records, health events

### TAB 2: DAILY RECORDS

**Purpose**: View all daily records for this batch

**Features**:
- Date range filter
- Export to CSV/PDF
- Table with columns: Date, Mortality, Eggs, Feed, Worker, Photos
- Click row to expand details
- "Add Record" button

**Data Source**: `daily_records` table joined with `workers`
- Filter: `batch_id = [current batch]`

### TAB 3: FINANCIALS

**Summary Cards**:
- Total income
- Total expenses  
- Net profit
- ROI percentage

**Data Source**: `batch_financials` view

**Transactions Table**:
- Show all transactions for this batch
- From `transactions` table
- Filter: `batch_id = [current batch]`
- Columns: Date, Type, Category, Amount, Receipt

**Charts**:
- Income vs Expenses over time
- Expense breakdown by category
- Profitability trend

### TAB 4: HEALTH EVENTS

**Sections**:
1. Upcoming events (next 5)
2. Overdue events (if any)
3. All events timeline

**Data Source**: `health_events` table
- Filter: `batch_id = [current batch]`
- Calculate status: completed, overdue, or upcoming

**Features**:
- "Schedule New Event" button
- "Mark Complete" action
- Show: event type, name, scheduled date, actual date, cost, administered by

### TAB 5: WORKERS

**Purpose**: Manage worker assignments for this batch

**Data Source**: `batch_workers` joined with `workers`
- Filter: `batch_id = [current batch]`

**Display Per Worker**:
- Name, role, phone, telegram
- Primary worker indicator
- Records submitted count
- Last active timestamp
- "Remove from Batch" button

**Features**:
- "Assign Worker" button
- Set/unset primary worker
- View worker performance stats

**Assignment Modal**:
- Dropdown of available workers (from `workers` table)
- Checkbox: "Set as primary"
- Insert into `batch_workers` table

### TAB 6: SETTINGS

**Purpose**: Edit batch details and manage status

**Editable Fields**:
- Batch name
- Current count (with warning)
- Expected end date
- Actual end date (if completed)
- Cost per chick
- Status (Active, Completed, Sold)
- Notes

**Danger Zone**:
- Archive batch button
- Delete batch button (with confirmation)

**Database**: Update `batches` table where `id = [batch_id]` and `farmer_id = auth.uid()`

---

## 3.4 WORKERS LIST PAGE

**Route**: `/workers`

**Purpose**: View and manage all workers

**Key Features**:
- Filter by status (All, Active, Inactive)
- Filter by role (All, Worker, Supervisor, Manager)
- Search by name
- "Add Worker" button

**Data Source**: `workers` table with aggregated data
- Join with `daily_records` for record count
- Join with `batch_workers` for assigned batches count
- Filter: `farmer_id = auth.uid()`

**Display Info Per Worker**:
- Name, role, phone
- Telegram status (connected or not)
- Active/inactive toggle
- Last active timestamp
- Records submitted count
- Assigned batches count
- Actions: View | Edit | Delete

---

## 3.5 ADD/EDIT WORKER

**Route**: `/workers/new` or `/workers/[id]/edit`

**Form Fields**:
- Name (required)
- Phone (optional)
- Role: Worker, Supervisor, or Manager (required)
- Communication method: Telegram, SMS, or Both (required)
- Assign to batches (multi-select, optional)

**Database Operations**:
- Insert/update `workers` table
- Set `farmer_id = auth.uid()`
- Set `is_active = true`
- If batches selected, insert into `batch_workers` table

**Post-Creation**:
- Show Telegram invitation code
- Instructions for worker to connect via bot
- Option to assign to batches

---

## 3.6 WORKER DETAILS PAGE

**Route**: `/workers/[id]`

**Purpose**: View worker profile and activity

**Profile Section**:
- Name, role, phone
- Telegram connection status
- Active/inactive toggle
- Edit button

**Stats Cards**:
1. Records submitted (total, this week, this month)
2. Assigned batches (count with links)
3. Last active timestamp

**Data Source**: 
- `workers` table
- Aggregate from `daily_records`
- Count from `batch_workers`

**Activity Timeline**:
- List recent records submitted
- From `daily_records` joined with `batches`
- Show: date, batch name, data summary

**Assigned Batches Section**:
- Cards for each assigned batch
- Show primary indicator
- Quick stats
- "Remove from Batch" button

**Actions**:
- Assign to more batches
- Send Telegram message (if connected)
- Deactivate worker
- Delete worker

---

## 3.7 BATCH-WORKER ASSIGNMENT SYSTEM

**Purpose**: Link workers to specific batches

**Database Table**: `batch_workers`
- Fields: `batch_id`, `worker_id`, `is_primary`, `assigned_at`
- Unique constraint on (batch_id, worker_id)

**Assignment Flow**:
1. From batch details → Assign worker
2. From worker details → Assign to batch
3. Select from available options
4. Optionally set as primary
5. Insert into `batch_workers`

**Removal Flow**:
1. Click "Remove from Batch"
2. Confirm action
3. Delete from `batch_workers`

**Primary Worker**:
- Only one primary worker per batch
- When setting new primary, unset previous
- Update `is_primary` field

---

## COMPONENTS TO BUILD

1. **BatchCard** - Display batch overview
2. **BatchFilters** - Filter and sort controls
3. **BatchForm** - Create/edit batch
4. **BatchTabs** - Tab navigation for batch details
5. **WorkerCard** - Display worker overview
6. **WorkerForm** - Create/edit worker
7. **AssignmentModal** - Assign worker to batch
8. **HealthScoreWidget** - Circular progress with score
9. **TimelineItem** - Activity/event timeline entry
10. **DataTable** - Reusable table component

---

## KEY QUERIES TO IMPLEMENT

1. **List batches with stats**: Join `batches` + `batch_statistics` + `batch_financials`
2. **Batch details**: Select from `batches` where `id = ?` and `farmer_id = auth.uid()`
3. **Batch records**: Select from `daily_records` where `batch_id = ?`
4. **Batch financials**: Select from `batch_financials` view where `batch_id = ?`
5. **Batch health events**: Select from `health_events` where `batch_id = ?`
6. **Batch workers**: Select from `batch_workers` joined with `workers` where `batch_id = ?`
7. **List workers**: Select from `workers` with aggregated stats where `farmer_id = auth.uid()`
8. **Worker details**: Select from `workers` where `id = ?` and `farmer_id = auth.uid()`
9. **Worker activity**: Select from `daily_records` where `worker_id = ?`
10. **Health score**: Call `get_batch_health_score(batch_id)` function

---

## VALIDATION RULES

**Batches**:
- Name must be unique per farmer
- Initial count must be positive
- Start date cannot be more than 1 year in past
- Expected end date must be after start date
- Current count cannot exceed initial count

**Workers**:
- Name required (min 2 characters)
- Phone format validation (if provided)
- Cannot delete worker with existing records
- Cannot assign same worker to batch twice

---

## REAL-TIME FEATURES

**Subscribe to changes**:
- `batches` table - refresh list when batch created/updated
- `daily_records` table - update batch stats when record added
- `batch_workers` table - refresh worker assignments

**Optimistic updates**:
- Toggle worker active status
- Mark health event complete
- Update batch status

---

## NEXT PHASE

Proceed to **Phase 4: Records & Financial Management** to build data entry and financial tracking features.

---

**Phase 3 Complete! ✅**
