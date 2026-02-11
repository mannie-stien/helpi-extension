-- ============================================================================
-- POULTRYPRO LEAN SCHEMA
-- Designed from research: 5 pain points, minimum fields, maximum money signal
-- Multi-tenant, multi-house, multi-batch, production-ready
-- ============================================================================

-- ============================================================================
-- EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- TABLE 1: FARMERS (Multi-tenancy root)
-- Every row in every table traces back to one farmer.
-- ============================================================================
CREATE TABLE farmers (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone           TEXT,
    name            TEXT NOT NULL,
    farm_name       TEXT,
    whatsapp_id     TEXT UNIQUE,                -- WhatsApp Business API identifier
    timezone        TEXT DEFAULT 'Africa/Accra',
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_farmers_whatsapp ON farmers(whatsapp_id) WHERE whatsapp_id IS NOT NULL;

-- ============================================================================
-- TABLE 2: HOUSES (Edge case from research: per-house tracking)
-- "Theft or overfeeding in one house is masked by correct usage in another
--  if combined" — Pain #1, Section 5
-- Optional: small farms may have only one house.
-- ============================================================================
CREATE TABLE houses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id       UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,               -- "House A", "big shed", etc.
    is_active       BOOLEAN DEFAULT TRUE NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(farmer_id, name)
);

CREATE INDEX idx_houses_farmer ON houses(farmer_id);

-- ============================================================================
-- TABLE 3: BATCHES (Cross-schema: serves Pain #1, #2, #5)
-- "A unified batch page at batch start could capture: batch ID, start date,
--  supplier, starting count, target sell date — all 5 fields in one
--  2-minute setup event" — Cross-Schema Observation #1
-- ============================================================================
CREATE TABLE batches (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id           UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    house_id            UUID REFERENCES houses(id) ON DELETE SET NULL,
    name                TEXT NOT NULL,               -- "Batch 7", "March batch"
    bird_type           TEXT NOT NULL CHECK (bird_type IN ('broiler', 'layer')),
    chick_supplier      TEXT,                        -- Pain #5: highest-value pattern variable
    initial_count       INTEGER NOT NULL CHECK (initial_count > 0),
    current_count       INTEGER NOT NULL CHECK (current_count >= 0),
    start_date          DATE NOT NULL,
    target_end_date     DATE,                        -- Pain #2: planning anchor
    actual_end_date     DATE,                        -- Pain #2: post-batch analysis
    actual_sell_price   NUMERIC(10,2),               -- Pain #2: GH₵/kg at sale
    status              TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'sold')),
    created_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(farmer_id, name),
    CHECK (actual_end_date IS NULL OR actual_end_date >= start_date),
    CHECK (target_end_date IS NULL OR target_end_date >= start_date)
);

CREATE INDEX idx_batches_farmer ON batches(farmer_id);
CREATE INDEX idx_batches_farmer_active ON batches(farmer_id) WHERE status = 'active';
CREATE INDEX idx_batches_supplier ON batches(farmer_id, chick_supplier) WHERE chick_supplier IS NOT NULL;

-- ============================================================================
-- TABLE 4: DAILY LOGS (Merged daily input: Pain #1 + #5)
-- "Pains #1 and #5 require one number per day" — Cross-Schema Observation #2
-- One row per batch per day. Under 45 seconds to record.
-- ============================================================================
CREATE TABLE daily_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    batch_id        UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    farmer_id       UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    log_date        DATE NOT NULL,
    -- Pain #1: Feed
    feed_bags       NUMERIC(5,2) DEFAULT 0 NOT NULL CHECK (feed_bags >= 0),
    feed_scoops     NUMERIC(5,1),                    -- Optional secondary unit
    -- Pain #5: Mortality
    deaths          INTEGER DEFAULT 0 NOT NULL CHECK (deaths >= 0),
    -- Pain #2 (layers only): Production
    eggs_crates     NUMERIC(6,1),                    -- Weekly for layers; NULL for broilers
    -- Context
    notes           TEXT,
    recorded_via    TEXT DEFAULT 'whatsapp' CHECK (recorded_via IN ('whatsapp', 'sms', 'web', 'voice')),
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(batch_id, log_date)
);

CREATE INDEX idx_daily_logs_batch_date ON daily_logs(batch_id, log_date DESC);
CREATE INDEX idx_daily_logs_farmer ON daily_logs(farmer_id);
CREATE INDEX idx_daily_logs_date ON daily_logs(farmer_id, log_date DESC);

