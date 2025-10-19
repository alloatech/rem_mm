-- Add avatar support for leagues
-- League avatars come from Sleeper API and should be displayed in UI

-- Add avatar column to leagues table
ALTER TABLE leagues 
ADD COLUMN IF NOT EXISTS avatar TEXT;

COMMENT ON COLUMN leagues.avatar IS 'Sleeper league avatar ID - use to construct URL: https://sleepercdn.com/avatars/thumbs/{avatar}';

-- Update get_user_leagues function to include avatar
DROP FUNCTION IF EXISTS get_user_leagues(TEXT);

CREATE OR REPLACE FUNCTION get_user_leagues(p_sleeper_user_id TEXT)
RETURNS TABLE (
  id UUID,
  sleeper_league_id TEXT,
  league_name TEXT,
  season INTEGER,
  sport TEXT,
  league_type TEXT,
  total_rosters INTEGER,
  scoring_settings JSONB,
  roster_positions JSONB,
  avatar TEXT,
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
  
  -- Return the leagues the user is a member of
  RETURN QUERY
  SELECT 
    l.id,
    l.sleeper_league_id,
    l.league_name,
    l.season,
    l.sport,
    l.league_type,
    l.total_rosters,
    l.scoring_settings,
    l.roster_positions,
    l.avatar,
    l.created_at,
    l.updated_at,
    l.last_synced,
    l.is_active
  FROM leagues l
  INNER JOIN league_memberships lm ON lm.league_id = l.id
  INNER JOIN app_users au ON au.id = lm.app_user_id
  WHERE au.sleeper_user_id = p_sleeper_user_id
    AND l.is_active = true
    AND lm.is_active = true
  ORDER BY l.season DESC, l.league_name;
END;
$$;

COMMENT ON FUNCTION get_user_leagues IS 'Get all leagues for a user with avatar support. Returns active leagues ordered by season and name.';
