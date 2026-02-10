# Phase 2: Dashboard & Core Features
## PoultryPro Frontend Development Guide

---

## 📋 PHASE OVERVIEW

**What You'll Build**:
- Main dashboard layout (sidebar, topbar, content area)
- Key metrics cards (birds, eggs, workers, profit)
- Alerts & notifications section
- Active batches overview with health scores
- Recent activity feed
- Quick actions panel
- Real-time data updates

**Database Tables**: `profiles`, `batches`, `workers`, `daily_records`, `transactions`, `alerts`, `batch_statistics` (view), `batch_financials` (view)

**Estimated Time**: 3-4 days

---

## 2.1 DASHBOARD LAYOUT

### Route: `/dashboard`

### Purpose
Main hub showing farm overview and quick access to all features.

### Layout Structure

```
┌─────────────────────────────────────────────────────────┐
│                     FULL LAYOUT                         │
│                                                         │
│  ┌──────────┬──────────────────────────────────────┐  │
│  │          │  Top Bar                             │  │
│  │          │  - Farm Name                         │  │
│  │          │  - Search                            │  │
│  │ Sidebar  │  - Notifications (bell with badge)   │  │
│  │          │  - User Avatar + Dropdown            │  │
│  │ - Logo   ├──────────────────────────────────────┤  │
│  │ - Nav    │                                       │  │
│  │   Links  │  Main Content Area                    │  │
│  │          │  (Dashboard content below)            │  │
│  │          │                                       │  │
│  │          │                                       │  │
│  └──────────┴──────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 2.2 SIDEBAR COMPONENT

### Desktop View (Width: 256px)

```
┌─────────────────┐
│                 │
│  🐔 PoultryPro  │ ← Logo
│                 │
├─────────────────┤
│                 │
│ 📊 Dashboard    │ ← Active
│ 🐔 Batches      │
│ 👷 Workers      │
│ 📝 Records      │
│ 💰 Finances     │
│ 💉 Health       │
│ 📊 Reports      │
│ ⚙️  Settings    │
│                 │
├─────────────────┤
│                 │
│ 💡 Help         │
│ 🎯 Tutorial     │
│                 │
└─────────────────┘
```

### Mobile View
- Collapsed by default (hamburger menu)
- Slide-in drawer from left
- Overlay on content
- Close button

### Navigation Items

```typescript
const navItems = [
  { label: 'Dashboard', icon: LayoutDashboard, href: '/dashboard' },
  { label: 'Batches', icon: Bird, href: '/batches' },
  { label: 'Workers', icon: Users, href: '/workers' },
  { label: 'Records', icon: ClipboardList, href: '/records' },
  { label: 'Finances', icon: DollarSign, href: '/finances' },
  { label: 'Health', icon: Heart, href: '/health' },
  { label: 'Reports', icon: BarChart, href: '/reports' },
  { label: 'Settings', icon: Settings, href: '/settings' },
];
```

### Active State
- Highlight current page
- Blue background + bold text
- Left border accent

---

## 2.3 TOP BAR COMPONENT

### Layout

```
┌─────────────────────────────────────────────────────────┐
│ Farm Name        [Search...]    🔔(3)  👤 John Doe ▼   │
└─────────────────────────────────────────────────────────┘
```

### Elements

**1. Farm Name**
```typescript
// Fetch from profile
const { data: profile } = await supabase
  .from('profiles')
  .select('farm_name')
  .eq('id', user.id)
  .single();
```

**2. Search Bar**
- Global search across batches, workers, records
- Keyboard shortcut: Cmd/Ctrl + K
- Dropdown with results

**3. Notifications Bell**
```typescript
// Get unread count
const { count } = await supabase
  .from('alerts')
  .select('*', { count: 'exact', head: true })
  .eq('farmer_id', user.id)
  .eq('is_read', false);

// Show badge with count
<Bell className="w-5 h-5" />
{count > 0 && <Badge>{count}</Badge>}
```

**4. User Dropdown**
- User name + avatar
- Dropdown menu:
  - Profile
  - Settings
  - Billing
  - Help
  - Sign Out

---

## 2.4 DASHBOARD CONTENT

### Section 1: KEY METRICS (Top Row)

Four metric cards displaying critical farm statistics.

```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ Total Birds  │ Today's Eggs │ Active       │ This Month's │
│              │              │ Workers      │ Profit       │
│    2,450     │     1,234    │      8       │   $2,345     │
│ ↑ 5% vs last │ ↓ 2% vs avg  │ 6 active     │ ↑ 15% vs     │
│   month      │              │ today        │ last month   │
└──────────────┴──────────────┴──────────────┴──────────────┘
```

#### Card 1: Total Birds

**Query**:
```sql
SELECT 
  SUM(current_count) as total_birds,
  COUNT(*) as active_batches