-- ============================================================================
-- TABLE 5: FEED DELIVERIES (Pain #1: inventory tracking)
-- "Enables running inventory: bought minus used = should have" — Pain #1 Field 5
-- Without this, no theft detection.
-- ============================================================================
CREATE TABLE feed_deliveries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id       UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    house_id        UUID REFERENCES houses(id) ON DELETE SET NULL,
    delivery_date   DATE NOT NULL,
    bags_received   NUMERIC(6,2) NOT NULL CHECK (bags_received > 0),
    supplier_name   TEXT,                            -- Overlaps with Pain #3 supplier
    cost_per_bag    NUMERIC(10,2),                   -- Deliberately excluded from minimum, but useful
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_feed_deliveries_farmer ON feed_deliveries(farmer_id, delivery_date DESC);
CREATE INDEX idx_feed_deliveries_house ON feed_deliveries(house_id, delivery_date DESC) WHERE house_id IS NOT NULL;

-- ============================================================================
-- TABLE 6: SUPPLIER LEDGER (Pain #3: payment tracking)
-- "Balance per supplier = Sum of all credit purchases − Sum of all payments"
-- Each row is ONE event: either a purchase (+) or a payment (−).
-- ============================================================================
CREATE TABLE supplier_ledger (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id       UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    supplier_name   TEXT NOT NULL,
    txn_date        DATE NOT NULL,
    txn_type        TEXT NOT NULL CHECK (txn_type IN ('purchase', 'payment')),
    amount          NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    is_credit       BOOLEAN DEFAULT TRUE NOT NULL,   -- Only matters for purchases
    due_date        DATE,                            -- Only for credit purchases
    reference       TEXT,                            -- MoMo ref, receipt number, etc.
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    CHECK (
        (txn_type = 'purchase') OR
        (txn_type = 'payment' AND due_date IS NULL)
    )
);

CREATE INDEX idx_supplier_ledger_farmer ON supplier_ledger(farmer_id);
CREATE INDEX idx_supplier_ledger_supplier ON supplier_ledger(farmer_id, supplier_name);
CREATE INDEX idx_supplier_ledger_due ON supplier_ledger(farmer_id, due_date)
    WHERE txn_type = 'purchase' AND is_credit = TRUE AND due_date IS NOT NULL;

-- ============================================================================
-- TABLE 7: WORKERS (Pain #4: labor cost tracking)
-- ============================================================================
CREATE TABLE workers (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id       UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    phone           TEXT,
    pay_type        TEXT NOT NULL DEFAULT 'daily' CHECK (pay_type IN ('daily', 'monthly', 'piece')),
    daily_rate      NUMERIC(10,2) CHECK (daily_rate > 0),       -- For daily/monthly workers
    piece_rate      NUMERIC(10,2) CHECK (piece_rate > 0),       -- For piece-rate workers
    rate_effective  DATE NOT NULL DEFAULT CURRENT_DATE,          -- When this rate started
    is_active       BOOLEAN DEFAULT TRUE NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(farmer_id, name),
    CHECK (
        (pay_type IN ('daily', 'monthly') AND daily_rate IS NOT NULL) OR
        (pay_type = 'piece' AND piece_rate IS NOT NULL)
    )
);

CREATE INDEX idx_workers_farmer ON workers(farmer_id);
CREATE INDEX idx_workers_active ON workers(farmer_id) WHERE is_active = TRUE;

-- ============================================================================
-- TABLE 8: ATTENDANCE (Pain #4: daily attendance + piece-rate units)
-- "Core of wage calculation: days present × daily rate = wages earned"
-- ============================================================================
CREATE TABLE attendance (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    worker_id       UUID NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
    farmer_id       UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    work_date       DATE NOT NULL,
    present         BOOLEAN NOT NULL,                            -- ✓ or ✗
    units_completed NUMERIC(8,2),                                -- For piece-rate workers
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(worker_id, work_date)
);

CREATE INDEX idx_attendance_worker ON attendance(worker_id, work_date DESC);
CREATE INDEX idx_attendance_farmer ON attendance(farmer_id, work_date DESC);

-- ============================================================================
-- TABLE 9: WAGE PAYMENTS (Pain #4: payment verification)
-- "Prevents double-payment claims" — Pain #4 derived signals
-- ============================================================================
CREATE TABLE wage_payments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    worker_id       UUID NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
    farmer_id       UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    payment_date    DATE NOT NULL,
    amount          NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    period_start    DATE,                            -- Pay period this covers
    period_end      DATE,                            -- Pay period this covers
    is_advance      BOOLEAN DEFAULT FALSE NOT NULL,
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_wage_payments_worker ON wage_payments(worker_id, payment_date DESC);
CREATE INDEX idx_wage_payments_farmer ON wage_payments(farmer_id, payment_date DESC);

-- ============================================================================
-- TABLE 10: MARKET PRICES (Pain #2: selling window)
-- "Builds price reference history; enables comparison of today's offer
--  vs. recent range" — Pain #2 Field 5
-- Farm-level, not batch-level (market price applies to all batches).
-- ============================================================================
CREATE TABLE market_prices (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id       UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    price_date      DATE NOT NULL,
    price_per_kg    NUMERIC(10,2) NOT NULL CHECK (price_per_kg > 0),
    price_type      TEXT NOT NULL DEFAULT 'broiler' CHECK (price_type IN ('broiler', 'culling')),
    source          TEXT,                            -- "Kofi buyer", "WhatsApp group" (optional per research)
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_market_prices_farmer ON market_prices(farmer_id, price_date DESC);
CREATE INDEX idx_market_prices_type ON market_prices(farmer_id, price_type, price_date DESC);

-- ============================================================================
-- TABLE 11: INVENTORY CHECKS (Pain #1: physical verification)
-- "Owner should periodically count physical bags on hand and compare
--  to expected inventory" — Pain #1 Section 5
-- ============================================================================
CREATE TABLE inventory_checks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farmer_id       UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    house_id        UUID REFERENCES houses(id) ON DELETE SET NULL,
    check_date      DATE NOT NULL,
    bags_counted    NUMERIC(6,2) NOT NULL CHECK (bags_counted >= 0),
    bags_expected   NUMERIC(6,2),                    -- System-calculated at time of check
    gap             NUMERIC(6,2),                    -- bags_expected - bags_counted
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_inventory_checks_farmer ON inventory_checks(farmer_id, check_date DESC);

-- ============================================================================
-- TABLE 12: WORKER RATE HISTORY (Pain #4: rate dispute resolution)
-- "Agreed rate with date → makes rate inflation indefensible"
-- Append-only log. Never update, only insert new rate.
-- ============================================================================
CREATE TABLE worker_rate_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    worker_id       UUID NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
    farmer_id       UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    pay_type        TEXT NOT NULL CHECK (pay_type IN ('daily', 'monthly', 'piece')),
    rate            NUMERIC(10,2) NOT NULL CHECK (rate > 0),
    effective_date  DATE NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(worker_id, effective_date)
);

CREATE INDEX idx_rate_history_worker ON worker_rate_history(worker_id, effective_date DESC);

-- ============================================================================
-- TRIGGERS: updated_at
-- ============================================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_farmers_updated BEFORE UPDATE ON farmers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_batches_updated BEFORE UPDATE ON batches
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_workers_updated BEFORE UPDATE ON workers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- TRIGGER: Auto-create farmer profile on signup
-- ============================================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO farmers (id, name, phone, farm_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
        NEW.raw_user_meta_data->>'phone',
        NEW.raw_user_meta_data->>'farm_name'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================================
-- TRIGGER: Update batch current_count when deaths recorded
-- ============================================================================
CREATE OR REPLACE FUNCTION update_batch_count_on_log()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE batches
        SET current_count = GREATEST(current_count - NEW.deaths, 0)
        WHERE id = NEW.batch_id;
    ELSIF TG_OP = 'UPDATE' AND NEW.deaths != OLD.deaths THEN
        UPDATE batches
        SET current_count = GREATEST(
            current_count + OLD.deaths - NEW.deaths,
            0
        )
        WHERE id = NEW.batch_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE batches
        SET current_count = current_count + OLD.deaths
        WHERE id = OLD.batch_id;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_daily_log_deaths
    AFTER INSERT OR UPDATE OR DELETE ON daily_logs
    FOR EACH ROW EXECUTE FUNCTION update_batch_count_on_log();

-- ============================================================================
-- TRIGGER: Log rate changes to history
-- ============================================================================
CREATE OR REPLACE FUNCTION log_worker_rate_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR
       (TG_OP = 'UPDATE' AND (
           NEW.daily_rate IS DISTINCT FROM OLD.daily_rate OR
           NEW.piece_rate IS DISTINCT FROM OLD.piece_rate OR
           NEW.pay_type IS DISTINCT FROM OLD.pay_type
       ))
    THEN
        INSERT INTO worker_rate_history (worker_id, farmer_id, pay_type, rate, effective_date)
        VALUES (
            NEW.id,
            NEW.farmer_id,
            NEW.pay_type,
            COALESCE(NEW.daily_rate, NEW.piece_rate),
            COALESCE(NEW.rate_effective, CURRENT_DATE)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_worker_rate_change
    AFTER INSERT OR UPDATE ON workers
    FOR EACH ROW EXECUTE FUNCTION log_worker_rate_change();

-- ============================================================================
-- ROW LEVEL SECURITY
-- Every table: farmer can only see/modify their own data.
-- ============================================================================
ALTER TABLE farmers ENABLE ROW LEVEL SECURITY;
ALTER TABLE houses ENABLE ROW LEVEL SECURITY;
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE wage_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_rate_history ENABLE ROW LEVEL SECURITY;

-- Farmers: own row only
CREATE POLICY farmers_own ON farmers
    FOR ALL USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- All other tables: farmer_id = auth.uid()
CREATE POLICY houses_own ON houses
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());
CREATE POLICY batches_own ON batches
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());
CREATE POLICY daily_logs_own ON daily_logs
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());
CREATE POLICY feed_deliveries_own ON feed_deliveries
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());
CREATE POLICY supplier_ledger_own ON supplier_ledger
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());
CREATE POLICY workers_own ON workers
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());
CREATE POLICY attendance_own ON attendance
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());
CREATE POLICY wage_payments_own ON wage_payments
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());
CREATE POLICY market_prices_own ON market_prices
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());
CREATE POLICY inventory_checks_own ON inventory_checks
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());
CREATE POLICY rate_history_own ON worker_rate_history
    FOR ALL USING (farmer_id = auth.uid()) WITH CHECK (farmer_id = auth.uid());

