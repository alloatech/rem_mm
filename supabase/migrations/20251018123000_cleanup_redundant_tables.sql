-- Database Cleanup - Remove Redundant Tables
-- This migration removes the old expensive embedding approach

-- Drop the old player_embeddings table (replaced by player_embeddings_selective)
DROP TABLE IF EXISTS player_embeddings CASCADE;

-- Drop any related functions that use the old table
DROP FUNCTION IF EXISTS match_players CASCADE;
DROP FUNCTION IF EXISTS similarity_search CASCADE;

-- Keep the enhanced function that uses selective embeddings
-- (enhanced_similarity_search should remain)

-- Verify cleanup
DO $$
BEGIN
    -- Check if old table is gone
    IF NOT EXISTS (SELECT FROM pg_tables WHERE tablename = 'player_embeddings') THEN
        RAISE NOTICE '✅ Old player_embeddings table successfully removed';
    END IF;
    
    -- Check if new table exists  
    IF EXISTS (SELECT FROM pg_tables WHERE tablename = 'player_embeddings_selective') THEN
        RAISE NOTICE '✅ New player_embeddings_selective table confirmed';
    END IF;
    
    -- Show remaining essential tables
    RAISE NOTICE '📊 Essential tables remaining:';
    RAISE NOTICE '   - players_raw: Complete NFL database';  
    RAISE NOTICE '   - player_embeddings_selective: Cost-optimized embeddings';
    RAISE NOTICE '   - app_users: User accounts';
    RAISE NOTICE '   - user_rosters: Your fantasy roster';
    RAISE NOTICE '   - user_leagues: League memberships';
END
$$;