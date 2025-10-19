# Complete Clean Bootstrap Walkthrough

## Step 1: Clean Your Environment

### 1a. Stop Supabase
```bash
cd /Users/thor/alloatech/dev/rem_mm
supabase stop
```

### 1b. Reset Database (Nuclear Option)
```bash
supabase db reset
```

This will:
- ✅ Drop all tables
- ✅ Re-run all migrations
- ✅ Re-seed with your admin user
- ❌ Clear database data
- ✅ **Keep Storage files** (embeddings backup survives!)

**Expected output**:
```
Resetting local database...
Recreating database...
Applying migration 20251018093956_create_player_embeddings_table.sql...
Applying migration 20251018101404_security_hardening.sql...
...
Applying migration 20251019085000_update_rosters_for_multi_user.sql...
Seeding data from supabase/seed.sql...
✅ Super admin user created: jc@alloatech.com / monkey
✅ Linked to Sleeper account: th0rjc (872612101674491904)
```

---

## Step 2: Verify Clean State

### 2a. Check Database is Empty
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT 
  'players_raw' as table_name, COUNT(*) as count FROM players_raw
UNION ALL
SELECT 'user_leagues', COUNT(*) FROM user_leagues
UNION ALL
SELECT 'user_rosters', COUNT(*) FROM user_rosters
UNION ALL
SELECT 'player_embeddings_selective', COUNT(*) FROM player_embeddings_selective;
"
```

**Expected output** (all zeros except maybe seed data):
```
      table_name           | count 
---------------------------+-------
 players_raw               |     0
 user_leagues              |     0
 user_rosters              |     0
 player_embeddings_selective|     0
```

### 2b. Check Admin User Exists
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT 
  sleeper_user_id, 
  sleeper_username, 
  display_name,
  is_admin()::text as is_admin
FROM app_users;
"
```

**Expected output**:
```
   sleeper_user_id    | sleeper_username | display_name | is_admin 
----------------------+------------------+--------------+----------
 872612101674491904   | th0rjc           | th0rJC       | t
```

### 2c. Check Storage Bucket Exists (Even After Reset)
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT name, public FROM storage.buckets WHERE name = 'player-data-backups';
"
```

**Expected output**:
```
        name         | public 
---------------------+--------
 player-data-backups | f
```

---

## Step 3: Run Complete Bootstrap

### 3a. Verify Environment Variables
```bash
# Check your .env file has everything
cat .env | grep -E "GEMINI_API_KEY|ADMIN_EMAIL|ADMIN_PASSWORD|ADMIN_SLEEPER_ID"
```

**Expected output**:
```
GEMINI_API_KEY=AIza...
ADMIN_EMAIL=jc@alloatech.com
ADMIN_PASSWORD=monkey
ADMIN_SLEEPER_ID=872612101674491904
```

### 3b. Run Bootstrap Script
```bash
./scripts/complete_bootstrap.sh
```

**Follow the prompts**:
1. Script authenticates automatically
2. Fetches 2,964 players (~30 seconds)
3. Syncs your league(s) (~2 seconds)
4. Syncs ALL rosters (~3 seconds)
5. Identifies unique rostered players
6. Shows cost estimate
7. **Asks: "Create embeddings for X players? (y/N)"** → Type `y` and press Enter
8. Creates embeddings (~3-5 minutes)
9. **Automatically backs up to Storage** (~2 seconds)
10. Shows summary with backup confirmation

**Expected output (abbreviated)**:
```
🚀 rem_mm Complete Bootstrap
============================================
🔐 Step 1/6: Authenticating...
✅ Authenticated as jc@alloatech.com

📥 Step 2/6: Fetching player data from Sleeper...
✅ Synced 2964 players to database

🏈 Step 3/6: Syncing admin leagues...
✅ Synced 1 league(s)
   Note: This varies year-to-year based on your participation

🏆 Step 4/6: Syncing ALL rosters in leagues...
✅ Synced 12 roster(s) across all teams

📊 Step 5/6: Identifying rostered players...
✅ Found 120 unique players across 12 rosters
💰 Estimated embedding cost: $0.0120
   (vs $0.2964 for all 2,964 players)
   💸 Savings: $0.28 (~96%)

Create embeddings for 120 players? (y/N) y

🧠 Step 6/6: Creating embeddings (targeted - rostered players only)...
⏳ Embedding in progress...
   [10%] 🧠 Checking which players need embedding...
   [50%] 🧠 Embedding player batch 1...
   [100%] ✅ Embeddings complete

📸 Embedding Snapshot:
   ✓ Patrick Mahomes (QB, KC)
   ✓ Christian McCaffrey (RB, SF)
   ✓ Justin Jefferson (WR, MIN)
   ✓ Travis Kelce (TE, KC)
   ✓ Tyreek Hill (WR, MIA)
   ... and 115 more players

✅ Embeddings created for 120 players

💾 Step 6b: Backing up embeddings to Supabase Storage...
   (Protects your $0.0120 investment)
✅ Embeddings backed up: embeddings_2025-10-19_13-45-30.json (0.6MB)
   Stored in Supabase Storage bucket: player-data-backups

