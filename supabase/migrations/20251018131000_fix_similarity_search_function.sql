-- Fix search_similar_players function to use new table
-- Replace the function to use player_embeddings_selective with JOIN to players_raw

DROP FUNCTION IF EXISTS search_similar_players(vector, double precision, integer);

CREATE OR REPLACE FUNCTION search_similar_players(
  query_embedding vector,
  similarity_threshold double precision DEFAULT 0.7,
  match_count integer DEFAULT 5
) 
RETURNS TABLE (
  player_id text,
  player_name text, 
  pos text,
  team text,
  content text,
  similarity double precision
)
LANGUAGE SQL
STABLE
AS $$
  SELECT
    pe.player_id,
    pr.full_name as player_name,
    pr.position as pos,
    pr.team,
    pe.content,
    -- Calculate cosine similarity using pgvector
    (pe.embedding <=> query_embedding) * -1 + 1 AS similarity
  FROM player_embeddings_selective pe
  JOIN players_raw pr ON pe.player_id = pr.player_id
  WHERE
    -- Only return results above similarity threshold
    (pe.embedding <=> query_embedding) * -1 + 1 >= similarity_threshold
  ORDER BY
    -- Order by similarity (highest first)
    pe.embedding <=> query_embedding
  LIMIT match_count;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION search_similar_players TO authenticated;
GRANT EXECUTE ON FUNCTION search_similar_players TO anon;

COMMENT ON FUNCTION search_similar_players IS 'Search for similar players using selective embeddings for cost optimization';