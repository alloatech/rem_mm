-- Create storage bucket and metadata tracking for player data backups

-- Create storage bucket for player data backups
INSERT INTO storage.buckets (id, name, public)
VALUES ('player-data-backups', 'player-data-backups', false)
ON CONFLICT (id) DO NOTHING;

-- Create backup metadata tracking table
CREATE TABLE IF NOT EXISTS backup_metadata (
    filename TEXT PRIMARY KEY,
    data_type TEXT NOT NULL CHECK (data_type IN ('players', 'embeddings')),
    record_count INTEGER NOT NULL DEFAULT 0,
    file_size BIGINT NOT NULL DEFAULT 0,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    created_by TEXT, -- sleeper_user_id of admin who created it
    
    -- Checksums for integrity
    md5_hash TEXT,
    
    -- Status tracking
    is_verified BOOLEAN DEFAULT false,
    last_restored TIMESTAMP,
    restore_count INTEGER DEFAULT 0
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_backup_metadata_type ON backup_metadata(data_type);
CREATE INDEX IF NOT EXISTS idx_backup_metadata_created ON backup_metadata(created_at DESC);

-- RLS policies for admin-only access
ALTER TABLE backup_metadata ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view backup metadata"
ON backup_metadata FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM app_users
        WHERE app_users.supabase_user_id = auth.uid()
        AND app_users.user_role IN ('admin', 'super_admin')
    )
);

CREATE POLICY "Admins can insert backup metadata"
ON backup_metadata FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM app_users
        WHERE app_users.supabase_user_id = auth.uid()
        AND app_users.user_role IN ('admin', 'super_admin')
    )
);

-- Storage policies for admin-only access
CREATE POLICY "Admins can upload backups"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'player-data-backups'
    AND EXISTS (
        SELECT 1 FROM app_users
        WHERE app_users.supabase_user_id = auth.uid()
        AND app_users.user_role IN ('admin', 'super_admin')
    )
);

CREATE POLICY "Admins can download backups"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'player-data-backups'
    AND EXISTS (
        SELECT 1 FROM app_users
        WHERE app_users.supabase_user_id = auth.uid()
        AND app_users.user_role IN ('admin', 'super_admin')
    )
);

CREATE POLICY "Admins can delete backups"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'player-data-backups'
    AND EXISTS (
        SELECT 1 FROM app_users
        WHERE app_users.supabase_user_id = auth.uid()
        AND app_users.user_role IN ('admin', 'super_admin')
    )
);

-- Helper function to get latest backup
CREATE OR REPLACE FUNCTION get_latest_backup(backup_type TEXT DEFAULT 'players')
RETURNS TABLE (
    filename TEXT,
    record_count INTEGER,
    created_at TIMESTAMP,
    age_hours NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bm.filename,
        bm.record_count,
        bm.created_at,
        EXTRACT(EPOCH FROM (NOW() - bm.created_at)) / 3600 AS age_hours
    FROM backup_metadata bm
    WHERE bm.data_type = backup_type
    ORDER BY bm.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if bootstrap needed
CREATE OR REPLACE FUNCTION should_bootstrap()
RETURNS JSONB AS $$
DECLARE
    player_count INTEGER;
    embedding_count INTEGER;
    latest_backup RECORD;
    result JSONB;
BEGIN
    -- Count existing data
    SELECT COUNT(*) INTO player_count FROM players_raw;
    SELECT COUNT(*) INTO embedding_count FROM player_embeddings_selective;
    
    -- Check for backups
    SELECT * INTO latest_backup FROM get_latest_backup('players');
    
    -- Build recommendation
    result := jsonb_build_object(
        'has_players', player_count > 100,
        'has_embeddings', embedding_count > 50,
        'has_backup', latest_backup.filename IS NOT NULL,
        'player_count', player_count,
        'embedding_count', embedding_count,
        'backup_age_hours', latest_backup.age_hours,
        'recommendation', CASE
            WHEN latest_backup.filename IS NOT NULL AND player_count < 100 THEN
                'restore_from_backup'
            WHEN player_count > 100 AND embedding_count > 50 THEN
                'data_exists'
            WHEN player_count > 100 AND embedding_count < 50 THEN
                'need_embeddings'
            ELSE
                'full_bootstrap'
        END
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Notify on table
COMMENT ON TABLE backup_metadata IS 'Tracks player data backups stored in Supabase Storage';
COMMENT ON FUNCTION should_bootstrap() IS 'Checks if bootstrap is needed and recommends action';
COMMENT ON FUNCTION get_latest_backup(TEXT) IS 'Gets the most recent backup metadata for a data type';
