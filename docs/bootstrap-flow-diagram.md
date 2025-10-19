# Smart Bootstrap Flow - Complete Diagram

## Decision Tree

```
START: smart_bootstrap
│
├─ Check database tables:
│  ├─ players_raw: 0 records
│  └─ player_embeddings_selective: 0 records
│
├─ Check Supabase Storage:
│  ├─ players/ folder: Check for player_backup_*.json
│  └─ embeddings/ folder: Check for embedding_backup_*.json
│
└─ Create optimal plan based on findings:

┌──────────────────────────────────────────────────────────────────┐
│ SCENARIO 1: Fresh Install (No data, No backups)                  │
├──────────────────────────────────────────────────────────────────┤
│ 1. fetch_sleeper_data      → Sleeper API (15 sec, FREE)         │
│ 2. backup_to_storage       → Save raw players (3 sec)           │
│ 3. run_ingestion           → Gemini API (300 sec, $0.50)        │
│ 4. backup_to_storage       → Save embeddings (3 sec)            │
│                                                                  │
│ Total Time: ~321 seconds (~5 minutes)                           │
│ Total Cost: $0.50                                               │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ SCENARIO 2: After db reset (No data, Both backups exist)         │
├──────────────────────────────────────────────────────────────────┤
│ 1. restore_from_storage    → Restore players (3 sec, FREE)      │
│ 2. restore_from_storage    → Restore embeddings (2 sec, FREE)   │
│                                                                  │
│ Total Time: ~5 seconds                                          │
│ Total Cost: $0.00                                               │
│ Savings: $0.50 (100% of embedding cost)                         │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ SCENARIO 3: Partial backup (Players backup exists, no embeddings)│
├──────────────────────────────────────────────────────────────────┤
│ 1. restore_from_storage    → Restore players (3 sec, FREE)      │
│ 2. run_ingestion           → Gemini API (300 sec, $0.50)        │
│ 3. backup_to_storage       → Save embeddings (3 sec)            │
│                                                                  │
│ Total Time: ~306 seconds (~5 minutes)                           │
│ Total Cost: $0.50                                               │
│ Benefit: Avoids Sleeper API call (faster, more reliable)        │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ SCENARIO 4: force_fresh=true (Ignore all backups)                │
├──────────────────────────────────────────────────────────────────┤
│ 1. fetch_sleeper_data      → Sleeper API (15 sec, FREE)         │
│ 2. backup_to_storage       → Overwrite player backup (3 sec)    │
│ 3. run_ingestion           → Gemini API (300 sec, $0.50)        │
│ 4. backup_to_storage       → Overwrite embedding backup (3 sec) │
│                                                                  │
│ Total Time: ~321 seconds (~5 minutes)                           │
│ Total Cost: $0.50                                               │
│ Use case: Weekly/daily data refresh to get latest trades        │
└──────────────────────────────────────────────────────────────────┘
```

## Backup Structure in Supabase Storage

```
player-data-backups/  (Storage Bucket)
│
├── players/
│   ├── player_backup_2025-10-19T10-30-00.json    (8,127 players, ~8MB)
│   ├── player_backup_2025-10-18T09-15-00.json
│   └── player_backup_2025-10-17T08-00-00.json
│
└── embeddings/
    ├── embedding_backup_2025-10-19T10-35-00.json  (502 players, ~3MB)
    ├── embedding_backup_2025-10-18T09-20-00.json
    └── embedding_backup_2025-10-17T08-05-00.json
```

## Backup Metadata in Database