FROM batches 
WHERE farmer_id = auth.uid() 
  AND status = 'active';
```

**Display**:
- Icon: 🐔 (Bird icon)
- Main number: `2,450`
- Subtitle: "Across 5 active batches"
- Trend: Compare to last month

**Implementation**:
```typescript
const { data } = await supabase
  .from('batches')
  .select('current_count')
  .eq('farmer_id', user.id)
  .eq('status', 'active');

const totalBirds = data?.reduce((sum, batch) => sum + batch.current_count, 0) || 0;
```

#### Card 2: Today's Eggs

**Query**:
```sql
SELECT 
  COALESCE(SUM(eggs_collected), 0) as total_eggs,
  COUNT(DISTINCT batch_id) as batches_recorded
FROM daily_records dr
JOIN batches b ON b.id = dr.batch_id
WHERE b.farmer_id = auth.uid() 
  AND dr.record_date = CURRENT_DATE;
```

**Display**:
- Icon: 🥚 (Egg icon)
- Main number: `1,234`
- Subtitle: "From 3 batches"
- Trend: Compare to 7-day average

#### Card 3: Active Workers

**Query**:
```sql
SELECT 
  COUNT(*) as total_workers,
  COUNT(DISTINCT CASE 
    WHEN last_active_at >= CURRENT_DATE 
    THEN id 
  END) as active_today
FROM workers 
WHERE farmer_id = auth.uid() 
  AND is_active = true;
```

**Display**:
- Icon: 👷 (Worker icon)
- Main number: `8`
- Subtitle: "6 recorded today"

#### Card 4: This Month's Profit

**Query**:
```sql
SELECT 
  COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
  COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expenses,
  COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END), 0) as profit
FROM transactions
WHERE farmer_id = auth.uid()
  AND transaction_date >= DATE_TRUNC('month', CURRENT_DATE);
```

**Display**:
- Icon: 💰 (Dollar icon)
- Main number: `$2,345` (green if positive, red if negative)
- Subtitle: "ROI: 23%"
- Trend: Compare to last month

---

### Section 2: ALERTS & NOTIFICATIONS

**Layout**:
```
┌─────────────────────────────────────────────────────────┐
│ Alerts & Notifications                    [View All]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 🔴 High Mortality Alert                   2 hours ago   │
│    Batch A recorded 15 deaths (5% of flock)             │
│    [View Batch]                                         │
│                                                         │
│ ⚠️  Vaccination Due                       1 day ago     │
│    Newcastle vaccine scheduled for Batch B tomorrow     │
│    [Schedule Now]                                       │
│                                                         │
│ ℹ️  Production Drop                       3 days ago    │
│    Egg production down 20% in Batch C                   │
│    [View Analytics]                                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Query**:
```sql
SELECT 
  a.*,
  b.name as batch_name
FROM alerts a
LEFT JOIN batches b ON b.id = a.batch_id
WHERE a.farmer_id = auth.uid() 
  AND a.is_dismissed = false
ORDER BY 
  CASE a.severity 
    WHEN 'critical' THEN 1 
    WHEN 'warning' THEN 2 
    ELSE 3 
  END,
  a.created_at DESC
LIMIT 5;
```

**Alert Card Components**:
- Severity icon (color-coded)
- Title
- Message (truncated to 100 chars)
- Timestamp (relative: "2 hours ago")
- Action button (if `action_url` exists)
- Mark as read button (eye icon)
- Dismiss button (X icon)

**Severity Colors**:
- Critical: Red (`#EF4444`)
- Warning: Yellow (`#F59E0B`)
- Info: Blue (`#3B82F6`)

**Interactions**:
```typescript
// Mark as read
const markAsRead = async (alertId: string) => {
  await supabase
    .from('alerts')
    .update({ is_read: true })
    .eq('id', alertId)
    .eq('farmer_id', user.id);
};

// Dismiss alert
const dismissAlert = async (alertId: string) => {
  await supabase
    .from('alerts')
    .update({ is_dismissed: true })
    .eq('id', alertId)
    .eq('farmer_id', user.id);
};
```

