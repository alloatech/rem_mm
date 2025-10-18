# 🚀 Production Deployment Security Checklist

## ✅ Pre-Deployment Security Tasks

### 1. Environment Configuration
- [ ] Create `.env.production` with production values
- [ ] Remove all development keys/secrets
- [ ] Set `ENVIRONMENT=production`
- [ ] Configure `ALLOWED_ORIGINS` to your actual domain(s)
- [ ] Generate secure JWT secrets (256-bit minimum)

### 2. Database Security
- [ ] Apply security hardening migration: `supabase db push`
- [ ] Review and test all RLS policies
- [ ] Remove or restrict anonymous access policies
- [ ] Test rate limiting functions
- [ ] Enable audit logging

### 3. Edge Functions Security
- [ ] Replace development Edge Function with production version
- [ ] Test input validation and sanitization
- [ ] Verify rate limiting works
- [ ] Test CORS restrictions
- [ ] Add error handling without information disclosure

### 4. Network Security
- [ ] Enable HTTPS/TLS certificates
- [ ] Configure reverse proxy (Nginx/Cloudflare)
- [ ] Set up Web Application Firewall (WAF)
- [ ] Configure DDoS protection
- [ ] Restrict database ports (only internal access)

### 5. Authentication & Authorization
- [ ] Configure Supabase Auth providers securely
- [ ] Set up proper JWT signing
- [ ] Test user registration/login flows
- [ ] Implement session management
- [ ] Add password policies

### 6. Monitoring & Alerting
- [ ] Set up error monitoring (Sentry/similar)
- [ ] Configure log aggregation
- [ ] Set up security alerts
- [ ] Monitor rate limiting metrics
- [ ] Set up uptime monitoring

## 🔧 Production Configuration Examples

### Nginx Reverse Proxy
```nginx
server {
    listen 443 ssl http2;
    server_name yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/m;
    
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://127.0.0.1:54321/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Docker Compose for Production
```yaml
version: '3.8'
services:
  supabase:
    image: supabase/supabase:latest
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - JWT_SECRET=${JWT_SECRET}
      - SITE_URL=${SITE_URL}
    ports:
      - "127.0.0.1:54321:8000"  # Only bind to localhost
    volumes:
      - ./supabase:/var/lib/supabase
    restart: unless-stopped
    
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/ssl/certs
    depends_on:
      - supabase
    restart: unless-stopped
```

## 🧪 Security Testing Commands

### Test Rate Limiting
```bash
# Test rate limiting (should fail after 10 requests)
for i in {1..15}; do
  curl -X POST https://yourdomain.com/api/get-fantasy-advice \
    -H "Content-Type: application/json" \
    -d '{"query": "test query"}' \
    -w "Request $i: %{http_code}\n"
done
```

### Test Input Validation
```bash
# Test XSS attempt (should be sanitized)
curl -X POST https://yourdomain.com/api/get-fantasy-advice \
  -H "Content-Type: application/json" \
  -d '{"query": "<script>alert(\"xss\")</script>who should I start?"}' \
  -v

# Test SQL injection attempt (should be blocked)
curl -X POST https://yourdomain.com/api/get-fantasy-advice \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"'; DROP TABLE player_embeddings; --\"}" \
  -v
```

## 📊 Security Monitoring Queries

### Check Rate Limiting
```sql
SELECT 
  identifier,
  endpoint,
  SUM(request_count) as total_requests,
  COUNT(*) as time_windows
FROM rate_limits 
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY identifier, endpoint
ORDER BY total_requests DESC;
```

### Security Audit Log
```sql
SELECT 
  event_type,
  COUNT(*) as count,
  DATE_TRUNC('hour', created_at) as hour
FROM security_audit 
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY event_type, hour
ORDER BY hour DESC, count DESC;
```

## 🚨 Incident Response

### Suspected Attack
1. Check security_audit table for unusual patterns
2. Review rate_limits for suspicious IPs
3. Block malicious IPs at firewall level
4. Increase rate limiting if needed
5. Review and rotate secrets if compromised

### Performance Issues
1. Check rate limiting metrics
2. Monitor database query performance
3. Review error logs
4. Scale resources if needed
5. Optimize queries and indexes