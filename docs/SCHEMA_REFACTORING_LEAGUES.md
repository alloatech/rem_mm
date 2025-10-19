# Schema Refactoring: Leagues Table Design

## Problem Identified

**Original (Flawed) Design:**
```sql
user_leagues (
  id UUID,
  app_user_id UUID,  -- ❌ WRONG: Each user gets their own copy of league data
  sleeper_league_id TEXT,
  league_name TEXT,
  scoring_settings JSONB,
  ...
)
UNIQUE(app_user_id, sleeper_league_id)
```

**Issues:**
1. **Data Duplication**: Same league data stored 12 times (once per user)
2. **Inconsistency Risk**: League settings could diverge between user records
3. **Storage Waste**: 12x storage for identical scoring rules, roster positions, etc.
4. **Update Complexity**: Updating league settings requires touching 12 records

## Solution Implemented

**New (Correct) Design:**

### 1. `leagues` Table (No User Reference)
```sql
leagues (
  id UUID PRIMARY KEY,
  sleeper_league_id TEXT UNIQUE,  -- ✅ One record per league
  league_name TEXT,
  season INTEGER,
  sport TEXT,
  league_type TEXT,
  total_rosters INTEGER,
  scoring_settings JSONB,  -- ✅ Stored once, shared by all
  roster_positions JSONB,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  last_synced TIMESTAMPTZ,
  is_active BOOLEAN
)
```

**Purpose**: Store league data once, no user reference

### 2. `league_memberships` Junction Table
```sql
league_memberships (
  id UUID PRIMARY KEY,
  app_user_id UUID REFERENCES app_users(id),
  league_id UUID REFERENCES leagues(id),
  joined_at TIMESTAMPTZ,
  is_active BOOLEAN,
  UNIQUE(app_user_id, league_id)  -- One membership per user per league
)
```

**Purpose**: Link users to leagues they participate in

### 3. `user_rosters` Table (Updated Reference)
```sql
user_rosters (
  ...
  league_id UUID REFERENCES leagues(id),  -- ✅ Now references leagues table
  sleeper_owner_id TEXT,
  team_name TEXT,
  ...
)
```

**Purpose**: Each roster belongs to one league

## Data Flow

### Before (Duplicated):
```
User A → user_leagues (league X data)
User B → user_leagues (league X data - DUPLICATE)
User C → user_leagues (league X data - DUPLICATE)
...12 copies of same data
```

### After (Normalized):
```
leagues → league X data (stored ONCE)
      ↑
      ├─ league_memberships → User A
      ├─ league_memberships → User B
      ├─ league_memberships → User C
      └─ ... (12 memberships, 1 league record)
```

## Migration Strategy

The migration (`20251019161000_refactor_leagues_schema.sql`) handles:

1. ✅ Create new `leagues` table
2. ✅ Create `league_memberships` junction table  
3. ✅ Migrate data from `user_leagues` to new structure:
   - Extract DISTINCT leagues (deduplication)
   - Create membership records for each user-league pair
4. ✅ Update `user_rosters` foreign key to reference `leagues`
5. ✅ Drop old `user_leagues` table
6. ✅ Setup RLS policies
7. ✅ Create helper function `get_user_leagues(sleeper_user_id)`

## Helper Function

```sql
CREATE FUNCTION get_user_leagues(p_sleeper_user_id TEXT)
RETURNS TABLE (...league fields...)
AS $$
BEGIN
  -- Sets RLS config automatically
  PERFORM set_config('app.current_sleeper_user_id', p_sleeper_user_id, true);
  
  -- Returns leagues user is a member of
  RETURN QUERY
  SELECT l.*
  FROM leagues l
  INNER JOIN league_memberships lm ON lm.league_id = l.id
  INNER JOIN app_users au ON au.id = lm.app_user_id
  WHERE au.sleeper_user_id = p_sleeper_user_id
    AND l.is_active = true
    AND lm.is_active = true
  ORDER BY l.season DESC, l.league_name;
END;
$$;
```

**Benefits**:
- Handles RLS configuration automatically
- Single function call from Flutter
- No manual session config needed
- Returns only active leagues for user

## RLS Policies

### `leagues` Table
```sql
-- Anyone can view active leagues (they're public data)
POLICY "Anyone can view active leagues"
  ON leagues FOR SELECT
  USING (is_active = true);

-- Service role can manage all
POLICY "Service role can manage leagues"
  ON leagues FOR ALL
  USING (auth.role() = 'service_role');
```

### `league_memberships` Table
```sql
-- Users can view their own memberships
POLICY "Users can view own memberships"
  ON league_memberships FOR SELECT
  USING (
    app_user_id IN (
      SELECT id FROM app_users 
      WHERE sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    )
  );
```

### `user_rosters` Table
```sql
-- Users can view rosters in their leagues
POLICY "Users can view rosters in their leagues"
  ON user_rosters FOR SELECT
  USING (
    league_id IN (
      SELECT lm.league_id 
      FROM league_memberships lm
      INNER JOIN app_users au ON au.id = lm.app_user_id
      WHERE au.sleeper_user_id = current_setting('app.current_sleeper_user_id', true)
    )
  );
```

