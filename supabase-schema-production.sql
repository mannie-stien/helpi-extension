-- ============================================================================
-- POULTRYPRO: PRODUCTION-READY SUPABASE DATABASE SCHEMA
-- ============================================================================
-- Version: 1.0.0
-- Description: Complete database schema for poultry farm management system
-- Features: Multi-tenant, RLS enabled, Telegram bot integration, subscriptions
-- ============================================================================

-- ============================================================================
-- SECTION 1: EXTENSIONS & SETUP
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- SECTION 2: UTILITY FUNCTIONS
-- ============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update batch current_count based on mortality
CREATE OR REPLACE FUNCTION update_batch_count()
RETURNS TRIGGER AS $$
DECLARE
  batch_initial_count INTEGER;
  total_mortality INTEGER;
BEGIN
  -- Get initial count and total mortality for the batch
  SELECT b.initial_count, COALESCE(SUM(dr.mortality_count), 0)
  INTO batch_initial_count, total_mortality
  FROM public.batches b
  LEFT JOIN public.daily_records dr ON dr.batch_id = b.id
  WHERE b.id = NEW.batch_id
  GROUP BY b.id, b.initial_count;
  
  -- Update current count
  UPDATE public.batches
  SET current_count = batch_initial_count - total_mortality
  WHERE id = NEW.batch_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create alert for high mortality
CREATE OR REPLACE FUNCTION check_mortality_alert()
RETURNS TRIGGER AS $$
DECLARE
  batch_record RECORD;
  mortality_rate DECIMAL;
BEGIN
  -- Get batch info
  SELECT b.*, b.current_count::DECIMAL / NULLIF(b.initial_count, 0) AS survival_rate
  INTO batch_record
  FROM public.batches b
  WHERE b.id = NEW.batch_id;
  
  -- Check if mortality is high (more than 5% in a single day)
  IF NEW.mortality_count > 0 AND 
     (NEW.mortality_count::DECIMAL / NULLIF(batch_record.initial_count, 0)) > 0.05 THEN
    
    INSERT INTO public.alerts (farmer_id, batch_id, type, severity, title, message)
    VALUES (
      batch_record.farmer_id,
      NEW.batch_id,
      'high_mortality',
      'critical',
      'High Mortality Alert',
      format('Batch "%s" recorded %s deaths on %s. This is %.1f%% of the flock.',
        batch_record.name,
        NEW.mortality_count,
        NEW.record_date,
        (NEW.mortality_count::DECIMAL / NULLIF(batch_record.initial_count, 0)) * 100
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 3: CORE TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1 USER PROFILES (extends auth.users)
-- ----------------------------------------------------------------------------

CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  phone TEXT,
  farm_name TEXT,
  subscription_status TEXT DEFAULT 'trial' CHECK (subscription_status IN ('trial', 'active', 'cancelled', 'past_due')),
  subscription_ends_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_subscription_status ON public.profiles(subscription_status);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own profile" 
  ON public.profiles FOR SELECT 
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" 
  ON public.profiles FOR UPDATE 
  USING (auth.uid() = id);

-- Triggers
CREATE TRIGGER update_profiles_updated_at 
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to auto-create profile on signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ----------------------------------------------------------------------------
-- 3.2 WORKERS (Farm Employees)
-- ----------------------------------------------------------------------------

CREATE TABLE public.workers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  telegram_id BIGINT UNIQUE,
  telegram_username TEXT,
  communication_method TEXT DEFAULT 'telegram' CHECK (communication_method IN ('telegram', 'sms', 'both')),
  role TEXT DEFAULT 'worker' CHECK (role IN ('worker', 'supervisor', 'manager')),
  is_active BOOLEAN DEFAULT TRUE,
  last_active_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT worker_name_not_empty CHECK (LENGTH(TRIM(name)) > 0)
);

-- Indexes
CREATE INDEX idx_workers_farmer_id ON public.workers(farmer_id);
CREATE INDEX idx_workers_telegram_id ON public.workers(telegram_id) WHERE telegram_id IS NOT NULL;
CREATE INDEX idx_workers_is_active ON public.workers(is_active);

-- Enable RLS
ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Farmers can view own workers" 
  ON public.workers FOR SELECT 
  USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can insert own workers" 
  ON public.workers FOR INSERT 
  WITH CHECK (farmer_id = auth.uid());

CREATE POLICY "Farmers can update own workers" 
  ON public.workers FOR UPDATE 
  USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can delete own workers" 
  ON public.workers FOR DELETE 
  USING (farmer_id = auth.uid());

-- Triggers
CREATE TRIGGER update_workers_updated_at 
  BEFORE UPDATE ON public.workers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 3.3 BATCHES (Flocks of Birds)
-- ----------------------------------------------------------------------------

CREATE TABLE public.batches (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  
  -- Batch Details
  name TEXT NOT NULL,
  bird_type TEXT NOT NULL CHECK (bird_type IN ('layer', 'broiler')),
  initial_count INTEGER NOT NULL CHECK (initial_count > 0),
  current_count INTEGER NOT NULL CHECK (current_count >= 0),
  
  -- Dates
  start_date DATE NOT NULL,
  expected_end_date DATE,
  actual_end_date DATE,
  
  -- Costs
  chick_cost_per_bird DECIMAL(10, 2) CHECK (chick_cost_per_bird >= 0),
  total_chick_cost DECIMAL(10, 2) CHECK (total_chick_cost >= 0),
  
  -- Status
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'sold')),
  
  -- Metadata
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT batch_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
  CONSTRAINT batch_current_count_valid CHECK (current_count <= initial_count),
  CONSTRAINT batch_expected_end_after_start CHECK (expected_end_date IS NULL OR expected_end_date > start_date),
  CONSTRAINT batch_actual_end_after_start CHECK (actual_end_date IS NULL OR actual_end_date >= start_date),
  CONSTRAINT batch_total_cost_matches CHECK (
    total_chick_cost IS NULL OR 
    chick_cost_per_bird IS NULL OR 
    total_chick_cost = chick_cost_per_bird * initial_count
  )
);

