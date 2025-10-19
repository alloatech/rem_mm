-- Add team_avatar_url column to user_rosters
ALTER TABLE user_rosters 
ADD COLUMN team_avatar_url TEXT;

COMMENT ON COLUMN user_rosters.team_avatar_url IS 'Team avatar URL from Sleeper user metadata';
