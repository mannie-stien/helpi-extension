# Phase 5: Health, Alerts & Reports
## PoultryPro Frontend Development Guide

---

## 📋 PHASE OVERVIEW

**What You'll Build**:
- Health events management page
- Schedule vaccinations and medications
- Alerts and notifications center
- Batch performance reports
- Analytics dashboard with charts
- Export functionality (PDF/Excel)

**Database Tables**: `health_events`, `alerts`, `batches`, `daily_records`, `transactions`, `batch_statistics` (view), `batch_financials` (view)

**Estimated Time**: 3-4 days

---

## 5.1 HEALTH EVENTS PAGE

**Route**: `/health`

**Purpose**: Manage vaccinations, medications, and treatments

**Layout Sections**:

### Upcoming Events (Top Priority)
- Show next 5 upcoming events
- Display: Event name, batch, scheduled date, days until due
- "Mark Complete" button per event

**Data Source**: `health_events` table
- Join with `batches`
- Filter: `batches.farmer_id = auth.uid()` AND `is_completed = false` AND `scheduled_date >= CURRENT_DATE`
- Order by: `scheduled_date ASC`

### Overdue Events (Alert Banner)
- Red alert banner if any overdue
- List overdue events
- Quick complete action

**Filter**: `is_completed = false` AND `scheduled_date < CURRENT_DATE`

### All Events Table
**Filters**:
- Batch (multi-select)
- Type: All, Vaccination, Medication, Treatment
- Status: All, Upcoming, Completed, Overdue

**Columns**:
- Scheduled Date, Actual Date, Batch, Event Type, Name, Dosage, Birds Treated, Cost, Administered By, Status, Actions

**Status Calculation**:
- Completed: `is_completed = true`
- Overdue: `is_completed = false` AND `scheduled_date < CURRENT_DATE`
- Upcoming: `is_completed = false` AND `scheduled_date >= CURRENT_DATE`

---

## 5.2 SCHEDULE HEALTH EVENT

**Route**: `/health/new` or Modal

**Form Fields**:
- Batch (dropdown, required)
- Event type: Vaccination, Medication, Treatment (required)
- Name (text input or quick select from common list, required)
- Scheduled date (date picker, required)
- Dosage (text, optional, e.g., "1ml per bird")
- Estimated cost (currency, optional)
- Notes (textarea, optional)
- Set reminder (checkbox, default: true)
- Reminder days before (number, default: 1)

**Common Vaccines/Medications** (Quick Select):
- Newcastle Disease
- Gumboro (IBD)
- Fowl Pox
- Infectious Bronchitis
- Coccidiosis Treatment
- Antibiotics
- Vitamins & Supplements
- Custom (manual entry)

**Database Insert**:
- Table: `health_events`
- Get `batch_id` from selected batch
- Set `is_completed = false`

**Create Reminder Alert**:
- If reminder enabled, insert into `alerts` table
- Type: `vaccination_due`
- Severity: `warning`
- Scheduled for: `scheduled_date - reminder_days_before`

---

## 5.3 MARK EVENT COMPLETE

**Trigger**: "Mark Complete" button

**Modal Form**:
- Actual date (date picker, default: today, required)
- Birds treated (number, default: batch current_count, required)
- Actual cost (currency, optional)
- Administered by (worker dropdown, optional)
- Notes (textarea, optional)
- Create expense transaction (checkbox, default: true)

**Database Update**:
- Table: `health_events`
- Set `is_completed = true`
- Set `actual_date`, `birds_treated`, `cost`, `administered_by_worker_id`, `notes`

**Optional Transaction**:
- If "Create expense transaction" checked
- Insert into `transactions` table
- Type: `expense`
- Category: `medication`
- Amount: actual cost
- Description: "Vaccination: {event_name}"

---

## 5.4 ALERTS & NOTIFICATIONS PAGE

**Route**: `/alerts`

**Purpose**: Central hub for all notifications

**Filter Tabs**:
- All (with count badge)
- Unread (with count badge)
- Critical
- Warnings
- Info

**Alert List**:
- Display alerts as cards
- Show: Severity icon, title, message, timestamp, batch (if applicable), action button
- Actions: Mark as read, Dismiss

**Data Source**: `alerts` table
- Join with `batches` for batch name
- Filter: `farmer_id = auth.uid()` AND `is_dismissed = false`
- Order by: Severity (critical first), then `created_at DESC`

