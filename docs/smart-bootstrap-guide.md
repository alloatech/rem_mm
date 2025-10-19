# Smart Bootstrap System - Complete Guide

## Overview

The smart bootstrap system **automatically checks** for existing data and backups before making expensive API calls. It uses **Supabase Storage** for centralized backup management.

## Key Features

✅ **Intelligent Decision Making**: Checks what data exists before proceeding
✅ **Supabase Storage Integration**: Backups stored centrally, not local files
✅ **Dual Backup Strategy**: Raw players (~8000) + selective embeddings (~500)
✅ **Avoids External APIs**: Checks Storage for raw players before calling Sleeper
✅ **Cost Optimization**: Avoids unnecessary Gemini API calls (~$0.50 saved per bootstrap)
✅ **Fast Recovery**: 2-3 second restore from backups vs 5+ minute rebuild
✅ **Admin Console Ready**: All operations exposed via Edge Functions for Flutter UI

## Quick Start

### First Time Ever
```bash
export GEMINI_API_KEY="your_key_here"
./scripts/smart_bootstrap.sh
```

This will:
1. Check if data exists (spoiler: it doesn't)
2. Fetch players from Sleeper (free, 15 seconds)
3. Create embeddings with Gemini ($0.50, 3-5 minutes)
4. **Automatically backup to Supabase Storage**

### After `supabase db reset`
```bash
./scripts/smart_bootstrap.sh
```

This will:
1. Detect backups in Supabase Storage
2. **Restore in 2-3 seconds** (no Gemini calls!)
3. Skip expensive operations entirely

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Smart Bootstrap                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
              ┌─────────────────────────┐
              │  check_existing_data    │
              │  - Count players_raw    │
              │  - Count embeddings     │
              │  - List Storage backups │
              └─────────────────────────┘
                            │
                ┌───────────┴───────────┐
                ▼                       ▼
       ┌─────────────┐         ┌─────────────┐
       │ HAS BACKUPS │         │ NO BACKUPS  │
       └─────────────┘         └─────────────┘
                │                       │
                ▼                       ▼
    ┌──────────────────┐    ┌─────────────────────┐
    │ RESTORE (2-3s)   │    │ FETCH & CREATE      │
    │ - From Storage   │    │ - Sleeper API       │
    │ - No Gemini cost │    │ - Gemini embeddings │
    │ - Instant        │    │ - Backup to Storage │
    └──────────────────┘    └─────────────────────┘
```

### Storage Structure

```
Supabase Storage Bucket: player-data-backups/
├── players_1729416000000.json      (5.2 MB, 6,847 records)
├── embeddings_1729416000000.json   (2.8 MB, 487 records)
├── players_1729329600000.json      (older backup)
└── embeddings_1729329600000.json   (older backup)

Database Table: backup_metadata
├── filename
├── data_type (players|embeddings)
├── record_count
├── file_size
├── created_at
├── is_verified
└── restore_count (tracks usage)
```

## Edge Function API

### Check Existing Data
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin-v2' \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"check_existing_data"}'
```

**Response:**
```json
{
  "success": true,
  "data": {
    "players": {
      "count": 6847,
      "exists": true
    },
    "embeddings": {
      "count": 487,
      "exists": true
    },
    "backups": {
      "available": true,
      "count": 4,
      "latest": {
        "filename": "players_1729416000000.json",
        "size": 5242880,
        "created_at": "2025-10-19T08:40:00Z",
        "record_count": 6847
      }
    }
  },
  "recommendation": "✅ RECOMMENDED: Restore from backups (fastest, free, 2-3 seconds)"
}
```

### Get Smart Bootstrap Plan
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin-v2' \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"smart_bootstrap","data":{"gemini_api_key":"YOUR_KEY"}}'
```

**Response:**
```json
{
  "success": true,
  "current_state": {
    "players": 0,
    "embeddings": 0,
    "backups_available": 2
  },
  "plan": [
    {
      "step": "restore_players",
      "action": "restore_from_storage",
      "filename": "players_1729416000000.json",
      "cost": 0,
      "time": 3,
      "reason": "Backup available"
    },
    {
      "step": "restore_embeddings",
      "action": "restore_from_storage",
      "filename": "embeddings_1729416000000.json",
      "cost": 0,
      "time": 2,
      "reason": "Backup available"
    }
  ],
  "estimated_cost": 0,
  "estimated_time_seconds": 5,
  "recommendation": "✅ RECOMMENDED: Restore from backups (fastest, free, 2-3 seconds)"
}
```

### Execute Bootstrap Plan
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin-v2' \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{
    "action": "execute_bootstrap_plan",
    "data": {
      "plan": <PLAN_FROM_ABOVE>,
      "gemini_api_key": "optional"
    }
  }'
```

### List Backups
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin-v2' \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"list_backups"}'
```

### Backup to Storage
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin-v2' \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"backup_to_storage","data":{"data_type":"players"}}'
```

### Restore from Storage
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin-v2' \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"restore_from_storage","data":{"filename":"players_1729416000000.json"}}'
```

## Database Helper Functions

### Check if Bootstrap Needed (SQL)
```sql
SELECT should_bootstrap();
```

**Returns:**
```json
{
  "has_players": true,
  "has_embeddings": true,
  "has_backup": true,
  "player_count": 6847,
  "embedding_count": 487,
  "backup_age_hours": 2.5,
  "recommendation": "data_exists"
}
```

### Get Latest Backup Info
```sql
SELECT * FROM get_latest_backup('players');
SELECT * FROM get_latest_backup('embeddings');
```

## Flutter Admin Console Integration

### Admin Screen Layout
```dart
class AdminDataManagement extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataStatus = ref.watch(dataStatusProvider);
    
    return dataStatus.when(
      data: (status) => Column(
        children: [
          // Status Cards
          StatusCard(
            title: 'Players',
            count: status.players.count,
            icon: Icons.sports_football,
          ),
          StatusCard(
            title: 'Embeddings',
            count: status.embeddings.count,
            icon: Icons.psychology,
          ),
          StatusCard(
            title: 'Backups',
            count: status.backups.count,
            icon: Icons.backup,
          ),
          
          // Actions
          if (!status.players.exists)
            BootstrapButton(
              onPressed: () => ref.read(adminServiceProvider).smartBootstrap(),
            ),
          if (status.players.exists)
            BackupButton(
              onPressed: () => ref.read(adminServiceProvider).createBackup(),
            ),
          
          // Backup List
          BackupList(backups: status.backups.list),
        ],
      ),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
    );
  }
}
```

### Provider Implementation
```dart
@riverpod
Future<DataStatus> dataStatus(DataStatusRef ref) async {
  final adminService = ref.watch(adminServiceProvider);
  return await adminService.checkExistingData();
}

