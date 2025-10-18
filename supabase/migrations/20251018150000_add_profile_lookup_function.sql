-- Add profile lookup function that handles RLS context
-- This function allows the app to get user profiles with proper security

CREATE OR REPLACE FUNCTION get_user_profile(target_sleeper_user_id TEXT)
RETURNS TABLE (
  id UUID,
  sleeper_user_id TEXT,
  sleeper_username TEXT,
  display_name TEXT,
  avatar TEXT,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE,
  last_login TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN,
  supabase_user_id UUID,
  user_role user_role
) 
LANGUAGE plpgsql
SECURITY DEFINER  -- Run with elevated privileges
SET search_path = public
AS $$
BEGIN
  -- Set the RLS context for this session
  PERFORM set_config('app.current_sleeper_user_id', target_sleeper_user_id, true);
  
  -- Return the user profile data
  RETURN QUERY
  SELECT 
    u.id,
    u.sleeper_user_id,
    u.sleeper_username,
    u.display_name,
    u.avatar,
    u.email,
    u.created_at,
    u.updated_at,
    u.last_login,
    u.is_active,
    u.supabase_user_id,
    u.user_role
  FROM app_users u
  WHERE u.sleeper_user_id = target_sleeper_user_id;
END;
$$;

-- Grant execute permission to anon role (used by Flutter app)
GRANT EXECUTE ON FUNCTION get_user_profile(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_user_profile(TEXT) TO authenticated;