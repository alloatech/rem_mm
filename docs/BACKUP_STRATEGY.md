# Backup Strategy: Protecting Your Investment

## The Problem

Embeddings are **expensive** to generate but **fast** to restore:
- Creating embeddings: $0.010-0.035 + 3-5 minutes
- Re-syncing leagues/rosters: FREE + 5 seconds
- Restoring embeddings from backup: FREE + 2-3 seconds

**Solution**: Backup embeddings to Supabase Storage after creation!

---

## What Gets Backed Up?

### ✅ Backed Up to Storage (Expensive/Slow to Regenerate)
- **Embeddings** (`player_embeddings_selective` table)
  - Cost to regenerate: $0.010-0.035
  - Time to regenerate: 3-5 minutes
  - Backup size: ~500KB-2MB
  - **Survives db resets**: YES ✅

### ❌ NOT Backed Up (Free/Fast to Regenerate)
- **Raw player data** (`players_raw` table)
  - Cost to re-fetch: FREE
  - Time to re-fetch: ~30 seconds
  - Size: ~10MB
  - **Re-sync anytime**: `curl https://api.sleeper.app/v1/players/nfl`

- **Leagues** (`user_leagues` table)
  - Cost to re-sync: FREE
  - Time to re-sync: ~2 seconds
  - **Re-sync anytime**: Edge Function call

- **Rosters** (`user_rosters` table)
  - Cost to re-sync: FREE
  - Time to re-sync: ~3 seconds
  - **Re-sync anytime**: Edge Function call

---

## Backup Workflow

### 1. Initial Bootstrap (Automatic)
```bash
./scripts/complete_bootstrap.sh
```

**What happens**:
```
1. Fetch players (FREE, 30s)
2. Sync leagues (FREE, 2s)
3. Sync rosters (FREE, 3s)
4. Identify rostered players
5. Create embeddings ($0.015, 3-5 min)
6. 💾 BACKUP embeddings to Storage ← Automatic!
```

**Result**:
- Database populated
- Embeddings backed up to `player-data-backups` bucket
- Backup file: `embeddings_2025-10-19_12-30-45.json`

### 2. After DB Reset (Manual)
```bash
./scripts/quick_restore.sh
```

**What happens**:
```
1. Authenticate
2. List available backups
3. Restore latest backup (2-3s)
4. Verify embeddings restored
```

**Result**:
- Embeddings restored in seconds
- No re-generation cost
- No Gemini API calls

### 3. Re-sync Fresh Data (Optional)
```bash
# Re-sync leagues and rosters (FREE)
curl -X POST "http://localhost:54321/functions/v1/user-sync" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"sync_rosters","sleeper_user_id":"872612101674491904"}'
```

---

## Storage Details

### Backup Location
- **Bucket**: `player-data-backups`
- **Path**: `/embeddings_YYYY-MM-DD_HH-MM-SS.json`
- **Access**: Admin-only (RLS policies)
- **Persistence**: Survives db reset, Supabase stop/start

### Backup Metadata
Stored in `backup_metadata` table:
```sql
SELECT 
  filename,
  data_type,
  record_count,
  size_mb,
  created_at
FROM backup_metadata
ORDER BY created_at DESC;
```

Example:
```
embeddings_2025-10-19_12-30-45.json | embeddings | 150 | 0.8 | 2025-10-19 12:30:45
```

### Storage Bucket Permissions
```sql
-- Only admins can upload
CREATE POLICY "Admins can upload backups"
ON storage.objects FOR INSERT
TO authenticated
USING (bucket_id = 'player-data-backups' AND is_admin());

-- Only admins can download
CREATE POLICY "Admins can download backups"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'player-data-backups' AND is_admin());
```

---

## Cost Analysis

### Without Backups (Re-generate Every Time)
```
Initial bootstrap:
- Embeddings: $0.015 (3-5 min)

After db reset #1:
- Re-generate: $0.015 (3-5 min)

After db reset #2:
- Re-generate: $0.015 (3-5 min)

Total: $0.045, 9-15 minutes
```

