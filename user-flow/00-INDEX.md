# PoultryPro: Complete User Flow Documentation
## Master Index - Phase-by-Phase Frontend Development Guide

---

## 📋 OVERVIEW

This documentation provides a comprehensive guide for building the PoultryPro frontend. Each phase is in a separate file to keep content manageable and focused.

**Use these documents with `supabase-schema-production.sql` to build the complete application.**

---

## 🎯 HOW TO USE THIS DOCUMENTATION

### For AI Developers:
1. **Start with the schema** - Read `supabase-schema-production.sql` first
2. **Follow phases in order** - Each phase builds on previous ones
3. **Implement as described** - All screens, forms, queries are detailed
4. **Copy queries directly** - SQL queries are production-ready
5. **Use provided data flows** - Understand how data moves through the system

### Tech Stack:
- **Frontend**: Next.js 14+ (App Router), React, TypeScript
- **Styling**: TailwindCSS + shadcn/ui components
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Realtime, Edge Functions)
- **Icons**: Lucide React
- **Charts**: Recharts
- **Forms**: React Hook Form + Zod validation
- **State**: React Query (TanStack Query) for server state

---

## 📚 DOCUMENTATION STRUCTURE

### Phase 1: Authentication & Onboarding
**File**: `01-AUTHENTICATION-ONBOARDING.md`

**What You'll Build**:
- Landing page
- Sign up / Login flows
- Email verification
- Password reset
- Onboarding wizard (5 steps)
- First batch creation
- Worker setup

**Database Tables Used**: `profiles`, `batches`, `workers`

---

### Phase 2: Dashboard & Core Features
**File**: `02-DASHBOARD-CORE.md`

**What You'll Build**:
- Main dashboard layout (sidebar, topbar)
- Key metrics cards (birds, eggs, workers, profit)
- Alerts section
- Active batches overview
- Recent activity feed
- Quick actions
- Real-time updates

**Database Tables Used**: `profiles`, `batches`, `workers`, `daily_records`, `transactions`, `alerts`

---

### Phase 3: Batch & Worker Management
**File**: `03-BATCH-WORKER-MANAGEMENT.md`

**What You'll Build**:
- Batches list page
- Create/edit batch forms
- Batch details page (6 tabs)
- Batch statistics & charts
- Workers list page
- Add/edit worker forms
- Worker details & performance
- Batch-worker assignments

**Database Tables Used**: `batches`, `workers`, `batch_workers`, `daily_records`, `transactions`, `health_events`

---

### Phase 4: Records & Financial Management
**File**: `04-RECORDS-FINANCES.md`

**What You'll Build**:
- Daily records list (calendar & table views)
- Add/edit record forms
- Photo uploads
- Finances overview page
- Income/expense tracking
- Transaction forms
- Financial charts
- Batch financial reports

**Database Tables Used**: `daily_records`, `transactions`, `transaction_categories`, `batches`, `workers`

---

### Phase 5: Health, Alerts & Reports
**File**: `05-HEALTH-ALERTS-REPORTS.md`

**What You'll Build**:
- Health events page
- Schedule vaccinations/medications
- Mark events complete
- Alerts & notifications center
- Alert types & triggers
- Reports page
- Batch performance reports
- Analytics dashboard
- Export functionality (PDF/Excel)

**Database Tables Used**: `health_events`, `alerts`, `batches`, `daily_records`, `transactions`

---

### Phase 6: Settings & Telegram Integration
**File**: `06-SETTINGS-TELEGRAM.md`

**What You'll Build**:
- User profile settings
- Farm settings
- Subscription management
- Payment history
- Telegram bot setup
- Worker invitation flow
- Bot conversation flows
- Edge function for webhook

**Database Tables Used**: `profiles`, `subscriptions`, `payments`, `telegram_conversations`, `workers`

---

## 🗂️ ADDITIONAL RESOURCES

### Component Library
**File**: `07-COMPONENT-LIBRARY.md`

Reusable components used across all phases:
- Layout components (Sidebar, TopBar, PageHeader)
- Form components (Input, Select, DatePicker, FileUpload)
- Data display (Table, Card, Badge, Chart)
- Feedback (Alert, Toast, Modal, Loading)

---

### API Reference
**File**: `08-API-REFERENCE.md`

Complete API documentation:
- Supabase client setup
- Authentication helpers
- Database queries (with RLS)
- Storage operations
- Real-time subscriptions
- Edge functions

---

### Data Flow Diagrams
**File**: `09-DATA-FLOWS.md`

Visual diagrams showing:
- User authentication flow
- Daily record submission (Web & Telegram)
- Alert generation flow
- Financial tracking flow
- Real-time update flow

---

## 🚀 QUICK START

### 1. Set Up Supabase
```bash
# Deploy the schema
# Go to Supabase Dashboard → SQL Editor
# Paste and run: supabase-schema-production.sql
```

