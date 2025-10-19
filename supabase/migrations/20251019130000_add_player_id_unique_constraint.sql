-- Add UNIQUE constraint on player_id for upsert operations
-- This allows the simple-ingestion function to upsert embeddings
-- without creating duplicates

-- First, check if there are any existing duplicates (there shouldn't be)
DO $$ 
BEGIN
  IF EXISTS (
    SELECT player_id
    FROM player_embeddings_selective
    GROUP BY player_id
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate player_id values exist in player_embeddings_selective. Clean up before adding constraint.';
  END IF;
END $$;

-- Add UNIQUE constraint on player_id
ALTER TABLE player_embeddings_selective
ADD CONSTRAINT player_embeddings_selective_player_id_unique UNIQUE (player_id);

-- Add comment
COMMENT ON CONSTRAINT player_embeddings_selective_player_id_unique ON player_embeddings_selective 
IS 'Ensures each player has at most one embedding. Required for upsert operations in simple-ingestion function.';
