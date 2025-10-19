-- Refactor leagues schema to avoid duplication
-- Problem: Current design duplicates league data for each user
-- Solution: Separate leagues table + junction table for memberships

-- Step 1: Create new leagues table (no user reference)
CREATE TABLE IF NOT EXISTS leagues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sleeper_league_id TEXT UNIQUE NOT NULL,
  league_name TEXT,
  season INTEGER,
  sport TEXT DEFAULT 'nfl',
  league_type TEXT, -- 'redraft', 'dynasty', 'keeper'
  total_rosters INTEGER,
  scoring_settings JSONB,
  roster_positions JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  last_synced TIMESTAMPTZ DEFAULT now(),
  is_active BOOLEAN DEFAULT true
);

-- Indexes for leagues
CREATE INDEX IF NOT EXISTS idx_leagues_sleeper_id ON leagues(sleeper_league_id);
CREATE INDEX IF NOT EXISTS idx_leagues_season ON leagues(season);
CREATE INDEX IF NOT EXISTS idx_leagues_active ON leagues(is_active) WHERE is_active = true;

-- Trigger for updated_at
CREATE TRIGGER update_leagues_updated_at
  BEFORE UPDATE ON leagues
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Step 2: Create league_memberships junction table
CREATE TABLE IF NOT EXISTS league_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_user_id UUID REFERENCES app_users(id) ON DELETE CASCADE,
  league_id UUID REFERENCES leagues(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  is_active BOOLEAN DEFAULT true,
  UNIQUE(app_user_id, league_id)
);

-- Indexes for league_memberships
CREATE INDEX IF NOT EXISTS idx_league_memberships_user ON league_memberships(app_user_id);
CREATE INDEX IF NOT EXISTS idx_league_memberships_league ON league_memberships(league_id);
CREATE INDEX IF NOT EXISTS idx_league_memberships_active ON league_memberships(is_active) WHERE is_active = true;

-- Step 3: Migrate data from user_leagues to new structure
-- First, insert unique leagues
INSERT INTO leagues (
  sleeper_league_id,
  league_name,
  season,
  sport,
  league_type,
  total_rosters,
  scoring_settings,
  roster_positions,
  created_at,
  updated_at,
  last_synced,
  is_active
)
SELECT DISTINCT ON (sleeper_league_id)
  sleeper_league_id,
  league_name,
  season,
  sport,
  league_type,
  total_rosters,
  scoring_settings,
  roster_positions,
  created_at,
  updated_at,
  last_synced,
  is_active
FROM user_leagues
ON CONFLICT (sleeper_league_id) DO UPDATE SET
  league_name = EXCLUDED.league_name,
  season = EXCLUDED.season,
  total_rosters = EXCLUDED.total_rosters,
  scoring_settings = EXCLUDED.scoring_settings,
  roster_positions = EXCLUDED.roster_positions,
  updated_at = EXCLUDED.updated_at,
  last_synced = EXCLUDED.last_synced;

-- Then, create league memberships
INSERT INTO league_memberships (app_user_id, league_id, joined_at)
SELECT 
  ul.app_user_id,
  l.id,
  ul.created_at
FROM user_leagues ul
INNER JOIN leagues l ON l.sleeper_league_id = ul.sleeper_league_id
WHERE ul.app_user_id IS NOT NULL
ON CONFLICT (app_user_id, league_id) DO NOTHING;

-- Step 4: Update rosters table to reference new leagues table
-- First add new column
ALTER TABLE user_rosters ADD COLUMN IF NOT EXISTS new_league_id UUID REFERENCES leagues(id) ON DELETE CASCADE;

-- Migrate the foreign key
UPDATE user_rosters ur
SET new_league_id = l.id
FROM user_leagues ul
INNER JOIN leagues l ON l.sleeper_league_id = ul.sleeper_league_id
WHERE ur.league_id = ul.id;

-- Drop old foreign key and rename new one
ALTER TABLE user_rosters DROP CONSTRAINT IF EXISTS user_rosters_league_id_fkey;
ALTER TABLE user_rosters DROP COLUMN IF EXISTS league_id;
ALTER TABLE user_rosters RENAME COLUMN new_league_id TO league_id;

-- Add back the constraint
ALTER TABLE user_rosters ADD CONSTRAINT user_rosters_league_id_fkey 
  FOREIGN KEY (league_id) REFERENCES leagues(id) ON DELETE CASCADE;

-- Recreate index
CREATE INDEX IF NOT EXISTS idx_user_rosters_league_id ON user_rosters(league_id);

-- Step 5: Drop old user_leagues table
DROP TABLE IF EXISTS user_leagues CASCADE;

-- Step 6: RLS Policies for leagues
ALTER TABLE leagues ENABLE ROW LEVEL SECURITY;

-- Anyone can view active leagues (they're public data)
CREATE POLICY "Anyone can view active leagues"
  ON leagues FOR SELECT
  USING (is_active = true);

-- Service role can manage all leagues
CREATE POLICY "Service role can manage leagues"
  ON leagues FOR ALL
  USING (auth.role() = 'service_role');

-- Step 7: RLS Policies for league_memberships
ALTER TABLE league_memberships ENABLE ROW LEVEL SECURITY;

-- Users can view their own memberships
CREATE POLICY "Users can view own memberships"
  ON league_memberships FOR SELECT
  USING (
    app_user_id IN (
      SELECT id FROM app_users 
      WHERE sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    )
  );

-- Service role can manage all memberships
CREATE POLICY "Service role can manage memberships"
  ON league_memberships FOR ALL
  USING (auth.role() = 'service_role');

-- Step 8: Update rosters RLS policy to work with new structure
DROP POLICY IF EXISTS "Users can view own rosters" ON user_rosters;

CREATE POLICY "Users can view rosters in their leagues"
  ON user_rosters FOR SELECT
  USING (
    league_id IN (
      SELECT lm.league_id 
      FROM league_memberships lm
      INNER JOIN app_users au ON au.id = lm.app_user_id
      WHERE au.sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    )
  );

-- Service role can manage all rosters
CREATE POLICY "Service role can manage rosters"
  ON user_rosters FOR ALL
  USING (auth.role() = 'service_role');

-- Step 9: Create helper function to get user's leagues
-- Drop old version first if it exists
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_leagues(TEXT) TO authenticated, anon;

COMMENT ON FUNCTION get_user_leagues(TEXT) IS 
'Returns all active leagues for a user by their Sleeper user ID. No duplication - one record per league.';

-- Step 10: Comments
COMMENT ON TABLE leagues IS 
'Stores unique league data. One record per Sleeper league, shared across all members.';

COMMENT ON TABLE league_memberships IS 
'Junction table linking users to leagues they participate in.';

COMMENT ON COLUMN user_rosters.league_id IS 
'References the leagues table. Each roster belongs to one league.';