-- Indexes
CREATE INDEX idx_batches_farmer_id ON public.batches(farmer_id);
CREATE INDEX idx_batches_status ON public.batches(status);
CREATE INDEX idx_batches_start_date ON public.batches(start_date);
CREATE INDEX idx_batches_bird_type ON public.batches(bird_type);

-- Enable RLS
ALTER TABLE public.batches ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Farmers can view own batches" 
  ON public.batches FOR SELECT 
  USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can insert own batches" 
  ON public.batches FOR INSERT 
  WITH CHECK (farmer_id = auth.uid());

CREATE POLICY "Farmers can update own batches" 
  ON public.batches FOR UPDATE 
  USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can delete own batches" 
  ON public.batches FOR DELETE 
  USING (farmer_id = auth.uid());

-- Triggers
CREATE TRIGGER update_batches_updated_at 
  BEFORE UPDATE ON public.batches
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 3.4 BATCH WORKERS (Assignment of workers to batches)
-- ----------------------------------------------------------------------------

CREATE TABLE public.batch_workers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  batch_id UUID REFERENCES public.batches(id) ON DELETE CASCADE NOT NULL,
  worker_id UUID REFERENCES public.workers(id) ON DELETE CASCADE NOT NULL,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_primary BOOLEAN DEFAULT FALSE,
  
  -- Ensure unique assignment
  UNIQUE(batch_id, worker_id)
);

-- Indexes
CREATE INDEX idx_batch_workers_batch_id ON public.batch_workers(batch_id);
CREATE INDEX idx_batch_workers_worker_id ON public.batch_workers(worker_id);

-- Enable RLS
ALTER TABLE public.batch_workers ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Farmers can view own batch workers" 
  ON public.batch_workers FOR SELECT 
  USING (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );

CREATE POLICY "Farmers can manage own batch workers" 
  ON public.batch_workers FOR ALL 
  USING (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );

-- ----------------------------------------------------------------------------
-- 3.5 DAILY RECORDS (Core Data from Workers)
-- ----------------------------------------------------------------------------

