-- Add team name and owner display name to user_rosters table
-- Note: In Sleeper terminology, "roster" = "team" (they're the same thing)
-- 
-- Data Model:
--   User can be in MANY leagues
--   User has EXACTLY ONE team (roster) per league (enforced by UNIQUE constraint)
--   Team has ONE owner (sleeper_owner_id) - co_owners rare/unused
--   Team contains player_ids array (the actual roster of NFL players)
--
-- This migration adds human-readable names for better UI display

ALTER TABLE user_rosters
ADD COLUMN IF NOT EXISTS team_name TEXT,
ADD COLUMN IF NOT EXISTS owner_display_name TEXT;

-- Create index for searching by team name
CREATE INDEX IF NOT EXISTS idx_user_rosters_team_name ON user_rosters(team_name);

-- Add comments explaining the fields
COMMENT ON COLUMN user_rosters.team_name IS 'Team nickname from Sleeper roster metadata p_nick_* fields (e.g., "Everyone Loves the Drake", "Crisis Alert!")';
COMMENT ON COLUMN user_rosters.owner_display_name IS 'Owner display name from Sleeper /league/X/users endpoint (e.g., "th0rjc", "iac21")';

-- Future enhancement: Add "is_my_team" boolean for explicit user selection
-- This would handle edge cases where user wants to mark their team
-- (useful if user manages multiple accounts or follows leagues without owning team)
