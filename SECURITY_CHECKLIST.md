# 🔒 Security Hardening Checklist for rem_mm

## Pre-Production Security Requirements

### 1. Environment Variables & Secrets
- [ ] **Generate production JWT secret** (not using development keys)
- [ ] **Secure Gemini API key storage**
- [ ] **Database passwords rotation**
- [ ] **Use environment-specific configs**

### 2. CORS Configuration
- [ ] **Restrict CORS origins** to your actual domains
- [ ] **Remove wildcard (*) origins**
- [ ] **Configure allowed headers precisely**

### 3. Database Security
- [ ] **Review and restrict RLS policies**
- [ ] **Remove anonymous read access**
- [ ] **Implement user authentication**
- [ ] **Add input validation triggers**

### 4. API Security
- [ ] **Implement rate limiting**
- [ ] **Add request validation**
- [ ] **Sanitize user inputs**
- [ ] **Add authentication middleware**

### 5. Network Security
- [ ] **Enable HTTPS/TLS**
- [ ] **Configure firewall rules**
- [ ] **Restrict database access**
- [ ] **Use reverse proxy**

### 6. Monitoring & Logging
- [ ] **Enable audit logging**
- [ ] **Set up security monitoring**
- [ ] **Configure alerts**
- [ ] **Log security events**

## Production Configuration Files

### Environment Variables (.env.production)
```bash
# Production Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-production-anon-key
SUPABASE_SERVICE_KEY=your-production-service-key

# Google Gemini API
GEMINI_API_KEY=your-production-gemini-key

# Security
JWT_SECRET=your-super-secure-jwt-secret-256-bits
ENVIRONMENT=production
```

### CORS Configuration (production)
```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://your-domain.com',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Max-Age': '86400'
}
```

### Database Security Policies
```sql
-- Secure RLS policies for production
DROP POLICY IF EXISTS "Allow read access for anonymous users" ON player_embeddings;

-- Only allow read access to specific, safe data
CREATE POLICY "Allow limited read access" ON player_embeddings
  FOR SELECT USING (
    -- Only allow reading basic player info, not sensitive metadata
    true -- Add your specific conditions here
  );

-- Rate limiting function
CREATE OR REPLACE FUNCTION check_rate_limit(user_identifier text)
RETURNS boolean AS $$
-- Implementation for rate limiting
$$ LANGUAGE plpgsql;
```

## Security Testing
- [ ] **Penetration testing**
- [ ] **SQL injection testing**
- [ ] **XSS testing**
- [ ] **Authentication bypass testing**
- [ ] **Rate limiting testing**

## Deployment Security
- [ ] **Use HTTPS only**
- [ ] **Configure security headers**
- [ ] **Enable CSP (Content Security Policy)**
- [ ] **Set up WAF (Web Application Firewall)**
- [ ] **Regular security updates**