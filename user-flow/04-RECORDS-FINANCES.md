# Phase 4: Records & Financial Management
## PoultryPro Frontend Development Guide

---

## 📋 PHASE OVERVIEW

**What You'll Build**:
- Daily records list page (calendar and table views)
- Add/edit record forms with photo upload
- Quick record modal
- Finances overview page with charts
- Transaction management (income/expense)
- Financial reports per batch

**Database Tables**: `daily_records`, `transactions`, `transaction_categories`, `batches`, `workers`

**Estimated Time**: 3-4 days

---

## 4.1 RECORDS LIST PAGE

**Route**: `/records`

**Purpose**: View all daily records across all batches

**View Modes**:
1. **Calendar View** - Monthly calendar showing record status per day
2. **Table View** - Detailed list with all fields

**Filters**:
- Date range picker (default: last 30 days)
- Batch filter (multi-select)
- Worker filter (multi-select)
- Recorded via: All, Telegram, SMS, Web, Voice

**Data Source**: `daily_records` table
- Join with `batches` for batch name
- Join with `workers` for worker name
- Filter: `batches.farmer_id = auth.uid()`

**Calendar View Features**:
- Color indicators: Green (all batches recorded), Yellow (partial), Red (missing)
- Click date to see records for that day
- Quick add button per date

**Table Columns**:
- Date, Batch, Mortality, Eggs, Feed (kg), Sick Birds, Worker, Method, Photos, Actions

**Export**: CSV and Excel options

---

## 4.2 ADD DAILY RECORD

**Route**: `/records/new` or Modal

**Form Steps**:

### Step 1: Select Batch & Date
- Batch dropdown (active batches only)
- Date picker (default: today)
- Check if record exists for batch+date combination

### Step 2: Enter Data
- Mortality count (default: 0)
- Eggs collected (show only for layers)
- Feed bags used (default: 0, step: 0.5)
- Feed kg used (auto-calculate: bags × 50kg, or manual entry)
- Water liters (optional)
- Temperature °C (optional)
- Humidity % (optional, 0-100)
- Sick birds count (default: 0)
- Notes (textarea, optional)

### Step 3: Photos (Optional)
- Upload up to 5 photos
- Drag & drop or click to upload
- Preview thumbnails
- Upload to Supabase Storage: `batch-photos/{farmer_id}/{batch_id}/{timestamp}`
- Store URLs in `photo_urls` array field

**Database Insert**:
- Table: `daily_records`
- Set `recorded_via = 'web'`
- Set `worker_id = null` (farmer entered)
- Unique constraint on (batch_id, record_date)

**Triggers Activated**:
- `update_batch_count()` - Updates batch current_count
- `check_mortality_alert()` - Creates alert if mortality > 5%

**Post-Submission**:
- Show success toast
- Options: Add another record, View batch, Back to dashboard

---

## 4.3 EDIT DAILY RECORD

**Route**: `/records/[id]/edit`

**Purpose**: Modify existing record

**Form**: Same as add record, pre-filled with existing data

**Validation**: 
- Can only edit records for own batches
- Check RLS policy: `batch_id IN (SELECT id FROM batches WHERE farmer_id = auth.uid())`

**Database Update**:
- Table: `daily_records`
- Set `updated_at = NOW()`
- Triggers re-calculate batch stats

---

## 4.4 QUICK RECORD MODAL

**Trigger**: "Add Record" button from dashboard or batch card

**Purpose**: Fast data entry with minimal fields

**Fields**:
- Batch (dropdown, pre-filled if from batch card)
- Date (default: today)
- Mortality count
- Eggs collected (if layer)
- Feed bags used
- Notes (optional)

**Simplified Flow**:
- No photo upload
- No optional fields
- Quick submit

---

## 4.5 FINANCES OVERVIEW PAGE

**Route**: `/finances`

**Purpose**: Track all income and expenses

**Summary Cards** (Top Row):
1. **Total Income** (This Month) - with trend vs last month
2. **Total Expenses** (This Month) - with trend vs last month
3. **Net Profit** (This Month) - color-coded, with trend
4. **Outstanding** (Future: unpaid invoices)

