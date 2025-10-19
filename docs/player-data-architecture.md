# Player Data Architecture & Admin Guide

## Overview

The rem_mm player data system uses a **two-table strategy** to minimize Gemini API costs while maintaining real-time player information and semantic search capabilities.

## Table Architecture

### 1. `players_raw` - Complete NFL Player Database

**Purpose**: Store ALL player data from Sleeper API with frequent updates (daily/real-time).

**Key Features**:
- Complete player profiles (8,000+ NFL players)
- Real-time updates: injuries, depth charts, status changes
- No embedding costs - just raw data storage
- Fast lookups by position, team, status
- Updated frequently (hourly/daily via cron)

**Data Includes**:
- Basic info: name, position, team, number
- Fantasy stats: depth chart, injury status, practice reports
- Metadata: age, height, weight, college, years of experience
- External IDs: ESPN, Yahoo, FantasyData cross-reference
- Raw JSON backup for future extensibility

**Cost**: FREE - No AI/embedding costs, just database storage

### 2. `player_embeddings_selective` - Smart Semantic Search

**Purpose**: Store embeddings for ONLY players that users care about (selective embedding strategy).

**Key Features**:
- Only embed ~200-500 players (vs 8,000+)
- Embeddings created based on user activity
- 768-dimensional vectors for semantic search
- Priority system for important players
- One-time embedding cost per player

**Embedding Triggers** (when to create embeddings):
1. **User Rosters**: Players on any user's fantasy roster (high priority)
2. **Trending**: Players with recent news/status changes
3. **Popular**: Top-owned players across leagues
4. **Manual**: Admin-selected important players

**Cost Optimization**:
- Initial setup: ~$0.50 for 500 players (one-time)
- Ongoing: Only new/changed players (~$0.01-0.05/week)
- **120x cheaper** than embedding all players weekly

## Cost Comparison

### Old Approach (Embed Everything):
- 8,000 players × weekly updates = **$60/month**
- Every query regenerates context = wasteful

### New Approach (Selective + Stable + Change Detection):
- 500 selective players × once = **$0.50 one-time**
- Updates only when roster changes = **$0.50/month**
- **Change detection skips 80-90% of re-embeddings** (profile data rarely changes)
- **Total savings: 99% reduction**

## Change Detection System

### Profile Hash Strategy

Player embeddings are based on **stable profile fields** only:
- Name, position, team, college
- Height, weight, birth date
- Draft info (year, round, pick)

These fields **rarely change** (only with trades/position changes).

### How It Works

1. **Generate Hash**: SHA-256 hash of stable fields when creating embedding
2. **Store Hash**: Save in `profile_hash` column in `player_embeddings_selective`
3. **Check Before Embedding**: On ingestion, compare current profile hash with existing
4. **Skip if Unchanged**: If hash matches, skip expensive Gemini API call
5. **Re-embed if Changed**: Only call API when profile actually changes

### Cost Impact

Example: 500 players, daily ingestion runs
- **Without change detection**: 500 API calls × $0.001 = $0.50 per run
- **With change detection** (90% unchanged): 50 API calls × $0.001 = $0.05 per run
- **Savings**: $0.45 per run = **90% reduction**

### Dynamic Data Strategy

Fields that change frequently (injury status, depth chart, fantasy points) are:
- Stored in `players_raw` for real-time queries
- **NOT included in embeddings** (would require constant re-embedding)
- Filtered at query time using WHERE clauses
- This separates stable semantic data from dynamic real-time data

## Bootstrapping Strategy

### 1. Initial Setup (First Time)

```bash
# Step 1: Fetch all players from Sleeper
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"action": "fetch_sleeper_data"}'

# Result: ~6,000-8,000 players stored in players_raw
```

```bash
# Step 2: Export players for backup
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"action": "export_players"}' > players_backup.json
```

```bash
# Step 3: Create selective embeddings (via simple-ingestion)
curl -X POST 'http://127.0.0.1:54321/functions/v1/simple-ingestion' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "limit": 500,
    "test_mode": false,
    "gemini_api_key": "YOUR_GEMINI_KEY"
  }'

# Result: ~500 embeddings created based on popularity/rosters
```

```bash
# Step 4: Export embeddings for backup
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"action": "export_embeddings"}' > embeddings_backup.json
```

### 2. Quick Restore (Testing/Development)

