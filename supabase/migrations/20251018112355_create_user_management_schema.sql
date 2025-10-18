-- Create user management schema for Sleeper integration
-- This handles user accounts, leagues, and roster syncing

-- Users table to store Sleeper user information
CREATE TABLE app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sleeper_user_id TEXT UNIQUE NOT NULL,
  sleeper_username TEXT,
  display_name TEXT,
  avatar TEXT,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true
);

-- Leagues table to store user's fantasy leagues
CREATE TABLE user_leagues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_user_id UUID REFERENCES app_users(id) ON DELETE CASCADE,
  sleeper_league_id TEXT NOT NULL,
  league_name TEXT,
  season INTEGER,
  sport TEXT DEFAULT 'nfl',
  league_type TEXT, -- 'dynasty', 'redraft', etc.
  total_rosters INTEGER,
  scoring_settings JSONB,
  roster_positions JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_synced TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  UNIQUE(app_user_id, sleeper_league_id)
);

-- Rosters table to cache user's roster data
CREATE TABLE user_rosters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  app_user_id UUID REFERENCES app_users(id) ON DELETE CASCADE,
  league_id UUID REFERENCES user_leagues(id) ON DELETE CASCADE,
  sleeper_roster_id INTEGER,
  player_ids TEXT[], -- Array of Sleeper player IDs
  starters TEXT[], -- Starting lineup player IDs
  reserves TEXT[], -- Bench player IDs
  taxi TEXT[], -- Taxi squad player IDs
  settings JSONB, -- Roster settings (wins, losses, points, etc.)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_synced TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(app_user_id, league_id)
);

-- Create indexes for performance
CREATE INDEX idx_app_users_sleeper_id ON app_users(sleeper_user_id);
CREATE INDEX idx_app_users_active ON app_users(is_active) WHERE is_active = true;
CREATE INDEX idx_user_leagues_user_id ON user_leagues(app_user_id);
CREATE INDEX idx_user_leagues_active ON user_leagues(is_active) WHERE is_active = true;
CREATE INDEX idx_user_rosters_user_id ON user_rosters(app_user_id);
CREATE INDEX idx_user_rosters_league_id ON user_rosters(league_id);

-- Create updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_app_users_updated_at BEFORE UPDATE ON app_users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_leagues_updated_at BEFORE UPDATE ON user_leagues FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_rosters_updated_at BEFORE UPDATE ON user_rosters FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS) policies
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_leagues ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_rosters ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY "Users can view own profile" ON app_users
  FOR SELECT USING (sleeper_user_id = current_setting('app.current_sleeper_user_id', true));

CREATE POLICY "Users can update own profile" ON app_users
  FOR UPDATE USING (sleeper_user_id = current_setting('app.current_sleeper_user_id', true));

-- Users can only see their own leagues
CREATE POLICY "Users can view own leagues" ON user_leagues
  FOR ALL USING (
    app_user_id IN (
      SELECT id FROM app_users 
      WHERE sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    )
  );

-- Users can only see their own rosters
CREATE POLICY "Users can view own rosters" ON user_rosters
  FOR ALL USING (
    app_user_id IN (
      SELECT id FROM app_users 
      WHERE sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    )
  );

-- Allow service role to manage all data (for Edge Functions)
CREATE POLICY "Service role can manage app_users" ON app_users
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage user_leagues" ON user_leagues
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage user_rosters" ON user_rosters
  FOR ALL USING (auth.role() = 'service_role');

-- Grant necessary permissions
GRANT ALL ON app_users TO authenticated, service_role;
GRANT ALL ON user_leagues TO authenticated, service_role;
GRANT ALL ON user_rosters TO authenticated, service_role;