CREATE TABLE public.daily_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  batch_id UUID REFERENCES public.batches(id) ON DELETE CASCADE NOT NULL,
  worker_id UUID REFERENCES public.workers(id) ON DELETE SET NULL,
  
  -- The actual data
  record_date DATE NOT NULL,
  mortality_count INTEGER DEFAULT 0 CHECK (mortality_count >= 0),
  eggs_collected INTEGER DEFAULT 0 CHECK (eggs_collected >= 0),
  feed_bags_used DECIMAL(5, 2) DEFAULT 0 CHECK (feed_bags_used >= 0),
  feed_kg_used DECIMAL(10, 2) DEFAULT 0 CHECK (feed_kg_used >= 0),
  
  -- Optional fields
  water_liters DECIMAL(10, 2) CHECK (water_liters IS NULL OR water_liters >= 0),
  temperature_celsius DECIMAL(4, 1),
  humidity_percent DECIMAL(4, 1) CHECK (humidity_percent IS NULL OR (humidity_percent >= 0 AND humidity_percent <= 100)),
  sick_birds_count INTEGER DEFAULT 0 CHECK (sick_birds_count >= 0),
  
  -- Media
  photo_urls TEXT[],
  notes TEXT,
  
  -- Recording metadata
  recorded_via TEXT CHECK (recorded_via IN ('telegram', 'sms', 'web', 'voice')),
  telegram_message_id BIGINT,
  voice_transcript TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure one record per batch per day
  UNIQUE(batch_id, record_date)
);

-- Indexes
CREATE INDEX idx_daily_records_batch_id ON public.daily_records(batch_id);
CREATE INDEX idx_daily_records_date ON public.daily_records(record_date DESC);
CREATE INDEX idx_daily_records_worker_id ON public.daily_records(worker_id);
CREATE INDEX idx_daily_records_batch_date ON public.daily_records(batch_id, record_date DESC);

-- Enable RLS
ALTER TABLE public.daily_records ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Farmers can view own batch records" 
  ON public.daily_records FOR SELECT 
  USING (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );

CREATE POLICY "Farmers can insert own batch records" 
  ON public.daily_records FOR INSERT 
  WITH CHECK (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );

CREATE POLICY "Farmers can update own batch records" 
  ON public.daily_records FOR UPDATE 
  USING (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );

CREATE POLICY "Farmers can delete own batch records" 
  ON public.daily_records FOR DELETE 
  USING (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );

-- Triggers
CREATE TRIGGER update_daily_records_updated_at 
  BEFORE UPDATE ON public.daily_records
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_batch_count_on_record 
  AFTER INSERT OR UPDATE ON public.daily_records
  FOR EACH ROW EXECUTE FUNCTION update_batch_count();

CREATE TRIGGER check_mortality_alert_trigger 
  AFTER INSERT ON public.daily_records
  FOR EACH ROW EXECUTE FUNCTION check_mortality_alert();

-- ----------------------------------------------------------------------------
-- 3.6 TRANSACTIONS (Income & Expenses)
-- ----------------------------------------------------------------------------

CREATE TABLE public.transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
  
  -- Transaction details
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  category TEXT NOT NULL,
  amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
  quantity DECIMAL(10, 2) CHECK (quantity IS NULL OR quantity > 0),
  unit_price DECIMAL(10, 2) CHECK (unit_price IS NULL OR unit_price > 0),
  
  -- Details
  description TEXT,
  transaction_date DATE NOT NULL,
  payment_method TEXT CHECK (payment_method IN ('mobile_money', 'cash', 'bank_transfer', 'credit', 'other')),
  
  -- Metadata
  recorded_by_worker_id UUID REFERENCES public.workers(id) ON DELETE SET NULL,
  receipt_url TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT transaction_amount_quantity_match CHECK (
    (quantity IS NULL AND unit_price IS NULL) OR
    (quantity IS NOT NULL AND unit_price IS NOT NULL AND ABS(amount - (quantity * unit_price)) < 0.01)
  )
);

-- Indexes
CREATE INDEX idx_transactions_farmer_id ON public.transactions(farmer_id);
CREATE INDEX idx_transactions_batch_id ON public.transactions(batch_id);
CREATE INDEX idx_transactions_date ON public.transactions(transaction_date DESC);
CREATE INDEX idx_transactions_type ON public.transactions(type);
CREATE INDEX idx_transactions_category ON public.transactions(category);

-- Enable RLS
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Farmers can view own transactions" 
  ON public.transactions FOR SELECT 
  USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can insert own transactions" 
  ON public.transactions FOR INSERT 
  WITH CHECK (farmer_id = auth.uid());

