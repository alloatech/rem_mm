# TODO: "My Team" Identification Feature

## Problem Statement
When a user belongs to multiple leagues, the system needs to reliably identify which team (roster) is "theirs" in each league for:
- Personalized advice ("Your QB1 is...", "You should start...")
- Lineup recommendations
- Trade analysis from their perspective
- Weekly projections for their specific team

## Current Implementation
**Status**: Partially works via `app_user_id` link

```sql
-- Current schema
user_rosters
  ├── app_user_id (UUID, nullable) ← Links to app_users when user registers
  ├── sleeper_owner_id (TEXT) ← Sleeper's user ID (always present)
  └── league_id (UUID) ← Which league this team belongs to

-- Query for "my teams"
SELECT * FROM user_rosters 
WHERE app_user_id = '<current_user_uuid>';
```

**Works For**:
- ✅ Users who register through our app (app_user_id gets linked)
- ✅ Single-account users (one Sleeper account)

**Breaks For**:
- ❌ User manages multiple Sleeper accounts (rare)
- ❌ User wants to follow league without owning team (spectator mode)
- ❌ User registers with different Sleeper ID than their league teams

## Proposed Solution (Phase 1)

### Database Changes
```sql
-- Migration: 20251020000000_add_my_team_flag.sql
ALTER TABLE user_rosters
ADD COLUMN is_my_team BOOLEAN DEFAULT NULL;

-- Index for fast "my teams" queries
CREATE INDEX idx_user_rosters_my_team 
ON user_rosters(app_user_id, is_my_team) 
WHERE is_my_team = TRUE;

-- Constraint: User can only mark ONE team per league as "mine"
CREATE UNIQUE INDEX idx_user_rosters_one_my_team_per_league
ON user_rosters(app_user_id, league_id)
WHERE is_my_team = TRUE;

-- Auto-set for obvious cases (when app_user_id matches sleeper_owner_id)
-- This covers 95% of users
UPDATE user_rosters ur
SET is_my_team = TRUE
WHERE ur.app_user_id IS NOT NULL
AND EXISTS (
  SELECT 1 FROM app_users au
  WHERE au.id = ur.app_user_id
  AND au.sleeper_user_id = ur.sleeper_owner_id
);
```

### Edge Case Handling
```sql
-- Case 1: User has multiple teams in same league (impossible per Sleeper rules)
-- Our UNIQUE constraint prevents this

-- Case 2: User wants to follow league without owning team
-- Solution: Don't set is_my_team for any roster in that league
-- UI shows "spectator mode" for that league

-- Case 3: User co-manages team with friend
-- Current: is_my_team = TRUE for both users
-- Future: Add role field (owner, co_owner, spectator)
```

## UI Implementation (Flutter)

### 1. Team Selection Screen (First-Time Setup)
When user registers and syncs leagues, show:

```dart
// After sync_leagues completes
for (var league in user.leagues) {
  // Fetch all rosters for this league
  final rosters = await fetchLeagueRosters(league.id);
  
  // Auto-detect user's team (if app_user_id matches)
  final myTeam = rosters.firstWhere(
    (r) => r.sleeperOwnerId == user.sleeperUserId,
    orElse: () => null
  );
  
  if (myTeam != null) {
    // Auto-set as "my team"
    await markAsMyTeam(myTeam.id);
  } else {
    // Show selection UI
    await showTeamSelectionDialog(league, rosters);
  }
}
```

### 2. Settings Screen (Change My Team)
Allow users to change which team is theirs:

```dart
// Settings → Leagues → Select League → Change My Team
LeagueSettingsScreen(
  league: currentLeague,
  currentMyTeam: currentTeam,
  allRosters: leagueRosters,
  onTeamSelected: (rosterId) async {
    await updateMyTeam(currentLeague.id, rosterId);
  }
)
```

### 3. Spectator Mode Toggle
```dart
// Allow users to mark league as "following only"
Switch(
  value: league.isSpectatorMode,
  onChanged: (value) async {
    if (value) {
      // Clear is_my_team for all rosters in this league
      await clearMyTeamForLeague(league.id);
    } else {
      // Show team selection
      await showTeamSelectionDialog(league);
    }
  }
)
```

## Backend Changes (Edge Functions)

### Update `user-sync` Function
```typescript
// After sync_rosters completes, auto-detect "my team"
async function autoDetectMyTeam(supabase: any, appUserId: string, sleeperUserId: string) {
  // Find rosters where sleeper_owner_id matches user's sleeper_user_id
  const { data: myRosters } = await supabase
    .from('user_rosters')
    .update({ is_my_team: true })
    .eq('app_user_id', appUserId)
    .eq('sleeper_owner_id', sleeperUserId)
    .select()
  
  return myRosters
}

// Call after sync_rosters
await autoDetectMyTeam(supabase, userData.id, sleeper_user_id)
```