-- ============================================================================
-- VIEW: BATCH STATS (Pain #1 + #5 derived signals)
-- Produces: mortality_rate, total_feed, feed_per_bird, age_days
-- ============================================================================
CREATE OR REPLACE VIEW v_batch_stats AS
SELECT
    b.id AS batch_id,
    b.farmer_id,
    b.name AS batch_name,
    b.bird_type,
    b.chick_supplier,
    b.initial_count,
    b.current_count,
    b.start_date,
    b.target_end_date,
    b.status,
    -- Age
    (CURRENT_DATE - b.start_date) AS age_days,
    FLOOR((CURRENT_DATE - b.start_date) / 7.0) AS age_weeks,
    -- Pain #5: Mortality
    COALESCE(SUM(dl.deaths), 0)::INTEGER AS total_deaths,
    ROUND(
        COALESCE(SUM(dl.deaths), 0) * 100.0 / NULLIF(b.initial_count, 0),
        2
    ) AS mortality_rate_pct,
    -- Pain #1: Feed
    COALESCE(SUM(dl.feed_bags), 0) AS total_feed_bags,
    ROUND(
        COALESCE(SUM(dl.feed_bags), 0) / NULLIF(b.current_count, 0),
        3
    ) AS feed_bags_per_bird,
    -- Pain #2 (layers): Eggs
    COALESCE(SUM(dl.eggs_crates), 0) AS total_egg_crates,
    -- Record completeness
    COUNT(dl.id) AS days_recorded,
    MAX(dl.log_date) AS last_record_date,
    -- Days to target sell
    CASE
        WHEN b.target_end_date IS NOT NULL AND b.status = 'active'
        THEN b.target_end_date - CURRENT_DATE
    END AS days_to_target
FROM batches b
LEFT JOIN daily_logs dl ON dl.batch_id = b.id
GROUP BY b.id;

-- ============================================================================
-- VIEW: FEED INVENTORY (Pain #1: running inventory = theft detection)
-- "Total bags received − total bags used = expected bags remaining"
-- ============================================================================
CREATE OR REPLACE VIEW v_feed_inventory AS
SELECT
    f.id AS farmer_id,
    h.id AS house_id,
    h.name AS house_name,
    COALESCE(del.total_received, 0) AS total_bags_received,
    COALESCE(used.total_used, 0) AS total_bags_used,
    COALESCE(del.total_received, 0) - COALESCE(used.total_used, 0) AS expected_bags_remaining,
    chk.last_counted,
    chk.last_counted_bags,
    CASE
        WHEN chk.last_counted_bags IS NOT NULL
        THEN (COALESCE(del.total_received, 0) - COALESCE(used.total_used, 0)) - chk.last_counted_bags
    END AS inventory_gap
FROM farmers f
CROSS JOIN LATERAL (
    SELECT id, name FROM houses WHERE farmer_id = f.id AND is_active = TRUE
) h
LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(bags_received), 0) AS total_received
    FROM feed_deliveries
    WHERE farmer_id = f.id AND (house_id = h.id OR house_id IS NULL)
) del ON TRUE
LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(dl.feed_bags), 0) AS total_used
    FROM daily_logs dl
    JOIN batches b ON b.id = dl.batch_id
    WHERE dl.farmer_id = f.id AND (b.house_id = h.id OR b.house_id IS NULL)
) used ON TRUE
LEFT JOIN LATERAL (
    SELECT check_date AS last_counted, bags_counted AS last_counted_bags
    FROM inventory_checks
    WHERE farmer_id = f.id AND (house_id = h.id OR house_id IS NULL)
    ORDER BY check_date DESC
    LIMIT 1
) chk ON TRUE;

