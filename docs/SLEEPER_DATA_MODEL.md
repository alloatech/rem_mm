# Sleeper Data Model & Our Database Schema

## Sleeper's Hierarchy (Reality)

```
User (Owner)
  ├── League 1
  │     └── Roster (Team) - ONE roster per user per league
  │           ├── Team Name (metadata: p_nick_*)
  │           ├── Player IDs (roster)
  │           ├── Starters
  │           ├── Bench/Reserves
  │           └── Taxi Squad
  ├── League 2
  │     └── Roster (Team) - Different team, different league
  └── League 3
        └── Roster (Team)
```

## Key Facts from Sleeper API Analysis

### ✅ Confirmed Facts
1. **One Roster Per User Per League**: Each user can only have ONE roster (team) per league
2. **Co-owners**: Sleeper supports `co_owners` field (for sharing team management) but in practice it's rarely used (null in your league)
3. **Multiple Leagues**: Users can participate in MANY leagues (you're in 1, but users can be in 10+)
4. **Roster = Team**: In Sleeper terminology, "roster" and "team" are the same thing
5. **Team Names**: Stored in roster metadata as `p_nick_<player_id>` fields (e.g., "Everyone Loves the Drake")

### 📊 API Evidence
```bash
# From your league (1086432375392956416):
- 12 rosters total
- Each owner_id appears exactly ONCE (team_count: 1)
- co_owners: null for all rosters
- You (th0rjc/872612101674491904) have 1 team in 1 league
```

## Our Database Schema (Current)

### ✅ Current Structure
```
app_users (User)
  ├── sleeper_user_id (e.g., "872612101674491904")
  ├── sleeper_username (e.g., "th0rjc")
  └── display_name

user_leagues (League Membership)
  ├── app_user_id (FK → app_users)
  ├── sleeper_league_id (e.g., "1086432375392956416")
  ├── league_name (e.g., "Thor's Fantasy League (TFL)")
  └── scoring_settings, roster_positions, etc.

user_rosters (Team/Roster) ⭐ THIS IS THE TEAM
  ├── app_user_id (FK → app_users) - nullable until user registers
  ├── league_id (FK → user_leagues)
  ├── sleeper_owner_id (Sleeper's user ID for this team's owner)
  ├── sleeper_roster_id (1-12, position in league)
  ├── team_name ⭐ NEW (e.g., "Everyone Loves the Drake")
  ├── owner_display_name ⭐ NEW (e.g., "th0rjc")
  ├── player_ids (array of player IDs on this team)
  ├── starters (array of starter player IDs)
  ├── reserves, taxi, settings
  └── UNIQUE(league_id, sleeper_owner_id)
```

## Terminology Clarification

### ❌ Confusing Terms
- "Roster" sounds like just a list of players
- But in Sleeper: **Roster = Team** (the entire entity)

### ✅ Clear Terms
- **Team = Roster** (interchangeable)
- **League**: Competition container
- **Owner**: User who manages a team
- **Player IDs**: The actual NFL players on the team's roster

## Cardinality Rules

```
User : League = Many : Many
  - User can be in multiple leagues ✅
  - League has multiple users ✅

User : Team = 1 : Many
  - User can have many teams (one per league) ✅
  - Team belongs to one user ✅ (ignoring rare co_owners)

League : Team = 1 : Many
  - League has many teams (typically 8-14) ✅
  - Team belongs to one league ✅

User : Team (within same league) = 1 : 1 ⭐ CRITICAL
  - User can have AT MOST ONE team per league ✅
  - Enforced by: UNIQUE(league_id, sleeper_owner_id)
```

## What We Store

### Multi-User Strategy
We store **ALL teams** in every league, not just the authenticated user's team:

```sql
-- Example: Thor's Fantasy League has 12 teams
-- We store all 12 in user_rosters:

league_id: xyz-123-abc
├── roster 1: sleeper_owner_id=833849..., app_user_id=NULL (not registered)
├── roster 2: sleeper_owner_id=872170..., app_user_id=NULL (not registered)
├── roster 3: sleeper_owner_id=741785..., app_user_id=NULL (not registered)
...
├── roster 7: sleeper_owner_id=872612..., app_user_id=<UUID> ⭐ THIS IS YOU (th0rjc)
...
└── roster 12: sleeper_owner_id=872601..., app_user_id=NULL (not registered)
```

**Why?**
1. Cost Optimization: Embed players once for entire league (not per user)
2. Future-Ready: When other users register, just link their rosters
3. AI Context: System knows all teams for better advice ("You're playing against...")

## Future Enhancements (Deferred TODOs)

### 🔜 Priority 1: "My Team" Identification
**Problem**: When user belongs to multiple leagues, how do we know which team is "theirs" in each league?

**Current**: We rely on `app_user_id` link (works if user registered via our app)

**Edge Case**: User could register with different Sleeper account than the one they use in a league (rare but possible)

**Solution (Future)**:
```sql
ALTER TABLE user_rosters
ADD COLUMN is_my_team BOOLEAN DEFAULT FALSE;

-- User explicitly selects "This is my team" in UI
-- Especially important if:
-- - User manages multiple accounts
-- - Co-ownership scenarios
-- - User wants to follow league without owning team
```

### 🔜 Priority 2: Historical/Versioning
**Not Implemented Yet**: Point-in-time roster snapshots

**Future Needs**:
- Weekly roster snapshots (who started when)
- Trade history
- Waiver wire changes
- Season-over-season comparison

**Approach** (when needed):
- Option A: `user_roster_history` table with timestamps
- Option B: JSON audit log in `user_rosters.history_log`
- Option C: Use Supabase Realtime to capture changes

### 🔜 Priority 3: Co-Owners Support
**Current**: We store `sleeper_owner_id` (single owner)

**Future**: If co-ownership becomes common:
```sql
ALTER TABLE user_rosters
ADD COLUMN co_owner_ids TEXT[]; -- Array of Sleeper user IDs

-- Then link multiple app_users to same roster
-- via junction table: roster_owners(roster_id, app_user_id, role)
```

## Database Design Decisions

### ✅ Why `user_rosters` Not `user_teams`?
- Matches Sleeper terminology (rosters endpoint)
- Avoids confusion with NFL teams (KC, BUF, etc.)
- Common fantasy football term

### ✅ Why Store `sleeper_owner_id` AND `app_user_id`?
- `sleeper_owner_id`: Source of truth from Sleeper API (immutable)
- `app_user_id`: Our internal link (nullable, set when user registers)
- Enables multi-user storage before registration

### ✅ Why UNIQUE(league_id, sleeper_owner_id)?
- Enforces Sleeper's rule: one roster per user per league
- Prevents duplicate roster entries
- Enables upsert logic (update existing or insert new)

## Summary for Context

**Correct Mental Model**:
```
League → Has Many Teams (Rosters)
Team (Roster) → Belongs to One Owner (User)
Team (Roster) → Contains Many Players (player_ids array)
User → Can Have Many Teams (one per league)
User → Cannot Have Multiple Teams in Same League
```

**Our Implementation**:
- ✅ Stores all teams in all leagues (multi-user)
- ✅ Links teams to users via `app_user_id` (when registered)
- ✅ Tracks ownership via `sleeper_owner_id` (always)
- ✅ Prevents duplicates via UNIQUE constraint
- ⚠️ Doesn't yet handle "my team" UI selection (future)
- ⚠️ Doesn't yet version/snapshot changes (future)
- ⚠️ Doesn't yet handle co-owners (rare, defer)

**Current Status**: Point-in-time snapshot, single ownership model, works perfectly for 95% of use cases.
