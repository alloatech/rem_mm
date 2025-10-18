-- Fix embedding dimensions to match Gemini text-embedding-004 (768 dimensions)
-- Drop and recreate the embedding column with correct dimensions

ALTER TABLE player_embeddings DROP COLUMN IF EXISTS embedding;
ALTER TABLE player_embeddings ADD COLUMN embedding VECTOR(768);

-- Recreate the similarity search index with correct dimensions
DROP INDEX IF EXISTS player_embeddings_embedding_idx;
CREATE INDEX player_embeddings_embedding_idx 
  ON player_embeddings USING ivfflat (embedding vector_cosine_ops);