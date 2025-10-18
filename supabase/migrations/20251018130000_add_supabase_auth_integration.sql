-- Migration: Add Supabase Auth Integration
-- This migration adds the necessary columns to link app_users to Supabase auth users

-- Add supabase_user_id column to app_users table
ALTER TABLE app_users 
ADD COLUMN supabase_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Create index for faster lookups
CREATE INDEX idx_app_users_supabase_id ON app_users(supabase_user_id);

-- Make the supabase_user_id unique (one Supabase user per app user)
ALTER TABLE app_users 
ADD CONSTRAINT app_users_supabase_user_id_unique UNIQUE (supabase_user_id);

-- Update RLS policies for better auth integration
-- Policy for authenticated users to read their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON app_users;
CREATE POLICY "Authenticated users can view own profile" ON app_users
    FOR SELECT USING (
        auth.uid() = supabase_user_id OR 
        sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    );

-- Policy for authenticated users to update their own profile  
DROP POLICY IF EXISTS "Users can update own profile" ON app_users;
CREATE POLICY "Authenticated users can update own profile" ON app_users
    FOR UPDATE USING (
        auth.uid() = supabase_user_id OR
        sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    );

-- Policy for authenticated users to insert their own profile
CREATE POLICY "Authenticated users can create own profile" ON app_users
    FOR INSERT WITH CHECK (auth.uid() = supabase_user_id);

-- Create a function to get current user info
CREATE OR REPLACE FUNCTION get_current_app_user()
RETURNS TABLE (
    id UUID,
    sleeper_user_id TEXT,
    sleeper_username TEXT,
    display_name TEXT,
    supabase_user_id UUID
) 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- First try to find by Supabase auth user
    IF auth.uid() IS NOT NULL THEN
        RETURN QUERY
        SELECT 
            u.id,
            u.sleeper_user_id,
            u.sleeper_username,
            u.display_name,
            u.supabase_user_id
        FROM app_users u
        WHERE u.supabase_user_id = auth.uid()
        LIMIT 1;
        
        -- If found, return
        IF FOUND THEN
            RETURN;
        END IF;
    END IF;
    
    -- Fallback to sleeper_user_id from settings
    RETURN QUERY
    SELECT 
        u.id,
        u.sleeper_user_id,
        u.sleeper_username,
        u.display_name,
        u.supabase_user_id
    FROM app_users u
    WHERE u.sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_current_app_user() TO authenticated;
GRANT EXECUTE ON FUNCTION get_current_app_user() TO anon;

COMMENT ON COLUMN app_users.supabase_user_id IS 'Links to Supabase auth.users for authenticated sessions';
COMMENT ON FUNCTION get_current_app_user() IS 'Returns current app user based on Supabase auth or sleeper_user_id setting';