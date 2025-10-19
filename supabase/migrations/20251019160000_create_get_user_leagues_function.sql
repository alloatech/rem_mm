-- Create a function to get user leagues with RLS context
-- This sets the app.current_sleeper_user_id config variable within the transaction

CREATE OR REPLACE FUNCTION get_user_leagues(p_sleeper_user_id TEXT)
RETURNS TABLE (
  id UUID,
  app_user_id UUID,
  sleeper_league_id TEXT,
  league_name TEXT,
  season INTEGER,
  sport TEXT,
  league_type TEXT,
  total_rosters INTEGER,
  scoring_settings JSONB,
  roster_positions JSONB,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  last_synced TIMESTAMPTZ,
  is_active BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Set the config variable for RLS
  PERFORM set_config('app.current_sleeper_user_id', p_sleeper_user_id, true);
  
  -- Return the leagues (RLS policy will now allow access)
  RETURN QUERY
  SELECT 
    ul.id,
    ul.app_user_id,
    ul.sleeper_league_id,
    ul.league_name,
    ul.season,
    ul.sport,
    ul.league_type,
    ul.total_rosters,
    ul.scoring_settings,
    ul.roster_positions,
    ul.created_at,
    ul.updated_at,
    ul.last_synced,
    ul.is_active
  FROM user_leagues ul
  INNER JOIN app_users au ON ul.app_user_id = au.id
  WHERE au.sleeper_user_id = p_sleeper_user_id
    AND ul.is_active = true
  ORDER BY ul.season DESC, ul.league_name;
END;
$$;

-- Grant execute permission to authenticated users and anon role
GRANT EXECUTE ON FUNCTION get_user_leagues(TEXT) TO authenticated, anon;

-- Add comment
COMMENT ON FUNCTION get_user_leagues(TEXT) IS 
'Returns all active leagues for a user by their Sleeper user ID. Sets RLS context automatically.';