CREATE POLICY "Farmers can update own transactions" 
  ON public.transactions FOR UPDATE 
  USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can delete own transactions" 
  ON public.transactions FOR DELETE 
  USING (farmer_id = auth.uid());

-- Triggers
CREATE TRIGGER update_transactions_updated_at 
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 3.7 HEALTH EVENTS (Vaccinations & Medications)
-- ----------------------------------------------------------------------------

CREATE TABLE public.health_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  batch_id UUID REFERENCES public.batches(id) ON DELETE CASCADE NOT NULL,
  
  -- Event details
  event_type TEXT NOT NULL CHECK (event_type IN ('vaccination', 'medication', 'treatment')),
  name TEXT NOT NULL,
  
  -- Schedule
  scheduled_date DATE NOT NULL,
  actual_date DATE,
  is_completed BOOLEAN DEFAULT FALSE,
  
  -- Details
  dosage TEXT,
  birds_treated INTEGER CHECK (birds_treated IS NULL OR birds_treated > 0),
  cost DECIMAL(10, 2) CHECK (cost IS NULL OR cost >= 0),
  administered_by_worker_id UUID REFERENCES public.workers(id) ON DELETE SET NULL,
  
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT health_event_name_not_empty CHECK (LENGTH(TRIM(name)) > 0),
  CONSTRAINT health_event_actual_date_valid CHECK (
    actual_date IS NULL OR is_completed = TRUE
  )
);

-- Indexes
CREATE INDEX idx_health_events_batch_id ON public.health_events(batch_id);
CREATE INDEX idx_health_events_scheduled_date ON public.health_events(scheduled_date);
CREATE INDEX idx_health_events_completed ON public.health_events(is_completed);

-- Enable RLS
ALTER TABLE public.health_events ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Farmers can view own health events" 
  ON public.health_events FOR SELECT 
  USING (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );

CREATE POLICY "Farmers can manage own health events" 
  ON public.health_events FOR ALL 
  USING (
    batch_id IN (SELECT id FROM public.batches WHERE farmer_id = auth.uid())
  );

-- Triggers
CREATE TRIGGER update_health_events_updated_at 
  BEFORE UPDATE ON public.health_events
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 3.8 ALERTS & NOTIFICATIONS
-- ----------------------------------------------------------------------------

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
  action_url TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_alerts_farmer_id ON public.alerts(farmer_id);
CREATE INDEX idx_alerts_is_read ON public.alerts(is_read);
CREATE INDEX idx_alerts_created_at ON public.alerts(created_at DESC);
CREATE INDEX idx_alerts_severity ON public.alerts(severity);

-- Enable RLS
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Farmers can view own alerts" 
  ON public.alerts FOR SELECT 
  USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can update own alerts" 
  ON public.alerts FOR UPDATE 
  USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can delete own alerts" 
  ON public.alerts FOR DELETE 
  USING (farmer_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 3.9 TELEGRAM CONVERSATIONS (Bot State Management)
-- ----------------------------------------------------------------------------

CREATE TABLE public.telegram_conversations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  telegram_id BIGINT NOT NULL UNIQUE,
  worker_id UUID REFERENCES public.workers(id) ON DELETE CASCADE,
  
  -- Conversation state
  current_state TEXT,
  pending_data JSONB,
  
  -- Context
  last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  message_count INTEGER DEFAULT 0 CHECK (message_count >= 0),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_telegram_conversations_telegram_id ON public.telegram_conversations(telegram_id);
CREATE INDEX idx_telegram_conversations_worker_id ON public.telegram_conversations(worker_id);

-- Note: This table doesn't need RLS as it's accessed by the Telegram bot service
-- using service role key

-- Triggers
CREATE TRIGGER update_telegram_conversations_updated_at 
  BEFORE UPDATE ON public.telegram_conversations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 3.10 SUBSCRIPTIONS
-- ----------------------------------------------------------------------------

CREATE TABLE public.subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
  
  -- Plan details
  plan_type TEXT DEFAULT 'basic' CHECK (plan_type IN ('basic', 'premium')),
  status TEXT DEFAULT 'trial' CHECK (status IN ('trial', 'active', 'past_due', 'cancelled')),
  
  -- Billing
  amount_monthly DECIMAL(10, 2) DEFAULT 10.00 CHECK (amount_monthly >= 0),
  currency TEXT DEFAULT 'USD',
  
  -- Dates
  trial_ends_at TIMESTAMP WITH TIME ZONE,
  current_period_start TIMESTAMP WITH TIME ZONE,
  current_period_end TIMESTAMP WITH TIME ZONE,
  cancelled_at TIMESTAMP WITH TIME ZONE,
  
  -- Payment provider details
  payment_provider TEXT DEFAULT 'paystack',
  provider_customer_id TEXT,
  provider_subscription_id TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT subscription_period_valid CHECK (
    current_period_start IS NULL OR 
    current_period_end IS NULL OR 
    current_period_end > current_period_start
  )
);