-- ============================================================================
-- VIEW: SUPPLIER BALANCES (Pain #3: balance per supplier)
-- "Sum of all credit purchases − Sum of all payments"
-- ============================================================================
CREATE OR REPLACE VIEW v_supplier_balances AS
SELECT
    farmer_id,
    supplier_name,
    SUM(CASE WHEN txn_type = 'purchase' AND is_credit = TRUE THEN amount ELSE 0 END) AS total_credit_purchases,
    SUM(CASE WHEN txn_type = 'payment' THEN amount ELSE 0 END) AS total_payments,
    SUM(CASE WHEN txn_type = 'purchase' AND is_credit = TRUE THEN amount ELSE 0 END)
        - SUM(CASE WHEN txn_type = 'payment' THEN amount ELSE 0 END) AS balance_owed,
    MIN(CASE
        WHEN txn_type = 'purchase' AND is_credit = TRUE AND due_date IS NOT NULL
             AND due_date >= CURRENT_DATE
        THEN due_date
    END) AS next_due_date,
    COUNT(*) FILTER (
        WHERE txn_type = 'purchase' AND is_credit = TRUE
              AND due_date IS NOT NULL AND due_date < CURRENT_DATE
    ) AS overdue_count,
    SUM(CASE
        WHEN txn_type = 'purchase' AND is_credit = TRUE
             AND due_date IS NOT NULL AND due_date < CURRENT_DATE
        THEN amount ELSE 0
    END) - SUM(CASE WHEN txn_type = 'payment' THEN amount ELSE 0 END) AS overdue_amount,
    MAX(CASE WHEN txn_type = 'payment' THEN txn_date END) AS last_payment_date
FROM supplier_ledger
GROUP BY farmer_id, supplier_name;

-- ============================================================================
-- VIEW: WORKER WAGES (Pain #4: wages earned vs paid)
-- "Days worked × agreed daily rate = wages earned"
-- ============================================================================
CREATE OR REPLACE VIEW v_worker_wages AS
SELECT
    w.id AS worker_id,
    w.farmer_id,
    w.name AS worker_name,
    w.pay_type,
    w.daily_rate,
    w.piece_rate,
    -- This month attendance
    COUNT(*) FILTER (
        WHERE a.present = TRUE
        AND a.work_date >= DATE_TRUNC('month', CURRENT_DATE)
    ) AS days_worked_this_month,
    COUNT(*) FILTER (
        WHERE a.present = FALSE
        AND a.work_date >= DATE_TRUNC('month', CURRENT_DATE)
    ) AS days_absent_this_month,
    -- Wages earned this month
    CASE
        WHEN w.pay_type IN ('daily', 'monthly') THEN
            COUNT(*) FILTER (
                WHERE a.present = TRUE
                AND a.work_date >= DATE_TRUNC('month', CURRENT_DATE)
            ) * w.daily_rate
        WHEN w.pay_type = 'piece' THEN
            COALESCE(SUM(a.units_completed) FILTER (
                WHERE a.work_date >= DATE_TRUNC('month', CURRENT_DATE)
            ), 0) * w.piece_rate
    END AS wages_earned_this_month,
    -- Payments this month
    COALESCE(wp.paid_this_month, 0) AS paid_this_month,
    -- Balance owed
    CASE
        WHEN w.pay_type IN ('daily', 'monthly') THEN
            COUNT(*) FILTER (
                WHERE a.present = TRUE
                AND a.work_date >= DATE_TRUNC('month', CURRENT_DATE)
            ) * w.daily_rate
        WHEN w.pay_type = 'piece' THEN
            COALESCE(SUM(a.units_completed) FILTER (
                WHERE a.work_date >= DATE_TRUNC('month', CURRENT_DATE)
            ), 0) * w.piece_rate
    END - COALESCE(wp.paid_this_month, 0) AS balance_owed
FROM workers w
LEFT JOIN attendance a ON a.worker_id = w.id
LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(amount), 0) AS paid_this_month
    FROM wage_payments
    WHERE worker_id = w.id
      AND payment_date >= DATE_TRUNC('month', CURRENT_DATE)
) wp ON TRUE
WHERE w.is_active = TRUE
GROUP BY w.id, w.farmer_id, w.name, w.pay_type, w.daily_rate, w.piece_rate, wp.paid_this_month;

