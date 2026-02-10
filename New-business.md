# PoultryPro: Complete Supabase Database Schema
## Next.js + Supabase + Telegram Bot Architecture

---

## ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────┐
│                   NEXT.JS WEBAPP                     │
│  - Owner dashboard (analytics, reports, finances)   │
│  - Worker management                                │
│  - Batch management                                 │
│  - Authentication (Supabase Auth)                   │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│                 SUPABASE BACKEND                     │
│  - PostgreSQL Database                              │
│  - Row Level Security (RLS)                         │
│  - Real-time subscriptions                          │
│  - Edge Functions (for Telegram webhook)            │
│  - Storage (for photos, PDFs)                       │
└────────────────────┬────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────┐
│              TELEGRAM BOT (Separate Service)         │
│  - Python FastAPI or Node.js                        │
│  - Receives messages from workers                   │
│  - Writes to Supabase via API                       │
│  - Sends confirmations back to Telegram             │
└─────────────────────────────────────────────────────┘
```

---

## COMPLETE DATABASE SCHEMA

### 1. AUTHENTICATION (Built-in Supabase Auth)

Supabase Auth handles users automatically. You just need to extend with profiles.

```sql
-- Extends Supabase auth.users
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  phone TEXT,
  farm_name TEXT,
  subscription_status TEXT DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'cancelled', 'past_due')),
  subscription_ends_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see and update their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);
```

---

### 2. WORKERS (Farm Employees)

```sql
CREATE TABLE public.workers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  telegram_id BIGINT UNIQUE, -- Telegram user ID (numeric)
  telegram_username TEXT, -- @username (optional)
  communication_method TEXT DEFAULT 'telegram' CHECK (communication_method IN ('telegram', 'sms', 'both')),
  role TEXT DEFAULT 'worker' CHECK (role IN ('worker', 'supervisor', 'manager')),
  is_active BOOLEAN DEFAULT TRUE,
  last_active_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_workers_farmer_id ON public.workers(farmer_id);
CREATE INDEX idx_workers_telegram_id ON public.workers(telegram_id);

-- Enable RLS
ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;

-- Policy: Farmers can only see their own workers
CREATE POLICY "Farmers can view own workers" ON public.workers
  FOR SELECT USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can insert own workers" ON public.workers
  FOR INSERT WITH CHECK (farmer_id = auth.uid());

CREATE POLICY "Farmers can update own workers" ON public.workers
  FOR UPDATE USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can delete own workers" ON public.workers
  FOR DELETE USING (farmer_id = auth.uid());
```

---

### 3. BATCHES (Flocks of Birds)

```sql
CREATE TABLE public.batches (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  
  -- Batch Details
  name TEXT NOT NULL, -- e.g., "Batch A", "January Layers"
  bird_type TEXT NOT NULL CHECK (bird_type IN ('layer', 'broiler')),
  initial_count INTEGER NOT NULL CHECK (initial_count > 0),
  current_count INTEGER NOT NULL CHECK (current_count >= 0),
  
  -- Dates
  start_date DATE NOT NULL,
  expected_end_date DATE, -- For broilers: ~42 days, For layers: ~18 months
  actual_end_date DATE,
  
  -- Costs
  chick_cost_per_bird DECIMAL(10, 2),
  total_chick_cost DECIMAL(10, 2),
  
  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'sold')),
  
  -- Metadata
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_batches_farmer_id ON public.batches(farmer_id);
CREATE INDEX idx_batches_status ON public.batches(status);
CREATE INDEX idx_batches_start_date ON public.batches(start_date);

-- Enable RLS
ALTER TABLE public.batches ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Farmers can view own batches" ON public.batches
  FOR SELECT USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can insert own batches" ON public.batches
  FOR INSERT WITH CHECK (farmer_id = auth.uid());

CREATE POLICY "Farmers can update own batches" ON public.batches
  FOR UPDATE USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can delete own batches" ON public.batches
  FOR DELETE USING (farmer_id = auth.uid());

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_batches_updated_at BEFORE UPDATE ON public.batches
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

### 4. DAILY RECORDS (Core Data from Workers)

