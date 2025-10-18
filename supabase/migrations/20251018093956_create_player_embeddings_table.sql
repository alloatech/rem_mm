-- Enable the vector extension for pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Create the player_embeddings table for our RAG system
CREATE TABLE IF NOT EXISTS player_embeddings (
  id BIGSERIAL PRIMARY KEY,
  player_id TEXT NOT NULL UNIQUE,
  player_name TEXT NOT NULL,
  position TEXT,
  team TEXT,
  status TEXT,
  content TEXT NOT NULL, -- The formatted player chunk: "Player: Name, Position: X, Team: Y, Status: Z"
  embedding VECTOR(1536), -- Gemini embeddings are 768-dimensional, but using 1536 for flexibility
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for efficient similarity search
CREATE INDEX IF NOT EXISTS player_embeddings_embedding_idx 
  ON player_embeddings USING ivfflat (embedding vector_cosine_ops);

-- Create indexes for filtering
CREATE INDEX IF NOT EXISTS player_embeddings_position_idx ON player_embeddings(position);
CREATE INDEX IF NOT EXISTS player_embeddings_team_idx ON player_embeddings(team);
CREATE INDEX IF NOT EXISTS player_embeddings_status_idx ON player_embeddings(status);

-- Enable Row Level Security
ALTER TABLE player_embeddings ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations for authenticated users
CREATE POLICY "Allow all operations for authenticated users" ON player_embeddings
  FOR ALL USING (auth.role() = 'authenticated');

-- Create policy to allow read access for anonymous users (for public queries)
CREATE POLICY "Allow read access for anonymous users" ON player_embeddings
  FOR SELECT USING (true);

-- Function to update the updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to automatically update the updated_at column
CREATE TRIGGER update_player_embeddings_updated_at 
    BEFORE UPDATE ON player_embeddings 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
