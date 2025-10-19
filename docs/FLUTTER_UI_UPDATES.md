# Flutter UI Updates - Team Names & Multi-User Rosters

## Summary of Backend Changes Integrated

### 1. Team Names & Owner Display
- ✅ Real team names from Sleeper (e.g., "GlenSuckIt Rangers")
- ✅ Owner display names (e.g., "th0rJC")
- ✅ Avatar URLs templated from `sleeper_owner_id`
- ✅ Multi-user rosters (all 12 teams in league)

### 2. Data Models Created

#### `Roster` Model (`lib/features/leagues/domain/roster.dart`)
```dart
class Roster {
  final String sleeperOwnerId;  // For avatar URL templating
  final String? teamName;  // "GlenSuckIt Rangers"
  final String? ownerDisplayName;  // "th0rJC"
  final bool isCurrentUser;  // Computed from logged-in user
  
  // Computed properties
  String get avatarUrl => 'https://sleepercdn.com/avatars/thumbs/$sleeperOwnerId';
  String get displayName => '$teamName [$ownerDisplayName]';
  String get shortName => teamName ?? ownerDisplayName;
}
```

**Key Features:**
- Avatar URL is templated (not stored)
- Smart display logic: "Team Name [Owner]" or fallback to owner name
- isCurrentUser flag highlights user's own team
- All roster data (players, starters, reserves, taxi)

### 3. Services Created

#### `RostersService` (`lib/features/leagues/data/rosters_service.dart`)
```dart
class RostersService {
  Future<List<Roster>> getLeagueRosters(String leagueId);
  Future<Roster?> getCurrentUserRoster(String leagueId);
  Future<List<Roster>> getUserRosters();  // Across all leagues
  Future<void> syncUserRosters(String sleeperUserId);
}
```

**Features:**
- Fetches all rosters from `user_rosters` table
- Automatically computes `isCurrentUser` flag
- Handles avatar URL templating
- Multi-league support

### 4. Providers Created

#### Roster Providers (`lib/features/leagues/presentation/providers/leagues_providers.dart`)
```dart
// All rosters in a league
final leagueRostersProvider = FutureProvider.family<List<Roster>, String>((ref, leagueId) {...});

// User's rosters across all leagues
final userRostersProvider = FutureProvider<List<Roster>>((ref) {...});

// Current user's roster for specific league
final currentUserRosterProvider = FutureProvider.family<Roster?, String>((ref, leagueId) {...});

// Sync rosters from Sleeper
final rosterSyncProvider = FutureProvider.family<void, String>((ref, sleeperUserId) {...});
```

**Usage:**
```dart
// In any widget
final rostersAsync = ref.watch(leagueRostersProvider(leagueId));
```

### 5. Widgets Created

#### `RosterCard` Widget (`lib/features/leagues/presentation/widgets/roster_card.dart`)
```dart
RosterCard(
  roster: roster,
  onTap: () { /* Navigate to roster detail */ },
)
```

**Features:**
- Shows avatar (from templated URL)
- Team name with owner in subtitle
- "YOU" badge for current user's roster
- Player count display
- Material design card

**Visual Hierarchy:**
```
[Avatar] Team Name                    X players
         owner name                   [YOU]
```

#### `LeagueDetailPage` (`lib/features/leagues/presentation/pages/league_detail_page.dart`)
```dart
LeagueDetailPage(league: league)
```

**Features:**
- Shows all teams in league
- Sorts current user's team first
- League info header (season, team count, type)
- Refresh button
- Error handling with retry

### 6. Updated Pages

#### `HomeTab` (`lib/features/leagues/presentation/pages/home_tab.dart`)
**Before:**
```dart
Card(
  child: Text('league features coming soon...'),
)
```

**After:**
```dart
ListView of leagues
  → Tap league → LeagueDetailPage
    → Shows all 12 teams with avatars
      → Tap team → Roster detail (TODO)
```

## User Flow

