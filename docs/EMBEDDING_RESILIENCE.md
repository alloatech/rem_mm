# Embedding Resilience & Recovery

## Problem
When the bootstrap script fails during embedding creation (network errors, API rate limits, etc.), it would:
1. ❌ Stop completely and lose progress
2. ❌ Not provide a way to resume
3. ❌ Unclear if re-running would skip existing embeddings

## Solution Implemented

### 1. **Automatic Skip of Existing Embeddings** ✅
The system uses **profile hashing** to detect unchanged player data:

```typescript
// Stable profile fields (non-game stats)
const profileData = {
  name: player.full_name,
  position: player.position,
  team: player.team,
  college: player.college,
  height: player.height,
  weight: player.weight,
  birth_date: player.birth_date
}

// Generate hash
const profileHash = SHA256(profileData)

// Check if embedding exists with same profile
if (existingHash === profileHash) {
  skippedCount++  // Skip Gemini API call
  continue
}
```

**Benefits:**
- 💰 **Zero cost** for re-runs if player data hasn't changed
- ⚡ **Fast recovery** - only processes new/updated players
- 🔄 **Idempotent** - safe to run multiple times

### 2. **Continue on Failure** ✅
Instead of stopping on first error, the system now:

```typescript
try {
  // Attempt embedding creation
  const response = await fetch(geminiAPI, ...)
  if (response.ok) {
    embeddedCount++
  } else {
    failedCount++
    failedPlayers.push(playerName)
    // ✅ CONTINUE PROCESSING
  }
} catch (error) {
  failedCount++
  failedPlayers.push(playerName)
  // ✅ CONTINUE PROCESSING (don't throw)
}
```

**Benefits:**
- ✅ **Partial success** - creates as many embeddings as possible
- 📊 **Full visibility** - see exactly which players failed
- 🔄 **Easy retry** - re-run to retry only failed players

### 3. **Detailed Failure Reporting** ✅

Response now includes comprehensive stats:

```json
{
  "success": false,
  "message": "Data ingestion completed with 5 errors. Re-run to retry failed players.",
  "stats": {
    "totalPlayers": 11400,
    "embeddedPlayers": 187,
    "skippedPlayers": 42,  // Already had embeddings
    "failedPlayers": 5,    // Network/API errors
    "cost": "$0.0187",
    "savedCost": "$0.0042"
  },
  "failures": [
    "Patrick Mahomes (4046)",
    "Travis Kelce (4098)",
    ...
  ],
  "retryAdvice": "Re-run the script to automatically retry only the failed players."
}
```

## Usage

### Normal Bootstrap
```bash
./scripts/complete_bootstrap.sh
```

If it fails partway through:
- ✅ Already-created embeddings are preserved
- ✅ Re-running skips unchanged players (via hash check)
- ✅ Only processes new/failed players

### Recovery from Failure

1. **Check what you have:**
```sql
SELECT COUNT(*) FROM player_embeddings_selective;
-- Example: 42 embeddings exist
```

2. **Re-run bootstrap:**
```bash
./scripts/complete_bootstrap.sh
```

3. **What happens:**
- ⏭️  Skips 42 players (hash match, no API call)
- 🔄 Retries 5 failed players
- ✅ Completes remaining players

## Hash-Based Change Detection

### What Triggers Re-Embedding?
Only changes to **stable profile fields**:
- Name
- Position
- Team (trades/signings)
- College
- Height/Weight
- Birth date

### What Does NOT Trigger Re-Embedding?
- ✅ Game stats (points, yards, TDs)
- ✅ Status (active, injured, suspended)
- ✅ Roster changes
- ✅ Fantasy rankings

**Why?** These change frequently but don't affect the semantic embedding of who the player IS.

## Cost Optimization

### Example Scenario
Initial run: 192 players × $0.0001 = **$0.0192**

Network failure after 42 players → Re-run:
- Skipped: 42 players (hash match) = **$0.00** ⏭️
- Retried: 150 players × $0.0001 = **$0.015** 🔄
- Total cost: **$0.0192** (same as if it never failed!)

