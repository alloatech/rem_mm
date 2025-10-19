-- Add additional league details for better UI display
-- Status, settings (separate from scoring), and metadata

ALTER TABLE leagues 
  ADD COLUMN IF NOT EXISTS status TEXT,
  ADD COLUMN IF NOT EXISTS settings JSONB,
  ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Update get_user_leagues function to include new fields
CREATE OR REPLACE FUNCTION get_user_leagues(p_app_user_id UUID)
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
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  last_synced TIMESTAMPTZ,
  is_active BOOLEAN,
  avatar TEXT,
  status TEXT,
  settings JSONB,
  metadata JSONB
)
LANGUAGE SQL
STABLE
AS $$
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
    l.created_at,
    l.updated_at,
    l.last_synced,
    l.is_active,
    l.avatar,
    l.status,
    l.settings,
    l.metadata
  FROM leagues l
  INNER JOIN user_rosters ur ON ur.league_id = l.id
  WHERE ur.app_user_id = p_app_user_id
    AND l.is_active = true
  GROUP BY l.id
  ORDER BY l.season DESC, l.league_name;
$$;
