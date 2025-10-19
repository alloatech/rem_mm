-- Update user_rosters schema to support storing rosters for unregistered users
-- This allows us to sync entire leagues (all rosters) even if not all users are registered

-- Add sleeper_owner_id to track which Sleeper user owns this roster
ALTER TABLE user_rosters
ADD COLUMN sleeper_owner_id TEXT;

-- Make app_user_id nullable (we'll link it when user registers)
ALTER TABLE user_rosters
ALTER COLUMN app_user_id DROP NOT NULL;

-- Drop old unique constraint
ALTER TABLE user_rosters
DROP CONSTRAINT IF EXISTS user_rosters_app_user_id_league_id_key;

-- Add new unique constraint based on league and Sleeper owner
-- This prevents duplicate rosters for the same user in the same league
ALTER TABLE user_rosters
ADD CONSTRAINT user_rosters_league_sleeper_owner_unique 
UNIQUE(league_id, sleeper_owner_id);

-- Add index for looking up rosters by Sleeper owner ID (for linking when they register)
CREATE INDEX idx_user_rosters_sleeper_owner ON user_rosters(sleeper_owner_id);

-- Update the sleeper_roster_id to be NOT NULL (it's the Sleeper API roster identifier)
ALTER TABLE user_rosters
ALTER COLUMN sleeper_roster_id SET NOT NULL;

-- Add comment explaining the schema
COMMENT ON COLUMN user_rosters.sleeper_owner_id IS 
'Sleeper user ID of the roster owner. Used to link rosters to app_users when they register.';

COMMENT ON COLUMN user_rosters.app_user_id IS 
'References app_users.id. NULL if user hasnt registered yet. Gets populated when user registers and we link their Sleeper account.';

-- Create helper function to link rosters when a user registers
CREATE OR REPLACE FUNCTION link_user_rosters(
  p_app_user_id UUID,
  p_sleeper_user_id TEXT
)
RETURNS INTEGER AS $$
DECLARE
  v_linked_count INTEGER;
BEGIN
  -- Update all rosters owned by this Sleeper user to link to their app_users record
  UPDATE user_rosters
  SET 
    app_user_id = p_app_user_id,
    updated_at = NOW()
  WHERE 
    sleeper_owner_id = p_sleeper_user_id
    AND (app_user_id IS NULL OR app_user_id = p_app_user_id);
  
  GET DIAGNOSTICS v_linked_count = ROW_COUNT;
  
  RETURN v_linked_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION link_user_rosters IS 
'Links existing rosters to a newly registered user. Called automatically during user registration. Returns count of rosters linked.';