-- ============================================================================
-- VIEW: MARKET PRICE CONTEXT (Pain #2: price range for sell decision)
-- "Highest and lowest price recorded in past 10-14 days"
-- ============================================================================
CREATE OR REPLACE VIEW v_price_context AS
SELECT
    farmer_id,
    price_type,
    MIN(price_per_kg) FILTER (WHERE price_date >= CURRENT_DATE - 14) AS min_price_14d,
    MAX(price_per_kg) FILTER (WHERE price_date >= CURRENT_DATE - 14) AS max_price_14d,
    ROUND(AVG(price_per_kg) FILTER (WHERE price_date >= CURRENT_DATE - 14), 2) AS avg_price_14d,
    ROUND(AVG(price_per_kg) FILTER (WHERE price_date >= CURRENT_DATE - 7), 2) AS avg_price_7d,
    ROUND(AVG(price_per_kg) FILTER (
        WHERE price_date >= CURRENT_DATE - 14 AND price_date < CURRENT_DATE - 7
    ), 2) AS avg_price_prev_7d,
    -- Trend: this week vs last week
    CASE
        WHEN AVG(price_per_kg) FILTER (WHERE price_date >= CURRENT_DATE - 7) >
             AVG(price_per_kg) FILTER (WHERE price_date >= CURRENT_DATE - 14 AND price_date < CURRENT_DATE - 7)
        THEN 'rising'
        WHEN AVG(price_per_kg) FILTER (WHERE price_date >= CURRENT_DATE - 7) <
             AVG(price_per_kg) FILTER (WHERE price_date >= CURRENT_DATE - 14 AND price_date < CURRENT_DATE - 7)
        THEN 'falling'
        ELSE 'stable'
    END AS trend,
    COUNT(*) FILTER (WHERE price_date >= CURRENT_DATE - 14) AS data_points_14d,
    MAX(price_date) AS last_price_date
FROM market_prices
GROUP BY farmer_id, price_type;

-- ============================================================================
-- VIEW: MORTALITY BY SUPPLIER (Pain #5: highest-value insight)
-- "If Supplier A averages 12% and Supplier B averages 8%, switch saves
--  GH₵4,000+/batch"
-- ============================================================================
CREATE OR REPLACE VIEW v_mortality_by_supplier AS
SELECT
    b.farmer_id,
    b.chick_supplier,
    COUNT(DISTINCT b.id) AS batch_count,
    ROUND(AVG(
        COALESCE(d.total_deaths, 0) * 100.0 / NULLIF(b.initial_count, 0)
    ), 2) AS avg_mortality_pct,
    MIN(
        COALESCE(d.total_deaths, 0) * 100.0 / NULLIF(b.initial_count, 0)
    ) AS min_mortality_pct,
    MAX(
        COALESCE(d.total_deaths, 0) * 100.0 / NULLIF(b.initial_count, 0)
    ) AS max_mortality_pct,
    SUM(COALESCE(d.total_deaths, 0)) AS total_deaths_all_batches,
    SUM(b.initial_count) AS total_birds_all_batches
FROM batches b
LEFT JOIN LATERAL (
    SELECT SUM(deaths) AS total_deaths
    FROM daily_logs WHERE batch_id = b.id
) d ON TRUE
WHERE b.chick_supplier IS NOT NULL
  AND b.status IN ('completed', 'sold')
GROUP BY b.farmer_id, b.chick_supplier;

-- ============================================================================
-- VIEW: MORTALITY BY SEASON (Pain #5: seasonal pattern)
-- ============================================================================
CREATE OR REPLACE VIEW v_mortality_by_season AS
SELECT
    b.farmer_id,
    CASE
        WHEN EXTRACT(MONTH FROM b.start_date) IN (3,4,5) THEN 'Mar-May (hot/rainy)'
        WHEN EXTRACT(MONTH FROM b.start_date) IN (6,7,8) THEN 'Jun-Aug (rainy)'
        WHEN EXTRACT(MONTH FROM b.start_date) IN (9,10,11) THEN 'Sep-Nov (dry)'
        ELSE 'Dec-Feb (harmattan)'
    END AS season,
    COUNT(DISTINCT b.id) AS batch_count,
    ROUND(AVG(
        COALESCE(d.total_deaths, 0) * 100.0 / NULLIF(b.initial_count, 0)
    ), 2) AS avg_mortality_pct
FROM batches b
LEFT JOIN LATERAL (
    SELECT SUM(deaths) AS total_deaths
    FROM daily_logs WHERE batch_id = b.id
) d ON TRUE
WHERE b.status IN ('completed', 'sold')
GROUP BY b.farmer_id, season;

-- ============================================================================
-- VIEW: MORTALITY BY AGE WEEK (Pain #5: vulnerability windows)
-- "Identifies age-vulnerability window; farmer can increase care"
-- ============================================================================
CREATE OR REPLACE VIEW v_mortality_by_age_week AS
SELECT
    b.farmer_id,
    b.chick_supplier,
    FLOOR((dl.log_date - b.start_date) / 7.0)::INTEGER + 1 AS age_week,
    SUM(dl.deaths) AS total_deaths,
    ROUND(AVG(dl.deaths), 2) AS avg_daily_deaths,
    COUNT(DISTINCT b.id) AS batches_with_data
FROM daily_logs dl
JOIN batches b ON b.id = dl.batch_id
WHERE dl.deaths > 0
GROUP BY b.farmer_id, b.chick_supplier, age_week;

-- ============================================================================
-- VIEW: FEED CONSUMPTION TREND (Pain #1: week-over-week comparison)
-- "If ratio exceeds 1.1-1.2, something has changed"
-- ============================================================================
CREATE OR REPLACE VIEW v_feed_weekly_trend AS
SELECT
    b.farmer_id,
    b.id AS batch_id,
    b.name AS batch_name,
    FLOOR((dl.log_date - b.start_date) / 7.0)::INTEGER + 1 AS age_week,
    SUM(dl.feed_bags) AS weekly_feed_bags,
    ROUND(SUM(dl.feed_bags) / NULLIF(b.current_count, 0), 4) AS feed_per_bird,
    COUNT(dl.id) AS days_recorded
FROM daily_logs dl
JOIN batches b ON b.id = dl.batch_id
WHERE b.status = 'active'
GROUP BY b.farmer_id, b.id, b.name, b.current_count, age_week;

-- ============================================================================
-- VIEW: PAYMENTS DUE (Pain #3: cash flow planning)
-- "Plan which payments to make before crisis, not during crisis"
-- ============================================================================
CREATE OR REPLACE VIEW v_payments_due AS
SELECT
    sl.farmer_id,
    sl.supplier_name,
    sl.txn_date AS purchase_date,
    sl.amount,
    sl.due_date,
    sl.due_date - CURRENT_DATE AS days_until_due,
    CASE
        WHEN sl.due_date < CURRENT_DATE THEN 'overdue'
        WHEN sl.due_date <= CURRENT_DATE + 7 THEN 'due_this_week'
        WHEN sl.due_date <= CURRENT_DATE + 30 THEN 'due_this_month'
        ELSE 'future'
    END AS urgency
FROM supplier_ledger sl
WHERE sl.txn_type = 'purchase'
  AND sl.is_credit = TRUE
  AND sl.due_date IS NOT NULL
ORDER BY sl.due_date ASC;

-- ============================================================================
-- FUNCTION: Feed cost of waiting (Pain #2: sell/wait decision)
-- "Direct cedis cost of waiting one more week"
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_feed_cost_of_waiting(
    p_batch_id UUID,
    p_cost_per_bag NUMERIC DEFAULT 50.0
)
RETURNS TABLE (
    batch_name TEXT,
    days_past_target INTEGER,
    avg_daily_feed NUMERIC,
    daily_feed_cost NUMERIC,
    total_cost_of_delay NUMERIC
) AS $$
SELECT
    b.name,
    GREATEST(CURRENT_DATE - b.target_end_date, 0),
    ROUND(COALESCE(AVG(dl.feed_bags), 0), 2),
    ROUND(COALESCE(AVG(dl.feed_bags), 0) * p_cost_per_bag, 2),
    ROUND(
        GREATEST(CURRENT_DATE - b.target_end_date, 0)
        * COALESCE(AVG(dl.feed_bags), 0)
        * p_cost_per_bag,
        2
    )
FROM batches b
LEFT JOIN daily_logs dl ON dl.batch_id = b.id
    AND dl.log_date >= b.start_date
WHERE b.id = p_batch_id
GROUP BY b.id, b.name, b.target_end_date;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Batch health score (composite signal)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_batch_health_score(p_batch_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_score INTEGER := 100;
    v_mortality_pct NUMERIC;
    v_days_since_record INTEGER;
    v_age_days INTEGER;
BEGIN
    SELECT
        COALESCE(SUM(dl.deaths), 0) * 100.0 / NULLIF(b.initial_count, 0),
        CURRENT_DATE - COALESCE(MAX(dl.log_date), b.start_date),
        CURRENT_DATE - b.start_date
    INTO v_mortality_pct, v_days_since_record, v_age_days
    FROM batches b
    LEFT JOIN daily_logs dl ON dl.batch_id = b.id
    WHERE b.id = p_batch_id
    GROUP BY b.id;

    -- Mortality penalty
    IF v_mortality_pct > 10 THEN v_score := v_score - 40;
    ELSIF v_mortality_pct > 5 THEN v_score := v_score - 25;
    ELSIF v_mortality_pct > 3 THEN v_score := v_score - 10;
    END IF;

    -- Recording gap penalty
    IF v_days_since_record > 7 THEN v_score := v_score - 30;
    ELSIF v_days_since_record > 3 THEN v_score := v_score - 15;
    ELSIF v_days_since_record > 1 THEN v_score := v_score - 5;
    END IF;

    RETURN GREATEST(v_score, 0);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- SCHEMA MAP → MONEY SIGNALS
-- ============================================================================
--
-- PAIN #1 (Feed Theft):
--   Tables: daily_logs.feed_bags, feed_deliveries, inventory_checks
--   Views:  v_feed_inventory (running inventory gap)
--           v_feed_weekly_trend (week-over-week comparison)
--   Signal: expected_bags - counted_bags = theft/waste amount
--
-- PAIN #2 (Selling Window):
--   Tables: batches (target_end_date, actual_sell_price), market_prices
--   Views:  v_batch_stats (days_to_target, age_days)
--           v_price_context (14-day range, trend)
--   Func:   fn_feed_cost_of_waiting (cedis cost of delay)
--   Signal: days_past_target × daily_feed_cost = money wasted
--
-- PAIN #3 (Supplier Payments):
--   Tables: supplier_ledger
--   Views:  v_supplier_balances (balance per supplier)
--           v_payments_due (urgency-sorted obligations)
--   Signal: balance_owed per supplier, overdue_amount
--
-- PAIN #4 (Labor Cost):
--   Tables: workers, attendance, wage_payments, worker_rate_history
--   Views:  v_worker_wages (earned vs paid, balance owed)
--   Signal: days_worked × rate - payments = balance_owed
--
-- PAIN #5 (Mortality Patterns):
--   Tables: daily_logs.deaths, batches.chick_supplier
--   Views:  v_batch_stats (mortality_rate_pct)
--           v_mortality_by_supplier (avg mortality per supplier)
--           v_mortality_by_season (seasonal patterns)
--           v_mortality_by_age_week (vulnerability windows)
--   Signal: supplier A avg 12% vs supplier B avg 8% = switch
--
-- ============================================================================
