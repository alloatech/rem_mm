# Multi-User Roster Strategy

## Overview
When syncing fantasy leagues, we fetch rosters for **ALL teams** in the league, not just the authenticated user's roster. This is necessary because:
1. Users need to see opponent rosters for analysis
2. League-wide player availability affects recommendations
3. Users may join a league where other members haven't registered yet

## How It Works

### 1. League Sync (First User)
When **User A** (e.g., th0rjc) syncs their leagues:
```
League: "The Championship"
├── Team 1: th0rjc (User A) ✅ Registered
├── Team 2: player_xyz ❌ Not registered yet
├── Team 3: fantasy_guru ❌ Not registered yet
└── Team 4: champ2024 ❌ Not registered yet
```

We store **all 4 rosters** in `user_rosters`:
```sql
-- User A's roster (linked immediately)
app_user_id: <th0rjc_id>
sleeper_owner_id: "872612101674491904"  -- th0rjc's Sleeper ID
league_id: <league_uuid>
player_ids: ["player1", "player2", ...]

-- User B's roster (not linked yet)
app_user_id: NULL  -- ⚠️ User hasn't registered
sleeper_owner_id: "123456789"  -- player_xyz's Sleeper ID
league_id: <league_uuid>
player_ids: ["player10", "player11", ...]
```

### 2. Later Registration (Second User)
When **User B** (player_xyz) registers later:

```typescript
// user-sync Edge Function automatically calls:
link_user_rosters(
  p_app_user_id: <new_user_id>,
  p_sleeper_user_id: "123456789"
)
```

This function:
1. Finds all rosters where `sleeper_owner_id = "123456789"` and `app_user_id IS NULL`
2. Updates them to set `app_user_id = <new_user_id>`
3. Returns count of rosters linked

**Result**: User B's existing roster data is now linked to their account automatically!

### 3. Refresh Strategy
When users log in or sync:
- Check `last_synced` timestamp on their rosters
- If > 24 hours old, refresh from Sleeper API
- This keeps data fresh without constant API calls

## Database Schema

### user_rosters Table
```sql
CREATE TABLE user_rosters (
  id UUID PRIMARY KEY,
  app_user_id UUID REFERENCES app_users(id),  -- NULL until user registers
  league_id UUID REFERENCES user_leagues(id),
  sleeper_owner_id TEXT NOT NULL,  -- Sleeper user ID (always present)
  sleeper_roster_id INTEGER NOT NULL,  -- Sleeper's roster identifier
  player_ids TEXT[],
  starters TEXT[],
  reserves TEXT[],
  taxi TEXT[],
  settings JSONB,
  last_synced TIMESTAMP WITH TIME ZONE,
  UNIQUE(league_id, sleeper_owner_id)  -- One roster per Sleeper user per league
);
```

**Key Points**:
- `app_user_id` can be NULL (unregistered users)
- `sleeper_owner_id` is always present (identifies the roster owner)
- UNIQUE constraint on `(league_id, sleeper_owner_id)` prevents duplicates
- No UNIQUE constraint on `app_user_id` (users can have multiple rosters across leagues)

## Edge Cases Handled

### Case 1: User Already Registered, Then Joins New League
✅ No conflict - their `app_user_id` is already set, new roster just references it

### Case 2: User Registers After Multiple League Syncs
✅ `link_user_rosters()` finds and links ALL their rosters across all leagues

### Case 3: User Has Multiple Teams in Same League
⚠️ Sleeper typically doesn't allow this, but if it happens, the UNIQUE constraint will catch it

### Case 4: Roster Refresh for Unregistered User
✅ We update based on `sleeper_owner_id`, not `app_user_id`, so it works fine

### Case 5: User Registers Twice (Different Email)
⚠️ They'll get two `app_users` records, but only one will link to their rosters (whoever registers last)
💡 Future: Add check to prevent duplicate Sleeper account linking

## Benefits

### 1. **Cost Optimization** ✅
- Fetch all roster data once per league (FREE from Sleeper API)
- Identify unique rostered players across all teams
- Only embed those ~150-200 players ($0.015-0.020)
- **97% savings** vs embedding all 2,964 players

