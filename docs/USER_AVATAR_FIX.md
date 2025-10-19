# User Avatar vs Team Avatar Fix
**Date:** October 19, 2025  
**Issue:** Main page profile avatar needs to always show USER avatar, not team avatar

## Problem
The `UserAvatar` widget (displayed in app bar with profile menu) was using `profile?.avatarUrl`, which could be:
- A team-specific avatar URL (if user customized their team)
- The user's personal Sleeper avatar URL

This caused confusion because the profile avatar should **always** represent the user's personal identity, not their team branding.

## Design Philosophy
**Avatar Usage Strategy:**

1. **User Avatar** (Personal Identity)
   - User's profile menu (app bar)
   - Small avatar next to owner names in roster cards
   - Always uses Sleeper user's personal avatar ID

2. **Team Avatar** (Team Branding)
   - Large avatar on roster cards
   - League detail pages
   - Prioritizes team-specific custom avatar, falls back to user avatar

## Solution

### File: `lib/features/profile/presentation/widgets/user_avatar.dart`

**Changed from:**
```dart
backgroundImage: profile?.avatarUrl != null
    ? NetworkImage(profile!.avatarUrl!)
    : null,
```

**Changed to:**
```dart
// Always use user's personal avatar, never team avatar
final userAvatarUrl = profile?.avatarId != null
    ? 'https://sleepercdn.com/avatars/thumbs/${profile!.avatarId}'
    : null;

CircleAvatar(
  backgroundColor: Colors.white, // Changed from orange to white
  backgroundImage: userAvatarUrl != null
      ? NetworkImage(userAvatarUrl)
      : null,
  child: userAvatarUrl == null
      ? Text(
          profile?.sleeperUsername.substring(0, 1).toUpperCase() ?? 'U',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        )
      : null,
)
```

### Changes Made:
1. ✅ **Construct URL from `avatarId`** instead of using `avatarUrl`
   - Ensures we always use the user's personal Sleeper avatar
   - Never uses team-specific avatars in profile context

2. ✅ **Changed background color** from orange to white
   - More neutral appearance
   - Better contrast for avatar images

3. ✅ **Updated fallback text color** to use theme primary color
   - Better integration with app theme
   - Consistent with design system

### Verification
The `ProfileMenu` widget was already correct:
```dart
SleeperAvatar(
  avatarId: profile!.avatarId,  // ✅ Correct - uses user avatar
  fallbackText: profile!.displayName ?? profile!.sleeperUsername,
  radius: 24,
),
```

## Visual Distinction

**Before:**
- Profile avatar could show team logo
- Confusing when user has custom team avatar
- Background: Orange

**After:**
- Profile avatar ALWAYS shows user's personal Sleeper avatar
- Team avatars only used in team/roster contexts
- Background: White
- Clear separation between "who I am" vs "my team"

## Testing
```dart
// Scenario 1: User with custom team avatar
// Profile Avatar: User's personal Sleeper avatar ✅
// Team Card Avatar: Custom team logo ✅

// Scenario 2: User without custom team avatar
// Profile Avatar: User's personal Sleeper avatar ✅
// Team Card Avatar: Same user avatar (fallback) ✅
```

## Files Changed
- ✅ `lib/features/profile/presentation/widgets/user_avatar.dart` - Always use `avatarId` for user profile
- ✅ `lib/features/leagues/presentation/widgets/roster_card.dart` - Already correct (uses team avatar priority)
- ✅ `lib/features/profile/presentation/widgets/profile_menu.dart` - Already correct (uses `avatarId`)

## Related Work
- Avatar sync fix in `supabase/functions/user-sync/index.ts`
- Small user avatars added to roster cards
- See: `docs/AVATAR_SYNC_FIX.md`

---
*Generated: October 19, 2025*  
*Addresses: User vs team avatar confusion in profile display*
