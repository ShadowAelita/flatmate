-- Migration: Add invite code + admin support
-- Run these SQL statements in your Supabase SQL editor.

-- ============================================================
-- HOUSEHOLDS: Add invite_code column
-- ============================================================
ALTER TABLE households
    ADD COLUMN IF NOT EXISTS invite_code TEXT;

-- Generate invite codes for existing households that don't have one.
UPDATE households
    SET invite_code = LEFT(gen_random_uuid()::TEXT, 8)
WHERE invite_code IS NULL;

-- Unique constraint so invite codes can be looked up safely.
-- Note: PostgreSQL does not support IF NOT EXISTS on ADD CONSTRAINT.
-- We use a DO block to skip if the constraint already exists.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'households_invite_code_unique'
    ) THEN
        ALTER TABLE households
        ADD CONSTRAINT households_invite_code_unique
        UNIQUE (invite_code);
    END IF;
END $$;

-- ============================================================
-- MEMBERS: Add is_admin column
-- ============================================================
ALTER TABLE members
    ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

-- The first member (earliest created_at) of each household becomes admin.
UPDATE members m
    SET is_admin = TRUE
WHERE m.id IN (
    SELECT id
    FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                   PARTITION BY household_id
                   ORDER BY created_at ASC
               ) AS rn
        FROM members
    ) ranked
    WHERE ranked.rn = 1
);

-- ============================================================
-- SHOPPING_ITEMS: Add added_by column (for notifications)
-- ============================================================
ALTER TABLE shopping_items
    ADD COLUMN IF NOT EXISTS added_by UUID
    REFERENCES members(id) ON DELETE SET NULL;

ALTER TABLE shopping_items
    ADD COLUMN IF NOT EXISTS note TEXT;

-- ============================================================
-- CHAT_MESSAGES: Add reference columns for task/shopping item mentions
-- ============================================================
ALTER TABLE chat_messages
    ADD COLUMN IF NOT EXISTS reference_id UUID;

ALTER TABLE chat_messages
    ADD COLUMN IF NOT EXISTS reference_type TEXT CHECK (
        reference_type IN ('task', 'shopping_item')
    );

-- ============================================================
-- TASKS: Add added_by column (for notifications)
-- ============================================================
ALTER TABLE tasks
    ADD COLUMN IF NOT EXISTS added_by UUID
    REFERENCES members(id) ON DELETE SET NULL;