```sql
CREATE TABLE public.daily_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  batch_id UUID REFERENCES public.batches(id) ON DELETE CASCADE NOT NULL,
  worker_id UUID REFERENCES public.workers(id) ON DELETE SET NULL, -- Who recorded this
  
  -- The actual data
  record_date DATE NOT NULL,
  mortality_count INTEGER DEFAULT 0 CHECK (mortality_count >= 0),
  eggs_collected INTEGER DEFAULT 0 CHECK (eggs_collected >= 0), -- For layers only
  feed_bags_used DECIMAL(5, 2) DEFAULT 0 CHECK (feed_bags_used >= 0),
  feed_kg_used DECIMAL(10, 2) DEFAULT 0 CHECK (feed_kg_used >= 0),
  
  -- Optional fields
  water_liters DECIMAL(10, 2),
  temperature_celsius DECIMAL(4, 1),
  humidity_percent DECIMAL(4, 1),
  sick_birds_count INTEGER DEFAULT 0,
  
  -- Media
  photo_urls TEXT[], -- Array of Supabase Storage URLs
  notes TEXT,
  
  -- Recording metadata
  recorded_via TEXT CHECK (recorded_via IN ('telegram', 'sms', 'web', 'voice')),
  telegram_message_id BIGINT, -- Original Telegram message ID
  voice_transcript TEXT, -- If recorded via voice
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure one record per batch per day
  UNIQUE(batch_id, record_date)
);

-- Indexes
CREATE INDEX idx_daily_records_batch_id ON public.daily_records(batch_id);
CREATE INDEX idx_daily_records_date ON public.daily_records(record_date);
CREATE INDEX idx_daily_records_worker_id ON public.daily_records(worker_id);

-- Enable RLS
ALTER TABLE public.daily_records ENABLE ROW LEVEL SECURITY;

-- Policy: Farmers can view records for their batches
CREATE POLICY "Farmers can view own batch records" ON public.daily_records
  FOR SELECT USING (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );

-- Policy: Workers can insert records for batches they're assigned to
CREATE POLICY "Workers can insert records" ON public.daily_records
  FOR INSERT WITH CHECK (
    batch_id IN (
      SELECT b.id FROM public.batches b
      JOIN public.workers w ON w.farmer_id = b.farmer_id
      WHERE w.id = worker_id
    )
  );

CREATE TRIGGER update_daily_records_updated_at BEFORE UPDATE ON public.daily_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

### 5. TRANSACTIONS (Income & Expenses)

```sql
CREATE TABLE public.transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL, -- Optional: link to specific batch
  
  -- Transaction details
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  category TEXT NOT NULL, -- 'egg_sale', 'bird_sale', 'feed_purchase', 'medication', 'chicks', 'labor', 'utilities', 'other'
  amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
  quantity DECIMAL(10, 2), -- e.g., 100 eggs, 50 birds, 10 bags
  unit_price DECIMAL(10, 2), -- Price per unit
  
  -- Details
  description TEXT,
  transaction_date DATE NOT NULL,
  payment_method TEXT, -- 'mobile_money', 'cash', 'bank_transfer', 'credit'
  
  -- Metadata
  recorded_by_worker_id UUID REFERENCES public.workers(id) ON DELETE SET NULL,
  receipt_url TEXT, -- Supabase Storage URL
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_transactions_farmer_id ON public.transactions(farmer_id);
CREATE INDEX idx_transactions_batch_id ON public.transactions(batch_id);
CREATE INDEX idx_transactions_date ON public.transactions(transaction_date);
CREATE INDEX idx_transactions_type ON public.transactions(type);

-- Enable RLS
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Farmers can view own transactions" ON public.transactions
  FOR SELECT USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can insert own transactions" ON public.transactions
  FOR INSERT WITH CHECK (farmer_id = auth.uid());

CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

---

### 6. VACCINATIONS & MEDICATIONS

```sql
CREATE TABLE public.health_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  batch_id UUID REFERENCES public.batches(id) ON DELETE CASCADE NOT NULL,
  
  -- Event details
  event_type TEXT NOT NULL CHECK (event_type IN ('vaccination', 'medication', 'treatment')),
  name TEXT NOT NULL, -- e.g., "Newcastle Disease Vaccine", "Antibiotics"
  
  -- Schedule
  scheduled_date DATE NOT NULL,
  actual_date DATE,
  is_completed BOOLEAN DEFAULT FALSE,
  
  -- Details
  dosage TEXT,
  birds_treated INTEGER,
  cost DECIMAL(10, 2),
  administered_by_worker_id UUID REFERENCES public.workers(id) ON DELETE SET NULL,
  
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_health_events_batch_id ON public.health_events(batch_id);
CREATE INDEX idx_health_events_scheduled_date ON public.health_events(scheduled_date);
CREATE INDEX idx_health_events_completed ON public.health_events(is_completed);

-- Enable RLS
ALTER TABLE public.health_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Farmers can view own health events" ON public.health_events
  FOR SELECT USING (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );

CREATE POLICY "Farmers can manage own health events" ON public.health_events
  FOR ALL USING (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );
```