### New Action: `set_my_team`
```typescript
case 'set_my_team':
  const { league_id, roster_id } = data
  
  // Clear existing "my team" for this league
  await supabase
    .from('user_rosters')
    .update({ is_my_team: false })
    .eq('app_user_id', appUserId)
    .eq('league_id', league_id)
  
  // Set new "my team"
  await supabase
    .from('user_rosters')
    .update({ is_my_team: true })
    .eq('id', roster_id)
    .eq('app_user_id', appUserId)
  
  break
```

## RAG Impact (AI Advice)

### Current Approach
```typescript
// hybrid-fantasy-advice function
const myRosters = await supabase
  .from('user_rosters')
  .select('player_ids')
  .eq('app_user_id', userId)
```

### Updated Approach
```typescript
// More explicit: get rosters marked as "mine"
const myRosters = await supabase
  .from('user_rosters')
  .select(`
    player_ids,
    team_name,
    league_id,
    user_leagues!inner (
      league_name,
      scoring_settings
    )
  `)
  .eq('app_user_id', userId)
  .eq('is_my_team', true)  // ← NEW: Explicit "my team" filter

// Build AI context
const context = myRosters.map(r => 
  `In ${r.user_leagues.league_name}, your team "${r.team_name}" has players: ${r.player_ids.join(', ')}`
).join('\n')
```

## Testing Strategy

### Test Cases
1. **Happy Path**: User registers → auto-detects team → is_my_team=TRUE
2. **Multiple Leagues**: User in 3 leagues → correctly identifies all 3 teams
3. **No Team**: User follows league without owning team → all is_my_team=NULL
4. **Manual Override**: User manually selects different team → updates correctly
5. **Constraint Test**: Try to set 2 teams as "mine" in same league → fails with error

### SQL Test Queries
```sql
-- Test 1: Verify one team per league
SELECT app_user_id, league_id, COUNT(*) as my_teams
FROM user_rosters
WHERE is_my_team = TRUE
GROUP BY app_user_id, league_id
HAVING COUNT(*) > 1;  -- Should return 0 rows

-- Test 2: Verify all registered users have at least one "my team"
SELECT au.sleeper_username, COUNT(ur.id) as my_teams_count
FROM app_users au
LEFT JOIN user_rosters ur ON ur.app_user_id = au.id AND ur.is_my_team = TRUE
GROUP BY au.id
HAVING COUNT(ur.id) = 0;  -- Should return 0 rows (unless spectator mode)

-- Test 3: Verify auto-detection worked
SELECT * FROM user_rosters
WHERE app_user_id IS NOT NULL
AND sleeper_owner_id IN (SELECT sleeper_user_id FROM app_users WHERE id = app_user_id)
AND is_my_team = FALSE;  -- Should return 0 rows
```

## Migration Path (Rollout)

### Phase 1: Add Column (Non-Breaking)
- Add `is_my_team` column with default NULL
- Deploy backend changes
- No UI changes yet
- Auto-detect runs on next roster sync

### Phase 2: Backfill Existing Users
```sql
-- Run once to set is_my_team for existing users
UPDATE user_rosters ur
SET is_my_team = TRUE
WHERE ur.app_user_id IS NOT NULL
AND EXISTS (
  SELECT 1 FROM app_users au
  WHERE au.id = ur.app_user_id
  AND au.sleeper_user_id = ur.sleeper_owner_id
);
```

### Phase 3: UI Changes (Flutter)
- Add team selection screen
- Add settings toggle
- Show "My Team" badge in UI

### Phase 4: Enforce NOT NULL (Future)
```sql
-- After all users have selected teams, make it required
ALTER TABLE user_rosters
ALTER COLUMN is_my_team SET DEFAULT FALSE;

-- Update any remaining NULLs
UPDATE user_rosters SET is_my_team = FALSE WHERE is_my_team IS NULL;

-- Make NOT NULL
ALTER TABLE user_rosters
ALTER COLUMN is_my_team SET NOT NULL;
```

## Deferred Until Needed
- Co-owner role management
- Historical "my team" changes (if user switches teams mid-season)
- Multi-account support (user has multiple Sleeper accounts)

## Priority: Medium
**Why Not Urgent**: 
- Current implementation works for 95% of users (single account, registers via app)
- Can be added incrementally without breaking changes
- Most valuable when app has multiple leagues per user

**When to Prioritize**:
- User feedback indicates confusion about "which team is mine"
- Analytics show users belong to 2+ leagues on average
- Ready to build advanced features (trade analyzer, lineup optimizer)

## Estimated Effort
- Database migration: 1 hour
- Backend changes: 2-3 hours
- Flutter UI: 4-6 hours (selection screen, settings, validation)
- Testing: 2-3 hours
- **Total: 1-2 days**