@riverpod
class AdminService {
  Future<DataStatus> checkExistingData() async {
    final response = await _supabase.functions.invoke(
      'player-data-admin-v2',
      body: {'action': 'check_existing_data'},
    );
    return DataStatus.fromJson(response.data);
  }
  
  Future<void> smartBootstrap({String? geminiApiKey}) async {
    // Show loading dialog
    final plan = await _getPlan(geminiApiKey);
    // Show confirmation with cost/time
    if (confirmed) {
      await _executePlan(plan);
      // Refresh data
      ref.invalidate(dataStatusProvider);
    }
  }
}
```

## Cost Comparison

### Without Smart Bootstrap
```
Every db reset:
  Fetch Sleeper: FREE (15s)
  Create embeddings: $0.50 (5 min)
  Total per reset: $0.50

10 resets during development = $5.00
```

### With Smart Bootstrap
```
First time:
  Fetch Sleeper: FREE (15s)
  Create embeddings: $0.50 (5 min)
  Backup to Storage: FREE (2s)
  Total: $0.50

Every subsequent reset:
  Restore from backup: FREE (2-3s)
  Total: $0.00

10 resets = $0.50 (98% savings!)
```

## Security

- All endpoints require JWT authentication
- RLS policies ensure admin-only access
- Backup metadata tracks who created each backup
- Storage policies prevent unauthorized access
- All operations logged in security_audit

## Troubleshooting

### "Storage bucket not found"
Run the migration:
```bash
supabase db reset
```

### "No backups available"
First time setup - run full bootstrap:
```bash
export GEMINI_API_KEY="your_key"
./scripts/smart_bootstrap.sh
```

### Backups out of sync
Manually create fresh backup:
```bash
curl -X POST 'http://127.0.0.1:54321/functions/v1/player-data-admin-v2' \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -d '{"action":"backup_to_storage","data":{"data_type":"players"}}'
```

## Production Deployment

### 1. Initial Setup
```bash
# Production environment
export SUPABASE_URL="https://your-project.supabase.co"
export JWT_TOKEN="your_prod_admin_token"
export GEMINI_API_KEY="your_key"

./scripts/smart_bootstrap.sh
```

### 2. Scheduled Backups (Cron)
```sql
SELECT cron.schedule(
  'weekly-backup',
  '0 2 * * 0',  -- Sunday 2 AM
  $$
  SELECT net.http_post(
    url:='http://supabase_kong:8000/functions/v1/player-data-admin-v2',
    body:='{"action":"backup_to_storage","data":{"data_type":"players"}}'::jsonb
  );
  $$
);
```

### 3. Staging/Dev Environments
Staging can restore from production backups:
```bash
# Export from production
curl prod-url/.../export > prod_backup.json

# Import to staging
curl staging-url/.../import -d @prod_backup.json
```

## Future Enhancements

- [ ] Automatic backup rotation (keep last 7 days)
- [ ] Backup compression (gzip)
- [ ] Incremental backups (only changed records)
- [ ] Cross-region backup replication
- [ ] Backup verification jobs
- [ ] Restore preview (show what will change)
- [ ] Backup scheduling from admin UI
- [ ] Email notifications on backup success/failure