### With Backups (Restore Every Time)
```
Initial bootstrap:
- Embeddings: $0.015 (3-5 min)
- Backup: FREE (2s)

After db reset #1:
- Restore: FREE (2s)

After db reset #2:
- Restore: FREE (2s)

Total: $0.015, 3-5 minutes
```

**Savings per db reset**: $0.015 + 3-5 minutes

---

## Backup Operations

### Create Backup (Automatic in bootstrap)
```bash
curl -X POST "http://localhost:54321/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"backup_to_storage","data":{"data_type":"embeddings"}}'
```

### List Backups
```bash
curl -X POST "http://localhost:54321/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"list_backups","data":{"data_type":"embeddings"}}'
```

### Restore Backup
```bash
curl -X POST "http://localhost:54321/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "action":"restore_from_storage",
    "data":{"filename":"embeddings_2025-10-19_12-30-45.json"}
  }'
```

### Delete Old Backups (Manual)
```bash
# Via Storage UI or SQL
DELETE FROM storage.objects 
WHERE bucket_id = 'player-data-backups' 
  AND created_at < NOW() - INTERVAL '30 days';
```

---

## Recovery Scenarios

### Scenario 1: Accidental db reset
```bash
# Before: Database empty
# Action: ./scripts/quick_restore.sh
# After: Embeddings restored in 2-3 seconds
# Cost: $0 (saved $0.015)
```

### Scenario 2: Storage cleared but DB intact
```bash
# No problem! Embeddings still in database
# Optional: Create new backup
curl ... {"action":"backup_to_storage","data":{"data_type":"embeddings"}}
```

### Scenario 3: Both DB and Storage cleared
```bash
# Rare! Would need to re-run bootstrap
./scripts/complete_bootstrap.sh
# Cost: $0.015 (unavoidable)
```

### Scenario 4: Want to refresh rosters (new trades)
```bash
# Restore embeddings first (if needed)
./scripts/quick_restore.sh

# Then re-sync rosters (FREE)
curl ... {"action":"sync_rosters","sleeper_user_id":"..."}

# Embeddings unchanged (players don't change much)
# Only roster assignments change (FREE to update)
```

---

## Best Practices

### ✅ DO
1. **Always backup after creating embeddings** (automatic in script)
2. **Keep at least 2 backups** (in case latest is corrupted)
3. **Restore before re-syncing** after db reset
4. **Test restore periodically** to verify backups work

### ❌ DON'T
1. **Don't re-generate embeddings** after db reset (restore instead!)
2. **Don't backup raw player data** (re-fetch is FREE and faster)
3. **Don't backup leagues/rosters** (re-sync is FREE and ensures freshness)
4. **Don't keep too many backups** (storage costs money, 3-5 is plenty)

---

## Monitoring

### Check Backup Status
```bash
# List all backups
curl -X POST "http://localhost:54321/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"list_backups","data":{"data_type":"embeddings"}}' | jq
```

### Verify Database State
```bash
# Check if embeddings exist
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
  SELECT COUNT(*) as embeddings FROM player_embeddings_selective;
"

# Check if backups exist
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
  SELECT COUNT(*) as backups FROM backup_metadata WHERE data_type = 'embeddings';
"
```

### Quick Status Check
```bash
curl -X POST "http://localhost:54321/functions/v1/player-data-admin-v2" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"check_existing_data"}' | jq '.data'
```

---

## Summary

### What's Protected
✅ **Embeddings** - Your $0.015 investment  
✅ **Backup metadata** - Tracking and verification  
✅ **Storage files** - Survive db resets

### What's Not Protected (By Design)
❌ **Raw players** - Re-fetch FREE from Sleeper  
❌ **Leagues** - Re-sync FREE from Sleeper  
❌ **Rosters** - Re-sync FREE from Sleeper

### Key Commands
```bash
# Initial setup
./scripts/complete_bootstrap.sh

# After db reset
./scripts/quick_restore.sh

# Re-sync data (anytime)
curl ... {"action":"sync_rosters","sleeper_user_id":"..."}
```

### Cost Savings
- Without backups: $0.015 per db reset
- With backups: $0.015 once, FREE forever
- **ROI**: Pays for itself after first db reset!

---

**Bottom line**: Backup your embeddings, re-sync everything else. It's faster, cheaper, and ensures you always have fresh data! 🎯
