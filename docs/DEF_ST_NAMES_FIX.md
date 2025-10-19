# DEF/ST Team Names Fix

## Problem
DEF/ST (Defense/Special Teams) players were showing as null names in the roster detail view because:
1. Sleeper API provides `first_name` (city) and `last_name` (mascot) for DEF teams
2. Our ingestion was only capturing `full_name` (which is null for DEF)
3. Player model wasn't using first/last names for display

## Solution

### 1. Fixed Data Ingestion (`supabase/functions/simple-ingestion/index.ts`)
**Added fields to capture DEF/ST names:**
```typescript
const batchData = playerBatch.map(([playerId, player]) => ({
  player_id: playerId,
  full_name: (player as any).full_name,
  first_name: (player as any).first_name,  // ✅ NEW: City name for DEF
  last_name: (player as any).last_name,    // ✅ NEW: Mascot name for DEF
  position: (player as any).position,
  // ... rest of fields
}))
```

### 2. Updated Player Model (`lib/features/players/domain/player.dart`)
**Enhanced `displayName` getter to handle DEF/ST:**
```dart
String get displayName {
  if (fullName != null && fullName!.isNotEmpty) {
    return fullName!;  // Regular players
  }
  // For DEF/ST: Sleeper provides first_name=city, last_name=mascot
  if (firstName != null && lastName != null) {
    return '$firstName $lastName';  // "Buffalo Bills", "Los Angeles Rams"
  }
  if (firstName != null) return firstName!;
  if (lastName != null) return lastName!;
  return playerId; // Fallback
}
```

## Data Source: Sleeper API

Sleeper provides proper team names in their players endpoint:

```json
{
  "BUF": {
    "player_id": "BUF",
    "position": "DEF",
    "first_name": "Buffalo",      // ✅ City name
    "last_name": "Bills",          // ✅ Mascot name
    "team": "BUF",
    "active": true
  },
  "LAR": {
    "player_id": "LAR",
    "position": "DEF",
    "first_name": "Los Angeles",   // ✅ City name
    "last_name": "Rams",           // ✅ Mascot name
    "team": "LAR",
    "active": true
  }
}
```

## Database Changes

**Before Fix:**
```
player_id | full_name | first_name | last_name | position
----------|-----------|------------|-----------|----------
LAR       | null      | null       | null      | DEF
BUF       | null      | null       | null      | DEF
```

**After Fix:**
```
player_id | full_name | first_name  | last_name | position
----------|-----------|-------------|-----------|----------
LAR       | null      | Los Angeles | Rams      | DEF
BUF       | null      | Buffalo     | Bills     | DEF
```

## Why This Approach?

1. **Data from Sleeper**: No static mapping needed - Sleeper maintains team names
2. **Handles Changes**: If teams relocate or rebrand, Sleeper updates it automatically
3. **Consistent Format**: Same pattern for all DEF/ST teams
4. **No Extra Complexity**: Uses existing first_name/last_name fields

## Alternative Considered (Not Implemented)

Creating a separate "Party" class to represent both organizations (teams) and people (players):
- **Pros**: More architecturally pure, type-safe distinction
- **Cons**: Adds complexity, Sleeper already provides the data we need
- **Decision**: Keep it simple - use Sleeper's data structure

## Testing

Run bootstrap to re-ingest players:
```bash
./scripts/complete_bootstrap.sh
```

Verify DEF/ST names in database:
```sql
SELECT player_id, first_name, last_name 
FROM players_raw 
WHERE position = 'DEF' 
LIMIT 5;
```

Expected results: All DEF teams show city + mascot (e.g., "Buffalo Bills")

## Impact

- ✅ DEF/ST players now display as "City Mascot" in roster views
- ✅ No static mapping needed - always up-to-date from Sleeper
- ✅ Works automatically for all 32 NFL teams
- ✅ Position badges still show "DEF" correctly
