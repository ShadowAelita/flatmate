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