**Bulk Actions**:
- "Mark All as Read" button
- "Clear All" button (dismiss all)

**Real-time**:
- Subscribe to `alerts` table
- Show toast notification for new critical alerts
- Update badge counts automatically

---

## 5.5 ALERT TYPES & TRIGGERS

### 1. High Mortality Alert
- **Trigger**: When daily mortality > 5% of flock
- **Created by**: `check_mortality_alert()` trigger (automatic)
- **Severity**: Critical
- **Action**: Link to batch details

### 2. Vaccination Due Alert
- **Trigger**: X days before scheduled vaccination
- **Created by**: Scheduled job or manual on event creation
- **Severity**: Warning
- **Action**: Link to health events

### 3. Low Feed Alert
- **Trigger**: Manual or scheduled check based on feed consumption
- **Severity**: Warning
- **Action**: Link to add transaction

### 4. Production Drop Alert
- **Trigger**: When egg production drops >20% from 7-day average
- **Created by**: Scheduled job analyzing `daily_records`
- **Severity**: Warning
- **Action**: Link to batch analytics

### 5. Batch Milestone Alert
- **Trigger**: Batch reaches 21 days, 42 days, etc.
- **Created by**: Scheduled job
- **Severity**: Info
- **Action**: Link to batch details

### 6. Subscription Expiring Alert
- **Trigger**: 7 days before subscription ends
- **Created by**: Scheduled job
- **Severity**: Warning
- **Action**: Link to billing

---

## 5.6 REPORTS PAGE

**Route**: `/reports`

**Purpose**: Generate comprehensive reports

**Report Templates** (Cards):

### 1. Batch Performance Report
- **Description**: Complete analysis of batch lifecycle
- **Inputs**: Select batch, date range
- **Output**: PDF/Excel
- **Sections**: Executive summary, mortality analysis, production, feed efficiency, health events, financials, recommendations

### 2. Financial Summary Report
- **Description**: Income, expenses, profitability
- **Inputs**: Date range, batch filter
- **Output**: PDF/Excel
- **Sections**: Summary, income breakdown, expense breakdown, profit trend

### 3. Worker Activity Report
- **Description**: Worker performance and records
- **Inputs**: Date range, worker filter
- **Output**: PDF/Excel
- **Sections**: Worker stats, records submitted, batches assigned, activity timeline

### 4. Health Events Report
- **Description**: Vaccination and medication history
- **Inputs**: Batch, date range
- **Output**: PDF
- **Sections**: Completed events, upcoming events, costs, compliance

### 5. Custom Report
- **Description**: Build your own report
- **Inputs**: Select metrics, filters, date range
- **Output**: PDF/Excel

---

## 5.7 BATCH PERFORMANCE REPORT

**Route**: `/reports/batch-performance`

**Inputs**:
- Batch selection (dropdown)
- Date range (optional, defaults to batch lifetime)

**Data Sources**:
- `batch_statistics` view
- `batch_financials` view
- `daily_records` table
- `health_events` table
- `transactions` table

**Report Sections**:

### 1. Executive Summary
- Batch details (name, type, status, duration)
- Population stats (initial, current, mortality rate)
- Production summary (total eggs, avg per day)
- Financial summary (income, expenses, profit, ROI)

### 2. Mortality Analysis
- Total deaths, mortality rate %
- Daily mortality chart (last 30 days)
- Peak mortality dates
- Comparison to industry standards (3-5% normal)

### 3. Production Analysis (Layers Only)
- Total eggs collected
- Average eggs per day
- Peak production dates
- Production efficiency (eggs per bird per day)
- Production trend chart

### 4. Feed Efficiency
- Total feed consumed (kg)
- Feed per bird ratio
- Feed conversion ratio (FCR)
- Feed cost per bird
- Feed efficiency trend chart

### 5. Health Events
- List of all vaccinations/medications
- Completion status
- Total health costs
- Compliance rate

### 6. Financial Performance
- Income breakdown by category (pie chart)
- Expense breakdown by category (pie chart)
- Net profit
- ROI percentage
- Break-even analysis
- Profitability timeline (line chart)

### 7. AI-Generated Recommendations
- Based on data patterns
- Areas for improvement
- Best practices suggestions