-- Indexes
CREATE INDEX idx_subscriptions_farmer_id ON public.subscriptions(farmer_id);
CREATE INDEX idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX idx_subscriptions_provider_customer_id ON public.subscriptions(provider_customer_id);

-- Enable RLS
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Farmers can view own subscription" 
  ON public.subscriptions FOR SELECT 
  USING (farmer_id = auth.uid());

CREATE POLICY "Farmers can update own subscription" 
  ON public.subscriptions FOR UPDATE 
  USING (farmer_id = auth.uid());

-- Triggers
CREATE TRIGGER update_subscriptions_updated_at 
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 3.11 PAYMENT HISTORY
-- ----------------------------------------------------------------------------

CREATE TABLE public.payments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  farmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  subscription_id UUID REFERENCES public.subscriptions(id) ON DELETE SET NULL,
  
  -- Payment details
  amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
  currency TEXT DEFAULT 'USD',
  status TEXT NOT NULL CHECK (status IN ('pending', 'success', 'failed', 'refunded')),
  
  -- Provider details
  payment_provider TEXT DEFAULT 'paystack',
  provider_payment_id TEXT,
  payment_method TEXT,
  
  -- Metadata
  description TEXT,
  receipt_url TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_payments_farmer_id ON public.payments(farmer_id);
CREATE INDEX idx_payments_subscription_id ON public.payments(subscription_id);
CREATE INDEX idx_payments_status ON public.payments(status);
CREATE INDEX idx_payments_created_at ON public.payments(created_at DESC);
CREATE INDEX idx_payments_provider_payment_id ON public.payments(provider_payment_id);

-- Enable RLS
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Farmers can view own payments" 
  ON public.payments FOR SELECT 
  USING (farmer_id = auth.uid());

-- ============================================================================
-- SECTION 4: VIEWS FOR ANALYTICS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1 Batch Statistics View
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW batch_statistics AS
SELECT 
  b.id AS batch_id,
  b.farmer_id,
  b.name AS batch_name,
  b.bird_type,
  b.status,
  b.initial_count,
  b.current_count,
  b.start_date,
  b.expected_end_date,
  
  -- Mortality stats
  COALESCE(SUM(dr.mortality_count), 0) AS total_deaths,
  ROUND(
    (COALESCE(SUM(dr.mortality_count), 0)::DECIMAL / NULLIF(b.initial_count, 0)) * 100, 
    2
  ) AS mortality_rate_percent,
  
  -- Production stats (layers)
  COALESCE(SUM(dr.eggs_collected), 0) AS total_eggs,
  ROUND(COALESCE(AVG(dr.eggs_collected), 0), 2) AS avg_eggs_per_day,
  
  -- Feed stats
  COALESCE(SUM(dr.feed_bags_used), 0) AS total_feed_bags,
  COALESCE(SUM(dr.feed_kg_used), 0) AS total_feed_kg,
  ROUND(
    COALESCE(SUM(dr.feed_kg_used), 0) / NULLIF(b.current_count, 0),
    2
  ) AS feed_per_bird_kg,
  
  -- Health stats
  COALESCE(SUM(dr.sick_birds_count), 0) AS total_sick_birds,
  
  -- Age in days
  CURRENT_DATE - b.start_date AS age_in_days,
  
  -- Last recorded
  MAX(dr.record_date) AS last_record_date,
  COUNT(dr.id) AS total_records
  
FROM public.batches b
LEFT JOIN public.daily_records dr ON dr.batch_id = b.id
GROUP BY 
  b.id, b.farmer_id, b.name, b.bird_type, b.status,
  b.initial_count, b.current_count, b.start_date, b.expected_end_date;

