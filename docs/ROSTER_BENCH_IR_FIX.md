# Roster Bench/IR Fix

## Problem
Roster detail page was showing incorrect player categorization:
- Missing bench players (Jaxson Dart, Calvin Ridley, Evan Engram)
- IR players (Conner, Wilson) showing in bench instead of IR section
- Only 2 "bench" players showing when should have been 3

## Root Cause
Misunderstanding of Sleeper API roster structure:

### Sleeper's Data Model:
```json
{
  "players": [15 total player IDs],
  "starters": [10 active lineup player IDs],
  "reserve": [2 IR player IDs],      // ⚠️ Singular, not plural!
  "taxi": [0 taxi squad IDs]         // Usually null/empty
}
```

**Key Issue**: Sleeper uses `reserve` (singular) for **IR players**, not bench players!

### Our Incorrect Mapping:
```typescript
// ❌ WRONG - we were storing IR as bench
reserves: roster.reserve || [],  // Sleeper's IR → our "reserves" column
taxi: roster.taxi || [],         // Sleeper's taxi → our "taxi" column
```

This meant:
- Our `reserves` column = IR players (Conner, Wilson)
- Our `taxi` column = empty
- **Bench players** = not stored anywhere! (Dart, Ridley, Engram lost)

## Solution

### Calculate Bench Players
Bench = All players NOT in starters AND NOT in IR AND NOT in taxi

```typescript
const allPlayers = roster.players || []
const starters = roster.starters || []
const reserve = roster.reserve || []  // Sleeper's IR
const taxi = roster.taxi || []

// Calculate bench: players - starters - reserve - taxi
const startersSet = new Set(starters)
const reserveSet = new Set(reserve)
const taxiSet = new Set(taxi)
const bench = allPlayers.filter(id => 
  !startersSet.has(id) && !reserveSet.has(id) && !taxiSet.has(id)
)
```

### Corrected Mapping:
```typescript
// ✅ CORRECT
player_ids: allPlayers,      // All 15 players
starters: starters,          // 10 active lineup
reserves: bench,             // 3 BENCH players (calculated)
taxi: reserve,               // 2 IR players (from Sleeper's "reserve")
```

## Data Verification

### Before Fix:
```
total | starters | reserves | taxi
------|----------|----------|------
  15  |    10    |     2    |   0
                 ↑ Only IR!  ↑ Empty
```

### After Fix:
```
total | starters | reserves (bench) | taxi (IR)
------|----------|------------------|----------
  15  |    10    |        3         |    2
```

### Player Breakdown:
**Bench (reserves column):**
- Jaxson Dart (QB, NYG)
- Calvin Ridley (WR, TEN)  
- Evan Engram (TE, DEN)

**IR (taxi column):**
- James Conner (RB, ARI)
- Garrett Wilson (WR, NYJ)

## Sleeper API Terminology Guide

| Sleeper API Field | Meaning | Our Column | UI Label |
|-------------------|---------|------------|----------|
| `players` | All roster players | `player_ids` | - |
| `starters` | Active lineup | `starters` | Starters |
| `reserve` | IR (injured reserve) | `taxi` | IR/Taxi |
| `taxi` | Taxi squad (dynasty) | (unused) | - |
| *calculated* | Bench players | `reserves` | Bench |

**Note**: We use `reserves` for bench and `taxi` for IR because that better matches fantasy football terminology from the user's perspective.

## Files Changed
- `supabase/functions/user-sync/index.ts` (lines 480-510)
  - Added bench calculation logic
  - Swapped reserve/taxi mapping to match user expectations

## Testing
1. Re-sync rosters: Call user-sync Edge Function with `sync_rosters` action
2. Query database to verify counts
3. Hot restart Flutter app
4. Check roster detail page - should show 3 bench + 2 IR

## Impact
- ✅ All roster players now visible
- ✅ Bench vs IR correctly categorized
- ✅ Matches Sleeper web app's display
- ✅ No data loss