📊 Bootstrap Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📥 Players synced:    2964
  🏈 Leagues synced:    1 (varies by season)
  🏆 Rosters synced:    12 (all teams)
  👥 Unique players:    120 (rostered)
  🧠 Embeddings:        120 (targeted)
  💰 Actual cost:       $0.0120
  💸 Amount saved:      $0.2844 (~96% savings)
  💾 Backup:            embeddings_2025-10-19_13-45-30.json ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ Bootstrap complete!

Next steps:
  1. ✅ Raw player data loaded (can re-sync anytime - FREE)
  2. ✅ Your leagues and rosters synced (can refresh anytime - FREE)
  3. ✅ Embeddings created (backed up to Storage)
  4. 💡 On db reset: Embeddings restore in 2-3 seconds from backup
  5. 🚀 Ready to use!

📦 Storage Backup Info:
  • Embeddings backed up to: player-data-backups bucket
  • Survives db resets: YES
  • Restore time: 2-3 seconds
  • Re-sync leagues: FREE anytime
```

---

## Step 4: Verify Bootstrap Success

### 4a. Check All Tables Have Data
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT 
  'players_raw' as table_name, COUNT(*) as count FROM players_raw
UNION ALL
SELECT 'user_leagues', COUNT(*) FROM user_leagues
UNION ALL
SELECT 'user_rosters', COUNT(*) FROM user_rosters
UNION ALL
SELECT 'player_embeddings_selective', COUNT(*) FROM player_embeddings_selective;
"
```

**Expected output**:
```
           table_name           | count 
-------------------------------+-------
 players_raw                   |  2964
 user_leagues                  |     1
 user_rosters                  |    12
 player_embeddings_selective   |   120
```

### 4b. Check Backup Exists in Storage
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT 
  name,
  metadata->>'size' as size_bytes,
  created_at
FROM storage.objects 
WHERE bucket_id = 'player-data-backups'
ORDER BY created_at DESC
LIMIT 1;
"
```

**Expected output**:
```
                 name                  | size_bytes |         created_at         
---------------------------------------+------------+----------------------------
 embeddings_2025-10-19_13-45-30.json  | 614832     | 2025-10-19 13:45:32+00
```

### 4c. Check Backup Metadata
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT 
  filename,
  data_type,
  record_count,
  size_mb,
  created_at
FROM backup_metadata
ORDER BY created_at DESC
LIMIT 1;
"
```

**Expected output**:
```
               filename                | data_type | record_count | size_mb |         created_at         
---------------------------------------+-----------+--------------+---------+----------------------------
 embeddings_2025-10-19_13-45-30.json  | embeddings|          120 |    0.59 | 2025-10-19 13:45:32
```

---

## Step 5: Test Restore Functionality

### 5a. Simulate DB Reset
```bash
supabase db reset
```

This clears all data but keeps Storage backups!

### 5b. Verify Database is Empty Again
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT COUNT(*) as embeddings_count 
FROM player_embeddings_selective;
"
```

**Expected output**:
```
 embeddings_count 
------------------
                0
```

### 5c. Verify Backup Still Exists in Storage
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT COUNT(*) as backup_count 
FROM storage.objects 
WHERE bucket_id = 'player-data-backups';
"
```

**Expected output**:
```
 backup_count 
--------------
            1
```

**✅ Proof that Storage survives db reset!**

### 5d. Run Quick Restore
```bash
./scripts/quick_restore.sh
```

**Follow the prompts**:
1. Script authenticates
2. Lists available backups
3. Shows latest backup details
4. **Asks: "Continue? (y/N)"** → Type `y` and press Enter
5. Restores embeddings in 2-3 seconds
6. Shows verification stats

**Expected output**:
```
💾 rem_mm Quick Restore
============================

🔐 Authenticating...
✅ Authenticated

📦 Checking available backups...
✅ Found 1 backup(s)

  • embeddings_2025-10-19_13-45-30.json - 0.59MB - 120 records - 2025-10-19 13:45:32

Will restore: embeddings_2025-10-19_13-45-30.json
Records: 120

Continue? (y/N) y

⏳ Restoring embeddings from backup...
✅ Restored 120 embeddings

📊 Verification:
  Embeddings in DB: 120
  Cost saved:       $0.0120 (didn't re-generate!)
  Time saved:       3-5 minutes

✨ Restore complete!
Note: You may want to re-sync leagues/rosters (FREE):
  curl -X POST 'http://127.0.0.1:54321/functions/v1/user-sync' \
    -H 'Authorization: Bearer $JWT_TOKEN' \
    -d '{"action":"sync_rosters","sleeper_user_id":"872612101674491904"}'
```

### 5e. Verify Restore Success
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT 
  COUNT(*) as total_embeddings,
  COUNT(DISTINCT player_id) as unique_players
FROM player_embeddings_selective;
"
```

**Expected output**:
```
 total_embeddings | unique_players 
------------------+----------------
              120 |            120
```

### 5f. Sample Restored Embeddings
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT 
  pr.full_name,
  pr.position,
  pr.team,
  'embedded ✓' as status
FROM player_embeddings_selective pes
JOIN players_raw pr ON pes.player_id = pr.player_id
ORDER BY pr.position, pr.full_name
LIMIT 10;
"
```

