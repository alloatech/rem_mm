-- Add avatar support for rosters and user profiles
-- This migration adds both user avatar IDs and team-specific avatar URLs

-- ============================================================================
-- 1. Add avatar columns to user_rosters table
-- ============================================================================

-- Add avatar_id column to store Sleeper user avatar IDs
ALTER TABLE user_rosters 
ADD COLUMN IF NOT EXISTS avatar_id TEXT;

COMMENT ON COLUMN user_rosters.avatar_id IS 'Sleeper avatar ID for user profile picture - use to construct URL: https://sleepercdn.com/avatars/thumbs/{avatar_id}';

-- Add team_avatar_url column to store team-specific avatar URLs
ALTER TABLE user_rosters 
ADD COLUMN IF NOT EXISTS team_avatar_url TEXT;

COMMENT ON COLUMN user_rosters.team_avatar_url IS 'Team-specific custom avatar URL from Sleeper metadata.avatar (full URL, e.g., https://sleepercdn.com/uploads/{hash}.jpg). Takes priority over user avatar.';

-- ============================================================================
-- 2. Add avatar_id to app_users table (if not exists)
-- ============================================================================

-- The app_users table should already have an 'avatar' column
-- We'll use that for storing avatar IDs
COMMENT ON COLUMN app_users.avatar IS 'Sleeper avatar ID for user profile picture - use to construct URL: https://sleepercdn.com/avatars/thumbs/{avatar}';

-- ============================================================================
-- 3. Create/Update get_league_rosters function
-- ============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_league_rosters(UUID, TEXT);

-- Create function that returns all roster data including avatar fields
CREATE OR REPLACE FUNCTION get_league_rosters(
  p_league_id UUID,
  p_sleeper_user_id TEXT
)
RETURNS TABLE (
  id UUID,
  app_user_id UUID,
  sleeper_roster_id INTEGER,
  player_ids TEXT[],
  starters TEXT[],
  reserves TEXT[],
  taxi TEXT[],
  settings JSONB,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  last_synced TIMESTAMPTZ,
  sleeper_owner_id TEXT,
  team_name TEXT,
  owner_display_name TEXT,
  league_id UUID,
  avatar_id TEXT,
  team_avatar_url TEXT
) AS $$
BEGIN
  -- Set the current sleeper user ID for the session
  PERFORM set_config('app.current_sleeper_user_id', p_sleeper_user_id, true);
  
  -- Return all rosters for the league with avatar_id and team_avatar_url
  RETURN QUERY
  SELECT ur.id, ur.app_user_id, ur.sleeper_roster_id, ur.player_ids, 
         ur.starters, ur.reserves, ur.taxi, ur.settings, 
         ur.created_at, ur.updated_at, ur.last_synced, ur.sleeper_owner_id,
         ur.team_name, ur.owner_display_name, ur.league_id, ur.avatar_id, ur.team_avatar_url
  FROM user_rosters ur
  WHERE ur.league_id = p_league_id
  ORDER BY ur.sleeper_roster_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_league_rosters IS 'Retrieve all rosters for a league with proper RLS context and avatar data. Includes both user avatar IDs and team-specific avatar URLs.';

-- ============================================================================
-- 4. Create function to update user avatar ID
-- ============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS update_user_avatar_id(TEXT, TEXT);

-- Create function to update avatar ID in app_users table
CREATE OR REPLACE FUNCTION update_user_avatar_id(
  p_sleeper_user_id TEXT,
  p_avatar_id TEXT
)
RETURNS TABLE (
  sleeper_user_id TEXT,
  sleeper_username TEXT,
  display_name TEXT,
  email TEXT,
  avatar TEXT,
  is_active BOOLEAN,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  last_login TIMESTAMPTZ
) AS $$
BEGIN
  -- Update the avatar ID for the user
  UPDATE app_users 
  SET avatar = p_avatar_id, updated_at = now()
  WHERE app_users.sleeper_user_id = p_sleeper_user_id;
  
  -- Return the updated user data
  RETURN QUERY
  SELECT au.sleeper_user_id, au.sleeper_username, au.display_name, 
         au.email, au.avatar, au.is_active, au.created_at, 
         au.updated_at, au.last_login
  FROM app_users au
  WHERE au.sleeper_user_id = p_sleeper_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION update_user_avatar_id IS 'Update the avatar ID for a user by their Sleeper user ID. Used when fetching avatar data from Sleeper API.';