-- ============================================================
-- EXPENSES: Create expenses table (WG-Kasse)
-- ============================================================
-- If the table already exists (from an earlier migration), just add the
-- category column. If it doesn't exist yet, create it with the column.
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL
        REFERENCES households(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    paid_by UUID
        REFERENCES members(id) ON DELETE SET NULL,
    category TEXT,
    exclude_from_balance BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add category column to any pre-existing expenses table.
ALTER TABLE expenses
    ADD COLUMN IF NOT EXISTS category TEXT;

-- Add exclude_from_balance column for expenses that shouldn't
-- factor into the equalisation calculation (e.g. shared bills).
ALTER TABLE expenses
    ADD COLUMN IF NOT EXISTS exclude_from_balance BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS expenses_household_id_idx
    ON expenses(household_id);

CREATE INDEX IF NOT EXISTS expenses_created_at_idx
    ON expenses(created_at);

-- ============================================================
-- EXPENSE_CATEGORIES: Per-household custom categories table
-- ============================================================
CREATE TABLE IF NOT EXISTS expense_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL
        REFERENCES households(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS expense_categories_household_id_idx
    ON expense_categories(household_id);

-- ============================================================
-- ROW LEVEL SECURITY: Enable with permissive policies
-- ============================================================
-- This app uses invite codes for access control (not Supabase Auth),
-- so we enable RLS and create permissive policies allowing all
-- operations. Access is gated at the invitation step.
--
-- Enable RLS on all tables:
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE shopping_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE expense_categories ENABLE ROW LEVEL SECURITY;

-- Permissive policies (allow all operations).
-- Use DROP IF EXISTS first because CREATE POLICY is not idempotent.
DROP POLICY IF EXISTS "Allow all for households" ON households;
CREATE POLICY "Allow all for households" ON households
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for members" ON members;
CREATE POLICY "Allow all for members" ON members
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for tasks" ON tasks;
CREATE POLICY "Allow all for tasks" ON tasks
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for shopping_items" ON shopping_items;
CREATE POLICY "Allow all for shopping_items" ON shopping_items
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for chat_messages" ON chat_messages;
CREATE POLICY "Allow all for chat_messages" ON chat_messages
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for expenses" ON expenses;
CREATE POLICY "Allow all for expenses" ON expenses
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for expense_categories" ON expense_categories;
CREATE POLICY "Allow all for expense_categories" ON expense_categories
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for chores" ON chores;
CREATE POLICY "Allow all for chores" ON chores
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for inventory_items" ON inventory_items;
CREATE POLICY "Allow all for inventory_items" ON inventory_items
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for meals" ON meals;
CREATE POLICY "Allow all for meals" ON meals
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for polls" ON polls;
CREATE POLICY "Allow all for polls" ON polls
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for poll_options" ON poll_options;
CREATE POLICY "Allow all for poll_options" ON poll_options
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for poll_votes" ON poll_votes;
CREATE POLICY "Allow all for poll_votes" ON poll_votes
    FOR ALL USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for message_reactions" ON message_reactions;
CREATE POLICY "Allow all for message_reactions" ON message_reactions
    FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- GRANT TABLE PRIVILEGES TO ANON ROLE
-- ============================================================
-- RLS policies control row-level access, but PostgreSQL also
-- requires table-level privileges for the anon role to perform
-- CRUD operations. Without these GRANTs, the REST API returns
-- "permission denied" even when policies allow all operations.
-- ============================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON expenses TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON expense_categories TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON shopping_items TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON tasks TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_messages TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON members TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON households TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON chores TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_items TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON meals TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON polls TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON poll_options TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON poll_votes TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON message_reactions TO anon;

-- ============================================================
-- CHORES: Cleaning/rotating chores
-- ============================================================
CREATE TABLE IF NOT EXISTS chores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL
        REFERENCES households(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    frequency TEXT NOT NULL DEFAULT 'weekly',
    rotation_index INTEGER NOT NULL DEFAULT 0,
    last_completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS chores_household_id_idx
    ON chores(household_id);

-- ============================================================
-- INVENTORY_ITEMS: Household consumables
-- ============================================================
CREATE TABLE IF NOT EXISTS inventory_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL
        REFERENCES households(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    quantity NUMERIC(10,2) NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'Stk',
    min_quantity NUMERIC(10,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS inventory_items_household_id_idx
    ON inventory_items(household_id);

-- ============================================================
-- MEALS: Shared meal planner + recipes
-- ============================================================
CREATE TABLE IF NOT EXISTS meals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL
        REFERENCES households(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    recipe TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS meals_household_id_idx
    ON meals(household_id);

-- ============================================================
-- POLLS: Simple polls in chat
-- ============================================================
CREATE TABLE IF NOT EXISTS polls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL
        REFERENCES households(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    created_by UUID
        REFERENCES members(id) ON DELETE SET NULL,
    closed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS poll_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL
        REFERENCES polls(id) ON DELETE CASCADE,
    text TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS poll_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL
        REFERENCES polls(id) ON DELETE CASCADE,
    option_id UUID NOT NULL
        REFERENCES poll_options(id) ON DELETE CASCADE,
    member_id UUID NOT NULL
        REFERENCES members(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(poll_id, member_id)
);

CREATE INDEX IF NOT EXISTS polls_household_id_idx
    ON polls(household_id);
CREATE INDEX IF NOT EXISTS poll_options_poll_id_idx
    ON poll_options(poll_id);
CREATE INDEX IF NOT EXISTS poll_votes_poll_id_idx
    ON poll_votes(poll_id);

-- ============================================================
-- MESSAGE_REACTIONS: Emoji reactions on chat messages
-- ============================================================
CREATE TABLE IF NOT EXISTS message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL
        REFERENCES chat_messages(id) ON DELETE CASCADE,
    member_id UUID NOT NULL
        REFERENCES members(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(message_id, member_id, emoji)
);

CREATE INDEX IF NOT EXISTS message_reactions_message_id_idx
    ON message_reactions(message_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON shopping_items TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON tasks TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON chat_messages TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON members TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON households TO anon;

-- ============================================================
-- Helper: Generate a new invite code (call from a Postgres function)
-- ============================================================
CREATE OR REPLACE FUNCTION refresh_invite_code(household_id UUID)
RETURNS TEXT AS $$
DECLARE
    new_code TEXT;
BEGIN
    new_code := LEFT(gen_random_uuid()::TEXT, 8);
    UPDATE households
    SET invite_code = new_code
    WHERE id = household_id;
    RETURN new_code;
END;
$$ LANGUAGE plpgsql;