### 1. Home Tab
```
┌─────────────────────────────────────┐
│  my leagues                         │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ 🛡️  Thor's Fantasy League     │ │
│  │    2024 season • 12 teams     │ │
│  │                            →  │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### 2. League Detail Page
```
┌─────────────────────────────────────┐
│ ← Thor's Fantasy League         🔄  │
├─────────────────────────────────────┤
│  2024 season • 12 teams             │
│  redraft                            │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐ │
│  │ 👤 GlenSuckIt Rangers         │ │
│  │    th0rJC                     │ │
│  │                    19 players │ │
│  │                         [YOU] │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │ 👤 #PugLyfe🏈💀                │ │
│  │    KeithMarsteller            │ │
│  │                    21 players │ │
│  └───────────────────────────────┘ │
│  ┌───────────────────────────────┐ │
│  │ 👤 BuffaLO Expectations       │ │
│  │    Macairns13                 │ │
│  │                    20 players │ │
│  └───────────────────────────────┘ │
│  ... (9 more teams)                 │
└─────────────────────────────────────┘
```

### 3. Avatar URL Templating

**How It Works:**
```dart
// In Roster model
String get avatarUrl => 'https://sleepercdn.com/avatars/thumbs/$sleeperOwnerId';

// In UI
CircleAvatar(
  backgroundImage: NetworkImage(roster.avatarUrl),
)
```

**Example URLs:**
- User with default avatar: `https://sleepercdn.com/avatars/thumbs/872612101674491904`
- User with custom avatar: `https://sleepercdn.com/uploads/b3ea51a07420e2e2f55b7a741ed5d0d5.jpg`

**Note:** The backend stores `sleeper_owner_id`, and the UI templates the full URL. Custom avatars are handled by Sleeper's CDN redirect.

## Key Features Implemented

### ✅ 1. Team Name Display
- **Primary:** "GlenSuckIt Rangers" (if custom name exists)
- **Fallback:** "th0rJC" (owner display name)
- **Last Resort:** "Team 11" (roster ID)

### ✅ 2. Multi-User Support
- Shows ALL 12 teams in league
- Not just current user's team
- Highlights current user with "YOU" badge
- Sorted with current user first

### ✅ 3. Avatar Integration
- Uses templated URL from `sleeper_owner_id`
- No database storage required
- Automatic fallback to default icon if fails

### ✅ 4. Data Consistency
- Backend schema: `user_rosters` table
- Fields used:
  - `sleeper_owner_id` → Avatar URL
  - `team_name` → Custom team name
  - `owner_display_name` → Owner username
  - `player_ids` → Roster players
  - `sleeper_roster_id` → Team identifier

### ✅ 5. Error Handling
- Loading states with CircularProgressIndicator
- Error states with retry button
- Empty states with helpful messages
- Image loading fallbacks

## Data Flow Diagram

```
User taps league
    ↓
LeagueDetailPage
    ↓
ref.watch(leagueRostersProvider(leagueId))
    ↓
RostersService.getLeagueRosters()
    ↓
Query: user_rosters WHERE league_id = ?
    ↓
For each roster:
  - Check if isCurrentUser (match sleeper_owner_id)
  - Template avatar URL
  - Build Roster model
    ↓
Return List<Roster>
    ↓
UI displays with RosterCard widgets
```

## Styling & Design

### Theme Alignment
- **Colors**: Uses theme colors (configurable)
- **Typography**: `Roboto Slab` body, `Raleway` headings
- **Spacing**: Consistent 16px padding
- **Cards**: Material elevation 1

### Key Visual Elements
```dart
// Avatar circle
CircleAvatar(radius: 20)  // 40px diameter

// Team name
TextStyle(fontWeight: FontWeight.bold)

// Owner name
TextStyle(fontSize: 12, color: Colors.grey[600])

// YOU badge
Container(
  backgroundColor: Colors.green,
  borderRadius: 12px,
  padding: 8x2,
  text: 'YOU' (white, bold, 10px)
)
```

## Future Enhancements (TODO)

### 1. Roster Detail Page
```dart
// Tap on RosterCard → Navigate to:
RosterDetailPage(roster: roster)
  - Shows all players with positions
  - Starters vs bench
  - Player stats integration
  - Trade/waiver history
```