```sql
-- Table: backup_metadata
SELECT * FROM backup_metadata ORDER BY created_at DESC;

┌──────────────────────────────────────────┬──────────┬──────────┬──────────┬────────────────────┐
│ filename                                  │ data_type│ count    │ file_size│ created_at         │
├──────────────────────────────────────────┼──────────┼──────────┼──────────┼────────────────────┤
│ embedding_backup_2025-10-19T10-35-00.json│ embeddings│ 502     │ 3145728  │ 2025-10-19 10:35:00│
│ player_backup_2025-10-19T10-30-00.json   │ players   │ 8127    │ 8388608  │ 2025-10-19 10:30:00│
│ embedding_backup_2025-10-18T09-20-00.json│ embeddings│ 498     │ 3100000  │ 2025-10-18 09:20:00│
│ player_backup_2025-10-18T09-15-00.json   │ players   │ 8105    │ 8350000  │ 2025-10-18 09:15:00│
└──────────────────────────────────────────┴──────────┴──────────┴──────────┴────────────────────┘
```

## How Storage Checking Works

### Step 1: Check Database Tables
```typescript
const playersCount = await supabase
  .from('players_raw')
  .select('player_id', { count: 'exact', head: true })

const embeddingsCount = await supabase
  .from('player_embeddings_selective')
  .select('id', { count: 'exact', head: true })
```

### Step 2: Check Storage Backups
```typescript
const playerBackups = await listStorageBackups(supabase, 'players')
const embeddingBackups = await listStorageBackups(supabase, 'embeddings')

// Returns array like:
[
  {
    filename: 'player_backup_2025-10-19T10-30-00.json',
    data_type: 'players',
    record_count: 8127,
    file_size_mb: 8.0,
    age_hours: 2,
    created_at: '2025-10-19T10:30:00Z'
  }
]
```

### Step 3: Smart Decision
```typescript
if (hasPlayerBackup && hasEmbeddingBackup && !force_fresh) {
  // BEST CASE: Restore both from Storage (5 seconds, $0)
  plan = ['restore_players', 'restore_embeddings']
  
} else if (hasPlayerBackup && !hasPlayers) {
  // GOOD CASE: Restore players, create embeddings (305 sec, $0.50)
  plan = ['restore_players', 'run_ingestion', 'backup_embeddings']
  
} else {
  // FULL BOOTSTRAP: Fetch from APIs, create everything (321 sec, $0.50)
  plan = ['fetch_sleeper_data', 'backup_players', 'run_ingestion', 'backup_embeddings']
}
```

## Why This Matters

### Development Workflow
During development, you might reset your database 10+ times:

**Without Storage Backups**:
- 10 resets × $0.50 = **$5.00 in Gemini API costs**
- 10 resets × 5 minutes = **50 minutes waiting**

**With Storage Backups**:
- First reset: $0.50 (creates backups)
- Next 9 resets: $0.00 (restores from backups in 5 seconds each)
- **Total: $0.50 and ~1 minute total wait time**
- **Savings: $4.50 (90%) and 49 minutes**

### Production Workflow

**Scenario A: Daily Refresh (Updates)**
```bash
# Only fetch new data if needed
./scripts/smart_bootstrap.sh
```
- Checks if backups are fresh (< 24 hours old)
- If fresh, restores from backup (5 sec, $0)
- If stale, fetches fresh and updates (321 sec, $0.50)

**Scenario B: Weekly Full Refresh**
```bash
# Force fresh data from Sleeper
./scripts/smart_bootstrap.sh --force-fresh
```
- Ignores backups
- Fetches latest from Sleeper API
- Creates new embeddings with change detection (only changed players)
- Overwrites backups with fresh data

## Cost Impact Summary

| Scenario | Time | Cost | Notes |
|----------|------|------|-------|
| Fresh install | 5 min | $0.50 | First time only |
| After db reset (with backups) | 5 sec | $0.00 | **90% savings** |
| Daily refresh (backup fresh) | 5 sec | $0.00 | Common case |
| Weekly refresh (force fresh) | 5 min | $0.05 | With change detection |
| Monthly full rebuild | 5 min | $0.50 | Rare |

**Total Monthly Cost** (daily bootstraps):
- Without optimization: 30 × $0.50 = **$15.00/month**
- With Storage backups: 1 × $0.50 = **$0.50/month**
- With change detection: 4 × $0.05 = **$0.20/month** (weekly refreshes)

**Combined savings: 98.7%** 🎉
