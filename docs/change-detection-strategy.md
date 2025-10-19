# Change Detection Strategy for Embeddings

## Problem Statement

Without change detection, the `simple-ingestion` function would call the Gemini API for **every player** on every run, even if their profile data hasn't changed. This is expensive and wasteful.

## Solution: Profile Hash Comparison

### Stable vs Dynamic Data

**Stable Fields** (rarely change, included in embedding):
- `full_name`: Player's name
- `position`: QB, RB, WR, TE, etc.
- `team`: Current NFL team
- `college`: College attended
- `height`: Height in inches
- `weight`: Weight in pounds
- `birth_date`: Date of birth

These fields are **embedded once** and only re-embedded when they change (e.g., trade, position change).

**Dynamic Fields** (change frequently, NOT embedded):
- `injury_status`: Questionable, Out, IR, etc.
- `depth_chart_position`: Starter, backup, practice squad
- `fantasy_points_ppr`: Weekly stats
- `practice_participation`: Limited, Full, DNP

These fields are stored in `players_raw` for real-time queries but **don't trigger re-embedding**.

## Implementation

### Database Schema

```sql
-- player_embeddings_selective table
ALTER TABLE player_embeddings_selective 
ADD COLUMN profile_hash TEXT;

CREATE INDEX idx_player_embeddings_profile_hash 
ON player_embeddings_selective(profile_hash);
```

### Edge Function Logic

```typescript
// 1. Fetch existing embeddings with their profile hashes
const { data: existingEmbeddings } = await supabase
  .from('player_embeddings_selective')
  .select('player_id, profile_hash')

const existingMap = new Map(
  existingEmbeddings?.map((e: any) => [e.player_id, e.profile_hash]) || []
)

// 2. For each player, generate hash from stable fields
const profileData = {
  name: player.full_name,
  position: player.position,
  team: player.team,
  college: player.college,
  height: player.height,
  weight: player.weight,
  birth_date: player.birth_date
}

const profileHash = await crypto.subtle.digest(
  'SHA-256',
  new TextEncoder().encode(JSON.stringify(profileData))
)

// 3. Check if profile has changed
const existingHash = existingMap.get(playerId)
if (existingHash === hashHex) {
  // Profile unchanged - skip Gemini API call
  skippedCount++
  continue
}

// 4. Profile changed or new player - create embedding
const embeddingResponse = await fetch(geminiApiUrl, {...})
const embedding = embeddingData.embedding.values

// 5. Store embedding with profile hash
await supabase.from('player_embeddings_selective').upsert({
  player_id: playerId,
  content,
  embedding: `[${embedding.join(',')}]`,
  profile_hash: hashHex // ← Store for next comparison
})
```

## Cost Impact

### Example Scenario: 500 Players, Daily Ingestion

**Without Change Detection**:
- 500 players × $0.001 per embedding = **$0.50 per run**
- Daily: $0.50 × 30 days = **$15.00/month**

**With Change Detection** (assuming 90% unchanged):
- 50 new/changed players × $0.001 = **$0.05 per run**
- Daily: $0.05 × 30 days = **$1.50/month**

**Savings**: $13.50/month = **90% cost reduction**

## When Profiles Change

### Common Scenarios

1. **Player Trades** (5-10 per week during season):
   - Team field changes
   - Profile hash changes
   - Re-embedding triggered

2. **Position Changes** (rare, 1-2 per season):
   - Position field changes
   - Profile hash changes
   - Re-embedding triggered

3. **Name Corrections** (very rare):
   - Name field changes
   - Profile hash changes
   - Re-embedding triggered

4. **New Players** (20-50 per week):
   - No existing hash
   - Embedding created

### Unchanged Scenarios (Skip API Call)

1. **Injury Status Updates** (100+ per week):
   - Dynamic field, not in hash
   - No re-embedding needed

2. **Weekly Stats Updates** (500+ per week):
   - Dynamic field, not in hash
   - No re-embedding needed

3. **Depth Chart Changes** (50+ per week):
   - Dynamic field, not in hash
   - No re-embedding needed

## Query Strategy

When users ask questions like "Who are the healthy starting RBs?", we:

1. **Use embeddings** for semantic search: "starting RBs" → similarity search
2. **Filter players_raw** for dynamic data: `WHERE injury_status = 'Healthy' AND depth_chart_position = 1`
3. **Combine results**: Embeddings provide semantic relevance, raw table provides real-time status

This gives us:
- **Fast semantic search** (embeddings)
- **Real-time data** (raw table)
- **Low cost** (only embed stable data)

## Monitoring

The `simple-ingestion` function logs:
- `embeddedPlayers`: Number of new embeddings created
- `skippedPlayers`: Number of unchanged players skipped
- `savingsPercent`: Percentage of API calls saved
- `actualCost`: Cost of embeddings created
- `savedCost`: Cost savings from skipped embeddings

Example output:
```json
{
  "embeddedPlayers": 48,
  "skippedPlayers": 452,
  "savingsPercent": 90,
  "actualCost": "0.0048",
  "savedCost": "0.0452"
}
```

## Best Practices

1. **Run ingestion daily**: Catches player changes quickly
2. **Monitor skip rate**: Should be 80-90% after initial setup
3. **Check for trades**: During trade deadlines, skip rate drops (expected)
4. **Review embeddings**: Ensure important player changes are captured
5. **Backup embeddings**: Use `backup_to_storage` action regularly

## Related Files

- `supabase/functions/simple-ingestion/index.ts`: Embedding logic with change detection
- `supabase/migrations/20251019084000_add_profile_hash.sql`: Database schema
- `docs/player-data-architecture.md`: Overall architecture
- `docs/smart-bootstrap-guide.md`: Bootstrap system guide