### 2. **User Experience** ✅
- New users see their existing roster data immediately
- No "sync your rosters again" step
- Opponent rosters already available for analysis

### 3. **Data Consistency** ✅
- One source of truth per league (from first sync)
- All users see the same roster data for opponents
- Refresh updates everyone's view

## Usage in Bootstrap

```bash
# 1. Admin bootstraps system
./scripts/smart_bootstrap.sh
  → Auth as admin (th0rjc)
  → Fetch all players (FREE)
  → Sync admin's leagues (FREE)
  → Sync ALL rosters in those leagues (FREE)  # ← Includes other users' rosters
  → Identify unique rostered players (~150)
  → Embed only those players ($0.015)

# 2. Another user registers later
User player_xyz signs up with email
  → Links to Sleeper account "123456789"
  → link_user_rosters() automatically links their roster
  → User sees their roster data immediately
  → No additional API calls needed
```

## API Flow

```
User Registration:
1. POST /user-sync { action: "register_user", sleeper_user_id: "123456789" }
2. registerUser() creates app_users record
3. registerUser() calls link_user_rosters()
4. Returns: { success: true, linked_rosters: 3 }

League Sync (stores ALL rosters):
1. POST /user-sync { action: "sync_leagues", sleeper_user_id: "872612101674491904" }
2. syncUserLeagues() fetches user's leagues from Sleeper
3. syncUserRosters() fetches ALL rosters for each league
4. Stores rosters with sleeper_owner_id (some have app_user_id=NULL)
5. Returns: { leagues: 2, rosters: 24 }  # All rosters across all leagues
```

## Security Considerations

### Row Level Security (RLS)
Users can only see:
- ✅ Their own rosters (where `app_user_id = auth.uid()`)
- ✅ Rosters in leagues they're a member of
- ❌ Cannot see rosters in leagues they don't belong to

### Data Privacy
- Roster data is public within a league (expected for fantasy sports)
- User email/auth data never exposed
- Only Sleeper usernames and display names are visible

## Future Enhancements

### 1. Stale Data Detection
```sql
-- Find rosters that haven't been synced in 24+ hours
SELECT * FROM user_rosters 
WHERE last_synced < NOW() - INTERVAL '24 hours'
  AND app_user_id = auth.uid();
```

### 2. Automatic Refresh Trigger
```sql
-- Trigger to auto-refresh stale data when user logs in
CREATE OR REPLACE FUNCTION check_stale_rosters()
RETURNS TRIGGER AS $$
BEGIN
  -- If user hasn't synced in 24 hours, mark for refresh
  UPDATE user_rosters
  SET needs_refresh = true
  WHERE app_user_id = NEW.id
    AND last_synced < NOW() - INTERVAL '24 hours';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 3. Orphan Roster Cleanup
```sql
-- Find rosters where Sleeper user no longer exists in league
-- (Useful for cleaning up after trades/drops)
```

## Cost Analysis

### Traditional Approach (Embed All Players)
```
2,964 players × $0.0001 = $0.30 (initial)
Daily updates: 2,964 × $0.0001 = $0.30/day
Monthly: $9.00
```

### Smart Multi-User Approach
```
Initial:
- Fetch players: FREE
- Sync 2 leagues × 12 teams = 24 rosters: FREE
- Identify ~150 unique rostered players
- Embed 150 × $0.0001 = $0.015

Daily updates (with change detection):
- Most players unchanged: FREE (profile_hash check)
- ~15 changed players × $0.0001 = $0.0015/day
Monthly: $0.045

Savings: $9.00 - $0.045 = $8.955/month (99.5% reduction!)
```

## Summary

✅ **Store all rosters** when syncing leagues (not just authenticated user's roster)  
✅ **Link rosters automatically** when users register (via `link_user_rosters()`)  
✅ **Cost optimization** by embedding only rostered players (~150 vs 2,964)  
✅ **Better UX** with immediate data availability for new users  
✅ **Flexible architecture** handles users registering in any order