## Edge Function Updates

### `user-sync/index.ts`

**`syncUserLeagues()` - Updated**:
```typescript
// OLD: Upsert to user_leagues with app_user_id
const leagueData = leagues.map(league => ({
  app_user_id: appUser.id,  // ❌ Duplicates data
  sleeper_league_id: league.league_id,
  ...
}))

// NEW: Upsert to leagues (no user ref) + create memberships
const leagueData = leagues.map(league => ({
  sleeper_league_id: league.league_id,  // ✅ No user ref
  league_name: league.name,
  ...
}))
await supabase.from('leagues').upsert(leagueData, {
  onConflict: 'sleeper_league_id'  // Deduplicates automatically
})

// Then create memberships
const membershipData = upsertedLeagues.map(league => ({
  app_user_id: appUser.id,
  league_id: league.id
}))
await supabase.from('league_memberships').upsert(membershipData)
```

**`syncUserRosters()` - Updated**:
```typescript
// OLD: Query user_leagues
const { data: userData } = await supabase
  .from('app_users')
  .select(`
    id,
    user_leagues (id, sleeper_league_id)  // ❌ Old table
  `)

// NEW: Query via league_memberships
const { data: userData } = await supabase
  .from('app_users')
  .select(`
    id,
    league_memberships!inner (
      league_id,
      leagues!inner (id, sleeper_league_id)  // ✅ New structure
    )
  `)
```

**`getRosteredPlayers()` - Updated**:
```typescript
// OLD: Query user_leagues
const leagueIds = userData.user_leagues.map(league => league.id)

// NEW: Query league_memberships
const { data: memberships } = await supabase
  .from('league_memberships')
  .select('league_id, app_users!inner(sleeper_user_id)')
  .eq('app_users.sleeper_user_id', sleeper_user_id)

const leagueIds = memberships.map(m => m.league_id)
```

## Flutter Service Updates

### `leagues_service.dart`

**Before**:
```dart
// Manual RLS config + direct query
await _supabase.rpc('set_config', params: {...});
final response = await _supabase
    .from('user_leagues')  // ❌ Old table
    .select()
    .eq('app_user_id', appUserId);
```

**After**:
```dart
// Single function call - RLS handled automatically
final response = await _supabase.rpc<List<dynamic>>(
  'get_user_leagues',  // ✅ Helper function
  params: {'p_sleeper_user_id': sleeperUserId},
);
```

**Benefits**:
- Simpler Flutter code
- No manual session config
- Automatic RLS handling
- Type-safe results

## Benefits of New Design

### 1. **No Data Duplication**
- ✅ League data stored once
- ✅ 12x storage reduction
- ✅ Single source of truth

### 2. **Consistency**
- ✅ All users see same league settings
- ✅ Updates propagate automatically
- ✅ No sync issues

### 3. **Scalability**
- ✅ Adding users doesn't duplicate league data
- ✅ Better query performance
- ✅ Reduced database size

### 4. **Maintainability**
- ✅ Clear separation of concerns
- ✅ Standard many-to-many pattern
- ✅ Easy to understand

### 5. **Flexibility**
- ✅ Can add league-wide features easily
- ✅ Can track membership history
- ✅ Can support league commissioners

## Database Verification

```sql
-- Check leagues (should have 1 record for 12-team league)
SELECT COUNT(*) FROM leagues;  -- Result: 1 ✅

-- Check memberships (should have 12 records)
SELECT COUNT(*) FROM league_memberships;  -- Result: 12 (when all synced)

-- Get user's leagues
SELECT * FROM get_user_leagues('872612101674491904');
-- Returns: Thor's Fantasy League (TFL) ✅

-- Check rosters reference correct table
SELECT ur.*, l.league_name
FROM user_rosters ur
INNER JOIN leagues l ON l.id = ur.league_id;  -- ✅ Works!
```

## Testing Checklist

### Backend
- [x] Migration applies cleanly
- [x] Old data migrated correctly
- [x] Foreign keys work
- [x] RLS policies function
- [x] Helper function returns data
- [x] Edge Function syncs leagues
- [x] Edge Function creates memberships
- [x] Edge Function syncs rosters

### Flutter
- [ ] App shows leagues
- [ ] League detail page works
- [ ] Rosters display correctly
- [ ] Avatar URLs work
- [ ] Team names display
- [ ] No hardcoded IDs remain

## Migration Commands

```bash
# Apply migration
cd /Users/thor/alloatech/dev/rem_mm
supabase db reset --local

# Sync user leagues
curl -X POST "http://localhost:54321/functions/v1/user-sync" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "sync_leagues",
    "sleeper_user_id": "872612101674491904"
  }'

# Verify in database
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  -c "SELECT * FROM get_user_leagues('872612101674491904');"
```

## Summary

**Before**: `user_leagues` duplicated league data 12x (once per user)

**After**: 
- `leagues` stores data once
- `league_memberships` links users to leagues
- `user_rosters` references normalized leagues table

**Result**: Proper relational design, no duplication, better performance! 🎉
