-- Migration: Add profile_hash column for change detection
-- Purpose: Track stable player profile data to avoid re-embedding unchanged players
-- Cost Impact: Reduces Gemini API calls by 80-90% on subsequent ingestion runs

-- Add profile_hash column to track stable player data
ALTER TABLE player_embeddings_selective 
ADD COLUMN IF NOT EXISTS profile_hash TEXT;

-- Index for fast lookup during change detection
CREATE INDEX IF NOT EXISTS idx_player_embeddings_profile_hash 
ON player_embeddings_selective(profile_hash);

-- Comment for documentation
COMMENT ON COLUMN player_embeddings_selective.profile_hash IS 
'SHA-256 hash of stable player profile fields (name, position, team, college, height, weight, birth_date). Used to detect when player profiles change and need re-embedding. Unchanged profiles skip expensive Gemini API calls.';