---

### Section 3: ACTIVE BATCHES OVERVIEW

**Layout**: Grid of batch cards (2-3 columns on desktop, 1 on mobile)

```
┌─────────────────────────────────────────────────────────┐
│ Active Batches                            [View All]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ┌──────────────────┐  ┌──────────────────┐            │
│ │ Batch A          │  │ Batch B          │            │
│ │ 🥚 Layer         │  │ 🍗 Broiler       │            │
│ │                  │  │                  │            │
│ │ 500 birds        │  │ 1,000 birds      │            │
│ │ 45 days old      │  │ 28 days old      │            │
│ │                  │  │                  │            │
│ │ Health: 85/100   │  │ Health: 92/100   │            │
│ │ ████████░░ Good  │  │ █████████░ Exc   │            │
│ │                  │  │                  │            │
│ │ [View] [Record]  │  │ [View] [Record]  │            │
│ └──────────────────┘  └──────────────────┘            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Query**:
```sql
SELECT 
  b.*,
  bs.total_deaths,
  bs.mortality_rate_percent,
  bs.total_eggs,
  bs.avg_eggs_per_day,
  bs.age_in_days,
  bs.last_record_date
FROM batches b
LEFT JOIN batch_statistics bs ON bs.batch_id = b.id
WHERE b.farmer_id = auth.uid() 
  AND b.status = 'active'
ORDER BY b.start_date DESC
LIMIT 6;
```

**Batch Card Components**:
- Batch name (bold)
- Bird type badge (Layer/Broiler with icon)
- Current bird count
- Age in days
- Health score (0-100 with progress bar)
- Mini mortality trend chart (last 7 days)
- Action buttons: "View Details" | "Add Record"

**Health Score Calculation**:
```typescript
// Use database function
const { data } = await supabase.rpc('get_batch_health_score', {
  batch_uuid: batchId
});

const healthScore = data || 0;

// Color coding
const getHealthColor = (score: number) => {
  if (score >= 80) return 'green';   // Excellent
  if (score >= 60) return 'yellow';  // Good
  if (score >= 40) return 'orange';  // Fair
  return 'red';                       // Poor
};
```

**Mini Chart** (Last 7 days mortality):
```typescript
// Fetch last 7 days of records
const { data } = await supabase
  .from('daily_records')
  .select('record_date, mortality_count')
  .eq('batch_id', batchId)
  .gte('record_date', subDays(new Date(), 7))
  .order('record_date', { ascending: true });

// Render as sparkline chart
<Sparkline data={data} />
```

---

### Section 4: RECENT ACTIVITY FEED

**Layout**:
```
┌─────────────────────────────────────────────────────────┐
│ Recent Activity                           [View All]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 📝 John recorded data for Batch A        2 hours ago   │
│    5 deaths, 120 eggs, 2 bags feed                      │
│                                                         │
│ 💰 Egg sale recorded                      5 hours ago   │
│    $150.00 - 300 eggs sold                              │
│                                                         │
│ 👷 New worker added: Mary Smith           1 day ago     │
│                                                         │
│ 💉 Vaccination completed for Batch B      2 days ago    │
│    Newcastle vaccine administered                       │
│                                                         │
│ 🐔 New batch created: Batch C             3 days ago    │
│    1,000 broiler chicks                                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Query** (Combine multiple tables):
```sql
-- Daily records
SELECT 
  'record' as type,
  dr.created_at,
  json_build_object(
    'worker', w.name,
    'batch', b.name,
    'mortality', dr.mortality_count,
    'eggs', dr.eggs_collected,
    'feed', dr.feed_bags_used
  ) as data
FROM daily_records dr
JOIN workers w ON w.id = dr.worker_id
JOIN batches b ON b.id = dr.batch_id
WHERE b.farmer_id = auth.uid()

UNION ALL

-- Transactions
SELECT 
  'transaction' as type,
  t.created_at,
  json_build_object(
    'type', t.type,
    'category', t.category,
    'amount', t.amount,
    'description', t.description
  ) as data
FROM transactions t
WHERE t.farmer_id = auth.uid()

UNION ALL

-- Workers
SELECT 
  'worker' as type,
  w.created_at,
  json_build_object(
    'name', w.name,
    'role', w.role
  ) as data
FROM workers w
WHERE w.farmer_id = auth.uid()

UNION ALL

-- Health events
SELECT 
  'health' as type,
  he.updated_at as created_at,
  json_build_object(
    'name', he.name,
    'batch', b.name,
    'completed', he.is_completed
  ) as data
FROM health_events he
JOIN batches b ON b.id = he.batch_id
WHERE b.farmer_id = auth.uid() AND he.is_completed = true

UNION ALL

-- Batches
SELECT 
  'batch' as type,
  b.created_at,
  json_build_object(
    'name', b.name,
    'bird_type', b.bird_type,
    'count', b.initial_count
  ) as data
FROM batches b
WHERE b.farmer_id = auth.uid()

ORDER BY created_at DESC
LIMIT 20;
```