### 2. Player Cards
```dart
PlayerCard(
  player: player,
  isStarter: true,
  // Shows player name, position, team, stats
)
```

### 3. Real-Time Updates
```dart
// Listen to roster changes
ref.listen(leagueRostersProvider(leagueId), (previous, next) {
  // Update UI when roster changes
});
```

### 4. Pull-to-Refresh
```dart
RefreshIndicator(
  onRefresh: () async {
    ref.invalidate(leagueRostersProvider(leagueId));
  },
  child: ListView(...),
)
```

### 5. Search & Filter
```dart
// Search by team name or owner
// Filter by current user only
// Sort by wins, points, etc.
```

## Testing Checklist

### ✅ Manual Testing Required

1. **League List Display**
   - [ ] Shows all user's leagues
   - [ ] Displays league name, season, team count
   - [ ] Navigation works to league detail

2. **Team Display**
   - [ ] Shows all 12 teams in league
   - [ ] Current user's team has "YOU" badge
   - [ ] Current user's team sorted first
   - [ ] Avatars load correctly
   - [ ] Fallback to default icon works

3. **Team Names**
   - [ ] Shows custom names (e.g., "GlenSuckIt Rangers")
   - [ ] Falls back to owner name when no custom name
   - [ ] Falls back to "Team X" when no owner name

4. **Data Consistency**
   - [ ] Matches bootstrap script output
   - [ ] All 166 rostered players accounted for
   - [ ] DEF/K players not breaking UI (26 players)

5. **Error Scenarios**
   - [ ] Network error shows retry button
   - [ ] Empty league shows helpful message
   - [ ] Image load failure shows default icon

## Code Quality

### ✅ Best Practices Applied

1. **Riverpod Patterns**
   - FutureProvider for async data
   - Provider.family for parameterized queries
   - Proper invalidation on updates

2. **Error Handling**
   - Try-catch in services
   - AsyncValue.when in UI
   - User-friendly error messages

3. **Performance**
   - Lazy loading with providers
   - Efficient list rendering
   - Image caching (NetworkImage)

4. **Maintainability**
   - Separate domain models
   - Service layer abstraction
   - Reusable widgets
   - Clear naming conventions

## Migration Notes

### Backend Schema Required
The UI expects the following database schema from recent migrations:

```sql
-- user_rosters table
CREATE TABLE user_rosters (
  id UUID PRIMARY KEY,
  app_user_id UUID REFERENCES app_users(id),  -- NULL if not registered
  league_id UUID REFERENCES user_leagues(id),
  sleeper_owner_id TEXT NOT NULL,  -- For avatar URL
  sleeper_roster_id INT NOT NULL,
  team_name TEXT,  -- Custom team name
  owner_display_name TEXT,  -- Owner username
  player_ids TEXT[],
  starters TEXT[],
  reserves TEXT[],
  taxi TEXT[],
  settings JSONB,
  last_synced TIMESTAMP,
  UNIQUE(league_id, sleeper_owner_id)
);
```

### Migrations Applied
1. `20251019085000_update_rosters_for_multi_user.sql` - Multi-user schema
2. `20251019120000_add_roster_names.sql` - Added team_name, owner_display_name
3. `20251019140000_remove_team_avatar_url.sql` - Removed redundant avatar storage

## Summary

### What's New in the UI
1. ✅ **Roster Model** - Complete domain model with smart display logic
2. ✅ **RostersService** - Data fetching and sync operations
3. ✅ **Roster Providers** - Riverpod state management
4. ✅ **RosterCard Widget** - Reusable team display component
5. ✅ **LeagueDetailPage** - Full league view with all teams
6. ✅ **Updated HomeTab** - Shows leagues list with navigation

### What Users See
- 📱 League list on home tab
- 👥 All 12 teams with avatars
- 🏆 Custom team names highlighted
- 🎯 "YOU" badge on their team
- 🔄 Refresh and error handling

### Next Steps
- [ ] Build roster detail page (player list)
- [ ] Add player cards with stats
- [ ] Implement pull-to-refresh
- [ ] Add search/filter capabilities
- [ ] Real-time roster updates