-- ----------------------------------------------------------------------------
-- 4.2 Financial Summary by Batch View
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW batch_financials AS
SELECT 
  b.id AS batch_id,
  b.farmer_id,
  b.name AS batch_name,
  b.bird_type,
  b.status,
  
  -- Income
  COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) AS total_income,
  
  -- Expenses
  COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) AS total_expenses,
  
  -- Profit
  COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) - 
  COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) AS net_profit,
  
  -- Initial investment
  COALESCE(b.total_chick_cost, 0) AS initial_investment,
  
  -- ROI
  CASE 
    WHEN b.total_chick_cost > 0 THEN
      ROUND(
        ((COALESCE(SUM(CASE WHEN t.type = 'income' THEN t.amount ELSE 0 END), 0) - 
          COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0)) / 
         b.total_chick_cost) * 100,
        2
      )
    ELSE NULL
  END AS roi_percent
  
FROM public.batches b
LEFT JOIN public.transactions t ON t.batch_id = b.id
GROUP BY b.id, b.farmer_id, b.name, b.bird_type, b.status, b.total_chick_cost;

-- ----------------------------------------------------------------------------
-- 4.3 Worker Performance View
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW worker_performance AS
SELECT 
  w.id AS worker_id,
  w.farmer_id,
  w.name AS worker_name,
  w.role,
  w.is_active,
  
  -- Record stats
  COUNT(dr.id) AS total_records,
  MAX(dr.record_date) AS last_record_date,
  MIN(dr.record_date) AS first_record_date,
  
  -- Assigned batches
  COUNT(DISTINCT bw.batch_id) AS assigned_batches_count
  
FROM public.workers w
LEFT JOIN public.daily_records dr ON dr.worker_id = w.id
LEFT JOIN public.batch_workers bw ON bw.worker_id = w.id
GROUP BY w.id, w.farmer_id, w.name, w.role, w.is_active;

-- ----------------------------------------------------------------------------
-- 4.4 Daily Summary View
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW daily_summary AS
SELECT 
  dr.record_date,
  b.farmer_id,
  b.id AS batch_id,
  b.name AS batch_name,
  b.bird_type,
  
  dr.mortality_count,
  dr.eggs_collected,
  dr.feed_bags_used,
  dr.feed_kg_used,
  dr.sick_birds_count,
  
  w.name AS recorded_by,
  dr.recorded_via,
  dr.created_at
  
FROM public.daily_records dr
JOIN public.batches b ON b.id = dr.batch_id
LEFT JOIN public.workers w ON w.id = dr.worker_id
ORDER BY dr.record_date DESC, dr.created_at DESC;