**Activity Item Components**:
- Icon based on type
- Description text
- Timestamp (relative)
- Optional metadata (amounts, counts)

---

### Section 5: QUICK ACTIONS

**Layout**:
```
┌─────────────────────────────────────────────────────────┐
│ Quick Actions                                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│ │ ➕ Add     │  │ 🐔 New     │  │ 👷 Add     │        │
│ │   Record   │  │   Batch    │  │   Worker   │        │
│ └────────────┘  └────────────┘  └────────────┘        │
│                                                         │
│ ┌────────────┐  ┌────────────┐  ┌────────────┐        │
│ │ 💰 Record  │  │ 💉 Schedule│  │ 📊 Generate│        │
│ │   Transaction│ │   Vaccine  │  │   Report   │        │
│ └────────────┘  └────────────┘  └────────────┘        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Actions**:
1. **Add Daily Record** → Open quick record modal
2. **Create New Batch** → Navigate to `/batches/new`
3. **Add Worker** → Open worker modal
4. **Record Transaction** → Open transaction modal
5. **Schedule Vaccination** → Navigate to `/health/new`
6. **Generate Report** → Navigate to `/reports`

**Keyboard Shortcuts**:
- Add Record: `Ctrl/Cmd + N`
- New Batch: `Ctrl/Cmd + B`
- Add Worker: `Ctrl/Cmd + W`

---

## 2.5 REAL-TIME UPDATES

### Supabase Realtime Subscriptions

**Subscribe to Changes**:
```typescript
useEffect(() => {
  const channel = supabase
    .channel('dashboard-updates')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'daily_records',
        filter: `batch_id=in.(${batchIds.join(',')})`,
      },
      (payload) => {
        // Refresh dashboard metrics
        queryClient.invalidateQueries(['dashboard-metrics']);
      }
    )
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'alerts',
        filter: `farmer_id=eq.${user.id}`,
      },
      (payload) => {
        // Show toast notification
        toast.info(payload.new.title);
        // Refresh alerts
        queryClient.invalidateQueries(['alerts']);
      }
    )
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'transactions',
        filter: `farmer_id=eq.${user.id}`,
      },
      (payload) => {
        // Refresh financial metrics
        queryClient.invalidateQueries(['financial-metrics']);
      }
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}, [batchIds, user.id]);
```

**Auto-refresh Intervals**:
- Metrics: Every 5 minutes
- Alerts: Real-time
- Activity feed: Every 2 minutes
- Batch cards: Every 5 minutes

---

## 2.6 QUICK RECORD MODAL

### Trigger
Click "Add Record" button from dashboard or batch card.

### Modal Layout
```
┌─────────────────────────────────────────┐
│ Add Daily Record                    ✕   │
├─────────────────────────────────────────┤
│                                         │
│ Batch: [Dropdown]                       │
│ Date: [Date Picker] (default: today)    │
│                                         │
│ Mortality Count: [Number Input]         │
│ Eggs Collected: [Number Input]          │
│ Feed Bags Used: [Number Input]          │
│                                         │
│ Notes: [Text Area] (optional)           │
│                                         │
│ [Cancel]              [Submit Record]   │
│                                         │
└─────────────────────────────────────────┘
```

### Form Fields
```typescript
interface QuickRecordForm {
  batchId: string;
  recordDate: Date;
  mortalityCount: number;
  eggsCollected?: number; // Only for layers
  feedBagsUsed: number;
  notes?: string;
}
```

### Validation
- Check if record already exists for batch + date
- If exists, show: "Record exists. Edit instead?"

### Submit
```typescript
const { error } = await supabase
  .from('daily_records')
  .insert({
    batch_id: formData.batchId,
    worker_id: null, // Farmer entered
    record_date: formData.recordDate,
    mortality_count: formData.mortalityCount,
    eggs_collected: formData.eggsCollected || 0,
    feed_bags_used: formData.feedBagsUsed,
    feed_kg_used: formData.feedBagsUsed * 50, // Assume 50kg per bag
    notes: formData.notes,
    recorded_via: 'web',
  });

