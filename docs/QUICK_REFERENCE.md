# Quick Reference: Multi-User Bootstrap

## TL;DR
**Problem**: Need to embed 2,964 players ($0.30) but only care about ~100-350 rostered players  
**Solution**: Sync entire league → identify rostered players → embed only those  
**Result**: 90-97% cost savings + better relevance

> **Note**: Player counts vary year-to-year based on your actual league participation. Script auto-detects and adapts.

## One-Command Bootstrap
```bash
./scripts/complete_bootstrap.sh
```

## What It Does
1. ✅ Fetches 2,964 players from Sleeper (FREE)
2. ✅ Syncs your league(s) (FREE) - detects how many you're in
3. ✅ Syncs ALL rosters in those leagues (FREE) - **includes other users**
4. ✅ Identifies ~100-150 unique rostered players (depends on league size)
5. ✅ Creates embeddings ONLY for those players ($0.010-0.015)

## Key Innovation: Multi-User Rosters

### Before
```
User A syncs → Only User A's roster stored
User B syncs → Only User B's roster stored
Result: Each user syncs separately
```

### After
```
User A syncs → ALL rosters in league stored
  ├── User A: linked immediately (app_user_id set)
  ├── User B: stored but not linked (app_user_id=NULL)
  └── User C: stored but not linked (app_user_id=NULL)

User B registers later → Auto-linked to their roster
  └── No sync needed, data already there!
```

## Database Schema

### user_rosters Table
```sql
-- Key fields
app_user_id         UUID      -- NULL until user registers
sleeper_owner_id    TEXT      -- Always present (Sleeper user ID)
league_id           UUID      -- References user_leagues
player_ids          TEXT[]    -- Array of rostered players

-- UNIQUE constraint
UNIQUE(league_id, sleeper_owner_id)  -- One roster per Sleeper user per league
```

## API Reference

### Register User (Auto-Links Rosters)
```bash
curl -X POST "http://localhost:54321/functions/v1/user-sync" \
  -H "Authorization: Bearer $JWT" \
  -d '{
    "action": "register_user",
    "sleeper_user_id": "872612101674491904",
    "sleeper_username": "th0rjc"
  }'
```

### Sync Leagues
```bash
curl -X POST "http://localhost:54321/functions/v1/user-sync" \
  -H "Authorization: Bearer $JWT" \
  -d '{
    "action": "sync_leagues",
    "sleeper_user_id": "872612101674491904"
  }'
```

### Sync ALL Rosters (Multi-User)
```bash
curl -X POST "http://localhost:54321/functions/v1/user-sync" \
  -H "Authorization: Bearer $JWT" \
  -d '{
    "action": "sync_rosters",
    "sleeper_user_id": "872612101674491904"
  }'
```

### Get Rostered Players
```bash
curl -X POST "http://localhost:54321/functions/v1/user-sync" \
  -H "Authorization: Bearer $JWT" \
  -d '{
    "action": "get_rostered_players",
    "sleeper_user_id": "872612101674491904"
  }'
# Returns: { player_ids: [...], player_count: 150 }
```

### Create Embeddings (Targeted)
```bash
curl -X POST "http://localhost:54321/functions/v1/simple-ingestion" \
  -H "Authorization: Bearer $JWT" \
  -d '{
    "gemini_api_key": "YOUR_KEY",
    "player_ids": ["4866", "2133", "7564", ...]
  }'
```

## Cost Breakdown

| Scenario | Players | Cost | Notes |
|----------|---------|------|-------|
| All players | 2,964 | $0.296 | ❌ Wasteful |
| Fantasy-relevant | 500 | $0.050 | ⚠️ Better but still broad |
| **Rostered only** | **~150** | **$0.015** | **✅ Optimal** |

**Savings**: $0.296 - $0.015 = $0.281 (95% reduction)

With change detection (90% unchanged):
- Daily updates: ~15 players × $0.0001 = $0.0015/day
- Monthly: $0.045 vs $9.00 = **99.5% savings**

## Environment Setup

### Required Variables (.env)
```bash
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=eyJh...
ADMIN_EMAIL=jc@alloatech.com
ADMIN_PASSWORD=monkey
ADMIN_SLEEPER_ID=872612101674491904
GEMINI_API_KEY=AIza...
```

## Testing

### Quick Test
```bash
# 1. Bootstrap system
./scripts/complete_bootstrap.sh

# 2. Check rosters (should see multiple teams)
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  -c "SELECT COUNT(*), COUNT(DISTINCT sleeper_owner_id) FROM user_rosters;"

# 3. Check embeddings (should be ~150 players)
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  -c "SELECT COUNT(*) FROM player_embeddings_selective;"
```

### Verify Multi-User
```bash
# Should see rosters with NULL app_user_id (unregistered users)
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "
  SELECT 
    sleeper_owner_id,
    CASE WHEN app_user_id IS NULL THEN '⏳ Not registered' ELSE '✅ Registered' END as status,
    array_length(player_ids, 1) as roster_size
  FROM user_rosters
  ORDER BY status DESC;
"
```

## Common Issues

### "User not found"
→ Run `register_user` action first

### "No leagues found"
→ Check Sleeper user ID is correct  
→ User must have active NFL leagues for current season

### "No rosters synced"
→ Run `sync_leagues` before `sync_rosters`  
→ Check user is actually in the leagues

### "Embeddings not creating"
→ Check `GEMINI_API_KEY` is valid  
→ Ensure `player_ids` array is not empty

## What's Next?

### Immediate
- ✅ Test complete bootstrap workflow
- ⏭️ Verify embeddings are created
- ⏭️ Test with second user registration

### Soon
- Build Flutter admin UI for league management
- Add automatic roster refresh (daily/weekly)
- Implement stale data detection

### Future
- Real-time roster updates via webhooks
- League-wide player pool analysis
- Trade analyzer with opponent rosters

## Key Files

- `scripts/complete_bootstrap.sh` - Main bootstrap script
- `supabase/functions/user-sync/index.ts` - League/roster sync
- `supabase/functions/simple-ingestion/index.ts` - Targeted embeddings
- `docs/MULTI_USER_ROSTER_STRATEGY.md` - Complete strategy guide
- `docs/COMPLETE_BOOTSTRAP_SUMMARY.md` - Implementation details

---

**Ready?** Run: `./scripts/complete_bootstrap.sh`