### 2. Set Up Next.js Project
```bash
npx create-next-app@latest poultrypro --typescript --tailwind --app
cd poultrypro
npm install @supabase/supabase-js @supabase/auth-helpers-nextjs
npm install @tanstack/react-query
npm install react-hook-form zod @hookform/resolvers
npm install lucide-react recharts
npx shadcn-ui@latest init
```

### 3. Configure Environment
```env
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

### 4. Start Building
- Begin with Phase 1 (Authentication)
- Follow each phase sequentially
- Test each feature before moving to next phase

---

## 📊 DATABASE TABLES REFERENCE

Quick reference to all tables (see schema for full details):

| Table | Purpose | Key Fields |
|-------|---------|------------|
| `profiles` | User accounts | email, farm_name, subscription_status |
| `workers` | Farm employees | name, telegram_id, role |
| `batches` | Bird flocks | name, bird_type, initial_count, current_count |
| `batch_workers` | Worker assignments | batch_id, worker_id, is_primary |
| `daily_records` | Daily farm data | batch_id, record_date, mortality_count, eggs_collected |
| `transactions` | Income/expenses | type, category, amount, transaction_date |
| `health_events` | Vaccinations | event_type, scheduled_date, is_completed |
| `alerts` | Notifications | type, severity, is_read |
| `subscriptions` | Billing | plan_type, status, current_period_end |
| `payments` | Payment history | amount, status, provider_payment_id |
| `telegram_conversations` | Bot state | telegram_id, current_state, pending_data |

---

## 🎨 DESIGN SYSTEM

### Colors
- **Primary**: Blue (#3B82F6) - Actions, links
- **Success**: Green (#10B981) - Positive metrics, completed
- **Warning**: Yellow (#F59E0B) - Warnings, pending
- **Danger**: Red (#EF4444) - Critical alerts, errors
- **Neutral**: Gray (#6B7280) - Text, borders

### Typography
- **Headings**: Inter font, bold
- **Body**: Inter font, regular
- **Mono**: JetBrains Mono (for numbers, codes)

### Spacing
- Use Tailwind's spacing scale (4px increments)
- Card padding: p-6
- Section spacing: space-y-6

---

## 🔐 SECURITY NOTES

### Row Level Security (RLS)
- All tables have RLS enabled
- Policies ensure users only see their own data
- Use `auth.uid()` in queries
- Never bypass RLS in frontend

### Authentication
- Use Supabase Auth exclusively
- Store tokens securely (httpOnly cookies)
- Implement proper session management
- Handle token refresh automatically

### Data Validation
- Validate on client AND server
- Use Zod schemas for type safety
- Sanitize user inputs
- Validate file uploads (type, size)

---

## 📱 RESPONSIVE DESIGN

### Breakpoints
- **Mobile**: < 640px
- **Tablet**: 640px - 1024px
- **Desktop**: > 1024px

### Mobile Considerations
- Collapsible sidebar → hamburger menu
- Stack cards vertically
- Simplify tables → cards on mobile
- Touch-friendly buttons (min 44px)
- Bottom navigation for key actions

---

## ♿ ACCESSIBILITY

### Requirements
- Semantic HTML
- ARIA labels for icons
- Keyboard navigation
- Focus indicators
- Alt text for images
- Color contrast (WCAG AA)
- Screen reader friendly

---

## 🧪 TESTING STRATEGY

### Unit Tests
- Component rendering
- Form validation
- Utility functions
- Data transformations

### Integration Tests
- User flows (signup → dashboard)
- CRUD operations
- Real-time updates
- File uploads

### E2E Tests
- Critical paths (Playwright)
- Multi-user scenarios
- Payment flows
- Telegram integration

---

## 📈 PERFORMANCE

### Optimization
- Use React Query for caching
- Implement pagination (50 items/page)
- Lazy load images
- Code splitting by route
- Optimize bundle size

### Real-time
- Subscribe only to relevant data
- Unsubscribe on unmount
- Debounce updates
- Use optimistic updates

---

## 🐛 ERROR HANDLING

### User-Facing Errors
- Show friendly messages
- Provide actionable solutions
- Log errors to monitoring service
- Graceful degradation

### Network Errors
- Retry failed requests
- Show offline indicator
- Queue actions when offline
- Sync when back online

---

## 📝 NEXT STEPS

1. **Read Phase 1** → Build authentication
2. **Deploy to Vercel** → Test in production
3. **Set up Telegram Bot** → Enable worker reporting
4. **Configure payments** → Integrate Paystack/Stripe
5. **Launch MVP** → Get user feedback
6. **Iterate** → Add features based on usage

---

## 🤝 SUPPORT

For questions about:
- **Schema**: See `supabase-schema-production.sql`
- **Specific features**: See phase documentation
- **Components**: See `07-COMPONENT-LIBRARY.md`
- **API**: See `08-API-REFERENCE.md`

---

**Ready to build? Start with Phase 1!** 🚀