if (!error) {
  toast.success('Record added successfully');
  queryClient.invalidateQueries(['dashboard-metrics']);
  closeModal();
}
```

---

## 2.7 RESPONSIVE DESIGN

### Desktop (> 1024px)
- Sidebar visible
- 4-column metric cards
- 2-3 column batch grid
- Side-by-side sections

### Tablet (640px - 1024px)
- Collapsible sidebar
- 2-column metric cards
- 2-column batch grid
- Stacked sections

### Mobile (< 640px)
- Hamburger menu
- 1-column metric cards
- 1-column batch grid
- Stacked sections
- Bottom navigation for quick actions

---

## 2.8 LOADING STATES

### Skeleton Screens
Show skeleton loaders while data is fetching:
- Metric cards: Shimmer rectangles
- Batch cards: Card outline with shimmer
- Activity feed: List of shimmer lines
- Alerts: Card shimmer

### Empty States
When no data exists:
- No batches: "Create your first batch to get started"
- No alerts: "No alerts. Everything looks good! ✅"
- No activity: "Activity will appear here as you use the app"

---

## 2.9 ERROR HANDLING

### Network Errors
```typescript
if (error) {
  toast.error('Failed to load dashboard data. Please refresh.');
  // Show retry button
}
```

### Permission Errors
```typescript
if (error?.code === 'PGRST301') {
  toast.error('Access denied. Please sign in again.');
  router.push('/login');
}
```

---

## COMPONENTS TO BUILD

### 1. DashboardLayout
Main layout wrapper with sidebar and topbar.

### 2. Sidebar
Navigation sidebar with active states.

### 3. TopBar
Top navigation with search, notifications, user menu.

### 4. MetricCard
Reusable card for displaying key metrics.

### 5. AlertCard
Alert display with severity indicators.

### 6. BatchCard
Batch overview card with health score.

### 7. ActivityItem
Single activity feed item.

### 8. QuickActionButton
Large button for quick actions.

### 9. QuickRecordModal
Modal for fast data entry.

### 10. Sparkline
Mini chart for trends.

---

## DATA FETCHING STRATEGY

### React Query Setup
```typescript
// Fetch dashboard metrics
export const useDashboardMetrics = () => {
  return useQuery({
    queryKey: ['dashboard-metrics'],
    queryFn: async () => {
      const { data, error } = await supabase.rpc(
        'get_farmer_dashboard_stats',
        { farmer_uuid: user.id }
      );
      if (error) throw error;
      return data;
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
    refetchInterval: 5 * 60 * 1000,
  });
};

// Fetch active batches
export const useActiveBatches = () => {
  return useQuery({
    queryKey: ['active-batches'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('batch_statistics')
        .select('*')
        .eq('farmer_id', user.id)
        .eq('status', 'active')
        .order('start_date', { ascending: false })
        .limit(6);
      if (error) throw error;
      return data;
    },
  });
};

// Fetch alerts
export const useAlerts = () => {
  return useQuery({
    queryKey: ['alerts'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('alerts')
        .select('*, batches(name)')
        .eq('farmer_id', user.id)
        .eq('is_dismissed', false)
        .order('created_at', { ascending: false })
        .limit(5);
      if (error) throw error;
      return data;
    },
  });
};
```

---

## TESTING CHECKLIST

### Dashboard
- [ ] Metrics display correctly
- [ ] Metrics update in real-time
- [ ] Alerts show with correct severity
- [ ] Batch cards display health scores
- [ ] Activity feed shows recent events
- [ ] Quick actions open correct modals/pages
- [ ] Sidebar navigation works
- [ ] User dropdown functions
- [ ] Notifications bell shows count
- [ ] Search bar works
- [ ] Responsive on mobile/tablet
- [ ] Loading states display
- [ ] Empty states display
- [ ] Error handling works

---

## NEXT PHASE

Once Phase 2 is complete, proceed to **Phase 3: Batch & Worker Management** to build detailed management interfaces.

---

**Phase 2 Complete! ✅**