```bash
# Restore players from backup
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d @players_backup.json

# Restore embeddings from backup
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d @embeddings_backup.json
```

### 3. After `supabase db reset`

```bash
# Option A: Restore from backups (FAST - 2 seconds)
cat players_backup.json | jq '.data' > /tmp/players.json
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d "{\"action\":\"import_players\",\"data\":$(cat /tmp/players.json)}"

curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d "{\"action\":\"import_embeddings\",\"data\":$(cat embeddings_backup.json | jq '.data')}"

# Option B: Fresh fetch (SLOW - 30 seconds + Gemini costs)
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"action": "fetch_sleeper_data"}'
```

## Admin Console Features

### Get Statistics

```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"action": "get_stats"}'
```

**Returns**:
```json
{
  "success": true,
  "players": {
    "totalPlayers": 6847,
    "byPosition": {"QB": 124, "RB": 543, "WR": 892, ...},
    "byTeam": {"KC": 67, "SF": 65, ...},
    "byStatus": {"Active": 5234, "Injured": 234, ...},
    "activeCount": 5234,
    "injuredCount": 234,
    "lastSyncTime": "2025-10-19T08:45:00Z"
  },
  "embeddings": {
    "totalEmbedded": 487,
    "byReason": {"user_roster": 312, "trending": 98, "popular": 77},
    "byPriority": {"3": 123, "2": 245, "1": 119},
    "averageContentLength": 156,
    "oldestEmbedding": "2025-10-18T12:00:00Z",
    "newestEmbedding": "2025-10-19T08:30:00Z"
  }
}
```

### Clear Data (Destructive Operations)

```bash
# Clear all players
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"action": "clear_players", "data": {"confirm": "DELETE_ALL_PLAYERS"}}'

# Clear all embeddings
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"action": "clear_embeddings", "data": {"confirm": "DELETE_ALL_EMBEDDINGS"}}'
```

## Daily Maintenance Strategy

### Cron Schedule (Supabase Edge Functions)

```sql
-- Daily player update (8 AM ET)
SELECT cron.schedule(
  'daily-player-sync',
  '0 8 * * *',
  $$
  SELECT net.http_post(
    url:='http://supabase_kong_rem_mm:8000/functions/v1/player-data-admin',
    headers:='{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.service_key') || '"}'::jsonb,
    body:='{"action": "fetch_sleeper_data"}'::jsonb
  );
  $$
);

-- Weekly embedding refresh (Sunday midnight)
SELECT cron.schedule(
  'weekly-embedding-refresh',
  '0 0 * * 0',
  $$
  SELECT net.http_post(
    url:='http://supabase_kong_rem_mm:8000/functions/v1/simple-ingestion',
    headers:='{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('app.service_key') || '"}'::jsonb,
    body:='{"limit": 500, "test_mode": false}'::jsonb
  );
  $$
);
```

## File Storage Recommendations

### Backup Files
```
/backups/
  ├── players/
  │   ├── players_2025-10-19.json
  │   ├── players_2025-10-18.json
  │   └── players_latest.json
  └── embeddings/
      ├── embeddings_2025-10-19.json
      ├── embeddings_2025-10-18.json
      └── embeddings_latest.json
```

### Git LFS for Large Files
```bash
# Add to .gitattributes
*.json filter=lfs diff=lfs merge=lfs -text

# Track backup files
git lfs track "backups/**/*.json"
```

## Testing Workflow

### Development Reset Workflow
```bash
# 1. Reset database
supabase db reset

# 2. Quick restore from backups
./scripts/restore_player_data.sh

# 3. Verify
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H 'Authorization: Bearer YOUR_JWT' \
  -d '{"action": "get_stats"}'
```

## Security

- All admin endpoints require JWT authentication
- Admin role verification (super_admin or admin)
- All actions logged in `security_audit` table
- Destructive operations require explicit confirmation

## Performance

- **Export**: ~2-5 seconds for 8,000 players
- **Import**: ~3-8 seconds for 8,000 players
- **Stats**: <1 second
- **Fetch Sleeper**: ~10-15 seconds
- **Embeddings**: ~2-5 minutes for 500 players (one-time)

## Next Steps

1. Create Flutter admin UI for these operations
2. Set up automated backups to S3/cloud storage
3. Add progress tracking for long operations
4. Create restore scripts for quick development setup
5. Monitor embedding costs and adjust selective strategy
