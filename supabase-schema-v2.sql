-- ============================================================================
-- POULTRYPRO v2 — LEAN PRODUCTION SCHEMA
-- ============================================================================
-- Architecture: Organization → Farms → Houses → Batches → Daily Logs
-- Roles: admin (owner), manager, staff
-- Removed: Worker pay/attendance (Pain #4) — not core money signal
-- Added: Egg inventory, Org hierarchy, smooth on/offboarding
-- Daily usage target: < 5 minutes for the Ghanaian farmer
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- CUSTOM TYPES
-- ============================================================================
CREATE TYPE member_role AS ENUM ('admin', 'manager', 'staff');
CREATE TYPE batch_status AS ENUM ('active', 'completed');
CREATE TYPE bird_type AS ENUM ('broiler', 'layer');
CREATE TYPE txn_type AS ENUM ('purchase', 'payment');
CREATE TYPE price_type AS ENUM ('broiler', 'culling', 'egg');
CREATE TYPE issue_tag AS ENUM ('water', 'feed', 'heat', 'unknown');
CREATE TYPE batch_exit_type AS ENUM ('sold_live', 'sold_meat', 'culled', 'died_out', 'transferred', 'unknown');
CREATE TYPE plan_tier AS ENUM ('trial', 'pro', 'enterprise');
CREATE TYPE subscription_status AS ENUM ('trialing', 'active', 'past_due', 'canceled');

-- ============================================================================
-- TABLE: PROFILES
-- Lightweight user identity. One row per auth.users entry.
-- ============================================================================
CREATE TABLE profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name       TEXT NOT NULL,
    phone           TEXT,
    avatar_url      TEXT,
    whatsapp_id     TEXT UNIQUE,
    locale          TEXT DEFAULT 'en',
    timezone        TEXT DEFAULT 'Africa/Accra',
    onboarded_at    TIMESTAMPTZ,           -- NULL = hasn't finished onboarding
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_profiles_whatsapp ON profiles(whatsapp_id) WHERE whatsapp_id IS NOT NULL;

-- ============================================================================
-- TABLE: ORGANIZATIONS
-- Multi-tenancy root. A poultry business. One person can own one org.
-- An org can have many farms.
-- ============================================================================
CREATE TABLE organizations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    owner_id        UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    currency        TEXT DEFAULT 'GHS' NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(owner_id)  -- One org per owner (can relax later)
);

-- ============================================================================
-- TABLE: MEMBERS
-- Who belongs to which org, with what role.
-- Smooth onboarding: invite by phone/email → accept → active member.
-- Smooth offboarding: deactivate, don't delete (preserves audit trail).
-- ============================================================================
CREATE TABLE members (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES profiles(id) ON DELETE SET NULL,  -- NULL until invite accepted
    role            member_role NOT NULL DEFAULT 'staff',
    email           TEXT,                   -- For invite lookup before user signs up
    phone           TEXT,                   -- For invite lookup (WhatsApp)
    is_active       BOOLEAN DEFAULT TRUE NOT NULL,
    invited_by      UUID REFERENCES profiles(id),
    invited_at      TIMESTAMPTZ DEFAULT NOW(),
    joined_at       TIMESTAMPTZ,           -- Set when user accepts invite
    deactivated_at  TIMESTAMPTZ,           -- Soft offboarding
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    -- One active membership per user per org
    UNIQUE(org_id, user_id)
);

CREATE INDEX idx_members_org ON members(org_id) WHERE is_active = TRUE;
CREATE INDEX idx_members_user ON members(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_members_email ON members(email) WHERE email IS NOT NULL AND user_id IS NULL;
CREATE INDEX idx_members_phone ON members(phone) WHERE phone IS NOT NULL AND user_id IS NULL;

-- ============================================================================
-- TABLE: FARMS
-- Physical farm location. An org can have many farms.
-- ============================================================================
CREATE TABLE farms (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    location        TEXT,                   -- "Kumasi", "Tema", etc.
    is_active       BOOLEAN DEFAULT TRUE NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(org_id, name)
);

CREATE INDEX idx_farms_org ON farms(org_id);

-- ============================================================================
-- TABLE: HOUSES
-- Per-house tracking prevents masking theft/mortality across houses.
-- A farm can have many houses. Small farms: just one house.
-- ============================================================================
CREATE TABLE houses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    farm_id         UUID NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,           -- "House A", "big shed"
    capacity        INTEGER,                 -- Max birds (optional)
    is_active       BOOLEAN DEFAULT TRUE NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(farm_id, name)
);

CREATE INDEX idx_houses_farm ON houses(farm_id);

-- ============================================================================
-- TABLE: BATCHES
-- Core entity. Serves feed tracking, selling window, mortality patterns.
-- One batch = one group of birds in one house for one production cycle.
-- ============================================================================
CREATE TABLE batches (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id              UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    farm_id             UUID NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
    house_id            UUID REFERENCES houses(id) ON DELETE SET NULL,
    name                TEXT NOT NULL,               -- "Batch 7", "March batch"
    bird_type           bird_type NOT NULL,
    chick_supplier      TEXT,                        -- Highest-value pattern variable
    initial_count       INTEGER NOT NULL CHECK (initial_count > 0),
    current_count       INTEGER NOT NULL CHECK (current_count >= 0),
    start_date          DATE NOT NULL,
    target_end_date     DATE,                        -- Selling window anchor
    actual_end_date     DATE,
    status              batch_status NOT NULL DEFAULT 'active',
    notes               TEXT,
    created_by          UUID REFERENCES profiles(id),
    created_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(org_id, farm_id, name),
    CHECK (actual_end_date IS NULL OR actual_end_date >= start_date),
    CHECK (target_end_date IS NULL OR target_end_date >= start_date)
);

