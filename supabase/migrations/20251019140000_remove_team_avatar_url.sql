-- Remove team_avatar_url since we can template it from sleeper_owner_id
ALTER TABLE user_rosters 
DROP COLUMN IF EXISTS team_avatar_url;

COMMENT ON COLUMN user_rosters.sleeper_owner_id IS 'Sleeper user ID of roster owner - use to template avatar URL: https://sleepercdn.com/avatars/thumbs/{sleeper_owner_id}';