**Expected output** (your actual players will vary):
```
      full_name       | position | team |   status    
----------------------+----------+------+-------------
 Patrick Mahomes      | QB       | KC   | embedded ✓
 Josh Allen           | QB       | BUF  | embedded ✓
 Christian McCaffrey  | RB       | SF   | embedded ✓
 Derrick Henry        | RB       | TEN  | embedded ✓
 Justin Jefferson     | WR       | MIN  | embedded ✓
 Tyreek Hill          | WR       | MIA  | embedded ✓
 CeeDee Lamb          | WR       | DAL  | embedded ✓
 Travis Kelce         | TE       | KC   | embedded ✓
 ...
```

---

## Step 6: Re-sync Fresh Data (Optional)

Now that embeddings are restored, you can re-sync leagues and rosters with latest data:

### 6a. Get Fresh Auth Token
```bash
# Already in your .env, script will use it
export $(grep -v '^#' .env | xargs)

# Get JWT token
AUTH_RESPONSE=$(curl -s -X POST "http://127.0.0.1:54321/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")

JWT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.access_token')
echo "JWT Token: ${JWT_TOKEN:0:50}..."
```

### 6b. Re-sync Leagues and Rosters
```bash
# Re-sync leagues
curl -X POST "http://127.0.0.1:54321/functions/v1/user-sync" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"sync_leagues","sleeper_user_id":"872612101674491904"}' | jq

# Re-sync rosters
curl -X POST "http://127.0.0.1:54321/functions/v1/user-sync" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"sync_rosters","sleeper_user_id":"872612101674491904"}' | jq
```

**Expected output for each**:
```json
{
  "success": true,
  "leagues_synced": 1,
  "timestamp": "2025-10-19T13:50:00.000Z"
}

{
  "success": true,
  "message": "All rosters synced successfully (multi-user)",
  "leagues_processed": 1,
  "rosters_synced": 12,
  "timestamp": "2025-10-19T13:50:05.000Z"
}
```

### 6c. Verify Complete State
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT 
  'players_raw' as table_name, COUNT(*) as count FROM players_raw
UNION ALL
SELECT 'user_leagues', COUNT(*) FROM user_leagues
UNION ALL
SELECT 'user_rosters', COUNT(*) FROM user_rosters
UNION ALL
SELECT 'player_embeddings_selective', COUNT(*) FROM player_embeddings_selective
UNION ALL
SELECT 'backup_metadata', COUNT(*) FROM backup_metadata;
"
```

**Expected output**:
```
           table_name           | count 
-------------------------------+-------
 players_raw                   |  2964  ← Re-synced from Sleeper (FREE)
 user_leagues                  |     1  ← Re-synced from Sleeper (FREE)
 user_rosters                  |    12  ← Re-synced from Sleeper (FREE)
 player_embeddings_selective   |   120  ← Restored from Storage (FREE)
 backup_metadata               |     1  ← Backup still tracked
```

---

## Summary: What You Just Proved

### ✅ Bootstrap Works
- Created 2,964 players
- Synced 1 league with 12 rosters
- Created 120 embeddings ($0.012)
- Backed up embeddings automatically

### ✅ Storage Persists
- Backup survived db reset
- Metadata tracked correctly
- Files accessible for restore

### ✅ Restore Works
- 2-3 second restore time
- 120 embeddings restored correctly
- $0.012 saved (didn't re-generate)

### ✅ Re-sync Works
- Leagues re-synced (FREE)
- Rosters re-synced (FREE)
- Fresh data without re-embedding

---

## Cost Analysis

### What You Just Did:
```
Initial bootstrap:
- Embeddings: $0.012 (one-time cost)
- Backup: FREE
Total: $0.012

After db reset:
- Restore: FREE (2 seconds)
- Re-sync: FREE (5 seconds)
Total: $0.000

Net savings: $0.012 per db reset
Time savings: 3-5 minutes per db reset
```

### If You Hadn't Backed Up:
```
Initial bootstrap:
- Embeddings: $0.012

After db reset:
- Re-generate embeddings: $0.012
- Re-sync: FREE
Total: $0.012

After 10 db resets: $0.120 wasted!
```

---

## Troubleshooting

### Issue: Backup not found
```bash
# Check if Storage bucket exists
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT * FROM storage.buckets WHERE name = 'player-data-backups';
"

# Check if files exist
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT name, created_at FROM storage.objects 
WHERE bucket_id = 'player-data-backups';
"
```

### Issue: Authentication failed
```bash
# Verify .env file
cat .env

# Test auth manually
curl -X POST "http://127.0.0.1:54321/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"email":"jc@alloatech.com","password":"monkey"}' | jq
```

### Issue: Embeddings count mismatch
```bash
# Check both tables
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
SELECT 
  (SELECT COUNT(*) FROM player_embeddings_selective) as db_count,
  (SELECT record_count FROM backup_metadata ORDER BY created_at DESC LIMIT 1) as backup_count;
"
```

---

**Ready to start?** Let me know when you want to begin and I'll guide you through each step! 🚀
