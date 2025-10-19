# Avatar System Fix - Edge Function Update
**Date:** October 19, 2025  
**Issue:** Roster cards showing generic avatars instead of actual user/team avatars

## Problem
The `user-sync` Edge Function was syncing rosters but **NOT** populating the `avatar_id` and `team_avatar_url` columns, even though:
- ✅ Columns existed in database (from migration `20251019180000_add_avatar_support.sql`)
- ✅ Flutter app was using `roster.avatarUrl` (correct)
- ✅ Sleeper API provides avatar data in `/v1/league/{id}/users` endpoint

## Root Cause
In `supabase/functions/user-sync/index.ts`, the `syncUserRosters()` function was:
1. ✅ Fetching user data from Sleeper API
2. ✅ Extracting `display_name` and `team_name`
3. ❌ **NOT** extracting `avatar` (user avatar ID)
4. ❌ **NOT** extracting `metadata.avatar` (team avatar URL)
5. ❌ **NOT** storing avatar fields in database

## Solution
Updated `supabase/functions/user-sync/index.ts` in `syncUserRosters()` function:

### Changes Made:
1. **Added avatar lookups:**
   ```typescript
   const userAvatarIds = new Map(users.map(u => [u.user_id, u.avatar || null]))
   const teamAvatarUrls = new Map(users.map(u => [u.user_id, u.metadata?.avatar || null]))
   ```

2. **Extract avatar data for each roster:**
   ```typescript
   const avatarId = userAvatarIds.get(roster.owner_id) || null
   const teamAvatarUrl = teamAvatarUrls.get(roster.owner_id) || null
   ```

3. **Store in database:**
   ```typescript
   .upsert({
     // ... existing fields ...
     avatar_id: avatarId,           // NEW
     team_avatar_url: teamAvatarUrl, // NEW
     // ... rest of fields ...
   })
   ```

## UI Enhancement - Owner Avatar
Added small user avatar next to owner name in roster cards:

### File: `lib/features/leagues/presentation/widgets/roster_card.dart`
```dart
Row(
  children: [
    // Small user avatar (10px radius)
    SleeperAvatar(
      avatarId: roster.avatarId,  // Uses USER avatar, not team
      fallbackText: roster.ownerDisplayName ?? 'U',
      radius: 10,
    ),
    const SizedBox(width: 6),
    Text(roster.ownerDisplayName ?? 'Unknown Owner', ...),
  ],
)
```

**Design:**
- Large avatar (24px) = Team avatar (or falls back to user avatar)
- Small avatar (10px) = Always user avatar next to owner name
- Provides visual distinction between team branding and user identity

## Testing
```bash
# 1. Re-sync rosters to populate avatars
curl POST /functions/v1/user-sync {"action":"sync_rosters"}

# 2. Verify database
psql> SELECT team_name, avatar_id, team_avatar_url FROM user_rosters;
# Result: ✅ All 12 rosters have avatar data

# 3. Hot reload Flutter app
# Result: ✅ Team avatars display correctly
# Result: ✅ Small user avatars appear next to owner names
```

## Files Changed
- ✅ `supabase/functions/user-sync/index.ts` - Added avatar extraction and storage
- ✅ `lib/features/leagues/presentation/widgets/roster_card.dart` - Added small user avatar

## Migration Status
**No migration needed** - These changes are:
1. Edge Function code (deployed, not database schema)
2. Flutter UI code (frontend only)

The database columns already exist from migration `20251019180000_add_avatar_support.sql`.

## Visual Result
**Before:**
```
[Generic] Team Name
          Owner Name
```

**After:**
```
[Team Avatar] Team Name
              [User] Owner Name
```

Where:
- `[Team Avatar]` = 48px diameter, uses team-specific avatar or user avatar
- `[User]` = 20px diameter, always uses user's personal Sleeper avatar

---
*Generated: October 19, 2025*  
*Addresses: Avatar display issues after schema refactoring*
