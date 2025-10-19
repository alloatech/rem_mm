-- Add unique constraint for roster upserts
-- The user-sync Edge Function expects this constraint for ON CONFLICT behavior

-- Add unique constraint on (league_id, sleeper_owner_id)
-- This ensures one roster per owner per league
ALTER TABLE user_rosters 
ADD CONSTRAINT user_rosters_league_owner_unique 
UNIQUE (league_id, sleeper_owner_id);

COMMENT ON CONSTRAINT user_rosters_league_owner_unique ON user_rosters IS 
'Ensures one roster per Sleeper owner per league. Used by user-sync Edge Function for upsert operations.';
