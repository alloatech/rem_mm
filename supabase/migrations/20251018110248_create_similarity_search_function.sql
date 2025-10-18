-- Create similarity search function for RAG pipeline
-- This function performs vector similarity search on player embeddings
CREATE OR REPLACE FUNCTION search_similar_players(
  query_embedding vector(768),
  similarity_threshold float DEFAULT 0.7,
  match_count int DEFAULT 5
)
RETURNS TABLE (
  player_id text,
  player_name text,
  pos text,
  team text,
  content text,
  similarity float
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    pe.player_id,
    pe.player_name,
    pe.position as pos,
    pe.team,
    pe.content,
    -- Calculate cosine similarity using pgvector
    (pe.embedding <=> query_embedding) * -1 + 1 AS similarity
  FROM player_embeddings pe
  WHERE 
    -- Only return results above similarity threshold
    (pe.embedding <=> query_embedding) * -1 + 1 >= similarity_threshold
  ORDER BY 
    -- Order by similarity (highest first)
    pe.embedding <=> query_embedding
  LIMIT match_count;
$$;

-- Add helpful comments
COMMENT ON FUNCTION search_similar_players IS 'Performs vector similarity search on player embeddings for RAG pipeline. Uses cosine distance with pgvector extension.';

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION search_similar_players TO anon, authenticated;