---

### 7. ALERTS & NOTIFICATIONS

```sql
CREATE TABLE public.alerts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  batch_id UUID REFERENCES public.batches(id) ON DELETE CASCADE,
  
  -- Alert details
  type TEXT NOT NULL CHECK (type IN (
    'high_mortality', 
    'low_feed', 
    'vaccination_due', 
    'production_drop', 
    'batch_milestone',
    'subscription_expiring',
    'custom'
  )),
  severity TEXT DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  
  -- Status
  is_read BOOLEAN DEFAULT FALSE,
  is_dismissed BOOLEAN DEFAULT FALSE,
  
  -- Actions
  action_url TEXT, -- Link to relevant page
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_alerts_farmer_id ON public.alerts(farmer_id);
CREATE INDEX idx_alerts_is_read ON public.alerts(is_read);
CREATE INDEX idx_alerts_created_at ON public.alerts(created_at DESC);

-- Enable RLS
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Farmers can view own alerts" ON public.alerts
  FOR SELECT USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can update own alerts" ON public.alerts
  FOR UPDATE USING (farmer_id = auth.uid());
```

---

### 8. TELEGRAM BOT STATE (For Conversations)

```sql
CREATE TABLE public.telegram_conversations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  telegram_id BIGINT NOT NULL UNIQUE,
  worker_id UUID REFERENCES public.workers(id) ON DELETE CASCADE,
  
  -- Conversation state
  current_state TEXT, -- 'awaiting_confirmation', 'selecting_batch', 'recording_voice', etc.
  pending_data JSONB, -- Store temporary data during multi-step conversations
  
  -- Context
  last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  message_count INTEGER DEFAULT 0,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_telegram_conversations_telegram_id ON public.telegram_conversations(telegram_id);
CREATE INDEX idx_telegram_conversations_worker_id ON public.telegram_conversations(worker_id);

-- This table doesn't need RLS since it's only accessed by the Telegram bot service
```

---

### 9. SUBSCRIPTION & PAYMENTS

```sql
CREATE TABLE public.subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
  
  -- Plan details
  plan_type TEXT DEFAULT 'basic' CHECK (plan_type IN ('basic', 'premium')),
  status TEXT DEFAULT 'trial' CHECK (status IN ('trial', 'active', 'past_due', 'cancelled')),
  
  -- Billing
  amount_monthly DECIMAL(10, 2) DEFAULT 10.00,
  currency TEXT DEFAULT 'USD',
  
  -- Dates
  trial_ends_at TIMESTAMP WITH TIME ZONE,
  current_period_start TIMESTAMP WITH TIME ZONE,
  current_period_end TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  
  -- Payment provider details (Paystack, Stripe, etc.)
  payment_provider TEXT DEFAULT 'paystack',
  provider_customer_id TEXT, -- Paystack customer ID
  provider_subscription_id TEXT, -- Paystack subscription ID
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_subscriptions_farmer_id ON public.subscriptions(farmer_id);
CREATE INDEX idx_subscriptions_status ON public.subscriptions(status);

-- Enable RLS
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Farmers can view own subscription" ON public.subscriptions
  FOR SELECT USING (farmer_id = auth.uid());
```

---

### 10. PAYMENT HISTORY

```sql
CREATE TABLE public.payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
  
  -- Payment details
  amount DECIMAL(10, 2) NOT NULL,
  currency TEXT DEFAULT 'USD',
  status TEXT NOT NULL CHECK (status IN ('pending', 'success', 'failed', 'refunded')),
  
  -- Provider details
  payment_provider TEXT DEFAULT 'paystack',
  provider_payment_id TEXT, -- Paystack transaction reference
  payment_method TEXT, -- 'mobile_money', 'card'
  
  -- Metadata
  description TEXT,
  receipt_url TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_payments_farmer_id ON public.payments(farmer_id);
CREATE INDEX idx_payments_status ON public.payments(status);
CREATE INDEX idx_payments_created_at ON public.payments(created_at DESC);

-- Enable RLS
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Farmers can view own payments" ON public.payments
  FOR SELECT USING (farmer_id = auth.uid());
```

---

## COMPUTED VIEWS (For Easy Querying)

### View 1: Batch Summary Statistics

