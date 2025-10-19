# Bootstrap Scripts

Quick setup and maintenance scripts for rem_mm player data.

## Quick Start

### First Time Setup
```bash
# Set your Gemini API key
export GEMINI_API_KEY="your_gemini_api_key_here"

# Run initial bootstrap (fetches players + creates embeddings)
./scripts/bootstrap_initial.sh
```

### After Database Reset
```bash
# Quick restore from backups (2-3 seconds)
export JWT_TOKEN=$(curl -s -X POST 'http://127.0.0.1:54321/auth/v1/token?grant_type=password' \
  -H 'apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH' \
  -H 'Content-Type: application/json' \
  -d '{"email":"jc@alloatech.com","password":"monkey"}' | jq -r '.access_token')

./scripts/restore_player_data.sh
```

### Regular Backups
```bash
# Export current data to backups/
./scripts/backup_player_data.sh
```

## Scripts

### `bootstrap_initial.sh`
**Purpose**: First-time setup - fetches all players and creates embeddings

**What it does**:
1. Fetches ~8,000 players from Sleeper API
2. Stores fantasy-relevant players in `players_raw`
3. Creates selective embeddings for ~500 key players
4. Exports backups for quick restore

**When to use**:
- First deployment
- After major data schema changes
- When starting fresh

**Time**: 3-5 minutes
**Cost**: ~$0.50 in Gemini API calls (one-time)

### `backup_player_data.sh`
**Purpose**: Export current player data and embeddings to JSON files

**What it does**:
1. Exports all `players_raw` records
2. Exports all `player_embeddings_selective` records
3. Saves to `./backups/` with timestamp
4. Creates `*_latest.json` symlinks
5. Cleans up backups older than 7 days

**When to use**:
- Before major changes
- Daily/weekly for safety
- Before `supabase db reset`

**Time**: 2-5 seconds

### `restore_player_data.sh`
**Purpose**: Quick restore from backup files (no API calls, no Gemini costs)

**What it does**:
1. Imports players from `backups/players_latest.json`
2. Imports embeddings from `backups/embeddings_latest.json`
3. Shows final statistics

**When to use**:
- After `supabase db reset`
- Testing/development workflow
- Disaster recovery

**Time**: 2-3 seconds
**Cost**: FREE - no API calls

## Environment Variables

### Required
- `JWT_TOKEN` - Admin JWT token (scripts can auto-generate if credentials are set)

### Optional
- `GEMINI_API_KEY` - Required only for `bootstrap_initial.sh`
- `SUPABASE_URL` - Defaults to `http://127.0.0.1:54321`

## Workflow Examples

### Development Workflow
```bash
# Daily work
supabase db reset
./scripts/restore_player_data.sh  # 2 seconds
# Continue development

# End of day (optional)
./scripts/backup_player_data.sh   # Save any changes
```

### Production Deployment
```bash
# 1. Initial setup
./scripts/bootstrap_initial.sh

# 2. Backup immediately
./scripts/backup_player_data.sh

# 3. Commit backups to Git (or upload to S3)
git add backups/
git commit -m "Add player data backups"

# 4. Set up cron for daily updates
# (see docs/player-data-architecture.md)
```

### Testing New Features
```bash
# 1. Backup current state
./scripts/backup_player_data.sh

# 2. Test changes
supabase db reset
./scripts/restore_player_data.sh

# 3. If something breaks, restore is instant
./scripts/restore_player_data.sh
```

## File Structure

```
backups/
├── players/
│   ├── players_2025-10-19_08-30-00.json
│   ├── players_2025-10-18_15-20-00.json
│   └── ...
├── embeddings/
│   ├── embeddings_2025-10-19_08-30-00.json
│   ├── embeddings_2025-10-18_15-20-00.json
│   └── ...
├── players_latest.json -> players/players_2025-10-19_08-30-00.json
└── embeddings_latest.json -> embeddings/embeddings_2025-10-19_08-30-00.json
```

## Troubleshooting

### "JWT_TOKEN not set"
```bash
export JWT_TOKEN=$(curl -s -X POST 'http://127.0.0.1:54321/auth/v1/token?grant_type=password' \
  -H 'apikey: sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH' \
  -H 'Content-Type: application/json' \
  -d '{"email":"jc@alloatech.com","password":"monkey"}' | jq -r '.access_token')
```

### "Players backup not found"
Run backup first:
```bash
./scripts/backup_player_data.sh
```

### "Failed to authenticate"
Check Supabase is running and credentials are correct:
```bash
supabase status
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "SELECT email FROM auth.users;"
```

### Restore fails
Try fetching fresh data:
```bash
# This will re-download from Sleeper (slower but guaranteed fresh)
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin' \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action":"fetch_sleeper_data"}'
```

## Cost Tracking

| Operation | Gemini API Calls | Cost | Time |
|-----------|-----------------|------|------|
| bootstrap_initial.sh | ~500 embeddings | ~$0.50 | 3-5 min |
| backup_player_data.sh | 0 | FREE | 2-5 sec |
| restore_player_data.sh | 0 | FREE | 2-3 sec |
| Daily player update | 0 | FREE | 10-15 sec |
| Weekly embed refresh | ~50 new players | ~$0.05 | 30-60 sec |

**Monthly estimate**: $0.50 initial + $0.20 ongoing = **$0.70/month**
