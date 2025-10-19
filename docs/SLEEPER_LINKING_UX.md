# Sleeper Account Linking UX Improvements

## Overview
Enhanced the user experience for linking and re-linking Sleeper accounts throughout the app with clear call-to-actions and seamless navigation.

## Changes Made

### 1. Home Tab Empty State Enhancement
**Location**: `lib/features/leagues/presentation/pages/home_tab.dart`

**Before**:
```dart
// Just showed text: "no leagues found - link your sleeper account to see leagues"
// No button or action to take
```

**After**:
```dart
// Shows:
// - Football icon
// - "no leagues found" heading
// - "link your sleeper account to see leagues" subtitle
// - "link sleeper account" button with icon
//   → Navigates to SleeperLinkPage
```

**User Flow**:
1. User logs in but has no Sleeper account linked
2. Home tab shows empty state with prominent button
3. Tap "link sleeper account" → Opens SleeperLinkPage
4. After successful linking → Auto-navigates back with leagues loaded

### 2. Profile Menu Re-Link Option
**Location**: `lib/features/profile/presentation/widgets/profile_menu.dart`

**Added**:
```dart
_MenuTile(
  icon: Icons.link,
  title: 're-link sleeper account',
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SleeperLinkPage(),
      ),
    );
  },
)
```

**User Flow**:
1. User taps profile icon (top right)
2. Profile menu drops down
3. Menu options:
   - view profile
   - settings
   - **re-link sleeper account** ← NEW
   - help & support
   - sign out
4. Tap "re-link sleeper account" → Opens SleeperLinkPage
5. Can update to different Sleeper account or refresh data

**Use Cases**:
- User wants to switch to a different Sleeper account
- User needs to refresh league/roster data
- User's Sleeper username changed
- Initial link had issues and needs retry

### 3. SleeperLinkPage Auto-Navigation
**Location**: `lib/features/auth/presentation/pages/sleeper_link_page.dart`

**Enhanced**:
```dart
// After successful linking:
1. Shows success message: "successfully linked to sleeper account!"
2. Invalidates auth providers (refresh user state)
3. Invalidates userLeaguesProvider (fetch new leagues)
4. Automatically navigates back: Navigator.of(context).pop()
```

**Before**:
- Success message shown but stayed on link page
- User had to manually tap back button
- Leagues didn't auto-refresh

**After**:
- Success message shown via SnackBar
- Automatically navigates back to previous screen
- Leagues immediately load (invalidated provider)
- Seamless experience - user sees their leagues right away

## Complete User Journeys

### Journey 1: New User First-Time Link
```
Login Page
  ↓ Sign in
Home Tab (empty state)
  ↓ Tap "link sleeper account" button
SleeperLinkPage
  ↓ Enter username, tap "link account"
Success! → Auto-navigate back
  ↓
Home Tab (with leagues!)
  ↓ Tap a league
League Detail Page (12 teams displayed)
```

### Journey 2: Existing User Re-Link
```
Home Tab (with leagues)
  ↓ Tap profile icon
Profile Menu
  ↓ Tap "re-link sleeper account"
SleeperLinkPage
  ↓ Enter new username, tap "link account"
Success! → Auto-navigate back
  ↓
Profile Menu (closes automatically)
  ↓
Home Tab (refreshed leagues)
```

### Journey 3: Error Recovery
```
Home Tab (empty state)
  ↓ Tap "link sleeper account"
SleeperLinkPage
  ↓ Enter invalid username
Error shown: "failed to link sleeper account: [error]"
  ↓ Fix username, try again
Success! → Auto-navigate back
  ↓
Home Tab (with leagues)
```

## UI Components

### Button Styling
```dart
ElevatedButton.icon(
  onPressed: () { /* Navigate to SleeperLinkPage */ },
  icon: const Icon(Icons.link),
  label: const Text('link sleeper account'),
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    ),
  ),
)
```

**Features**:
- Icon + text for clarity
- Proper padding for touch target
- Theme-consistent styling
- Lowercase text per project guidelines

### Empty State Layout
```
┌─────────────────────────────────┐
│                                 │
│          🏈 (icon)              │
│                                 │
│      no leagues found           │
│                                 │
│  link your sleeper account to   │
│        see leagues              │
│                                 │
│   ┌──────────────────────┐     │
│   │  🔗 link sleeper     │     │
│   │     account          │     │
│   └──────────────────────┘     │
│                                 │
└─────────────────────────────────┘
```

### Profile Menu Addition
```
┌──────────────────────────────┐
│  👤 th0rJC                   │
│     @th0rjc                  │
├──────────────────────────────┤
│  👤 view profile             │
│  ⚙️  settings                 │
│  🔗 re-link sleeper account  │  ← NEW
│  ❓ help & support            │
├──────────────────────────────┤
│  🚪 sign out                 │
└──────────────────────────────┘
```

## State Management

### Provider Invalidation Chain
```dart
// After successful link:
ref.invalidate(isLinkedToSleeperProvider);    // Auth status
ref.invalidate(currentSleeperUserIdProvider); // User ID
ref.invalidate(authStatusProvider);           // Overall auth
ref.invalidate(userLeaguesProvider);          // Leagues list ← NEW

// Triggers:
1. Auth providers re-fetch user data
2. userLeaguesProvider re-queries leagues
3. Home tab auto-updates with new data
4. League detail pages refresh rosters
```