```sql
CREATE OR REPLACE VIEW batch_statistics AS
SELECT 
  b.id AS batch_id,
  b.farmer_id,
  b.name AS batch_name,
  b.bird_type,
  b.current_count,
  b.start_date,
  
  -- Mortality stats
  COALESCE(SUM(dr.mortality_count), 0) AS total_deaths,
  ROUND((COALESCE(SUM(dr.mortality_count), 0)::DECIMAL / NULLIF(b.initial_count, 0)) * 100, 2) AS mortality_rate_percent,
  
  -- Production stats (layers)
  COALESCE(SUM(dr.eggs_collected), 0) AS total_eggs,
  ROUND(AVG(dr.eggs_collected), 2) AS avg_eggs_per_day,
  
  -- Feed stats
  COALESCE(SUM(dr.feed_bags_used), 0) AS total_feed_bags,
  COALESCE(SUM(dr.feed_kg_used), 0) AS total_feed_kg,
  
  -- Age in days
  CURRENT_DATE - b.start_date AS age_in_days,
  
  -- Last recorded
  MAX(dr.record_date) AS last_record_date
  
FROM public.batches b
LEFT JOIN public.daily_records dr ON dr.batch_id = b.id
GROUP BY b.id, b.farmer_id, b.name, b.bird_type, b.current_count, b.start_date, b.initial_count;
```

### View 2: Financial Summary by Batch

```sql
CREATE OR REPLACE VIEW batch_financials AS
SELECT 
  b.id AS batch_id,
  b.farmer_id,
  b.name AS batch_name,
  
  -- Income
  COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) AS total_income,
  
  -- Expenses
  COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) AS total_expenses,
  
  -- Profit
  COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) - 
  COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) AS net_profit,
  
  -- Initial investment
  b.total_chick_cost AS initial_investment
  
FROM public.batches b
LEFT JOIN public.transactions t ON t.batch_id = b.id
GROUP BY b.id, b.farmer_id, b.name, b.total_chick_cost;
```

---

## SUPABASE EDGE FUNCTIONS (For Telegram Webhook)

You'll need to create a Supabase Edge Function to handle Telegram webhook:

**File: `supabase/functions/telegram-webhook/index.ts`**

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    const update = await req.json()
    
    // Handle incoming Telegram message
    if (update.message) {
      const message = update.message
      const telegramId = message.from.id
      const text = message.text
      
      // Find worker by telegram_id
      const { data: worker } = await supabase
        .from('workers')
        .select('*, batches!inner(*)')
        .eq('telegram_id', telegramId)
        .single()
      
      if (!worker) {
        // Send "Not registered" message
        await sendTelegramMessage(telegramId, "You're not registered. Ask your boss to add you.")
        return new Response(JSON.stringify({ ok: true }), { status: 200 })
      }
      
      // Parse the message
      const parsed = parseMessage(text)
      
      if (parsed) {
        // Save to daily_records
        const { error } = await supabase
          .from('daily_records')
          .insert({
            batch_id: worker.batches[0].id, // Assume first batch for now
            worker_id: worker.id,
            record_date: new Date().toISOString().split('T')[0],
            mortality_count: parsed.mortality,
            eggs_collected: parsed.eggs,
            feed_bags_used: parsed.feed,
            recorded_via: 'telegram',
            telegram_message_id: message.message_id
          })
        
        if (error) throw error
        
        // Send confirmation
        await sendTelegramMessage(
          telegramId,
          `✅ Recorded!\n🐔 Deaths: ${parsed.mortality}\n🥚 Eggs: ${parsed.eggs}\n🌾 Feed: ${parsed.feed} bags`
        )
      }
    }
    
    return new Response(JSON.stringify({ ok: true }), { status: 200 })
    
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})

function parseMessage(text: string) {
  // Simple parsing logic (implement your own)
  const mortality = parseInt(text.match(/(\d+)\s*(dead|died)/i)?.[1] || '0')
  const eggs = parseInt(text.match(/(\d+)\s*egg/i)?.[1] || '0')
  const feed = parseFloat(text.match(/(\d+)\s*(bag|sack)/i)?.[1] || '0')
  
  return { mortality, eggs, feed }
}

async function sendTelegramMessage(chatId: number, text: string) {
  const botToken = Deno.env.get('TELEGRAM_BOT_TOKEN')
  await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text })
  })
}
```

---



**You're ready to build! 🚀**

This schema handles:
✅ Multi-tenant (multiple farmers)
✅ Workers per farm
✅ Multiple batches per farm
✅ Daily records from Telegram/SMS/Web
✅ Financial tracking
✅ Health events (vaccinations)
✅ Alerts & notifications
✅ Subscriptions & payments
✅ Real-time updates
✅ Secure (RLS)
