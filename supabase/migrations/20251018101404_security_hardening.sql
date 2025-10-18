-- Production Security Hardening Migration
-- Run this before deploying to production

-- Drop overly permissive anonymous policy
DROP POLICY IF EXISTS "Allow read access for anonymous users" ON player_embeddings;

-- Create more restrictive policies
CREATE POLICY "Limited anonymous read" ON player_embeddings
  FOR SELECT USING (
    -- Only allow reading basic player info, limit columns
    -- Consider adding time-based restrictions or query limits
    position IS NOT NULL AND team IS NOT NULL
  );

-- Rate limiting table
CREATE TABLE IF NOT EXISTS rate_limits (
  id BIGSERIAL PRIMARY KEY,
  identifier TEXT NOT NULL, -- IP address or user ID
  endpoint TEXT NOT NULL,
  request_count INTEGER DEFAULT 1,
  window_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Rate limiting function
CREATE OR REPLACE FUNCTION check_rate_limit(
  user_identifier TEXT,
  endpoint_name TEXT,
  max_requests INTEGER DEFAULT 100,
  window_minutes INTEGER DEFAULT 60
) RETURNS BOOLEAN AS $$
DECLARE
  current_count INTEGER;
  window_start_time TIMESTAMP WITH TIME ZONE;
BEGIN
  window_start_time := NOW() - INTERVAL '1 minute' * window_minutes;
  
  -- Clean old entries
  DELETE FROM rate_limits 
  WHERE window_start < window_start_time;
  
  -- Get current count
  SELECT COALESCE(SUM(request_count), 0) INTO current_count
  FROM rate_limits 
  WHERE identifier = user_identifier 
    AND endpoint = endpoint_name 
    AND window_start >= window_start_time;
  
  -- Check if limit exceeded
  IF current_count >= max_requests THEN
    RETURN FALSE;
  END IF;
  
  -- Insert or update count
  INSERT INTO rate_limits (identifier, endpoint, request_count, window_start)
  VALUES (user_identifier, endpoint_name, 1, NOW())
  ON CONFLICT (identifier, endpoint) 
  DO UPDATE SET 
    request_count = rate_limits.request_count + 1,
    window_start = CASE 
      WHEN rate_limits.window_start < window_start_time THEN NOW()
      ELSE rate_limits.window_start
    END;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add unique constraint for rate limiting
CREATE UNIQUE INDEX IF NOT EXISTS rate_limits_identifier_endpoint_idx 
  ON rate_limits(identifier, endpoint);

-- Security audit log table
CREATE TABLE IF NOT EXISTS security_audit (
  id BIGSERIAL PRIMARY KEY,
  event_type TEXT NOT NULL,
  user_identifier TEXT,
  details JSONB DEFAULT '{}',
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on security tables
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_audit ENABLE ROW LEVEL SECURITY;

-- Only allow service role to manage security tables
CREATE POLICY "Service role only" ON rate_limits
  FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role only" ON security_audit
  FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS security_audit_event_type_idx ON security_audit(event_type);
CREATE INDEX IF NOT EXISTS security_audit_created_at_idx ON security_audit(created_at);
CREATE INDEX IF NOT EXISTS rate_limits_created_at_idx ON rate_limits(created_at);