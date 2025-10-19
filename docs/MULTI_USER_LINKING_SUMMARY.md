# Multi-User Roster Linking - Implementation Summary

## What Changed

### Database Schema Update
**Migration**: `20251019085000_update_rosters_for_multi_user.sql`

**Changes to `user_rosters` table**:
1. ✅ Added `sleeper_owner_id TEXT` column - tracks Sleeper user ID of roster owner
2. ✅ Made `app_user_id` nullable - allows storing rosters before user registers
3. ✅ Updated UNIQUE constraint to `(league_id, sleeper_owner_id)` - prevents duplicate rosters per league
4. ✅ Added index on `sleeper_owner_id` - for efficient roster lookup during registration
5. ✅ Added helper function `link_user_rosters(p_app_user_id, p_sleeper_user_id)` - links rosters automatically

### Edge Function Update
**File**: `supabase/functions/user-sync/index.ts`

**Change**: Added automatic roster linking in `registerUser()` function
```typescript
// After user registration, link any existing rosters
const { data: linkResult } = await supabase
  .rpc('link_user_rosters', {
    p_app_user_id: user.id,
    p_sleeper_user_id: sleeperUser.user_id
  })

// Returns count of rosters linked (e.g., 3)
```

## How It Works Now

### Scenario 1: Admin Bootstraps System
```
1. Admin (th0rjc) logs in
2. Syncs their leagues → Fetches ALL rosters in each league
3. Stores rosters for all teams (some with app_user_id=NULL)
   ✅ admin's roster: app_user_id=<admin_id>, sleeper_owner_id="872612101674491904"
   ⏳ user2's roster: app_user_id=NULL, sleeper_owner_id="123456789"
   ⏳ user3's roster: app_user_id=NULL, sleeper_owner_id="987654321"
```

### Scenario 2: New User Registers
```
1. User2 signs up with email
2. Links their Sleeper account "123456789"
3. registerUser() automatically calls link_user_rosters()
4. Their roster (stored from admin's league sync) gets linked:
   ✅ user2's roster: app_user_id=<user2_id>, sleeper_owner_id="123456789"
5. User2 sees their roster immediately (no additional sync needed!)
```

## Benefits

### 1. Zero Friction for New Users ✅
- Register → See your roster immediately
- No "sync your data" step required
- Rosters already populated from league sync

### 2. Cost Optimization ✅
- Sync entire league once (FREE from Sleeper API)
- Identify ~150 unique rostered players across all teams
- Embed only those players ($0.015 vs $0.50 for all players)
- **97% cost savings on embeddings**

### 3. Data Consistency ✅
- One source of truth per league
- All users see the same opponent rosters
- Updates refresh everyone's view

### 4. Flexible User Onboarding ✅
- Users can register in any order
- Works whether they register before or after league sync
- No duplicate data issues

## Testing

### Verify Schema
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  -c "\d user_rosters"
```

**Expected**: 
- `sleeper_owner_id TEXT` column exists
- `app_user_id` nullable
- UNIQUE constraint on `(league_id, sleeper_owner_id)`

### Verify Function
```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  -c "\df link_user_rosters"
```

**Expected**: Function exists with signature `(p_app_user_id uuid, p_sleeper_user_id text) RETURNS integer`

### Test Registration Linking
```bash
# After running league sync with rosters, register a new user
curl -X POST "http://localhost:54321/functions/v1/user-sync" \
  -H "Authorization: Bearer <valid_jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "register_user",
    "sleeper_user_id": "123456789",
    "sleeper_username": "test_user"
  }'
```

**Expected Response**:
```json
{
  "success": true,
  "user": { ... },
  "linked_rosters": 3  // ← Number of rosters linked
}
```

## Next Steps

1. ✅ **Schema updated** - Multi-user roster support enabled
2. ✅ **Auto-linking implemented** - Users see rosters immediately
3. ⏳ **Build league-sync function** - Fetch leagues and ALL rosters
4. ⏳ **Update bootstrap script** - Add league sync step
5. ⏳ **Implement targeted embeddings** - Only embed rostered players

## Security Notes

- `app_user_id` can be NULL (unregistered users)
- RLS policies ensure users only see rosters in their leagues
- `link_user_rosters()` is SECURITY DEFINER (admin-only access via function)
- No sensitive data exposed (only Sleeper usernames and roster data)

## Documentation

Full details in: `docs/MULTI_USER_ROSTER_STRATEGY.md`
- Complete workflow diagrams
- Edge case handling
- Cost analysis
- Future enhancements