-- ============================================================================
-- SECTION 5: HELPER FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.1 Function to get farmer's dashboard stats
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_farmer_dashboard_stats(farmer_uuid UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'total_batches', (SELECT COUNT(*) FROM public.batches WHERE farmer_id = farmer_uuid),
    'active_batches', (SELECT COUNT(*) FROM public.batches WHERE farmer_id = farmer_uuid AND status = 'active'),
    'total_birds', (SELECT COALESCE(SUM(current_count), 0) FROM public.batches WHERE farmer_id = farmer_uuid AND status = 'active'),
    'total_workers', (SELECT COUNT(*) FROM public.workers WHERE farmer_id = farmer_uuid AND is_active = TRUE),
    'unread_alerts', (SELECT COUNT(*) FROM public.alerts WHERE farmer_id = farmer_uuid AND is_read = FALSE),
    'total_income_this_month', (
      SELECT COALESCE(SUM(amount), 0) 
      FROM public.transactions 
      WHERE farmer_id = farmer_uuid 
        AND type = 'income' 
        AND transaction_date >= DATE_TRUNC('month', CURRENT_DATE)
    ),
    'total_expenses_this_month', (
      SELECT COALESCE(SUM(amount), 0) 
      FROM public.transactions 
      WHERE farmer_id = farmer_uuid 
        AND type = 'expense' 
        AND transaction_date >= DATE_TRUNC('month', CURRENT_DATE)
    )
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 5.2 Function to get batch health score
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION get_batch_health_score(batch_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
  score INTEGER := 100;
  mortality_rate DECIMAL;
  days_since_record INTEGER;
BEGIN
  -- Get mortality rate
  SELECT 
    (COALESCE(SUM(dr.mortality_count), 0)::DECIMAL / NULLIF(b.initial_count, 0)) * 100
  INTO mortality_rate
  FROM public.batches b
  LEFT JOIN public.daily_records dr ON dr.batch_id = b.id
  WHERE b.id = batch_uuid
  GROUP BY b.id, b.initial_count;
  
  -- Deduct points for high mortality
  IF mortality_rate > 10 THEN
    score := score - 30;
  ELSIF mortality_rate > 5 THEN
    score := score - 15;
  END IF;
  
  -- Check days since last record
  SELECT CURRENT_DATE - MAX(record_date)
  INTO days_since_record
  FROM public.daily_records
  WHERE batch_id = batch_uuid;
  
  -- Deduct points for missing records
  IF days_since_record > 3 THEN
    score := score - 20;
  ELSIF days_since_record > 1 THEN
    score := score - 10;
  END IF;
  
  RETURN GREATEST(score, 0);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 6: STORAGE BUCKETS SETUP
-- ============================================================================

-- Note: Run these commands in Supabase Dashboard or via Supabase CLI
-- They create storage buckets for photos and receipts

-- Create storage bucket for batch photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('batch-photos', 'batch-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Create storage bucket for receipts
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for batch photos
CREATE POLICY "Farmers can upload batch photos"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'batch-photos' AND
  auth.uid()::TEXT = (storage.foldername(name))[1]
);

CREATE POLICY "Anyone can view batch photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'batch-photos');

CREATE POLICY "Farmers can delete own batch photos"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'batch-photos' AND
  auth.uid()::TEXT = (storage.foldername(name))[1]
);

-- Storage policies for receipts
CREATE POLICY "Farmers can upload receipts"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'receipts' AND
  auth.uid()::TEXT = (storage.foldername(name))[1]
);

CREATE POLICY "Farmers can view own receipts"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'receipts' AND
  auth.uid()::TEXT = (storage.foldername(name))[1]
);

CREATE POLICY "Farmers can delete own receipts"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'receipts' AND
  auth.uid()::TEXT = (storage.foldername(name))[1]
);

-- ============================================================================
-- SECTION 7: INITIAL SEED DATA (OPTIONAL)
-- ============================================================================

-- Common transaction categories
CREATE TABLE IF NOT EXISTS public.transaction_categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  name TEXT NOT NULL,
  description TEXT,
  is_default BOOLEAN DEFAULT TRUE,
  UNIQUE(type, name)
);

INSERT INTO public.transaction_categories (type, name, description) VALUES
  ('income', 'egg_sale', 'Revenue from selling eggs'),
  ('income', 'bird_sale', 'Revenue from selling birds'),
  ('income', 'manure_sale', 'Revenue from selling manure'),
  ('expense', 'feed_purchase', 'Cost of purchasing feed'),
  ('expense', 'chicks', 'Cost of purchasing chicks'),
  ('expense', 'medication', 'Cost of medications and vaccines'),
  ('expense', 'labor', 'Labor and worker wages'),
  ('expense', 'utilities', 'Water, electricity, etc.'),
  ('expense', 'equipment', 'Equipment and tools'),
  ('expense', 'maintenance', 'Repairs and maintenance'),
  ('expense', 'other', 'Other miscellaneous expenses')
ON CONFLICT (type, name) DO NOTHING;

-- ============================================================================
-- SCHEMA DEPLOYMENT COMPLETE
-- ============================================================================

-- Verification queries (run these to verify setup)
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
-- SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' ORDER BY table_name, ordinal_position;
-- SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename;

-- ============================================================================
-- NOTES FOR DEPLOYMENT
-- ============================================================================
-- 1. Run this entire script in Supabase SQL Editor
-- 2. Enable Realtime for tables you want to subscribe to in the frontend
-- 3. Set up environment variables for Telegram bot
-- 4. Deploy Edge Function for Telegram webhook
-- 5. Configure authentication providers in Supabase Dashboard
-- 6. Set up payment provider (Paystack/Stripe) webhooks
-- ============================================================================
