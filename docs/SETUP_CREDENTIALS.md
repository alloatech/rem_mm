# Setup Guide - Credentials & Environment

## ⚠️ Security First

**NEVER commit credentials to version control!**

The following files contain sensitive information and are in `.gitignore`:
- `.env` - Your environment variables and credentials
- `supabase/seed.sql` - Database seed file with password hashes

## Initial Setup

### 1. Copy Example Files

```bash
# Copy environment template
cp .env.example .env

# Copy seed template  
cp supabase/seed.sql.example supabase/seed.sql
```

### 2. Generate Secure Password Hash

Your seed.sql needs a bcrypt hash of your password:

```bash
# Install bcrypt if needed
npm install -g bcrypt-cli

# Generate hash (replace 'your_password' with actual password)
node -e "console.log(require('bcrypt').hashSync('your_password', 10))"
```

### 3. Update seed.sql

Edit `supabase/seed.sql`:
- Replace `YOUR_ADMIN_EMAIL_HERE` with your email
- Replace `YOUR_PASSWORD_HASH_HERE` with the bcrypt hash from step 2
- Replace `YOUR_SLEEPER_USER_ID_HERE` with your Sleeper user ID
- Replace `YOUR_SLEEPER_USERNAME_HERE` with your Sleeper username

### 4. Update .env

Edit `.env`:
```
ADMIN_EMAIL=your_actual_email@example.com
ADMIN_PASSWORD=your_actual_password_here
GEMINI_API_KEY=your_gemini_api_key
```

### 5. Apply Seeds

```bash
supabase db reset
```

This will:
- Reset the database
- Run all migrations
- Apply your seed.sql (creating admin user)

## Using the Bootstrap Script

The `smart_bootstrap.sh` script automatically:
1. Reads credentials from `.env`
2. Authenticates as admin
3. Checks for existing data/backups
4. Creates optimal bootstrap plan
5. Executes the plan

```bash
./scripts/smart_bootstrap.sh
```

## Changing Your Password

If you need to change your admin password:

1. **Update `.env`**:
   ```
   ADMIN_PASSWORD=new_secure_password
   ```

2. **Generate new hash**:
   ```bash
   node -e "console.log(require('bcrypt').hashSync('new_secure_password', 10))"
   ```

3. **Update `supabase/seed.sql`** with new hash

4. **Reset database**:
   ```bash
   supabase db reset
   ```

All scripts will automatically use the new credentials from `.env`.

## Files NOT in Git

These files contain credentials and are **never committed**:

```
.env                    ← Your actual credentials
supabase/seed.sql       ← Your actual seed data
```

These files ARE committed as templates:

```
.env.example            ← Template for .env
supabase/seed.sql.example  ← Template for seed.sql
```

## Production Deployment

For production:

1. **Create separate `.env.production`** with production credentials
2. **Use strong passwords** (not 'monkey'!)
3. **Use production Supabase URL and keys**
4. **Never use local development credentials in production**

## Troubleshooting

### "Authentication failed"
- Check `.env` has correct `ADMIN_EMAIL` and `ADMIN_PASSWORD`
- Verify seed.sql was applied: `supabase db reset`
- Ensure password in `.env` matches hash in seed.sql

### "Admin access required"
- User must have `user_role='super_admin'` in `app_users` table
- Check with: `psql ... -c "SELECT * FROM app_users WHERE user_role='super_admin';"`

### "Can't find seed.sql"
- Copy from template: `cp supabase/seed.sql.example supabase/seed.sql`
- Edit with your credentials
- Run `supabase db reset`
