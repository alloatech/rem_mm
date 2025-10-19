# Admin Bootstrap Guide

## First Super Admin Setup

After a fresh `supabase db reset`, the seed file automatically creates:

- **Email**: `admin@rem-mm.local`
- **Password**: `admin123`
- **Sleeper Account**: th0rjc (872612101674491904)
- **Role**: super_admin

## For Production

### Option 1: Manual First Admin
1. Deploy to production
2. Sign up normally through the app
3. Manually run SQL to promote to super_admin:
```sql
UPDATE app_users 
SET user_role = 'super_admin' 
WHERE sleeper_username = 'th0rjc';
```

### Option 2: Environment-Based Seed
Modify `supabase/seed.sql` to use environment variables:
```sql
-- Only seed in development
DO $$
BEGIN
  IF current_setting('app.environment', true) = 'development' THEN
    -- Insert super admin
  END IF;
END $$;
```

### Option 3: Admin Promotion Endpoint
Create a special Edge Function with a secret key for first-time setup:
```typescript
// One-time use endpoint with secret
if (secret === Deno.env.get('BOOTSTRAP_SECRET')) {
  // Promote user to super_admin
}
```

## Changing Super Admin Credentials

To change the seeded admin email/password, edit `supabase/seed.sql`:

```sql
email = 'your-email@example.com',
encrypted_password = crypt('your-secure-password', gen_salt('bf')),
```

Then run:
```bash
supabase db reset
```

## Security Note

⚠️ **IMPORTANT**: The seed file is for local development only. Never commit production credentials to git. For production, use one of the secure methods above.