CREATE INDEX idx_batches_org ON batches(org_id);
CREATE INDEX idx_batches_farm ON batches(farm_id);
CREATE INDEX idx_batches_active ON batches(org_id) WHERE status = 'active';
CREATE INDEX idx_batches_supplier ON batches(org_id, chick_supplier) WHERE chick_supplier IS NOT NULL;

-- ============================================================================
-- TABLE: DAILY LOGS
-- ONE row per batch per day. The farmer's daily 45-second input.
-- Feed bags (Pain #1) + Deaths (Pain #5) + Egg crates (layers).
-- ============================================================================
CREATE TABLE daily_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    batch_id        UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    log_date        DATE NOT NULL,
    -- Feed
    feed_bags       NUMERIC(5,2) DEFAULT 0 NOT NULL CHECK (feed_bags >= 0),
    -- Mortality
    deaths          INTEGER DEFAULT 0 NOT NULL CHECK (deaths >= 0),
    -- Context
    issue           issue_tag,
    notes           TEXT,
    recorded_by     UUID REFERENCES profiles(id),
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(batch_id, log_date)
);

CREATE INDEX idx_daily_logs_batch ON daily_logs(batch_id, log_date DESC);
CREATE INDEX idx_daily_logs_org ON daily_logs(org_id, log_date DESC);

-- ============================================================================
-- TABLE: BATCH OUTCOMES (1-time per batch)
-- High value, low burden: locks in the batch result for learning and P&L.
-- ============================================================================
CREATE TABLE batch_outcomes (
    batch_id            UUID PRIMARY KEY REFERENCES batches(id) ON DELETE CASCADE,
    org_id              UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    closed_date         DATE NOT NULL,
    exit_type           batch_exit_type NOT NULL DEFAULT 'unknown',
    birds_sold_count    INTEGER CHECK (birds_sold_count >= 0),
    total_sale_amount   NUMERIC(12,2) CHECK (total_sale_amount >= 0),
    avg_price_per_bird  NUMERIC(10,2) CHECK (avg_price_per_bird >= 0),
    avg_price_per_kg    NUMERIC(10,2) CHECK (avg_price_per_kg >= 0),
    notes               TEXT,
    recorded_by         UUID REFERENCES profiles(id),
    created_at          TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    CHECK (birds_sold_count IS NULL OR birds_sold_count >= 0)
);

CREATE INDEX idx_batch_outcomes_org ON batch_outcomes(org_id, closed_date DESC);

