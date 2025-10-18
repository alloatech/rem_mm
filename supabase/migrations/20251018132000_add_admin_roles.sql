-- Add Admin Role System to app_users
-- This migration adds role-based access control with admin capabilities

-- Create user role enum
CREATE TYPE user_role AS ENUM ('user', 'admin', 'super_admin');

-- Add role column to app_users
ALTER TABLE app_users 
ADD COLUMN user_role user_role DEFAULT 'user' NOT NULL;

-- Add index for efficient role-based queries
CREATE INDEX idx_app_users_role ON app_users(user_role);

-- Add admin-only audit log for role changes
CREATE TABLE admin_role_changes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id UUID REFERENCES app_users(id) ON DELETE CASCADE,
  target_sleeper_user_id TEXT,
  old_role user_role,
  new_role user_role NOT NULL,
  changed_by_user_id UUID REFERENCES app_users(id),
  changed_by_sleeper_user_id TEXT,
  reason TEXT,
  ip_address INET,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for audit queries
CREATE INDEX idx_admin_role_changes_target ON admin_role_changes(target_user_id);
CREATE INDEX idx_admin_role_changes_by ON admin_role_changes(changed_by_user_id);
CREATE INDEX idx_admin_role_changes_date ON admin_role_changes(created_at);

-- RLS Policies for admin_role_changes (only admins can see)
ALTER TABLE admin_role_changes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admin role changes admin access" ON admin_role_changes
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM app_users 
      WHERE (supabase_user_id = auth.uid() OR sleeper_user_id = current_setting('app.current_sleeper_user_id', true))
      AND user_role IN ('admin', 'super_admin')
    )
  );

-- Function to check if current user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check by Supabase auth first
  IF auth.uid() IS NOT NULL THEN
    RETURN EXISTS (
      SELECT 1 FROM app_users 
      WHERE supabase_user_id = auth.uid() 
      AND user_role IN ('admin', 'super_admin')
    );
  END IF;
  
  -- Fallback to sleeper_user_id setting
  RETURN EXISTS (
    SELECT 1 FROM app_users 
    WHERE sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    AND user_role IN ('admin', 'super_admin')
  );
END;
$$ LANGUAGE plpgsql;

-- Function to check if current user is super admin
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    RETURN EXISTS (
      SELECT 1 FROM app_users 
      WHERE supabase_user_id = auth.uid() 
      AND user_role = 'super_admin'
    );
  END IF;
  
  RETURN EXISTS (
    SELECT 1 FROM app_users 
    WHERE sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    AND user_role = 'super_admin'
  );
END;
$$ LANGUAGE plpgsql;

-- Function to safely change user roles (with audit logging)
CREATE OR REPLACE FUNCTION change_user_role(
  target_sleeper_user_id TEXT,
  new_role user_role,
  reason TEXT DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  old_role user_role,
  new_role_value user_role
)
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_record RECORD;
  target_user_record RECORD;
  old_role_value user_role;
BEGIN
  -- Get current user (admin making the change)
  SELECT * INTO current_user_record FROM get_current_app_user();
  
  IF current_user_record IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated'::TEXT, NULL::user_role, NULL::user_role;
    RETURN;
  END IF;
  
  -- Check if current user is admin
  IF NOT is_admin() THEN
    RETURN QUERY SELECT false, 'Access denied: Admin role required'::TEXT, NULL::user_role, NULL::user_role;
    RETURN;
  END IF;
  
  -- Get target user
  SELECT * INTO target_user_record 
  FROM app_users 
  WHERE sleeper_user_id = target_sleeper_user_id;
  
  IF target_user_record IS NULL THEN
    RETURN QUERY SELECT false, 'Target user not found'::TEXT, NULL::user_role, NULL::user_role;
    RETURN;
  END IF;
  
  -- Super admin restriction: only super admins can create/modify other super admins
  IF (new_role = 'super_admin' OR target_user_record.user_role = 'super_admin') 
     AND NOT is_super_admin() THEN
    RETURN QUERY SELECT false, 'Access denied: Super admin role required'::TEXT, NULL::user_role, NULL::user_role;
    RETURN;
  END IF;
  
  -- Store old role for audit
  old_role_value := target_user_record.user_role;
  
  -- Update the role
  UPDATE app_users 
  SET user_role = new_role, updated_at = NOW()
  WHERE sleeper_user_id = target_sleeper_user_id;
  
  -- Log the change
  INSERT INTO admin_role_changes (
    target_user_id,
    target_sleeper_user_id,
    old_role,
    new_role,
    changed_by_user_id,
    changed_by_sleeper_user_id,
    reason
  ) VALUES (
    target_user_record.id,
    target_sleeper_user_id,
    old_role_value,
    new_role,
    current_user_record.id,
    current_user_record.sleeper_user_id,
    reason
  );
  
  RETURN QUERY SELECT true, 'Role updated successfully'::TEXT, old_role_value, new_role;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin() TO anon;
GRANT EXECUTE ON FUNCTION is_super_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION is_super_admin() TO anon;
GRANT EXECUTE ON FUNCTION change_user_role(TEXT, user_role, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION change_user_role(TEXT, user_role, TEXT) TO anon;

-- Drop and recreate get_current_app_user function to include role
DROP FUNCTION IF EXISTS get_current_app_user();

CREATE OR REPLACE FUNCTION get_current_app_user()
RETURNS TABLE (
    id UUID,
    sleeper_user_id TEXT,
    sleeper_username TEXT,
    display_name TEXT,
    supabase_user_id UUID,
    user_role user_role
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
            u.supabase_user_id,
            u.user_role
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
        u.supabase_user_id,
        u.user_role
    FROM app_users u
    WHERE u.sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Set initial admin user (you can change this to your user)
-- This is safe to run multiple times
DO $$
BEGIN
  -- Make th0rjc a super admin (you can change this)
  UPDATE app_users 
  SET user_role = 'super_admin' 
  WHERE sleeper_user_id = '872612101674491904'
  AND user_role != 'super_admin'; -- Only if not already super admin
  
  IF FOUND THEN
    RAISE NOTICE '✅ th0rjc promoted to super admin';
  ELSE
    RAISE NOTICE 'ℹ️  th0rjc is already super admin or user not found';
  END IF;
END $$;

COMMENT ON TYPE user_role IS 'User roles: user (standard), admin (can manage users), super_admin (can manage admins)';
COMMENT ON TABLE admin_role_changes IS 'Audit log for admin role changes';
COMMENT ON FUNCTION is_admin() IS 'Returns true if current user has admin or super_admin role';
COMMENT ON FUNCTION change_user_role(TEXT, user_role, TEXT) IS 'Safely change user roles with audit logging';