### Key Point
**Re-running is essentially free** if player data hasn't changed. The profile hash system ensures you only pay for:
1. New players
2. Players whose profiles changed (trades, position changes, etc.)
3. Players that failed on previous runs

## Monitoring

### Check Current State
```sql
-- Total embeddings
SELECT COUNT(*) as total FROM player_embeddings_selective;

-- Embeddings by team
SELECT 
  pr.team,
  COUNT(*) as embeddings
FROM player_embeddings_selective pe
JOIN players_raw pr ON pe.player_id = pr.player_id
GROUP BY pr.team
ORDER BY embeddings DESC;

-- Recent embedings (by profile_hash update)
SELECT 
  pr.full_name,
  pr.position,
  pr.team,
  pe.created_at
FROM player_embeddings_selective pe
JOIN players_raw pr ON pe.player_id = pr.player_id
ORDER BY pe.created_at DESC
LIMIT 10;
```

### Bootstrap Script Output
```
Step 5: Creating embeddings
  Creating embeddings for 192 rostered players...
  
  Status: ⏭️  Skipped: Patrick Mahomes (unchanged) (42/192)
  Status: 🧠 Embedding: Travis Kelce (new) (43/192)
  Status: ❌ Failed: Christian McCaffrey - Network timeout (44/192)
  ...
  
  ⚠️  Complete with errors! Synced 11400, embedded 150, skipped 42, failed 5
  
  Failures:
    - Christian McCaffrey (7547)
    - Tyreek Hill (4983)
  
  💡 Re-run to retry failed players (will skip 192 existing)
```

## Best Practices

1. **Always Safe to Re-Run** ✅
   - Hash checking prevents duplicate API calls
   - Existing embeddings preserved
   - Idempotent operation

2. **Monitor for Failures** 📊
   - Check bootstrap output for "⚠️ Complete with errors"
   - Review failed player list
   - Re-run if needed

3. **Cost Tracking** 💰
   - Profile hash skips count towards "savedCost"
   - Only "embeddedPlayers" count incurs charges
   - Re-runs on unchanged data = $0.00

4. **Network Issues** 🌐
   - Script continues on individual failures
   - Partial progress saved
   - Simply re-run to complete

## Technical Details

### Profile Hash Storage
```sql
-- player_embeddings_selective table
CREATE TABLE player_embeddings_selective (
  player_id TEXT PRIMARY KEY,
  content TEXT,
  embedding vector(768),
  profile_hash TEXT,  -- SHA-256 of stable profile fields
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Index for hash lookups
CREATE INDEX idx_profile_hash ON player_embeddings_selective(profile_hash);
```

### Embedding Creation Flow
```
1. Fetch existing embeddings with profile_hash
   ↓
2. For each player:
   ├─ Calculate profile_hash from stable fields
   ├─ Check if hash exists in existingMap
   │  ├─ Match? → Skip (no API call) ⏭️
   │  └─ No match/new? → Continue ↓
   ├─ Call Gemini API
   │  ├─ Success? → Upsert with new hash ✅
   │  ├─ Network error? → Log failure, continue 🔄
   │  └─ API error? → Log failure, continue 🔄
   └─ Next player
   ↓
3. Report: embedded, skipped, failed counts
```

### Error Handling Strategy
```typescript
// OLD: Stop on first error
try {
  await createEmbedding(player)
} catch (error) {
  throw error  // ❌ Stops entire process
}

// NEW: Continue on errors
try {
  await createEmbedding(player)
} catch (error) {
  failedPlayers.push(player)
  // ✅ Continue to next player
}
```

## Related Docs
- [EMBEDDING_BUG_FIX.md](./EMBEDDING_BUG_FIX.md) - UNIQUE constraint issue
- [BOOTSTRAP_IMPROVEMENTS.md](./BOOTSTRAP_IMPROVEMENTS.md) - Script enhancements
- [COST_OPTIMIZATION.md](./COST_OPTIMIZATION.md) - Selective embedding strategy
