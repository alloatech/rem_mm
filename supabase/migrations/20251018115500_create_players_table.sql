-- Enhanced Player Management with Full Data + Selective Embeddings
-- This migration creates a complete player storage system

-- Raw Players Table (ALL data from Sleeper, updated frequently)
CREATE TABLE IF NOT EXISTS players_raw (
    player_id TEXT PRIMARY KEY,
    full_name TEXT,
    first_name TEXT,
    last_name TEXT,
    position TEXT,
    team TEXT,
    team_abbr TEXT,
    status TEXT,
    active BOOLEAN DEFAULT true,
    
    -- Fantasy relevant real-time data
    depth_chart_position TEXT,
    depth_chart_order INTEGER,
    injury_status TEXT,
    injury_notes TEXT,
    injury_body_part TEXT,
    injury_start_date TIMESTAMP,
    practice_participation TEXT,
    practice_description TEXT,
    
    -- Player metadata
    age INTEGER,
    height TEXT,
    weight TEXT,
    college TEXT,
    years_exp INTEGER,
    number INTEGER,
    rookie_year TEXT,
    
    -- External IDs for cross-referencing
    espn_id TEXT,
    yahoo_id TEXT,
    fantasy_data_id INTEGER,
    
    -- Raw JSON backup (for future use)
    raw_data JSONB,
    
    -- Timestamps
    news_updated BIGINT, -- Sleeper's news timestamp
    last_synced TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_players_raw_team ON players_raw(team);
CREATE INDEX IF NOT EXISTS idx_players_raw_position ON players_raw(position);
CREATE INDEX IF NOT EXISTS idx_players_raw_status ON players_raw(status);
CREATE INDEX IF NOT EXISTS idx_players_raw_active ON players_raw(active);
CREATE INDEX IF NOT EXISTS idx_players_raw_name ON players_raw(full_name);
CREATE INDEX IF NOT EXISTS idx_players_raw_news_updated ON players_raw(news_updated);

-- Composite index for fantasy queries
CREATE INDEX IF NOT EXISTS idx_players_fantasy_active 
ON players_raw(position, team, status) 
WHERE active = true AND position IN ('QB', 'RB', 'WR', 'TE', 'K');

-- Separate embedding table for SELECTIVE semantic search
-- Only embed players that users actually care about
CREATE TABLE IF NOT EXISTS player_embeddings_selective (
    id SERIAL PRIMARY KEY,
    player_id TEXT REFERENCES players_raw(player_id) ON DELETE CASCADE,
    
    -- Embedding data (only for selected players)
    content TEXT NOT NULL,
    embedding vector(768),
    
    -- Metadata
    embedding_model TEXT DEFAULT 'text-embedding-004',
    embedding_created TIMESTAMP DEFAULT NOW(),
    
    -- Track why this player was embedded
    embed_reason TEXT, -- 'user_roster', 'trending', 'manual', 'popular'
    embed_priority INTEGER DEFAULT 1, -- Higher = more important
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for vector search
CREATE INDEX IF NOT EXISTS idx_embeddings_selective_vector 
ON player_embeddings_selective USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_embeddings_selective_player 
ON player_embeddings_selective(player_id);

CREATE INDEX IF NOT EXISTS idx_embeddings_selective_priority 
ON player_embeddings_selective(embed_priority DESC);

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for timestamp updates
CREATE TRIGGER update_players_raw_updated_at 
    BEFORE UPDATE ON players_raw 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_embeddings_selective_updated_at 
    BEFORE UPDATE ON player_embeddings_selective 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- View for easy fantasy player queries with embedding status
CREATE OR REPLACE VIEW fantasy_players_with_embeddings AS
SELECT 
    p.*,
    e.id as embedding_id,
    e.embed_reason,
    e.embed_priority,
    e.embedding_created,
    CASE WHEN e.id IS NOT NULL THEN true ELSE false END as has_embedding
FROM players_raw p
LEFT JOIN player_embeddings_selective e ON p.player_id = e.player_id
WHERE p.active = true 
  AND p.position IN ('QB', 'RB', 'WR', 'TE', 'K')
  AND p.team IS NOT NULL;

-- Grant permissions
GRANT ALL ON players_raw TO postgres, anon, authenticated, service_role;
GRANT ALL ON player_embeddings_selective TO postgres, anon, authenticated, service_role;
GRANT ALL ON fantasy_players_with_embeddings TO postgres, anon, authenticated, service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;