-- ============================================================================
-- TABLE: ORG SUBSCRIPTIONS (Packages: Trial / Pro / Enterprise)
-- Minimal: one current subscription row per organization.
-- ============================================================================
CREATE TABLE org_subscriptions (
    org_id              UUID PRIMARY KEY REFERENCES organizations(id) ON DELETE CASCADE,
    tier                plan_tier NOT NULL DEFAULT 'trial',
    status              subscription_status NOT NULL DEFAULT 'trialing',
    trial_ends_at        TIMESTAMPTZ,
    current_period_start TIMESTAMPTZ,
    current_period_end   TIMESTAMPTZ,
    canceled_at          TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_org_subscriptions_status ON org_subscriptions(status);

-- ============================================================================
-- TABLE: FEED DELIVERIES
-- Running inventory: received − used = expected bags.
-- Without this, no theft detection.
-- ============================================================================
CREATE TABLE feed_deliveries (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    farm_id         UUID NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
    house_id        UUID REFERENCES houses(id) ON DELETE SET NULL,
    delivery_date   DATE NOT NULL,
    bags_received   NUMERIC(6,2) NOT NULL CHECK (bags_received > 0),
    cost_per_bag    NUMERIC(10,2),
    total_cost      NUMERIC(12,2),
    supplier_name   TEXT,
    notes           TEXT,
    recorded_by     UUID REFERENCES profiles(id),
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_feed_del_org ON feed_deliveries(org_id, delivery_date DESC);
CREATE INDEX idx_feed_del_farm ON feed_deliveries(farm_id, delivery_date DESC);

-- ============================================================================
-- TABLE: EGG INVENTORY
-- Tracks egg stock at farm level. Layers produce daily, sell periodically.
-- Stock = collected − broken − sold − used(home)
-- ============================================================================
CREATE TABLE egg_inventory (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    farm_id         UUID NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
    record_date     DATE NOT NULL,
    opening_stock   NUMERIC(8,1) DEFAULT 0 NOT NULL CHECK (opening_stock >= 0),  -- Crates
    collected       NUMERIC(8,1) DEFAULT 0 NOT NULL CHECK (collected >= 0),
    broken          NUMERIC(8,1) DEFAULT 0 CHECK (broken >= 0),
    sold            NUMERIC(8,1) DEFAULT 0 CHECK (sold >= 0),
    sale_amount     NUMERIC(12,2) DEFAULT 0 CHECK (sale_amount >= 0),  -- GH₵
    home_use        NUMERIC(8,1) DEFAULT 0 CHECK (home_use >= 0),
    closing_stock   NUMERIC(8,1) GENERATED ALWAYS AS (
        opening_stock + collected - COALESCE(broken, 0) - COALESCE(sold, 0) - COALESCE(home_use, 0)
    ) STORED,
    notes           TEXT,
    recorded_by     UUID REFERENCES profiles(id),
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(farm_id, record_date)
);

CREATE INDEX idx_egg_inv_farm ON egg_inventory(farm_id, record_date DESC);
CREATE INDEX idx_egg_inv_org ON egg_inventory(org_id, record_date DESC);

-- ============================================================================
-- TABLE: SUPPLIER LEDGER
-- Purchase (+) or payment (−) per supplier. Balance = purchases − payments.
-- ============================================================================
CREATE TABLE supplier_ledger (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    supplier_name   TEXT NOT NULL,
    txn_date        DATE NOT NULL,
    txn_type        txn_type NOT NULL,
    amount          NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    is_credit       BOOLEAN DEFAULT TRUE NOT NULL,
    due_date        DATE,
    description     TEXT,                    -- "50 bags feed", "MoMo payment"
    reference       TEXT,                    -- MoMo ref, receipt #
    recorded_by     UUID REFERENCES profiles(id),
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    CHECK (
        (txn_type = 'purchase') OR
        (txn_type = 'payment' AND due_date IS NULL)
    )
);

CREATE INDEX idx_ledger_org ON supplier_ledger(org_id);
CREATE INDEX idx_ledger_supplier ON supplier_ledger(org_id, supplier_name);
CREATE INDEX idx_ledger_due ON supplier_ledger(org_id, due_date)
    WHERE txn_type = 'purchase' AND is_credit = TRUE AND due_date IS NOT NULL;

-- ============================================================================
-- TABLE: MARKET PRICES
-- Price heard from buyers. Farm-level (market price applies to all batches).
-- ============================================================================
CREATE TABLE market_prices (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    price_date      DATE NOT NULL,
    price_per_unit  NUMERIC(10,2) NOT NULL CHECK (price_per_unit > 0),
    price_type      price_type NOT NULL DEFAULT 'broiler',
    unit            TEXT DEFAULT 'kg',       -- "kg", "crate", "bird"
    source          TEXT,                    -- "Kofi buyer", "WhatsApp group"
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_prices_org ON market_prices(org_id, price_date DESC);
CREATE INDEX idx_prices_type ON market_prices(org_id, price_type, price_date DESC);

-- ============================================================================
-- TABLE: INVENTORY CHECKS
-- Physical count vs expected. The theft-catching mechanism.
-- ============================================================================
CREATE TABLE inventory_checks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id          UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    farm_id         UUID NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
    house_id        UUID REFERENCES houses(id) ON DELETE SET NULL,
    check_date      DATE NOT NULL,
    item_type       TEXT NOT NULL DEFAULT 'feed' CHECK (item_type IN ('feed', 'eggs')),
    counted         NUMERIC(8,2) NOT NULL CHECK (counted >= 0),
    expected        NUMERIC(8,2),            -- System-calculated
    gap             NUMERIC(8,2),            -- expected − counted
    notes           TEXT,
    checked_by      UUID REFERENCES profiles(id),
    created_at      TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_inv_checks_farm ON inventory_checks(farm_id, check_date DESC);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- updated_at trigger
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_organizations_updated BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_farms_updated BEFORE UPDATE ON farms
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_members_updated BEFORE UPDATE ON members
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_batches_updated BEFORE UPDATE ON batches
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_org_subscriptions_updated BEFORE UPDATE ON org_subscriptions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- TRIGGER: Auto-create profile on signup
-- ============================================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, full_name, phone)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email, 'Farmer'),
        NEW.raw_user_meta_data->>'phone'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================================
-- TRIGGER: Auto-link pending invites when user signs up
-- If a member row exists with matching email/phone but no user_id,
-- link it to the newly created profile.
-- ============================================================================
CREATE OR REPLACE FUNCTION link_pending_invites()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE members
    SET user_id = NEW.id,
        joined_at = NOW(),
        is_active = TRUE
    WHERE user_id IS NULL
      AND is_active = TRUE
      AND (
          (email IS NOT NULL AND NEW.email IS NOT NULL AND email = NEW.email)
          OR (phone IS NOT NULL AND phone = NEW.raw_user_meta_data->>'phone')
      );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_invite_link
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION link_pending_invites();

-- ============================================================================
-- TRIGGER: Update batch current_count on death recording
-- ============================================================================
CREATE OR REPLACE FUNCTION update_batch_count_on_log()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE batches
        SET current_count = GREATEST(current_count - NEW.deaths, 0)
        WHERE id = NEW.batch_id;
    ELSIF TG_OP = 'UPDATE' AND NEW.deaths IS DISTINCT FROM OLD.deaths THEN
        UPDATE batches
        SET current_count = GREATEST(current_count + OLD.deaths - NEW.deaths, 0)
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
-- TRIGGER: Auto-carry forward egg opening stock from previous day's closing
-- ============================================================================
CREATE OR REPLACE FUNCTION set_egg_opening_stock()
RETURNS TRIGGER AS $$
DECLARE
    v_prev_closing NUMERIC(8,1);
BEGIN
    SELECT closing_stock INTO v_prev_closing
    FROM egg_inventory
    WHERE farm_id = NEW.farm_id
      AND record_date < NEW.record_date
    ORDER BY record_date DESC
    LIMIT 1;

    IF v_prev_closing IS NOT NULL AND NEW.opening_stock = 0 THEN
        NEW.opening_stock := v_prev_closing;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_egg_opening_stock
    BEFORE INSERT ON egg_inventory
    FOR EACH ROW EXECUTE FUNCTION set_egg_opening_stock();

-- ============================================================================
-- FUNCTION: Onboard new organization
-- Creates org + default farm + default house + admin membership in one call.
-- Zero friction: farmer signs up → calls this → ready to record.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_onboard_organization(
    p_org_name TEXT,
    p_farm_name TEXT DEFAULT 'My Farm',
    p_house_name TEXT DEFAULT 'House A',
    p_location TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_org_id UUID;
    v_farm_id UUID;
    v_house_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Create organization
    INSERT INTO organizations (name, owner_id)
    VALUES (p_org_name, v_user_id)
    RETURNING id INTO v_org_id;

    -- Create default subscription (trial)
    INSERT INTO org_subscriptions (org_id, tier, status, trial_ends_at)
    VALUES (v_org_id, 'trial', 'trialing', NOW() + INTERVAL '14 days');

    -- Create admin membership
    INSERT INTO members (org_id, user_id, role, joined_at)
    VALUES (v_org_id, v_user_id, 'admin', NOW());

    -- Create default farm
    INSERT INTO farms (org_id, name, location)
    VALUES (v_org_id, p_farm_name, p_location)
    RETURNING id INTO v_farm_id;

    -- Create default house
    INSERT INTO houses (farm_id, org_id, name)
    VALUES (v_farm_id, v_org_id, p_house_name)
    RETURNING id INTO v_house_id;

    -- Mark profile as onboarded
    UPDATE profiles SET onboarded_at = NOW() WHERE id = v_user_id;

    RETURN json_build_object(
        'org_id', v_org_id,
        'farm_id', v_farm_id,
        'house_id', v_house_id,
        'status', 'onboarded'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Invite member to organization
-- Admin/manager invites by email or phone. Member row created immediately.
-- When invitee signs up, trigger auto-links them.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_invite_member(
    p_org_id UUID,
    p_email TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL,
    p_role member_role DEFAULT 'staff'
)
RETURNS UUID AS $$
DECLARE
    v_member_id UUID;
    v_caller_role member_role;
BEGIN
    -- Check caller is admin or manager
    SELECT role INTO v_caller_role
    FROM members
    WHERE org_id = p_org_id AND user_id = auth.uid() AND is_active = TRUE;

    IF v_caller_role IS NULL OR v_caller_role = 'staff' THEN
        RAISE EXCEPTION 'Only admin or manager can invite members';
    END IF;

    -- Only admin can invite managers
    IF p_role = 'manager' AND v_caller_role != 'admin' THEN
        RAISE EXCEPTION 'Only admin can invite managers';
    END IF;

    -- Cannot invite another admin
    IF p_role = 'admin' THEN
        RAISE EXCEPTION 'Cannot invite admin. Transfer ownership instead.';
    END IF;

    INSERT INTO members (org_id, email, phone, role, invited_by)
    VALUES (p_org_id, p_email, p_phone, p_role, auth.uid())
    RETURNING id INTO v_member_id;

    RETURN v_member_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Deactivate member (offboarding)
-- Soft delete: preserves data, removes access.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_deactivate_member(
    p_member_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_target_org UUID;
    v_target_role member_role;
    v_caller_role member_role;
BEGIN
    SELECT org_id, role INTO v_target_org, v_target_role
    FROM members WHERE id = p_member_id AND is_active = TRUE;

    IF v_target_org IS NULL THEN
        RAISE EXCEPTION 'Member not found or already deactivated';
    END IF;

    -- Cannot deactivate admin (must transfer ownership first)
    IF v_target_role = 'admin' THEN
        RAISE EXCEPTION 'Cannot deactivate admin. Transfer ownership first.';
    END IF;

    -- Check caller is admin
    SELECT role INTO v_caller_role
    FROM members
    WHERE org_id = v_target_org AND user_id = auth.uid() AND is_active = TRUE;

    IF v_caller_role != 'admin' THEN
        RAISE EXCEPTION 'Only admin can deactivate members';
    END IF;

    UPDATE members
    SET is_active = FALSE, deactivated_at = NOW()
    WHERE id = p_member_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HELPER: Get user's org_id (used in RLS policies)
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_org_id()
RETURNS UUID AS $$
    SELECT org_id FROM members
    WHERE user_id = auth.uid() AND is_active = TRUE
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ============================================================================
-- HELPER: Check user role in org
-- ============================================================================
CREATE OR REPLACE FUNCTION user_has_role(p_org_id UUID, p_min_role member_role)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM members
        WHERE org_id = p_org_id
          AND user_id = auth.uid()
          AND is_active = TRUE
          AND (
              role = 'admin'
              OR (p_min_role = 'manager' AND role IN ('admin', 'manager'))
              OR (p_min_role = 'staff')
          )
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ============================================================================
-- ROW LEVEL SECURITY
-- All data scoped to organization via membership.
-- Staff can read, managers can read/write, admins can do everything.
-- ============================================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE farms ENABLE ROW LEVEL SECURITY;
ALTER TABLE houses ENABLE ROW LEVEL SECURITY;
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE egg_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE supplier_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE batch_outcomes ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_subscriptions ENABLE ROW LEVEL SECURITY;

-- Profiles: own row only
CREATE POLICY profiles_own ON profiles
    FOR ALL USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- Organizations: members can read, admin can update
CREATE POLICY org_read ON organizations
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM members WHERE org_id = id AND user_id = auth.uid() AND is_active = TRUE)
    );
CREATE POLICY org_insert ON organizations
    FOR INSERT WITH CHECK (owner_id = auth.uid());
CREATE POLICY org_update ON organizations
    FOR UPDATE USING (owner_id = auth.uid());

-- Org subscriptions: org members can read; admin can update
CREATE POLICY org_subscriptions_read ON org_subscriptions
    FOR SELECT USING (
        org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE)
    );
CREATE POLICY org_subscriptions_insert ON org_subscriptions
    FOR INSERT WITH CHECK (
        user_has_role(org_id, 'admin')
    );
CREATE POLICY org_subscriptions_update ON org_subscriptions
    FOR UPDATE USING (
        user_has_role(org_id, 'admin')
    );

-- Members: org members can see each other; admin/manager can insert
CREATE POLICY members_read ON members
    FOR SELECT USING (
        org_id IN (SELECT org_id FROM members m WHERE m.user_id = auth.uid() AND m.is_active = TRUE)
    );
CREATE POLICY members_manage ON members
    FOR INSERT WITH CHECK (
        user_has_role(org_id, 'manager')
    );
CREATE POLICY members_update ON members
    FOR UPDATE USING (
        user_has_role(org_id, 'admin')
    );

-- All operational tables: org members can read, manager+ can write
-- Using a macro pattern for consistency

-- FARMS
CREATE POLICY farms_read ON farms
    FOR SELECT USING (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY farms_write ON farms
    FOR INSERT WITH CHECK (user_has_role(org_id, 'manager'));
CREATE POLICY farms_update ON farms
    FOR UPDATE USING (user_has_role(org_id, 'manager'));
CREATE POLICY farms_delete ON farms
    FOR DELETE USING (user_has_role(org_id, 'admin'));

-- HOUSES
CREATE POLICY houses_read ON houses
    FOR SELECT USING (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY houses_write ON houses
    FOR INSERT WITH CHECK (user_has_role(org_id, 'manager'));
CREATE POLICY houses_update ON houses
    FOR UPDATE USING (user_has_role(org_id, 'manager'));

-- BATCHES
CREATE POLICY batches_read ON batches
    FOR SELECT USING (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY batches_write ON batches
    FOR INSERT WITH CHECK (user_has_role(org_id, 'manager'));
CREATE POLICY batches_update ON batches
    FOR UPDATE USING (user_has_role(org_id, 'manager'));

-- DAILY LOGS — staff can write (they record daily)
CREATE POLICY logs_read ON daily_logs
    FOR SELECT USING (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY logs_write ON daily_logs
    FOR INSERT WITH CHECK (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY logs_update ON daily_logs
    FOR UPDATE USING (user_has_role(org_id, 'manager'));

-- FEED DELIVERIES
CREATE POLICY feed_del_read ON feed_deliveries
    FOR SELECT USING (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY feed_del_write ON feed_deliveries
    FOR INSERT WITH CHECK (user_has_role(org_id, 'manager'));
CREATE POLICY feed_del_update ON feed_deliveries
    FOR UPDATE USING (user_has_role(org_id, 'manager'));

-- EGG INVENTORY — staff can write (daily egg collection)
CREATE POLICY egg_inv_read ON egg_inventory
    FOR SELECT USING (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY egg_inv_write ON egg_inventory
    FOR INSERT WITH CHECK (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY egg_inv_update ON egg_inventory
    FOR UPDATE USING (user_has_role(org_id, 'manager'));

-- SUPPLIER LEDGER — manager+ only (financial data)
CREATE POLICY ledger_read ON supplier_ledger
    FOR SELECT USING (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY ledger_write ON supplier_ledger
    FOR INSERT WITH CHECK (user_has_role(org_id, 'manager'));
CREATE POLICY ledger_update ON supplier_ledger
    FOR UPDATE USING (user_has_role(org_id, 'manager'));

-- MARKET PRICES
CREATE POLICY prices_read ON market_prices
    FOR SELECT USING (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY prices_write ON market_prices
    FOR INSERT WITH CHECK (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));

-- INVENTORY CHECKS
CREATE POLICY inv_checks_read ON inventory_checks
    FOR SELECT USING (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY inv_checks_write ON inventory_checks
    FOR INSERT WITH CHECK (user_has_role(org_id, 'manager'));

-- BATCH OUTCOMES
CREATE POLICY batch_outcomes_read ON batch_outcomes
    FOR SELECT USING (org_id IN (SELECT org_id FROM members WHERE user_id = auth.uid() AND is_active = TRUE));
CREATE POLICY batch_outcomes_write ON batch_outcomes
    FOR INSERT WITH CHECK (user_has_role(org_id, 'manager'));
CREATE POLICY batch_outcomes_update ON batch_outcomes
    FOR UPDATE USING (user_has_role(org_id, 'manager'));

-- ============================================================================
-- VIEW: BATCH DASHBOARD
-- The farmer's primary view. Feed, mortality, eggs, age, sell countdown.
-- ============================================================================
CREATE OR REPLACE VIEW v_batch_dashboard AS
SELECT
    b.id AS batch_id,
    b.org_id,
    b.farm_id,
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
    FLOOR((CURRENT_DATE - b.start_date) / 7.0)::INTEGER AS age_weeks,
    -- Mortality
    COALESCE(agg.total_deaths, 0) AS total_deaths,
    ROUND(COALESCE(agg.total_deaths, 0) * 100.0 / NULLIF(b.initial_count, 0), 1) AS mortality_pct,
    -- Feed
    COALESCE(agg.total_feed, 0) AS total_feed_bags,
    ROUND(COALESCE(agg.total_feed, 0) / NULLIF(CURRENT_DATE - b.start_date, 0), 2) AS avg_daily_feed,
    -- Sell countdown
    CASE
        WHEN b.target_end_date IS NOT NULL AND b.status = 'active'
        THEN b.target_end_date - CURRENT_DATE
    END AS days_to_target,
    -- Recording health
    COALESCE(agg.days_recorded, 0) AS days_recorded,
    agg.last_record_date
FROM batches b
LEFT JOIN LATERAL (
    SELECT
        SUM(deaths)::INTEGER AS total_deaths,
        SUM(feed_bags) AS total_feed,
        COUNT(*) AS days_recorded,
        MAX(log_date) AS last_record_date
    FROM daily_logs WHERE batch_id = b.id
) agg ON TRUE;

-- ============================================================================
-- VIEW: RECORDING COMPLETENESS (behavior driver; no new fields)
-- Last 7 days coverage for active batches.
-- ============================================================================
CREATE OR REPLACE VIEW v_recording_completeness AS
SELECT
    b.org_id,
    b.farm_id,
    b.id AS batch_id,
    b.name AS batch_name,
    COUNT(dl.id) FILTER (WHERE dl.log_date >= CURRENT_DATE - 7) AS logs_last_7d,
    7 AS expected_days,
    ROUND(
        COUNT(dl.id) FILTER (WHERE dl.log_date >= CURRENT_DATE - 7) * 100.0 / 7.0,
        0
    ) AS completeness_pct,
    MAX(dl.log_date) AS last_log_date
FROM batches b
LEFT JOIN daily_logs dl ON dl.batch_id = b.id
WHERE b.status = 'active'
GROUP BY b.org_id, b.farm_id, b.id, b.name;

-- ============================================================================
-- VIEW: FEED INVENTORY (theft detection)
-- Expected bags = received − used. Gap = expected − counted.
-- ============================================================================
CREATE OR REPLACE VIEW v_feed_inventory AS
SELECT
    f.org_id,
    f.id AS farm_id,
    f.name AS farm_name,
    COALESCE(del.total_received, 0) AS bags_received,
    COALESCE(used.total_used, 0) AS bags_used,
    COALESCE(del.total_received, 0) - COALESCE(used.total_used, 0) AS bags_expected,
    chk.last_check_date,
    chk.last_counted,
    CASE
        WHEN chk.last_counted IS NOT NULL
        THEN ROUND(
            (COALESCE(del.total_received, 0) - COALESCE(used.total_used, 0)) - chk.last_counted,
            2
        )
    END AS gap_bags,
    CASE
        WHEN chk.last_counted IS NOT NULL AND del.avg_cost IS NOT NULL
        THEN ROUND(
            ((COALESCE(del.total_received, 0) - COALESCE(used.total_used, 0)) - chk.last_counted)
            * del.avg_cost,
            2
        )
    END AS gap_value_ghs
FROM farms f
LEFT JOIN LATERAL (
    SELECT
        COALESCE(SUM(bags_received), 0) AS total_received,
        AVG(cost_per_bag) AS avg_cost
    FROM feed_deliveries WHERE farm_id = f.id
) del ON TRUE
LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(dl.feed_bags), 0) AS total_used
    FROM daily_logs dl
    JOIN batches b ON b.id = dl.batch_id
    WHERE b.farm_id = f.id
) used ON TRUE
LEFT JOIN LATERAL (
    SELECT check_date AS last_check_date, counted AS last_counted
    FROM inventory_checks
    WHERE farm_id = f.id AND item_type = 'feed'
    ORDER BY check_date DESC LIMIT 1
) chk ON TRUE;

-- ============================================================================
-- VIEW: FEED STOCK-OUT RISK (derived, no extra data entry)
-- Days of feed left = expected_bags / avg_daily_bags_last_7d
-- ============================================================================
CREATE OR REPLACE VIEW v_feed_stockout_risk AS
SELECT
    inv.org_id,
    inv.farm_id,
    inv.farm_name,
    inv.bags_expected,
    COALESCE(usage.avg_daily_bags_7d, 0) AS avg_daily_bags_7d,
    CASE
        WHEN COALESCE(usage.avg_daily_bags_7d, 0) > 0
        THEN ROUND(inv.bags_expected / usage.avg_daily_bags_7d, 1)
    END AS days_of_feed_left
FROM v_feed_inventory inv
LEFT JOIN LATERAL (
    SELECT ROUND(AVG(d.feed_bags), 2) AS avg_daily_bags_7d
    FROM daily_logs d
    JOIN batches b ON b.id = d.batch_id
    WHERE b.farm_id = inv.farm_id
      AND d.log_date >= CURRENT_DATE - 7
) usage ON TRUE;

-- ============================================================================
-- VIEW: SUPPLIER BALANCES
-- ============================================================================
CREATE OR REPLACE VIEW v_supplier_balances AS
SELECT
    org_id,
    supplier_name,
    SUM(CASE WHEN txn_type = 'purchase' AND is_credit THEN amount ELSE 0 END) AS total_credit,
    SUM(CASE WHEN txn_type = 'payment' THEN amount ELSE 0 END) AS total_paid,
    SUM(CASE WHEN txn_type = 'purchase' AND is_credit THEN amount ELSE 0 END)
        - SUM(CASE WHEN txn_type = 'payment' THEN amount ELSE 0 END) AS balance_owed,
    MIN(CASE
        WHEN txn_type = 'purchase' AND is_credit AND due_date >= CURRENT_DATE
        THEN due_date
    END) AS next_due_date,
    SUM(CASE
        WHEN txn_type = 'purchase' AND is_credit AND due_date < CURRENT_DATE
        THEN amount ELSE 0
    END) AS overdue_amount,
    MAX(CASE WHEN txn_type = 'payment' THEN txn_date END) AS last_payment_date,
    COUNT(*) AS total_transactions
FROM supplier_ledger
GROUP BY org_id, supplier_name;

-- ============================================================================
-- VIEW: CASH PINCH FORECAST (derived)
-- Sums upcoming credit obligations by window: 7d / 14d / 30d.
-- ============================================================================
CREATE OR REPLACE VIEW v_cash_pinch AS
SELECT
    org_id,
    SUM(amount) FILTER (
        WHERE txn_type = 'purchase' AND is_credit = TRUE AND due_date IS NOT NULL
          AND due_date >= CURRENT_DATE AND due_date <= CURRENT_DATE + 7
    ) AS due_next_7d,
    SUM(amount) FILTER (
        WHERE txn_type = 'purchase' AND is_credit = TRUE AND due_date IS NOT NULL
          AND due_date >= CURRENT_DATE AND due_date <= CURRENT_DATE + 14
    ) AS due_next_14d,
    SUM(amount) FILTER (
        WHERE txn_type = 'purchase' AND is_credit = TRUE AND due_date IS NOT NULL
          AND due_date >= CURRENT_DATE AND due_date <= CURRENT_DATE + 30
    ) AS due_next_30d,
    SUM(amount) FILTER (
        WHERE txn_type = 'purchase' AND is_credit = TRUE AND due_date IS NOT NULL
          AND due_date < CURRENT_DATE
    ) AS overdue
FROM supplier_ledger
GROUP BY org_id;

-- ============================================================================
-- VIEW: EGG PRODUCTION SUMMARY (layers money signal)
-- ============================================================================
CREATE OR REPLACE VIEW v_egg_summary AS
SELECT
    org_id,
    farm_id,
    -- This week
    SUM(collected) FILTER (WHERE record_date >= CURRENT_DATE - 7) AS eggs_this_week,
    SUM(sold) FILTER (WHERE record_date >= CURRENT_DATE - 7) AS sold_this_week,
    SUM(sale_amount) FILTER (WHERE record_date >= CURRENT_DATE - 7) AS revenue_this_week,
    SUM(broken) FILTER (WHERE record_date >= CURRENT_DATE - 7) AS broken_this_week,
    -- This month
    SUM(collected) FILTER (WHERE record_date >= DATE_TRUNC('month', CURRENT_DATE)) AS eggs_this_month,
    SUM(sold) FILTER (WHERE record_date >= DATE_TRUNC('month', CURRENT_DATE)) AS sold_this_month,
    SUM(sale_amount) FILTER (WHERE record_date >= DATE_TRUNC('month', CURRENT_DATE)) AS revenue_this_month,
    -- Breakage rate (money lost)
    ROUND(
        SUM(broken) FILTER (WHERE record_date >= CURRENT_DATE - 30) * 100.0
        / NULLIF(SUM(collected) FILTER (WHERE record_date >= CURRENT_DATE - 30), 0),
        1
    ) AS breakage_rate_30d,
    -- Latest stock
    (SELECT closing_stock FROM egg_inventory ei
     WHERE ei.farm_id = egg_inventory.farm_id
     ORDER BY record_date DESC LIMIT 1) AS current_stock
FROM egg_inventory
GROUP BY org_id, farm_id;

-- ============================================================================
-- VIEW: MORTALITY BY SUPPLIER (highest-value long-term insight)
-- ============================================================================
CREATE OR REPLACE VIEW v_mortality_by_supplier AS
SELECT
    b.org_id,
    b.chick_supplier,
    COUNT(DISTINCT b.id) AS batch_count,
    ROUND(AVG(
        COALESCE(d.total_deaths, 0) * 100.0 / NULLIF(b.initial_count, 0)
    ), 1) AS avg_mortality_pct,
    MIN(COALESCE(d.total_deaths, 0) * 100.0 / NULLIF(b.initial_count, 0)) AS best_batch_pct,
    MAX(COALESCE(d.total_deaths, 0) * 100.0 / NULLIF(b.initial_count, 0)) AS worst_batch_pct,
    SUM(b.initial_count) AS total_birds
FROM batches b
LEFT JOIN LATERAL (
    SELECT SUM(deaths) AS total_deaths FROM daily_logs WHERE batch_id = b.id
) d ON TRUE
WHERE b.chick_supplier IS NOT NULL AND b.status = 'completed'
GROUP BY b.org_id, b.chick_supplier;

-- ============================================================================
-- VIEW: MORTALITY BY SEASON (Ghana-specific seasons)
-- ============================================================================
CREATE OR REPLACE VIEW v_mortality_by_season AS
SELECT
    b.org_id,
    CASE
        WHEN EXTRACT(MONTH FROM b.start_date) IN (3,4,5) THEN 'Mar-May (hot/rainy)'
        WHEN EXTRACT(MONTH FROM b.start_date) IN (6,7,8) THEN 'Jun-Aug (rainy)'
        WHEN EXTRACT(MONTH FROM b.start_date) IN (9,10,11) THEN 'Sep-Nov (dry)'
        ELSE 'Dec-Feb (harmattan)'
    END AS season,
    COUNT(DISTINCT b.id) AS batch_count,
    ROUND(AVG(
        COALESCE(d.total_deaths, 0) * 100.0 / NULLIF(b.initial_count, 0)
    ), 1) AS avg_mortality_pct
FROM batches b
LEFT JOIN LATERAL (
    SELECT SUM(deaths) AS total_deaths FROM daily_logs WHERE batch_id = b.id
) d ON TRUE
WHERE b.status = 'completed'
GROUP BY b.org_id, season;

-- ============================================================================
-- VIEW: PRICE CONTEXT (sell/wait decision support)
-- ============================================================================
CREATE OR REPLACE VIEW v_price_context AS
SELECT
    org_id,
    price_type,
    unit,
    MIN(price_per_unit) FILTER (WHERE price_date >= CURRENT_DATE - 14) AS min_14d,
    MAX(price_per_unit) FILTER (WHERE price_date >= CURRENT_DATE - 14) AS max_14d,
    ROUND(AVG(price_per_unit) FILTER (WHERE price_date >= CURRENT_DATE - 14), 2) AS avg_14d,
    ROUND(AVG(price_per_unit) FILTER (WHERE price_date >= CURRENT_DATE - 7), 2) AS avg_7d,
    CASE
        WHEN AVG(price_per_unit) FILTER (WHERE price_date >= CURRENT_DATE - 7) >
             AVG(price_per_unit) FILTER (WHERE price_date BETWEEN CURRENT_DATE - 14 AND CURRENT_DATE - 8)
        THEN 'rising'
        WHEN AVG(price_per_unit) FILTER (WHERE price_date >= CURRENT_DATE - 7) <
             AVG(price_per_unit) FILTER (WHERE price_date BETWEEN CURRENT_DATE - 14 AND CURRENT_DATE - 8)
        THEN 'falling'
        ELSE 'stable'
    END AS trend,
    COUNT(*) FILTER (WHERE price_date >= CURRENT_DATE - 14) AS data_points,
    MAX(price_date) AS last_price_date
FROM market_prices
GROUP BY org_id, price_type, unit;

-- ============================================================================
-- VIEW: FARM P&L SNAPSHOT (the money view)
-- Revenue vs costs at farm level. This is what justifies the subscription.
-- ============================================================================
CREATE OR REPLACE VIEW v_farm_pnl AS
SELECT
    f.org_id,
    f.id AS farm_id,
    f.name AS farm_name,
    -- Revenue: egg sales (from egg_inventory)
    COALESCE(eggs.revenue_30d, 0) AS egg_revenue_30d,
    -- Revenue: bird sales (from batch_outcomes)
    COALESCE(birds.sale_revenue_30d, 0) AS bird_revenue_30d,
    -- Total revenue
    COALESCE(eggs.revenue_30d, 0) + COALESCE(birds.sale_revenue_30d, 0) AS total_revenue_30d,
    -- Costs: feed (from feed_deliveries)
    COALESCE(feed.cost_30d, 0) AS feed_cost_30d,
    -- Costs: supplier purchases (from ledger)
    COALESCE(sup.purchases_30d, 0) AS supplier_cost_30d,
    -- Gross margin
    (COALESCE(eggs.revenue_30d, 0) + COALESCE(birds.sale_revenue_30d, 0))
        - COALESCE(feed.cost_30d, 0) AS gross_margin_30d
FROM farms f
LEFT JOIN LATERAL (
    SELECT SUM(sale_amount) AS revenue_30d
    FROM egg_inventory
    WHERE farm_id = f.id AND record_date >= CURRENT_DATE - 30
) eggs ON TRUE
LEFT JOIN LATERAL (
    SELECT SUM(bo.total_sale_amount) AS sale_revenue_30d
    FROM batch_outcomes bo
    JOIN batches b ON b.id = bo.batch_id
    WHERE b.farm_id = f.id
      AND bo.closed_date >= CURRENT_DATE - 30
) birds ON TRUE
LEFT JOIN LATERAL (
    SELECT SUM(COALESCE(total_cost, bags_received * COALESCE(cost_per_bag, 0))) AS cost_30d
    FROM feed_deliveries
    WHERE farm_id = f.id AND delivery_date >= CURRENT_DATE - 30
) feed ON TRUE
LEFT JOIN LATERAL (
    SELECT SUM(amount) AS purchases_30d
    FROM supplier_ledger
    WHERE org_id = f.org_id AND txn_type = 'purchase'
      AND txn_date >= CURRENT_DATE - 30
) sup ON TRUE;

-- ============================================================================
-- VIEW: ORG ROLLUP (multi-farm owners)
-- Gives a single money number for the whole business.
-- ============================================================================
CREATE OR REPLACE VIEW v_org_summary_30d AS
SELECT
    org_id,
    SUM(total_revenue_30d) AS total_revenue_30d,
    SUM(feed_cost_30d) AS total_feed_cost_30d,
    SUM(gross_margin_30d) AS total_gross_margin_30d,
    COUNT(*) AS farm_count
FROM v_farm_pnl
GROUP BY org_id;

-- ============================================================================
-- FUNCTION: Feed cost of waiting past target sell date
-- "Every extra day costs GH₵X in feed"
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
    total_delay_cost NUMERIC
) AS $$
SELECT
    b.name,
    GREATEST(CURRENT_DATE - b.target_end_date, 0)::INTEGER,
    ROUND(COALESCE(AVG(dl.feed_bags), 0), 2),
    ROUND(COALESCE(AVG(dl.feed_bags), 0) * p_cost_per_bag, 2),
    ROUND(GREATEST(CURRENT_DATE - b.target_end_date, 0) * COALESCE(AVG(dl.feed_bags), 0) * p_cost_per_bag, 2)
FROM batches b
LEFT JOIN daily_logs dl ON dl.batch_id = b.id
WHERE b.id = p_batch_id
GROUP BY b.id, b.name, b.target_end_date;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ============================================================================
-- SCHEMA MAP → MONEY SIGNALS
-- ============================================================================
--
-- FEED THEFT:
--   daily_logs.feed_bags + feed_deliveries + inventory_checks
--   → v_feed_inventory.gap_bags, gap_value_ghs
--
-- SELLING WINDOW:
--   batches.target_end_date + market_prices
--   → v_batch_dashboard.days_to_target + v_price_context.trend
--   → fn_feed_cost_of_waiting()
--
-- SUPPLIER PAYMENTS:
--   supplier_ledger
--   → v_supplier_balances.balance_owed, overdue_amount
--
-- MORTALITY PATTERNS:
--   daily_logs.deaths + batches.chick_supplier
--   → v_mortality_by_supplier, v_mortality_by_season
--
-- EGG REVENUE:
--   egg_inventory only (farm-level)
--   → v_egg_summary.revenue_this_week, breakage_rate
--
-- FARM PROFITABILITY:
--   All above combined
--   → v_farm_pnl.gross_margin_30d
--
-- ============================================================================
-- TABLE COUNT: 11 (down from 12)
-- VIEW COUNT: 8 (focused on money signals + analytics)
-- FUNCTION COUNT: 4 (onboard, invite, deactivate, feed cost)
-- DAILY INPUT: feed_bags + deaths + eggs = under 2 minutes
-- ============================================================================