**Export Options**:
- PDF (formatted, printable)
- Excel (raw data + charts)
- Email report to specified address

---

## 5.8 ANALYTICS DASHBOARD

**Route**: `/analytics`

**Purpose**: Advanced data visualization and insights

**Time Period Selector**:
- Last 7 days, 30 days, 3 months, 6 months, 1 year, Custom range

**Key Metrics Row** (with comparison to previous period):
- Total Birds (trend arrow)
- Avg Mortality Rate (trend arrow)
- Total Eggs (trend arrow)
- Net Profit (trend arrow)

**Charts Grid** (2 columns):

### Row 1:
1. **Mortality Trend** - Multi-line chart (one line per active batch)
2. **Production Trend** - Multi-line chart (one line per layer batch)

### Row 2:
3. **Feed Consumption** - Stacked area chart (by batch)
4. **Financial Overview** - Grouped bar chart (Income, Expenses, Profit by month)

### Row 3:
5. **Batch Comparison** - Radar chart (mortality rate, production, feed efficiency, profitability, health score)
6. **Expense Breakdown** - Treemap (categories sized by amount)

### Row 4:
7. **Worker Performance** - Horizontal bar chart (records submitted per worker)
8. **Health Events Timeline** - Gantt chart (scheduled vs actual dates)

**Data Aggregation**:
- Aggregate from `daily_records` by date/week/month
- Aggregate from `transactions` by month
- Calculate metrics from views

**Interactive Features**:
- Click chart to drill down
- Hover for detailed tooltips
- Toggle batch visibility
- Export chart as image

---

## 5.9 EXPORT FUNCTIONALITY

**PDF Generation**:
- Use library: jsPDF or Puppeteer
- Include: Logo, farm name, report title, date
- Format: Professional layout with charts as images
- Footer: Page numbers, generated timestamp

**Excel Generation**:
- Use library: ExcelJS or SheetJS
- Multiple sheets: Summary, Raw Data, Charts
- Format: Headers, borders, number formatting
- Include formulas for calculations

**Email Reports**:
- Generate PDF/Excel
- Upload to temporary storage
- Send via email service (SendGrid, Resend)
- Include download link
- Auto-delete after 7 days

---

## COMPONENTS TO BUILD

1. **HealthEventCard** - Display event with status
2. **HealthEventForm** - Schedule/edit event
3. **MarkCompleteModal** - Complete event form
4. **AlertCard** - Display alert with actions
5. **AlertFilters** - Filter tabs for alerts
6. **ReportTemplate** - Report selection card
7. **ReportForm** - Report configuration form
8. **AnalyticsChart** - Reusable chart component
9. **MetricCard** - Metric with trend indicator
10. **ExportButton** - Export to PDF/Excel

---

## KEY QUERIES TO IMPLEMENT

1. **Upcoming events**: Select from `health_events` where not completed and date >= today
2. **Overdue events**: Select from `health_events` where not completed and date < today
3. **All events**: Select from `health_events` with filters
4. **Alerts list**: Select from `alerts` with severity ordering
5. **Unread count**: Count from `alerts` where not read
6. **Batch performance data**: Select from multiple tables and views
7. **Analytics aggregations**: Group by date/week/month from `daily_records`
8. **Financial trends**: Aggregate from `transactions` by period
9. **Worker performance**: Aggregate from `daily_records` by worker
10. **Health compliance**: Calculate completion rate from `health_events`

---

## SCHEDULED JOBS (Supabase Edge Functions with Cron)

**Daily Jobs**:
- Check for vaccination reminders (create alerts)
- Check for production drops (create alerts)
- Check for batch milestones (create alerts)

**Weekly Jobs**:
- Check subscription expiration (create alerts)
- Generate weekly summary email

**Implementation**:
- Create Edge Functions in `supabase/functions/`
- Configure cron schedule in Supabase Dashboard
- Use service role key for database access

---

## REAL-TIME FEATURES

**Subscribe to**:
- `health_events` - Update upcoming events when completed
- `alerts` - Show new alerts immediately with toast
- Real-time badge count updates

**Optimistic Updates**:
- Mark alert as read immediately
- Complete health event immediately
- Rollback on error

---

## NEXT PHASE

Proceed to **Phase 6: Settings & Telegram Integration** to build user settings and complete Telegram bot integration.

---

**Phase 5 Complete! ✅**