**Data Source**: `transactions` table
- Filter: `farmer_id = auth.uid()`
- Filter: `transaction_date >= start of current month`

**Charts Section**:
1. **Income vs Expenses Over Time** - Line chart, monthly data
2. **Expense Breakdown** - Pie chart by category
3. **Profit Trend** - Area chart, monthly net profit

**Filters**:
- Date range picker
- Batch filter (All or specific batch)
- Type: All, Income, Expense
- Category filter

---

## 4.6 TRANSACTIONS TABLE

**Display**: Below charts on finances page

**Columns**:
- Date
- Type (badge: green for income, red for expense)
- Category
- Description
- Batch (if linked)
- Amount
- Payment Method
- Receipt (icon if exists)
- Actions (View | Edit | Delete)

**Data Source**: `transactions` table
- Join with `batches` for batch name
- Join with `workers` for recorded_by name
- Filter: `farmer_id = auth.uid()`
- Order by: `transaction_date DESC`

**Pagination**: 50 items per page

**Export**: CSV/Excel with filtered data

---

## 4.7 ADD TRANSACTION

**Route**: `/finances/new` or Modal

**Form Fields**:
- Type: Income or Expense (radio buttons, required)
- Category (dropdown, dynamic based on type, required)
- Amount (currency input, required)
- Quantity (optional, e.g., "100 eggs")
- Unit price (optional, auto-calculate amount if quantity provided)
- Description (textarea, optional)
- Transaction date (date picker, default: today)
- Payment method: Mobile Money, Cash, Bank Transfer, Credit, Other
- Batch (dropdown, optional - link to specific batch)
- Receipt (file upload: image or PDF, max 5MB)

**Categories**:
- Get from `transaction_categories` table
- Filter by `type` (income or expense)

**Income Categories**:
- Egg Sale, Bird Sale, Manure Sale, Other

**Expense Categories**:
- Feed Purchase, Chicks, Medication, Labor, Utilities, Equipment, Maintenance, Other

**Amount Calculator**:
- If quantity and unit_price entered: `amount = quantity × unit_price`
- Show calculation: "100 eggs × $0.50 = $50.00"

**Receipt Upload**:
- Upload to Supabase Storage: `receipts/{farmer_id}/{transaction_id}`
- Store URL in `receipt_url` field

**Database Insert**:
- Table: `transactions`
- Set `farmer_id = auth.uid()`
- Validate: If quantity provided, unit_price must be provided
- Constraint: `amount = quantity × unit_price` (within 0.01 tolerance)

---

## 4.8 EDIT TRANSACTION

**Route**: `/finances/[id]/edit`

**Form**: Same as add transaction, pre-filled

**Validation**: Can only edit own transactions

**Database Update**: 
- Table: `transactions`
- Where: `id = ?` AND `farmer_id = auth.uid()`

---

## 4.9 BATCH FINANCIAL REPORT

**Route**: `/finances/batch/[batchId]`

**Purpose**: Detailed financial breakdown for single batch

**Sections**:

### Summary
- Total income (with breakdown by category)
- Total expenses (with breakdown by category)
- Net profit
- ROI percentage: `(profit / initial_investment) × 100`
- Break-even analysis

**Data Source**: `batch_financials` view

### Income Breakdown
- Table of all income transactions for this batch
- Subtotals by category
- From `transactions` where `batch_id = ?` AND `type = 'income'`

### Expense Breakdown
- Table of all expense transactions for this batch
- Subtotals by category
- From `transactions` where `batch_id = ?` AND `type = 'expense'`

### Profitability Timeline
- Chart showing cumulative profit over batch lifetime
- X-axis: Date
- Y-axis: Cumulative profit
- Data: Running sum of transactions ordered by date

**Export**: PDF report with all data and charts

---

## 4.10 TELEGRAM BOT DATA ENTRY

**Worker Side Flow**:

### Method 1: Simple Text Message
- Worker sends: "3 dead, 120 eggs, 2 bags"
- Bot parses using regex/NLP
- Bot shows confirmation with parsed data
- Worker confirms
- Bot saves to `daily_records`

### Method 2: Voice Message
- Worker sends voice note
- Bot transcribes using speech-to-text
- Bot parses transcript
- Bot shows confirmation
- Saves with `voice_transcript` field

### Method 3: Photo with Caption
- Worker sends photo with caption: "5 dead birds"
- Bot uploads photo to Storage
- Bot parses caption
- Bot saves record with `photo_urls`

### Method 4: Guided Conversation
- Worker sends: `/record`
- Bot asks: "Which batch?"
- Worker selects from list
- Bot asks: "How many deaths?"
- Worker responds
- Bot asks: "How many eggs?"
- Worker responds
- Bot asks: "Feed bags used?"
- Worker responds
- Bot shows summary and confirmation
- Worker confirms
- Bot saves to database

**Database Operations** (via Edge Function):
- Insert into `daily_records`
- Set `recorded_via = 'telegram'`
- Set `telegram_message_id` from message
- Set `worker_id` from telegram_id lookup

**Conversation State**:
- Store in `telegram_conversations` table
- Fields: `telegram_id`, `worker_id`, `current_state`, `pending_data` (JSONB)
- Update `last_message_at` on each message

---

## COMPONENTS TO BUILD

1. **RecordCalendar** - Monthly calendar view
2. **RecordForm** - Add/edit record form
3. **QuickRecordModal** - Simplified record entry
4. **PhotoUpload** - Drag & drop photo uploader
5. **FinancialSummary** - Summary cards with trends
6. **TransactionForm** - Add/edit transaction
7. **TransactionTable** - Sortable, filterable table
8. **CategorySelect** - Dynamic category dropdown
9. **AmountCalculator** - Quantity × Unit Price calculator
10. **ReceiptUpload** - File uploader for receipts

---

## KEY QUERIES TO IMPLEMENT

1. **List records**: Select from `daily_records` joined with `batches` and `workers`
2. **Record details**: Select from `daily_records` where `id = ?`
3. **Check duplicate**: Select from `daily_records` where `batch_id = ?` AND `record_date = ?`
4. **Financial summary**: Aggregate from `transactions` by date range
5. **Transactions list**: Select from `transactions` with filters
6. **Batch financials**: Select from `batch_financials` view where `batch_id = ?`
7. **Transaction categories**: Select from `transaction_categories` where `type = ?`
8. **Income by category**: Aggregate from `transactions` where `type = 'income'` GROUP BY `category`
9. **Expense by category**: Aggregate from `transactions` where `type = 'expense'` GROUP BY `category`

---

## VALIDATION RULES

**Daily Records**:
- Batch must be active
- Date cannot be in future
- Mortality count cannot exceed current batch count
- Eggs collected only for layers
- One record per batch per date (unique constraint)

**Transactions**:
- Amount must be positive
- If quantity provided, unit_price required
- Amount must equal quantity × unit_price (within tolerance)
- Date cannot be in future
- Receipt file: max 5MB, types: JPG, PNG, PDF

---

## STORAGE BUCKETS

**batch-photos**:
- Public bucket
- Path: `{farmer_id}/{batch_id}/{timestamp}_{filename}`
- Policy: Farmers can upload to own folder, anyone can view

**receipts**:
- Private bucket
- Path: `{farmer_id}/{transaction_id}_{filename}`
- Policy: Farmers can upload/view/delete own receipts only

---

## REAL-TIME FEATURES

**Subscribe to**:
- `daily_records` - Update dashboard metrics when new record added
- `transactions` - Update financial summary when transaction added

**Optimistic Updates**:
- Add record to list immediately, rollback on error
- Update transaction in table, rollback on error

---

## NEXT PHASE

Proceed to **Phase 5: Health, Alerts & Reports** to build health management and reporting features.

---

**Phase 4 Complete! ✅**