### Navigation Handling
```dart
// In SleeperLinkPage after success:
if (mounted) {
  Navigator.of(context).pop(); // Go back to previous screen
}

// SnackBar persists across navigation:
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('successfully linked to sleeper account!')),
);
```

## Error Handling

### User-Friendly Error Messages
```dart
try {
  // Link account
} catch (error) {
  _showMessage('failed to link sleeper account: ${error.toString()}');
  // Stays on page - user can retry
}
```

**Error Scenarios**:
- Invalid username: "failed to link sleeper account: User not found"
- Network error: "failed to link sleeper account: Network error"
- Already linked: "failed to link sleeper account: Account already linked"

**Recovery**:
- Error shown via SnackBar
- User stays on form
- Can edit and retry immediately
- No need to navigate away

## Accessibility & UX Best Practices

### ✅ Clear Call-to-Action
- Empty state has prominent button
- Button text clearly states action
- Icon reinforces meaning

### ✅ Visual Hierarchy
- Icon at top (64px) draws attention
- Heading in title size
- Subtitle in smaller, grey text
- Button stands out with elevation

### ✅ User Feedback
- Success message confirms action
- Auto-navigation shows result immediately
- Loading indicator during processing
- Error messages explain what went wrong

### ✅ Multiple Entry Points
- Home tab empty state (first-time users)
- Profile menu (existing users, re-linking)
- Both lead to same SleeperLinkPage

### ✅ Seamless Navigation
- Auto-navigation after success
- Back button works if user cancels
- SnackBar persists across screens
- Providers auto-refresh

## Testing Checklist

### Manual Testing

#### First-Time Link Flow
- [ ] Login with new account (no Sleeper linked)
- [ ] Home tab shows empty state
- [ ] "link sleeper account" button visible
- [ ] Tap button → SleeperLinkPage opens
- [ ] Enter valid username → Success
- [ ] Auto-navigate back to home
- [ ] Leagues immediately visible
- [ ] Success SnackBar shows

#### Re-Link Flow
- [ ] User with existing Sleeper account
- [ ] Tap profile icon → Menu opens
- [ ] "re-link sleeper account" option visible
- [ ] Tap option → SleeperLinkPage opens
- [ ] Enter different username → Success
- [ ] Auto-navigate back to home
- [ ] New leagues loaded
- [ ] Profile menu closes

#### Error Handling
- [ ] Enter invalid username
- [ ] Error SnackBar shows with details
- [ ] Stays on form (doesn't navigate)
- [ ] Can edit and retry
- [ ] Success after fix

#### Edge Cases
- [ ] Tap link button while loading
- [ ] Tap back during API call
- [ ] Network timeout
- [ ] Empty username field
- [ ] Username with special characters
- [ ] Already linked account

## Code Quality

### Consistency
- ✅ Uses existing SleeperLinkPage (no duplication)
- ✅ Follows project navigation patterns
- ✅ Matches theme and styling guidelines
- ✅ Lowercase text per copilot-instructions

### Maintainability
- ✅ Single source of truth (SleeperLinkPage)
- ✅ Proper provider invalidation
- ✅ Mounted checks before navigation
- ✅ Reusable menu tile pattern

### Performance
- ✅ Lazy provider invalidation
- ✅ Only refreshes what's needed
- ✅ No unnecessary re-renders
- ✅ Efficient navigation stack

## Future Enhancements (Optional)

### 1. Link Status Indicator
```dart
// In home tab or profile:
if (isLinkedToSleeper) {
  Row(
    children: [
      Icon(Icons.check_circle, color: Colors.green),
      Text('sleeper account linked'),
    ],
  )
}
```

### 2. Last Sync Timestamp
```dart
Text('last synced: ${formatTimestamp(lastSyncedAt)}')
```

### 3. Automatic Re-Sync
```dart
// Button in league detail page:
ElevatedButton.icon(
  onPressed: () => ref.read(rosterSyncProvider(sleeperUserId).future),
  icon: Icon(Icons.sync),
  label: Text('sync now'),
)
```

### 4. Bulk Re-Link Confirmation
```dart
// Before re-linking, show dialog:
showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: Text('re-link sleeper account?'),
    content: Text('this will replace your current account data'),
    actions: [
      TextButton(child: Text('cancel'), onPressed: () => Navigator.pop(context)),
      TextButton(child: Text('re-link'), onPressed: _linkSleeperAccount),
    ],
  ),
)
```

### 5. Link Multiple Accounts
```dart
// Support multiple Sleeper accounts per user
// Switch between accounts in profile menu
```

## Summary

### What Changed
1. ✅ Home tab empty state now has a button to link Sleeper
2. ✅ Profile menu has "re-link sleeper account" option
3. ✅ SleeperLinkPage auto-navigates back after success
4. ✅ Leagues provider auto-refreshes after linking

### User Benefits
- 🎯 Clear path to link Sleeper account (no confusion)
- 🔄 Easy to re-link or switch accounts
- ⚡ Instant feedback - leagues load immediately
- 🚀 Seamless UX - minimal clicks, automatic navigation

### Developer Benefits
- 📦 Single SleeperLinkPage used everywhere
- 🔗 Proper provider invalidation chain
- 🧪 Testable navigation flow
- 📚 Clear user journeys documented
